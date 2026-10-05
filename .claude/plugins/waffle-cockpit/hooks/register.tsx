import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { CockpitStatus, DodRun, DodView, RepoInfo, SessionInfo } from '../types'
import { applyLine, emptyRun, excerptOf, LineSplitter, summaryOf } from './dod'
import { verdictOf } from './guard'
import { dirtyComponentsOf, dirtyCountOf, phaseOf } from './status'
import { linesOf } from './view'
import type { Tone } from './view'

const PLUGIN = 'waffle-cockpit'
const PANE = 'waffle-dod'
const CONTAINER = 'waffle-dev'

/** One timer drives the lines: the session every tick, the repository every other, the umbrella every tenth. */
const TICK_MS = 30_000
/** The least time between two umbrella refreshes, and between two `gh pr view`. */
const REFRESH_GAP_MS = 20_000
const PR_GAP_MS = 5 * 60_000

/** Bash commands after which the repository and umbrella lines are refreshed. */
const REFRESHES_STATUS = /^\s*(git|gh|wfl|bin\/wfl|\.\/bin\/wfl|docker)\b/

/** A component name as `wfl dod` takes it. */
const COMPONENT = /^[a-z0-9][a-z0-9-]*$/

const status = atom({ plugin: 'waffle-cockpit', key: 'status' } as const, null)
const session = atom({ plugin: 'waffle-cockpit', key: 'session' } as const, null)
const repo = atom({ plugin: 'waffle-cockpit', key: 'repo' } as const, null)
const dod = atom({ plugin: 'waffle-cockpit', key: 'dod' } as const, null)
const isHidden = atom({ plugin: 'waffle-cockpit', key: 'isHidden' } as const, false)

const EMPTY_SESSION: SessionInfo = {
  model: '',
  effort: '',
  contextPercent: null,
  contextTokens: null,
  contextWindow: null,
  costUsd: null,
  startedAt: null,
  limits: [],
  cacheRead: 0,
  cacheInput: 0,
  lastTurnAt: null,
}

/**
 * The module's own state. A reload is a fresh load of the module, so this
 * starts over with it; what the drawing reads lives in `$.state` instead.
 */
const local: {
  rootPromise: Promise<string | undefined> | undefined
  refreshing: Promise<void> | undefined
  lastRefreshAt: number
  lastContainer: string
  isDodRunning: boolean
  ticks: number
  pr: RepoInfo['pr']
  prCheckedAt: number
  prBranch: string
} = {
  rootPromise: undefined,
  refreshing: undefined,
  lastRefreshAt: 0,
  lastContainer: '',
  isDodRunning: false,
  ticks: 0,
  pr: null,
  prCheckedAt: -PR_GAP_MS,
  prBranch: '',
}

/** Work started without awaiting (a refresh, a /dod run) reports nothing when it fails. */
const ignoreFailure = (): undefined => undefined

/** Text props for a segment's tone. */
function propsOf(tone: Tone): { dimColor?: boolean; bold?: boolean; color?: string } {
  if (tone === 'plain') return {}
  if (tone === 'dim') return { dimColor: true }
  if (tone === 'bold') return { bold: true }
  return { color: tone }
}

/** The umbrella root: the nearest directory holding both bin/wfl and .gitmodules. */
async function findRoot($: EngineInterface, start: string): Promise<string | undefined> {
  let dir = start.replace(/\/+$/, '')
  while (dir !== '') {
    if ((await $.fs.exists(`${dir}/bin/wfl`)) && (await $.fs.exists(`${dir}/.gitmodules`))) return dir
    dir = dir.slice(0, dir.lastIndexOf('/'))
  }
  return undefined
}

function rootOf($: EngineInterface, start?: string): Promise<string | undefined> {
  local.rootPromise ??= (async () => findRoot($, start ?? (await $.session.cwd())))().catch(() => undefined)
  return local.rootPromise
}

async function textOf($: EngineInterface, argv: string[], cwd: string, timeoutMs: number): Promise<string | undefined> {
  try {
    const { exitCode, stdout } = await $.process.run(argv, { cwd, timeoutMs })
    return exitCode === 0 ? stdout : undefined
  } catch {
    return undefined
  }
}

/** Context, cost, limits and start time, as the session reports them (a free call). */
async function refreshSession($: EngineInterface): Promise<void> {
  const usage = await $.session.usage()
  await update($, session, (was): SessionInfo => ({
    ...(was ?? EMPTY_SESSION),
    contextPercent: usage.context.percent ?? null,
    contextTokens: usage.context.tokens ?? null,
    contextWindow: usage.context.window,
    costUsd: usage.cost?.usd ?? null,
    startedAt: usage.startedAt,
    limits: usage.rateLimits.map(limit => ({ kind: limit.kind, percent: limit.percentUsed, resetsAt: limit.resetsAt ?? '' })),
  }))
}

