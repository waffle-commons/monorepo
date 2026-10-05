import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { CockpitStatus, DodRun, DodView } from '../types'
import { applyLine, emptyRun, excerptOf, LineSplitter, summaryOf } from './dod'
import { verdictOf } from './guard'
import { dirtyComponentsOf, dirtyCountOf, phaseOf } from './status'

const PLUGIN = 'waffle-cockpit'
const PANE = 'waffle-dod'
const CONTAINER = 'waffle-dev'

/** How often the band refreshes on its own, and the least time between two refreshes. */
const REFRESH_EVERY_MS = 5 * 60_000
const REFRESH_GAP_MS = 20_000

/** Bash commands after which the band is refreshed. */
const REFRESHES_STATUS = /^\s*(git|wfl|bin\/wfl|\.\/bin\/wfl|docker)\b/

/** A component name as `wfl dod` takes it. */
const COMPONENT = /^[a-z0-9][a-z0-9-]*$/

const status = atom({ plugin: 'waffle-cockpit', key: 'status' } as const, null)
const dod = atom({ plugin: 'waffle-cockpit', key: 'dod' } as const, null)
const isBandHidden = atom({ plugin: 'waffle-cockpit', key: 'isBandHidden' } as const, false)

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
} = { rootPromise: undefined, refreshing: undefined, lastRefreshAt: 0, lastContainer: '', isDodRunning: false }

/** Work started without awaiting (a refresh, a /dod run) reports nothing when it fails. */
const ignoreFailure = (): undefined => undefined

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

/** Refreshes the band's status; a refresh already running is shared, not doubled. */
function refresh($: EngineInterface, force = false): Promise<void> {
  local.refreshing ??= readStatus($, force).finally(() => {
    local.refreshing = undefined
  })
  return local.refreshing
}

/** A refresh of its own for an explicit request: waits out any running one, then reads afresh. */
async function refreshNow($: EngineInterface): Promise<void> {
  await local.refreshing?.catch(ignoreFailure)
  await refresh($, true)
}

async function readStatus($: EngineInterface, force: boolean): Promise<void> {
  const root = await rootOf($)
  if (root === undefined) return
  const now = await $.clock.now()
  if (!force && now - local.lastRefreshAt < REFRESH_GAP_MS) return
  local.lastRefreshAt = now
  {
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
 * Registers the cockpit. Inside the waffle-commons umbrella it draws the
 * status band, serves /dod and /cockpit and guards Bash calls; anywhere else
 * it stays silent and lets everything through.
 *
 * @param on the engine's registrar
 */
export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    const root = await rootOf($, e.cwd)
    if (root === undefined) return started

    await $.command.register({
      name: 'dod',
      description: 'Run wfl dod in a pane, with no model turn (components, or --changed)',
      argumentHint: '<component…> | --changed',
    })
    await $.command.register({
      name: 'cockpit',
      description: 'Refresh the Waffle status band, or show / hide it',
      argumentHint: '[show|hide]',
    })
    void refresh($, true).catch(ignoreFailure)
    $.clock.every(REFRESH_EVERY_MS, () => void refresh($).catch(ignoreFailure))

    return started
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if ((await rootOf($)) === undefined) return next(e)

    const verdict = verdictOf(e.command)
    if (verdict !== undefined) return { deny: `${PLUGIN}: ${verdict}` }

    const ran = await next(e)
    if (REFRESHES_STATUS.test(e.command)) void refresh($).catch(ignoreFailure)
    return ran
  })

  on('command.run', { command: 'cockpit' }, async ($, e) => {
    if ((await rootOf($)) === undefined) return { text: 'Not inside the waffle-commons umbrella.' }
    const word = e.args.trim()
    if (word === 'hide') {
      await update($, isBandHidden, () => true)
      return { text: 'Waffle status band hidden (/cockpit show brings it back).' }
    }
    await update($, isBandHidden, () => false)
    await refreshNow($)
    const now = await read($, status)
    return {
      text:
        now === null
          ? 'The Waffle status is unavailable right now.'
          : `${now.phase || now.branch} · ${CONTAINER} ${now.container} · ${now.dirty ?? '?'} dirty · igor ${now.igor || '?'}`,
    }
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

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey || (await read($, isBandHidden))) return next(e)
    const now = await read($, status)
    if (now === null) return next(e)

    const { Box, Text, Button } = $.ui.resolve(e)
    const isUp = now.container === 'running'

    return (
      <Box flexDirection="row">
        <Text bold>{now.phase === '' ? '◆ ' : `◆ ${now.phase}  `}</Text>
        <Text dimColor wrap="truncate">{`${now.branch}  `}</Text>
        <Text color={isUp ? 'green' : 'red'}>{`${CONTAINER} ${isUp ? '●' : '○'} `}</Text>
        <Text dimColor>{` ${now.dirty === null ? '?' : now.dirty} dirty · igor ${now.igor || '?'} `}</Text>
        <Button key="hide" label="Hide" plain onPress={() => update($, isBandHidden, () => true)} />
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