/** The repository of the working directory: branch, changed paths, diff size, and its open PR (from gh, at most every five minutes). */
async function refreshRepo($: EngineInterface): Promise<void> {
  const cwd = await $.session.cwd()
  const top = await textOf($, ['git', 'rev-parse', '--show-toplevel'], cwd, 3_000)
  if (top === undefined) {
    await update($, repo, () => null)
    return
  }
  const [branch, porcelain, shortstat] = await Promise.all([
    textOf($, ['git', 'rev-parse', '--abbrev-ref', 'HEAD'], cwd, 3_000),
    textOf($, ['git', 'status', '--porcelain', '--ignore-submodules=all'], cwd, 5_000),
    textOf($, ['git', 'diff', '--shortstat', '--ignore-submodules=all', 'HEAD'], cwd, 5_000),
  ])
  const name = (branch ?? '?').trim()
  const now = await $.clock.now()
  if (name !== local.prBranch || now - local.prCheckedAt >= PR_GAP_MS) {
    local.prBranch = name
    local.prCheckedAt = now
    const json = await textOf($, ['gh', 'pr', 'view', '--json', 'number,reviewDecision,isDraft'], cwd, 10_000)
    local.pr = null
    if (json !== undefined) {
      try {
        const pr = JSON.parse(json) as { number?: unknown; reviewDecision?: unknown; isDraft?: unknown }
        if (typeof pr.number === 'number') {
          local.pr = { number: pr.number, review: pr.isDraft === true ? 'DRAFT' : typeof pr.reviewDecision === 'string' ? pr.reviewDecision : '' }
        }
      } catch {
        local.pr = null
      }
    }
  }
  const stat = shortstat ?? ''
  const next: RepoInfo = {
    repo: top.trim().slice(top.trim().lastIndexOf('/') + 1),
    branch: name,
    dirty: (porcelain ?? '').split('\n').filter(line => line.trim() !== '').length,
    added: Number(/(\d+) insertions?\(\+\)/.exec(stat)?.[1] ?? 0),
    removed: Number(/(\d+) deletions?\(-\)/.exec(stat)?.[1] ?? 0),
    pr: local.pr,
  }
  await update($, repo, () => next)
}

/** Refreshes the umbrella's status; a refresh already running is shared, not doubled. */
function refresh($: EngineInterface, force = false): Promise<void> {
  local.refreshing ??= readStatus($, force).finally(() => {
    local.refreshing = undefined
  })
  return local.refreshing
}

/** Everything, for an explicit request: waits out any running umbrella refresh, then reads afresh. */
async function refreshNow($: EngineInterface): Promise<void> {
  await local.refreshing?.catch(ignoreFailure)
  await Promise.all([refresh($, true), refreshSession($), refreshRepo($)])
}

/** One timer tick: the session every time, the repository every other, the umbrella every tenth. */
async function tick($: EngineInterface): Promise<void> {
  local.ticks += 1
  await refreshSession($)
  if (local.ticks % 2 === 0) await refreshRepo($)
  if (local.ticks % 10 === 0) await refresh($)
}

async function readStatus($: EngineInterface, force: boolean): Promise<void> {
  const root = await rootOf($)
  if (root === undefined) return
  const now = await $.clock.now()
  if (!force && now - local.lastRefreshAt < REFRESH_GAP_MS) return
  local.lastRefreshAt = now
  const [branch, container, changed, igor] = await Promise.all([
    textOf($, ['git', '-C', root, 'rev-parse', '--abbrev-ref', 'HEAD'], root, 5_000),
    textOf($, ['docker', 'inspect', '-f', '{{.State.Status}}', CONTAINER], root, 5_000),
    textOf($, [`${root}/scripts/changed-components.sh`], root, 30_000),
    $.fs.read(`${root}/.igor-version`).catch(() => ''),
  ])
  const next: CockpitStatus = {
    branch: branch?.trim() ?? '?',
    phase: phaseOf(branch ?? ''),
    container: container?.trim() || 'absent',
    dirty: changed === undefined ? null : (dirtyCountOf(changed) ?? null),
    igor: igor.trim(),
  }
  await update($, status, () => next)
  if (local.lastContainer === 'running' && next.container !== 'running') {
    $.ui.toast(`${CONTAINER} is ${next.container}: start it with \`wfl up\``)
  }
  local.lastContainer = next.container
}

async function runDod($: EngineInterface, root: string, components: string[]): Promise<void> {
  local.isDodRunning = true
  let runs: DodRun[] = components.map(emptyRun)
  const publish = (isActive: boolean) => update($, dod, (): DodView => ({ runs, isActive }))
  await publish(true)
  try {
    for (const [index, component] of components.entries()) {
      let run = runs[index] ?? emptyRun(component)
      const setRun = async (next: DodRun) => {
        run = next
        runs = runs.map((one, i) => (i === index ? next : one))
        await publish(true)
      }
      const splitters = { stdout: new LineSplitter(), stderr: new LineSplitter() }
      try {
        const child = $.process.spawn({ argv: [`${root}/bin/wfl`, 'dod', component], cwd: root })
        for await (const chunk of child) {
          let next = run
          for (const line of splitters[chunk.stream].push(chunk.text)) next = applyLine(next, line)
          if (next !== run) await setRun(next)
        }
        let next = run
        for (const line of [...splitters.stdout.flush(), ...splitters.stderr.flush()]) next = applyLine(next, line)
        const ended = await child.result
        if (next.verdict === 'running') {
          next = ended.code === 0 ? { ...next, verdict: 'pass' } : { ...next, verdict: 'fail', error: next.error || `wfl dod exited ${ended.code ?? ended.signal ?? '?'}` }
        }
        await setRun(next)
      } catch (error) {
        await setRun({ ...run, verdict: 'fail', error: `could not run wfl dod: ${error instanceof Error ? error.message : String(error)}` })
      }
    }
  } finally {
    local.isDodRunning = false
    await publish(false)
    const failed = runs.filter(run => run.verdict !== 'pass').map(run => run.component)
    $.ui.toast(failed.length === 0 ? `DoD PASS: ${components.join(', ')}` : `DoD FAIL: ${failed.join(', ')}`)
    void refresh($, true).catch(ignoreFailure)
  }
}

/**
 * Registers the cockpit: three lines under the prompt in every project (model,
 * context, cache, cost, limits, repository, PR), plus inside the waffle-commons
 * umbrella the Waffle segments, /dod and the Bash guard. Outside the umbrella
 * the guard lets everything through.
 *
 * @param on the engine's registrar
 */
export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    const model = await $.session.model().catch(() => '')
    await update($, session, (was): SessionInfo => ({ ...(was ?? EMPTY_SESSION), model }))
    await $.command.register({
      name: 'cockpit',
      description: 'Refresh the cockpit lines under the prompt, or show / hide them',
      argumentHint: '[show|hide]',
    })
    void refreshSession($).catch(ignoreFailure)
    void refreshRepo($).catch(ignoreFailure)
    $.clock.every(TICK_MS, () => void tick($).catch(ignoreFailure))

    const root = await rootOf($, e.cwd)
    if (root !== undefined) {
      await $.command.register({
        name: 'dod',
        description: 'Run wfl dod in a pane, with no model turn (components, or --changed)',
        argumentHint: '<component…> | --changed',
      })
      void refresh($, true).catch(ignoreFailure)
    }

    return started
  })

  on('turn.step', async function* ($, e, next) {
    if (e.agentId === undefined) {
      const effort = e.effort === undefined ? '' : String(e.effort)
      await update($, session, (was): SessionInfo => ({ ...(was ?? EMPTY_SESSION), model: e.model, effort }))
    }
    return yield* next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    if (e.agentId === undefined) {
      const at = await $.clock.now()
      const usage = e.usage
      await update($, session, (was): SessionInfo => {
        const base = was ?? EMPTY_SESSION
        if (usage === undefined) return { ...base, lastTurnAt: at }
        const input = usage.input_tokens + usage.cache_read_input_tokens + usage.cache_creation_input_tokens
        return { ...base, cacheRead: base.cacheRead + usage.cache_read_input_tokens, cacheInput: base.cacheInput + input, lastTurnAt: at }
      })
      void refreshSession($).catch(ignoreFailure)
      void refreshRepo($).catch(ignoreFailure)
    }
    return done
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const root = await rootOf($)
    if (root !== undefined) {
      const verdict = verdictOf(e.command)
      if (verdict !== undefined) return { deny: `${PLUGIN}: ${verdict}` }
    }

    const ran = await next(e)
    if (REFRESHES_STATUS.test(e.command)) {
      void refreshRepo($).catch(ignoreFailure)
      if (root !== undefined) void refresh($).catch(ignoreFailure)
    }
    return ran
  })

  on('command.run', { command: 'cockpit' }, async ($, e) => {
    const word = e.args.trim()
    if (word === 'hide') {
      await update($, isHidden, () => true)
      return { text: 'Cockpit lines hidden (/cockpit show brings them back).' }
    }
    await update($, isHidden, () => false)
    await refreshNow($)
    const now = await read($, session)
    const where = await read($, repo)
    const waffle = await read($, status)
    const parts = [
      now?.contextPercent === null || now?.contextPercent === undefined ? 'ctx —' : `ctx ${Math.round(now.contextPercent)}%`,
      where === null ? '' : `${where.repo} ⎇ ${where.branch}`,
      waffle === null ? '' : `${waffle.phase || waffle.branch} · ${CONTAINER} ${waffle.container} · igor ${waffle.igor || '?'}`,
    ]
    return { text: parts.filter(part => part !== '').join(' │ ') }
  })

  on('command.run', { command: 'dod' }, async ($, e) => {
    const root = await rootOf($)
    if (root === undefined) return { text: 'Not inside the waffle-commons umbrella.' }
    if (local.isDodRunning) return { text: 'A /dod run is already in progress (see the DoD pane).' }

    const words = e.args.trim().split(/\s+/).filter(word => word !== '')
    let components: string[]
    if (words.length === 1 && words[0] === '--changed') {
      components = dirtyComponentsOf((await textOf($, [`${root}/scripts/changed-components.sh`], root, 30_000)) ?? '')
      if (components.length === 0) return { text: 'No component has uncommitted changes.' }
    } else if (words.length === 0) {
      const inside = (await $.session.cwd()).slice(root.length + 1).split('/')[0] ?? ''
      if (inside === '') return { text: 'Usage: /dod <component…> | --changed' }
      components = [inside]
    } else {
      components = words
    }
    const invalid = components.filter(component => !COMPONENT.test(component))
    if (invalid.length > 0) return { text: `Not a component name: ${invalid.join(', ')}` }

    void runDod($, root, components).catch(ignoreFailure)
    await $.ui.open({ id: PANE, title: 'DoD' })
    return { text: `Running wfl dod for ${components.join(', ')} in the DoD pane.` }
  })

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    if (await read($, isHidden)) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    const lines = linesOf({
      session: await read($, session),
      repo: await read($, repo),
      waffle: await read($, status),
      now: await $.clock.now(),
      hint: e.props.hint,
    })

    return (
      <Box flexDirection="column">
        {lines.map((line, row) => (
          <Box key={`line-${row}`} flexDirection="row">
            {line.map((segment, i) => (
              <Text key={`seg-${row}-${i}`} wrap="truncate" {...propsOf(segment.tone)}>
                {segment.text}
              </Text>
            ))}
          </Box>
        ))}
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const view = await read($, dod)

    if (view === null) {
      return <Text dimColor>No /dod run yet. Try /dod contracts, or /dod --changed.</Text>
    }

    const icon = (state: string) =>
      state === 'pass' ? '✓' : state === 'fail' ? '✗' : state === 'running' ? '…' : state === 'skipped' ? '–' : '·'
    const hasFailure = view.runs.some(run => run.verdict === 'fail')

    return (
      <Box flexDirection="column">
        {view.runs.map(run => (
          <Box key={run.component} flexDirection="column">
            <Text bold color={run.verdict === 'pass' ? 'green' : run.verdict === 'fail' ? 'red' : undefined}>
              {`${icon(run.verdict)} ${run.component}${run.verdict === 'running' ? '' : run.verdict === 'pass' ? '  PASS' : '  FAIL'}`}
            </Text>
            {run.error !== '' && <Text color="red">{`  ${run.error}`}</Text>}
            {run.steps
              .filter(step => step.state !== 'pending')
              .map(step => (
                <Box key={`${run.component}-${step.name}`} flexDirection="column">
                  <Text color={step.state === 'fail' ? 'red' : undefined} wrap="truncate">
                    {`  ${icon(step.state)} ${step.name}  ${step.message}`}
                  </Text>
                  {step.excerpt.slice(0, 8).map((line, i) => (
                    <Text key={`${run.component}-${step.name}-${i}`} dimColor wrap="truncate">{`      ${line}`}</Text>
                  ))}
                </Box>
              ))}
          </Box>
        ))}
        {!view.isActive && (
          <Box flexDirection="row">
            <Button
              key="send"
              label="Send verdict to Claude"
              hotkey="s"
              onPress={() => $.prompt.fill({ text: `${summaryOf(view.runs)}\n`, mode: 'insert' })}
            />
            {hasFailure && (
              <Button key="copy" label="Copy failing excerpt" hotkey="c" onPress={() => $.ui.copy({ text: excerptOf(view.runs), surface: e.surface })} />
            )}
          </Box>
        )}
      </Box>
    )
  })
}
