import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer } from 'claude-code'

import type { AuditStatus, AuditView, CockpitStatus, DodRecord, DodRun, DodView, Job, JobState, RepoInfo, SessionInfo } from '../types'
import {
  AUDIT_RUN,
  AUDIT_VERSION,
  auditRunOf,
  auditStatusOf,
  branchVersionOf,
  choiceOf,
  decisionsTextOf,
  findingsOf,
  firstOf,
  notStarted,
  optionLabelOf,
  requiresAudit,
} from './audit'
import { applyLine, emptyRun, excerptOf, LineSplitter, summaryOf } from './dod'
import {
  EMPTY_EVIDENCE,
  isGated,
  lintContextOf,
  localOf,
  placeOf,
  recordOf,
  runsOfOutput,
  staleOf,
  stopReasonOf,
  withEdit,
  withGreen,
  withRecords,
} from './evidence'
import { isSecretPath, verdictOf } from './guard'
import {
  backgrounded,
  dropped,
  ended,
  evented,
  jobOf,
  liveOf,
  notificationsOf,
  oneLine,
  pruned,
  started,
  startedCommand,
  stateOf,
  withAgents,
} from './jobs'
import { optionsOf } from './options'
import type { CockpitOptions } from './options'
import { dirtyComponentsOf, dirtyCountOf, phaseOf } from './status'
import { isLedgerPath, ledgerVerdictOf, mixedVerdictOf, secretVerdictOf } from './strict'
import { duration, elapsed, JOB_ICONS, linesOf } from './view'
import type { Tone } from './view'

const PLUGIN = 'waffle-cockpit'
const PANE = 'waffle-dod'
const JOBS_PANE = 'waffle-jobs'
const AUDIT_PANE = 'waffle-audit'
const CONTAINER = 'waffle-dev'

/** One timer drives the lines: the session every tick, the repository every other, the umbrella every tenth. */
const TICK_MS = 30_000
/** While a command runs, the lines redraw this often so its running time moves. */
const PULSE_MS = 1_000
/** The least time between two umbrella refreshes, and between two `gh pr view`. */
const REFRESH_GAP_MS = 20_000
const PR_GAP_MS = 5 * 60_000

/** Bash commands after which the repository and umbrella lines are refreshed. */
const REFRESHES_STATUS = /^\s*(git|gh|wfl|bin\/wfl|\.\/bin\/wfl|docker)\b/

/** A component name as `wfl dod` takes it. */
const COMPONENT = /^[a-z0-9][a-z0-9-]*$/

/** Bash commands whose output may hold `wfl dod` verdicts. */
const RUNS_DOD = /(^|[\s/;&|(])(wfl|dod\.sh)\b[^;&|]*\bdod\b|scripts\/dod\.sh/

/** How often the local-only count and the backup age are read. */
const LOCAL_GAP_MS = 5 * 60_000

/** Where the store keeps the DoD history across sessions. */
const HISTORY_KEY = 'dodHistory'

/** The model-callable tools, as `$.tool.register` names them. */
const TOOL_DOD = `mcp__${PLUGIN}__dod`
const TOOL_XREF = `mcp__${PLUGIN}__xref`
const TOOL_GAPS = `mcp__${PLUGIN}__coverage_gaps`
const TOOL_HISTORY = `mcp__${PLUGIN}__dod_history`

const status = atom({ plugin: 'waffle-cockpit', key: 'status' } as const, null)
const session = atom({ plugin: 'waffle-cockpit', key: 'session' } as const, null)
const repo = atom({ plugin: 'waffle-cockpit', key: 'repo' } as const, null)
const dod = atom({ plugin: 'waffle-cockpit', key: 'dod' } as const, null)
const jobs = atom({ plugin: 'waffle-cockpit', key: 'jobs' } as const, [])
const pulse = atom({ plugin: 'waffle-cockpit', key: 'pulse' } as const, 0)
const evidence = atom({ plugin: 'waffle-cockpit', key: 'evidence' } as const, EMPTY_EVIDENCE)
const history = atom({ plugin: 'waffle-cockpit', key: 'history' } as const, {})
const isHidden = atom({ plugin: 'waffle-cockpit', key: 'isHidden' } as const, false)
const auditView = atom({ plugin: 'waffle-cockpit', key: 'auditView' } as const, null)

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
  options: CockpitOptions
  components: Promise<ReadonlySet<string>> | undefined
  localOnly: number | null
  backupAgeS: number | null
  localCheckedAt: number
  /** Per component, the edit time a stop reminder already named, so it is not repeated for the same edits. */
  reminded: Record<string, number>
  /** Numbers the commands that came without a `tool_use_id`. */
  commands: number
  /** Commands started and not yet ended, counted at once (the job list follows a moment later). */
  runningCommands: number
  /** The redraw timer, alive only while a command runs or lingers. */
  pulseTimer: Timer | undefined
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
  options: optionsOf(undefined),
  components: undefined,
  localOnly: null,
  backupAgeS: null,
  localCheckedAt: -LOCAL_GAP_MS,
  reminded: {},
  commands: 0,
  runningCommands: 0,
  pulseTimer: undefined,
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

/** The umbrella's components, from scripts/list-components.sh (read once). */
function componentsOf($: EngineInterface, root: string): Promise<ReadonlySet<string>> {
  local.components ??= textOf($, [`${root}/scripts/list-components.sh`], root, 10_000).then(
    out => new Set((out ?? '').split('\n').map(line => line.trim()).filter(line => line !== '')),
  )
  return local.components
}

/**
 * Runs a host command to its end through `$.process.spawn` (no time cap, as
 * `wfl dod` and `coverage:gaps` can outlast `process.run`'s ten minutes) and
 * hands back its exit code and both streams joined.
 */
async function collect($: EngineInterface, argv: string[], cwd: string, env?: Record<string, string>): Promise<{ code: number | null; output: string }> {
  const child = $.process.spawn(env === undefined ? { argv, cwd } : { argv, cwd, env })
  let output = ''
  for await (const chunk of child) output += chunk.text
  const ended = await child.result
  return { code: ended.code, output }
}

/** A field of a plugin tool's input, which the engine passes beside `tool`. */
function fieldOf(e: object, key: string): unknown {
  return Reflect.get(e, key)
}

/** Remembers finished `wfl dod` runs: the history (kept across sessions) and, for a pass, the evidence. */
async function recordRuns($: EngineInterface, runs: readonly DodRun[]): Promise<void> {
  if (runs.length === 0) return
  const at = await $.clock.now()
  const records = runs.map(run => recordOf(run, at))
  await update($, history, was => withRecords(was, records))
  await update($, evidence, was => records.filter(record => record.verdict === 'pass').reduce((acc, record) => withGreen(acc, record.component, at), was))
  await $.store.set(HISTORY_KEY, await read($, history))
}

/** Loads the DoD history the store kept from earlier sessions. */
async function loadHistory($: EngineInterface): Promise<void> {
  const kept = await $.store.get(HISTORY_KEY)
  if (typeof kept !== 'object' || kept === null) return
  const records: DodRecord[] = Object.values(kept).filter(
    (value): value is DodRecord =>
      typeof value === 'object' && value !== null && typeof Reflect.get(value, 'component') === 'string' && typeof Reflect.get(value, 'at') === 'number',
  )
  await update($, history, was => withRecords(records.reduce<Record<string, DodRecord>>((acc, r) => ({ ...acc, [r.component]: r }), {}), Object.values(was)))
}

/** Mago on one edited PHP file, inside the container: what the model should read, or undefined when clean. */
/** How long between two looks at the container's copy of an edited file, and how many looks at most. */
const SYNC_GAP_MS = 100
const SYNC_TRIES = 15

/**
 * Whether the container sees the file as the host wrote it. Docker's file sharing can show a just-written
 * file with its old size for a moment (the new text cut at the old length), and Mago then reports parse
 * errors or unused imports that are not there. Waits for the two sizes to match, `SYNC_TRIES` looks at most.
 */
async function caughtUp($: EngineInterface, root: string, component: string, inner: string): Promise<boolean> {
  const text = await $.fs.read(`${root}/${component}/${inner}`).catch(() => undefined)
  if (text === undefined) return true
  const size = new TextEncoder().encode(text).length
  for (let look = 0; look < SYNC_TRIES; look++) {
    if (look > 0) await $.clock.sleep(SYNC_GAP_MS)
    const seen = await textOf($, ['docker', 'exec', CONTAINER, 'stat', '-c', '%s', `/waffle-commons/${component}/${inner}`], root, 5_000)
    if (Number((seen ?? '').trim()) === size) return true
  }
  return false
}

async function instantLint($: EngineInterface, root: string, component: string, inner: string): Promise<string | undefined> {
  const mode = local.options.instantLint
  if (mode === 'off' || (await read($, status))?.container !== 'running') return undefined
  // A check of a copy the container has not caught up with reports what is not there: skip it.
  if (!(await caughtUp($, root, component, inner))) return undefined
  const base = ['docker', 'exec', '-w', `/waffle-commons/${component}`, CONTAINER, 'vendor/bin/mago']
  const outputs: string[] = []
  for (const sub of mode === 'lint' ? ['lint'] : ['lint', 'analyze']) {
    try {
      const run = await $.process.run([...base, sub, inner], { cwd: root, timeoutMs: 30_000 })
      outputs.push(`${run.stdout}\n${run.stderr}`)
    } catch {
      return undefined
    }
  }
  return lintContextOf(component, inner, outputs)
}

/** What an Edit or Write is about to change: the text before and after, as far as the call shows it. */
async function changeOf($: EngineInterface, e: { tool: string; file_path: string; old_string?: string; new_string?: string; content?: string }): Promise<{ before: string; after: string }> {
  if (e.tool === 'Edit') return { before: e.old_string ?? '', after: e.new_string ?? '' }
  const before = await $.fs.read(e.file_path).catch(() => '')
  return { before, after: e.content ?? '' }
}

/** A release audit ledger's whole text before and after an Edit or Write, so its decisions compare. */
async function ledgerTextsOf($: EngineInterface, e: { tool: string; file_path: string; old_string?: string; new_string?: string; content?: string }): Promise<{ before: string; after: string }> {
  const before = await $.fs.read(e.file_path).catch(() => '')
  if (e.tool !== 'Edit') return { before, after: e.content ?? '' }
  const old = e.old_string ?? ''
  const replacement = e.new_string ?? ''
  if (old === '') return { before, after: before }
  const after = Reflect.get(e, 'replace_all') === true ? before.split(old).join(replacement) : before.replace(old, () => replacement)
  return { before, after }
}

/**
 * Why an Edit or Write is refused (a secret anywhere; new `mixed` in waffle-commons PHP; a change to a
 * release audit's decisions, whatever the guard setting), or undefined.
 */
async function editVerdictOf($: EngineInterface, e: { tool: string; file_path: string; old_string?: string; new_string?: string; content?: string }): Promise<string | undefined> {
  const { options } = local
  if (isLedgerPath(e.file_path)) {
    const whole = await ledgerTextsOf($, e)
    const ledger = ledgerVerdictOf(e.file_path, whole.before, whole.after)
    if (ledger !== undefined) return ledger
  }
  const { before, after } = await changeOf($, e)
  if (options.secretScan) {
    const secret = secretVerdictOf(before, after, e.file_path)
    if (secret !== undefined) return secret
  }
  const root = await rootOf($)
  if (options.guard === 'strict' && root !== undefined && e.file_path.endsWith('.php') && e.file_path.startsWith(`${root}/`)) {
    const inner = e.file_path.slice(root.length + 1)
    if (!/(^|\/)(vendor|contributions)\//.test(inner)) return mixedVerdictOf(before, after)
  }
  return undefined
}

/** After an Edit or Write landed: the evidence it stales, and Mago's instant word on a PHP file. */
async function afterEdit($: EngineInterface, path: string): Promise<string | undefined> {
  const root = await rootOf($)
  if (root === undefined) return undefined
  const place = placeOf(root, path, await componentsOf($, root))
  if (place === undefined || !isGated(place.inner)) return undefined
  const at = await $.clock.now()
  await update($, evidence, was => withEdit(was, place.component, at))
  return place.inner.endsWith('.php') ? instantLint($, root, place.component, place.inner) : undefined
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

/**
 * Applies a change to the background jobs, dropping those ended a while ago.
 * Callers do not await it: bookkeeping never holds up or fails a tool call.
 */
async function changeJobs($: EngineInterface, change: (was: Job[], now: number) => Job[]): Promise<void> {
  const now = await $.clock.now()
  await update($, jobs, was => pruned(change(was, now), now, local.options.jobLingerSeconds * 1000))
}

/** The call's own id, else a fresh one for a command the engine gave none. */
function commandIdOf(toolUseId: string | undefined): string {
  if (toolUseId !== undefined && toolUseId !== '') return toolUseId
  local.commands += 1
  return `command-${local.commands}`
}

/**
 * Puts a foreground command on the work line and starts the redraw pulse; resolves once the job is
 * recorded. The call it tracks never waits for it.
 */
function startCommand($: EngineInterface, id: string, label: string, detail: string): Promise<void> {
  local.runningCommands += 1
  local.pulseTimer ??= $.clock.every(PULSE_MS, () => void beat($).catch(ignoreFailure))
  return changeJobs($, (was, now) => startedCommand(was, jobOf('command', id, label, detail, now))).catch(ignoreFailure)
}

/** Ends a command once its start is recorded, so a fast command never ends before it began. */
function endCommand($: EngineInterface, shown: Promise<void>, change: (was: Job[], now: number) => Job[]): void {
  local.runningCommands = Math.max(0, local.runningCommands - 1)
  void shown.then(() => changeJobs($, change)).catch(ignoreFailure)
}

/** Runs a script as a command on the work line: running, then ticked, or crossed when `isOk` says it failed. */
async function tracked<T>($: EngineInterface, label: string, work: () => Promise<T>, isOk: (value: T) => boolean): Promise<T> {
  const id = commandIdOf(undefined)
  const shown = startCommand($, id, label, label)
  let state: JobState = 'killed'
  try {
    const value = await work()
    state = isOk(value) ? 'completed' : 'failed'
    return value
  } finally {
    endCommand($, shown, (was, now) => ended(was, id, state, now))
  }
}

/**
 * One pulse: a redraw, so a running command's time moves and an ended one leaves on time. The timer stops
 * once no command runs or lingers; the running count is read after the last await, so a command starting
 * meanwhile keeps it alive.
 */
async function beat($: EngineInterface): Promise<void> {
  const now = await $.clock.now()
  const isShown = pruned(await read($, jobs), now, local.options.jobLingerSeconds * 1000).some(job => job.kind === 'command')
  if (!isShown && local.runningCommands === 0) {
    local.pulseTimer?.cancel()
    local.pulseTimer = undefined
  }
  await update($, pulse, beats => beats + 1)
}

/** Ends or counts the jobs a delivered task notification names; a failed one raises a toast. */
async function noticeJobs($: EngineInterface, text: string): Promise<void> {
  const notices = notificationsOf(text)
  if (notices.length === 0) return
  const before = await read($, jobs)
  await changeJobs($, (was, now) =>
    notices.reduce((acc, notice) => (notice.status === '' ? evented(acc, notice.id) : ended(acc, notice.id, stateOf(notice.status), now)), was),
  )
  for (const notice of notices) {
    const job = before.find(one => one.id === notice.id && one.endedAt === null)
    if (job !== undefined && notice.status !== '' && stateOf(notice.status) === 'failed') $.ui.toast(`${job.kind} failed: ${job.label}`)
  }
}

/** Folds the session's agents into the jobs: subagents and teammates, foreground or background. */
async function refreshAgents($: EngineInterface): Promise<void> {
  const agents = await $.agent.list()
  const now = await $.clock.now()
  await update($, jobs, was => pruned(withAgents(was, agents, now), now, local.options.jobLingerSeconds * 1000))
}

/** One timer tick: the session every time, the repository every other, the umbrella every tenth. */
async function tick($: EngineInterface): Promise<void> {
  local.ticks += 1
  await refreshSession($)
  await refreshAgents($).catch(ignoreFailure)
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
  if (now - local.localCheckedAt >= LOCAL_GAP_MS) {
    local.localCheckedAt = now
    const seen = localOf((await textOf($, [`${root}/scripts/local-only.sh`], root, 30_000)) ?? '')
    local.localOnly = seen.localOnly
    local.backupAgeS = seen.backupAgeS
  }
  const audit = await auditOf($, root, branch?.trim() ?? '').catch(() => null)
  const next: CockpitStatus = {
    branch: branch?.trim() ?? '?',
    phase: phaseOf(branch ?? ''),
    container: container?.trim() || 'absent',
    dirty: changed === undefined ? null : (dirtyCountOf(changed) ?? null),
    igor: igor.trim(),
    localOnly: local.localOnly,
    backupAgeS: local.backupAgeS,
    audit,
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
        await recordRuns($, [next]).catch(ignoreFailure)
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
 * The release audit the status line shows: the branch's own release when it waits for an audit (`not
 * started` until a run exists), else the newest run while it is under way; null when there is none.
 */
async function auditOf($: EngineInterface, root: string, branch: string): Promise<AuditStatus | null> {
  const version = branchVersionOf(branch)
  const wanted = version !== undefined && requiresAudit(version) ? version : undefined
  const out = await textOf($, [`${root}/bin/wfl`, 'audit:status', ...(wanted === undefined ? ['--latest'] : [wanted]), '--json'], root, 15_000)
  const seen = out === undefined ? undefined : auditStatusOf(out)
  if (seen !== undefined) return wanted === undefined && seen.phase === 'done' ? null : seen
  return wanted === undefined ? null : notStarted(wanted)
}

/** A decision the pane can record. */
function isChoice(value: string): value is AuditView['choice'] {
  return value === 'fix' || value === 'accept' || value === 'post-v1'
}

/** A run's ledger as the /audit pane's view: the newest run, or the release (and run) named. A string says why not. */
async function loadAudit($: EngineInterface, root: string, version: string, run: string): Promise<AuditView | string> {
  const argv = [`${root}/bin/wfl`, 'audit:status', ...(version === '' ? ['--latest'] : [version]), ...(run === '' ? [] : ['--run', run]), '--json']
  const out = await textOf($, argv, root, 15_000)
  const report = out === undefined ? undefined : auditRunOf(out)
  if (report === undefined) {
    return version === ''
      ? 'No release audit run yet: the release-audit skill starts one (wfl audit:init <version>).'
      : `No audit run for ${version}${run === '' ? '' : ` (${run})`}.`
  }
  const text = await $.fs.read(`${root}/${report.dir}/ledger.json`).catch(() => undefined)
  if (text === undefined) return `The audit of ${report.version} (${report.run}) has no ledger yet (phase: ${report.phase}): nothing to decide.`
  const findings = findingsOf(text)
  if (findings === undefined) return `${report.dir}/ledger.json does not read as a ledger: run wfl audit:check ${report.version}.`
  const first = firstOf(findings)
  return { version: report.version, run: report.run, dir: report.dir, findings, selected: first?.id ?? '', choice: choiceOf(first?.proposal ?? ''), message: '', recorded: [], isBusy: false }
}

/** Re-reads the open ledger; `toNext` moves the selection to the most severe finding still undecided. */
async function reloadAudit($: EngineInterface, message: string, toNext = false): Promise<void> {
  const root = await rootOf($)
  const view = await read($, auditView)
  if (root === undefined || view === null) return
  const findings = findingsOf(await $.fs.read(`${root}/${view.dir}/ledger.json`).catch(() => ''))
  if (findings === undefined) {
    await update($, auditView, was => (was === null ? was : { ...was, message: '✗ the ledger no longer reads: run wfl audit:check', isBusy: false }))
    return
  }
  const kept = findings.find(f => f.id === view.selected)
  const moves = toNext || kept === undefined
  const selected = moves ? firstOf(findings) : kept
  await update($, auditView, was =>
    was === null ? was : { ...was, findings, selected: selected?.id ?? '', choice: moves ? choiceOf(selected?.proposal ?? '') : was.choice, message, isBusy: false },
  )
}

/**
 * Records the maintainer's decision on the selected finding through `wfl audit:sign`, from the pane: the
 * person's own action, never a model turn. Accepting the risk or moving to post-v1 needs a reason.
 */
async function recordDecision($: EngineInterface, reason: string): Promise<void> {
  const root = await rootOf($)
  const view = await read($, auditView)
  if (root === undefined || view === null || view.isBusy || view.selected === '') return
  const why = reason.trim()
  if (view.choice !== 'fix' && why === '') {
    const what = view.choice === 'accept' ? 'Accepting the risk' : 'Moving it to post-v1'
    await update($, auditView, was => (was === null ? was : { ...was, message: `✗ ${what} needs a reason: type it, then Enter.` }))
    return
  }
  await update($, auditView, was => (was === null ? was : { ...was, isBusy: true, message: `recording ${view.selected} ${view.choice}…` }))
  const argv = [
    `${root}/bin/wfl`, 'audit:sign', view.version, view.selected, view.choice,
    ...(why === '' ? [] : [why]),
    ...(view.run === 'release-audit' ? [] : ['--run', view.run]),
  ]
  const done = await collect($, argv, root, { WFL_AUDIT_SIGNER: 'cockpit' }).catch((error: unknown) => ({
    code: null,
    output: error instanceof Error ? error.message : String(error),
  }))
  const last = done.output.trim().split('\n').filter(line => line.trim() !== '').pop() ?? ''
  if (done.code === 0) {
    const entry = `${view.selected} ${view.choice}`
    await update($, auditView, was => (was === null ? was : { ...was, recorded: [...was.recorded, entry] }))
    await reloadAudit($, `✓ ${last.replace(/^✓\s*/, '')}`, true)
    $.ui.toast(`Recorded ${entry}`)
  } else {
    const why2 = last.replace(/^✗\s*/, '') || `wfl audit:sign exited ${done.code ?? '?'}`
    await update($, auditView, was => (was === null ? was : { ...was, isBusy: false, message: `✗ ${why2}` }))
  }
}

/** The tools the model can call inside the umbrella: structured verdicts instead of terminal text to parse. */
async function registerTools($: EngineInterface): Promise<void> {
  await $.tool.register({
    name: 'dod',
    description:
      'Run the waffle-commons definition-of-done gate (wfl dod: Mago zero output, clean PHPUnit OK, coverage, igor 0 KO) for one or more components and get a structured verdict per gate, with the failing excerpt. Use it instead of parsing `wfl dod` output. Pass ["--changed"] for every component with uncommitted changes.',
    inputSchema: {
      type: 'object',
      properties: { components: { type: 'array', items: { type: 'string' }, minItems: 1, description: 'Component names (contracts, security, …), or ["--changed"].' } },
      required: ['components'],
    },
  })
  await $.tool.register({
    name: 'xref',
    description: 'Find every reference to a PHP symbol across the components\' src (vendor excluded), as structured {file, line, text} rows. Set tests to true to include tests/.',
    inputSchema: {
      type: 'object',
      properties: { symbol: { type: 'string', description: 'A class, interface, function or constant name, short or fully qualified.' }, tests: { type: 'boolean' } },
      required: ['symbol'],
    },
  })
  await $.tool.register({
    name: 'coverage_gaps',
    description: 'List the files of one component under 95% line coverage with their uncovered line counts (wfl coverage:gaps). Slow: it runs the suite with coverage.',
    inputSchema: { type: 'object', properties: { component: { type: 'string' } }, required: ['component'] },
  })
  await $.tool.register({
    name: 'dod_history',
    description: 'The last wfl dod verdict per component (pass/fail, age, coverage, failed gates), kept across sessions, and which components were edited since their last green run.',
    inputSchema: { type: 'object', properties: {} },
  })
}

/**
 * Registers the cockpit: lines under the prompt in every project (model,
 * context, cache, cost, limits, repository, PR, background jobs), plus inside the waffle-commons
 * umbrella the Waffle segments, /dod and the Bash guard. Outside the umbrella
 * the guard lets everything through.
 *
 * @param on the engine's registrar
 */
export const register: Register = (on, options) => {
  local.options = optionsOf(options)

  on('session.start', async ($, e, next) => {
    const started = await next(e)
    void loadHistory($).catch(ignoreFailure)
    const model = await $.session.model().catch(() => '')
    await update($, session, (was): SessionInfo => ({ ...(was ?? EMPTY_SESSION), model }))
    await $.command.register({
      name: 'cockpit',
      description: 'Refresh the cockpit lines under the prompt, show / hide them, or list the background jobs',
      argumentHint: '[show|hide|jobs]',
    })
    void refreshSession($).catch(ignoreFailure)
    void refreshRepo($).catch(ignoreFailure)
    $.clock.every(TICK_MS, () => void tick($).catch(ignoreFailure))

    const root = await rootOf($, e.cwd)
    if (root !== undefined) {
      await $.command.register({
        name: 'dod',
        description: 'Run wfl dod in a pane, with no model turn (components, or --changed; --history for the last verdicts)',
        argumentHint: '<component…> | --changed | --history',
      })
      await $.command.register({
        name: 'audit',
        description: "Decide the release audit's findings in a pane, with no model turn: fix, accept the risk, or post-v1",
        argumentHint: '[version] [--run <name>]',
      })
      await registerTools($).catch(ignoreFailure)
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
    } else {
      void refreshAgents($).catch(ignoreFailure)
    }
    return done
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const root = await rootOf($)
    if (root !== undefined) {
      const verdict = verdictOf(e.command, 0, false, local.options.guard === 'strict', local.options.releaseTag)
      if (verdict !== undefined) return { deny: `${PLUGIN}: ${verdict}` }
    } else if (local.options.secretScan) {
      // Outside the umbrella only the secret-file rule applies.
      const verdict = verdictOf(e.command, 0, true, false)
      if (verdict !== undefined && /holds secrets/.test(verdict)) return { deny: `${PLUGIN}: ${verdict}` }
    }

    // A foreground command is on the work line while it runs; a backgrounded one joins it by its task id.
    const commandId = e.run_in_background === true ? undefined : commandIdOf(e.tool_use_id)
    const shown = commandId === undefined ? undefined : startCommand($, commandId, e.description ?? e.command, e.command)
    const ran = await next(e).catch((error: unknown) => {
      if (commandId !== undefined && shown !== undefined) endCommand($, shown, (was, now) => ended(was, commandId, 'killed', now))
      throw error
    })
    if (root !== undefined && RUNS_DOD.test(e.command) && ran.deny === undefined) {
      const output = ran.text ?? (ran.isError === true ? '' : `${ran.result?.stdout ?? ''}\n${ran.result?.stderr ?? ''}`)
      void recordRuns($, runsOfOutput(output)).catch(ignoreFailure)
    }
    // run_in_background, or Ctrl+B on a running command: either way the result names the task.
    const taskId = ran.deny === undefined && ran.isError !== true ? ran.result?.backgroundTaskId : undefined
    if (commandId !== undefined && shown !== undefined) {
      const state: JobState = ran.isError === true ? 'failed' : ran.result?.interrupted === true ? 'killed' : 'completed'
      endCommand($, shown, (was, now) => {
        if (taskId !== undefined) return backgrounded(was, commandId, taskId)
        return ran.deny === undefined ? ended(was, commandId, state, now) : dropped(was, commandId)
      })
    } else if (taskId !== undefined) {
      void changeJobs($, (was, now) => started(was, jobOf('shell', taskId, e.description ?? e.command, e.command, now))).catch(ignoreFailure)
    }
    if (REFRESHES_STATUS.test(e.command)) {
      void refreshRepo($).catch(ignoreFailure)
      if (root !== undefined) void refresh($).catch(ignoreFailure)
    }
    return ran
  })

  on('tool.call', { tool: 'Edit' }, async ($, e, next) => {
    const verdict = await editVerdictOf($, e).catch(ignoreFailure)
    if (verdict !== undefined) return { deny: `${PLUGIN}: ${verdict}` }
    const ran = await next(e)
    if (ran.deny !== undefined || ran.isError === true) return ran
    const context = await afterEdit($, e.file_path).catch(ignoreFailure)
    return context === undefined ? ran : { ...ran, context: [...(ran.context ?? []), context] }
  })

  on('tool.call', { tool: 'Write' }, async ($, e, next) => {
    const verdict = await editVerdictOf($, e).catch(ignoreFailure)
    if (verdict !== undefined) return { deny: `${PLUGIN}: ${verdict}` }
    const ran = await next(e)
    if (ran.deny !== undefined || ran.isError === true) return ran
    const context = await afterEdit($, e.file_path).catch(ignoreFailure)
    return context === undefined ? ran : { ...ran, context: [...(ran.context ?? []), context] }
  })

  on('tool.call', { tool: 'Read' }, async ($, e, next) => {
    if (local.options.secretScan && isSecretPath(e.file_path)) {
      return { deny: `${PLUGIN}: ${e.file_path} holds secrets and is not read into the conversation. Ask the person for the one value needed, or read the committed .env.example.` }
    }
    return next(e)
  })

  // Done means evidence: a turn that edited a component does not end on silence about its gate.
  on('classic.Stop', async ($, e, next) => {
    if (!local.options.evidenceAtStop || e.stop_hook_active || (await rootOf($)) === undefined) return next(e)
    const ev = await read($, evidence)
    const fresh = staleOf(ev).filter(component => (local.reminded[component] ?? -1) < (ev.edited[component] ?? 0))
    if (fresh.length === 0) return next(e)
    for (const component of fresh) local.reminded[component] = ev.edited[component] ?? 0
    return { block: stopReasonOf(fresh) }
  })

  on('tool.call', { tool: TOOL_DOD }, async ($, e) => {
    const root = await rootOf($)
    if (root === undefined) return { result: 'Not inside the waffle-commons umbrella.' }
    const asked = fieldOf(e, 'components')
    let components = Array.isArray(asked) ? asked.filter((one): one is string => typeof one === 'string') : []
    if (components.length === 1 && components[0] === '--changed') {
      components = dirtyComponentsOf((await textOf($, [`${root}/scripts/changed-components.sh`], root, 30_000)) ?? '')
    }
    const invalid = components.filter(component => !COMPONENT.test(component))
    if (components.length === 0 || invalid.length > 0) return { result: `Give one or more component names (or ["--changed"]). Not valid: ${invalid.join(', ') || '(none given)'}` }
    const runs: DodRun[] = []
    for (const component of components) {
      try {
        const out = await tracked($, `wfl dod ${component}`, () => collect($, [`${root}/bin/wfl`, 'dod', component], root), done => done.code === 0)
        const parsed = runsOfOutput(out.output)[0]
        runs.push(parsed ?? { ...emptyRun(component), verdict: out.code === 0 ? 'pass' : 'fail', error: out.code === 0 ? '' : `wfl dod exited ${out.code ?? '?'}` })
      } catch (error) {
        runs.push({ ...emptyRun(component), verdict: 'fail', error: `could not run wfl dod: ${error instanceof Error ? error.message : String(error)}` })
      }
    }
    await recordRuns($, runs).catch(ignoreFailure)
    const report = runs.map(run => ({
      component: run.component,
      verdict: run.verdict,
      error: run.error || undefined,
      gates: run.steps.filter(step => step.state !== 'pending').map(step => ({ gate: step.name, state: step.state, message: step.message, excerpt: step.excerpt.length > 0 ? step.excerpt : undefined })),
    }))
    return { result: JSON.stringify({ summary: summaryOf(runs), runs: report }, null, 2) }
  })

  on('tool.call', { tool: TOOL_XREF }, async ($, e) => {
    const root = await rootOf($)
    const symbol = fieldOf(e, 'symbol')
    if (root === undefined || typeof symbol !== 'string' || !/^[A-Za-z_\\][A-Za-z0-9_\\:]*$/.test(symbol)) return { result: 'Give a PHP symbol: a class, interface, function or constant name.' }
    const argv = [`${root}/scripts/xref.sh`, symbol, ...(fieldOf(e, 'tests') === true ? ['--tests'] : [])]
    const out = await tracked($, `wfl xref ${symbol}`, () => textOf($, argv, root, 60_000), found => found !== undefined)
    const refs = (out ?? '')
      .split('\n')
      .map(line => /^\.\/([^:]+):(\d+):(.*)$/.exec(line))
      .filter((match): match is RegExpExecArray => match !== null)
      .map(match => ({ file: match[1], line: Number(match[2]), text: (match[3] ?? '').trim() }))
    return { result: JSON.stringify({ symbol, count: refs.length, refs: refs.slice(0, 300), isTruncated: refs.length > 300 }, null, 2) }
  })

  on('tool.call', { tool: TOOL_GAPS }, async ($, e) => {
    const root = await rootOf($)
    const component = fieldOf(e, 'component')
    if (root === undefined || typeof component !== 'string' || !COMPONENT.test(component)) return { result: 'Give one component name.' }
    const out = await tracked(
      $,
      `wfl coverage:gaps ${component}`,
      () => collect($, [`${root}/bin/wfl`, 'coverage:gaps', component], root).catch(() => ({ code: null, output: '' })),
      gaps => gaps.code === 0,
    )
    return { result: out.output.trim() || `wfl coverage:gaps ${component} printed nothing or failed (is waffle-dev running?)` }
  })

  on('tool.call', { tool: TOOL_HISTORY }, async $ => {
    const now = await $.clock.now()
    const rows = Object.values(await read($, history))
      .sort((a, b) => a.component.localeCompare(b.component))
      .map(record => ({ ...record, age: duration(now - record.at) }))
    const ev = await read($, evidence)
    return { result: JSON.stringify({ records: rows, editedSinceGreen: staleOf(ev) }, null, 2) }
  })

  on('tool.call', { tool: 'Monitor' }, async ($, e, next) => {
    const ran = await next(e)
    const taskId = ran.deny === undefined && ran.isError !== true ? ran.result?.taskId : undefined
    if (taskId !== undefined) {
      void changeJobs($, (was, now) => started(was, jobOf('monitor', taskId, e.description, e.command ?? e.ws?.url ?? '', now))).catch(ignoreFailure)
    }
    return ran
  })

  on('tool.call', { tool: 'Agent' }, async ($, e, next) => {
    void refreshAgents($).catch(ignoreFailure)
    const ran = await next(e)
    void refreshAgents($).catch(ignoreFailure)
    return ran
  })

  on('tool.call', { tool: 'TaskStop' }, async ($, e, next) => {
    const ran = await next(e)
    const id = e.task_id ?? e.shell_id
    if (id !== undefined && ran.deny === undefined && ran.isError !== true) {
      void changeJobs($, (was, now) => ended(was, id, 'killed', now)).catch(ignoreFailure)
    }
    return ran
  })

  on('tool.call', { tool: 'ScheduleWakeup' }, async ($, e, next) => {
    const ran = await next(e)
    if (ran.deny === undefined && ran.isError !== true) {
      const { stopped, clampedDelaySeconds = 0 } = ran.result ?? {}
      void changeJobs($, (was, now) => {
        const others = was.filter(job => job.kind !== 'wakeup')
        if (stopped === true) return others
        return [...others, { ...jobOf('wakeup', 'wakeup', e.reason || 'wakeup', e.prompt ?? '', now), dueAt: now + clampedDelaySeconds * 1000 }]
      }).catch(ignoreFailure)
    }
    return ran
  })

  // A background task's end reaches the session as a notification prompt: that is where a job ends.
  on('prompt.submit', ($, e, next) => {
    if (e.origin.kind === 'task-notification') void noticeJobs($, e.text).catch(ignoreFailure)
    return next(e)
  })

  on('command.run', { command: 'cockpit' }, async ($, e) => {
    const word = e.args.trim()
    if (word === 'hide') {
      await update($, isHidden, () => true)
      return { text: 'Cockpit lines hidden (/cockpit show brings them back).' }
    }
    if (word === 'jobs') {
      await refreshAgents($).catch(ignoreFailure)
      await $.ui.open({ id: JOBS_PANE, title: 'Background' })
      const live = liveOf(await read($, jobs)).length
      return { text: `${live} background job(s) running: see the Background pane.` }
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
      `bg ${liveOf(await read($, jobs)).length}`,
    ]
    return { text: parts.filter(part => part !== '').join(' │ ') }
  })

  on('command.run', { command: 'dod' }, async ($, e) => {
    const root = await rootOf($)
    if (root === undefined) return { text: 'Not inside the waffle-commons umbrella.' }
    if (local.isDodRunning) return { text: 'A /dod run is already in progress (see the DoD pane).' }

    const words = e.args.trim().split(/\s+/).filter(word => word !== '')
    if (words.length === 1 && words[0] === '--history') {
      await update($, dod, () => null)
      await $.ui.open({ id: PANE, title: 'DoD' })
      return { text: 'The last verdict per component is in the DoD pane.' }
    }
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

  on('command.run', { command: 'audit' }, async ($, e) => {
    const root = await rootOf($)
    if (root === undefined) return { text: 'Not inside the waffle-commons umbrella.' }
    const words = e.args.trim().split(/\s+/).filter(word => word !== '')
    const runAt = words.indexOf('--run')
    const run = runAt === -1 ? '' : (words[runAt + 1] ?? '')
    const version = words.find((word, i) => !word.startsWith('-') && (runAt === -1 || i !== runAt + 1)) ?? ''
    if (version !== '' && !AUDIT_VERSION.test(version)) return { text: `Not a release version: ${version} (for example 0.1.0-beta8).` }
    if (runAt !== -1 && !AUDIT_RUN.test(run)) return { text: 'Give the run name after --run: lowercase letters, digits and hyphens.' }
    const loaded = await loadAudit($, root, version, run)
    if (typeof loaded === 'string') return { text: loaded }
    await update($, auditView, () => loaded)
    await $.ui.open({ id: AUDIT_PANE, title: 'Release audit' })
    const decided = loaded.findings.filter(f => f.decision !== '').length
    return { text: `Release audit ${loaded.version} (${loaded.run}): ${loaded.findings.length} finding(s), ${decided} decided. Decide them in the Release audit pane.` }
  })

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    if (await read($, isHidden)) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    // Reading the pulse redraws the lines every second while a command runs.
    await read($, pulse)
    const now = await $.clock.now()
    const lines = linesOf({
      session: await read($, session),
      repo: await read($, repo),
      waffle: await read($, status),
      now,
      hint: e.props.hint,
      jobs: pruned(await read($, jobs), now, local.options.jobLingerSeconds * 1000),
      contextLevels: [local.options.contextWarn, local.options.contextAlert],
      backupWarnHours: local.options.backupWarnHours,
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

  on('ui.render', { component: 'Pane', requestId: JOBS_PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    await read($, pulse)
    const now = await $.clock.now()
    const all = pruned(await read($, jobs), now)
    if (all.length === 0) return <Text dimColor>Nothing running: commands, background shells, monitors, subagents and wakeups show here while they run.</Text>

    const order = [...liveOf(all), ...all.filter(job => job.endedAt !== null)]
    const stateText = (job: Job) =>
      job.kind === 'wakeup' ? `fires in ${elapsed((job.dueAt ?? now) - now)}` : job.endedAt === null ? `running ${elapsed(now - job.startedAt)}` : `${job.state} ${elapsed(now - job.endedAt)} ago`

    return (
      <Box flexDirection="column">
        {order.map(job => (
          <Box key={`${job.kind}-${job.id}`} flexDirection="column">
            <Text bold={job.endedAt === null} color={job.state === 'failed' || job.state === 'killed' ? 'red' : job.state === 'completed' ? 'green' : undefined} wrap="truncate">
              {`${JOB_ICONS[job.kind]} ${job.kind}  ${job.label}  ·  ${stateText(job)}${job.events > 0 ? `  ·  ${job.events} event(s)` : ''}`}
            </Text>
            {job.detail !== '' && job.detail !== job.label && <Text dimColor wrap="truncate">{`    ${oneLine(job.detail, 400)}`}</Text>}
            <Text dimColor>{`    id ${job.id}`}</Text>
          </Box>
        ))}
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const view = await read($, dod)

    if (view === null) {
      const now = await $.clock.now()
      const records = Object.values(await read($, history)).sort((a, b) => a.component.localeCompare(b.component))
      const stale = new Set(staleOf(await read($, evidence)))
      if (records.length === 0) return <Text dimColor>No /dod run yet. Try /dod contracts, or /dod --changed.</Text>
      return (
        <Box flexDirection="column">
          <Text bold>Last DoD per component</Text>
          {records.map(record => (
            <Text key={`h-${record.component}`} color={record.verdict === 'pass' ? 'green' : 'red'} wrap="truncate">
              {`${record.verdict === 'pass' ? '✓' : '✗'} ${record.component.padEnd(18)} ${duration(now - record.at).padStart(6)} ago${record.coverage === '' ? '' : `  coverage ${record.coverage}%`}${record.failed.length === 0 ? '' : `  failed: ${record.failed.join(', ')}`}${stale.has(record.component) ? '  · edited since' : ''}`}
            </Text>
          ))}
        </Box>
      )
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

  // The maintainer's decisions on a release audit's findings: their action in the pane, no model turn.
  on('ui.render', { component: 'Pane', requestId: AUDIT_PANE }, async ($, e) => {
    const { Box, Text, Button, Select, Input } = $.ui.resolve(e)
    const view = await read($, auditView)
    if (view === null) return <Text dimColor>No audit open: /audit [version] reads a run's ledger.</Text>

    const decided = view.findings.filter(f => f.decision !== '').length
    const finding = view.findings.find(f => f.id === view.selected)
    const toneOf = (severity: string) => (severity === 'CRITICAL' ? 'red' : severity === 'HIGH' ? 'yellow' : undefined)
    const select = (id: string) =>
      void update($, auditView, was => {
        if (was === null) return was
        const picked = was.findings.find(f => f.id === id)
        return picked === undefined ? was : { ...was, selected: id, choice: choiceOf(picked.proposal), message: '' }
      }).catch(ignoreFailure)
    const choose = (value: string) => void update($, auditView, was => (was === null || !isChoice(value) ? was : { ...was, choice: value, message: '' })).catch(ignoreFailure)

    return (
      <Box flexDirection="column">
        <Text bold>{`Release audit ${view.version} (${view.run}) · ${view.findings.length} finding(s) · decided ${decided}/${view.findings.length}`}</Text>
        {view.findings.length === 0 && <Text dimColor>The ledger holds no finding: nothing to decide.</Text>}
        {view.findings.length > 0 && (
          <Select key="audit-finding" label="Finding " options={view.findings.map(f => ({ value: f.id, label: optionLabelOf(f) }))} value={view.selected} onSelect={select} />
        )}
        {finding !== undefined && (
          <Box flexDirection="column">
            <Text bold color={toneOf(finding.severity)} wrap="truncate">{`${finding.id} · ${finding.severity} · ${finding.title}`}</Text>
            <Text dimColor wrap="truncate">{`  ${finding.where} · lens ${finding.lens} · ${finding.verdict} · ${finding.moscow} · proposed: ${finding.proposal} · ${finding.status}`}</Text>
            {finding.summary !== '' && <Text>{`  ${finding.summary}`}</Text>}
            {finding.fix !== '' && <Text dimColor>{`  fix: ${finding.fix}`}</Text>}
            <Text color={finding.decision === '' ? 'yellow' : 'green'}>{finding.decision === '' ? '  undecided' : `  decided: ${finding.decision}`}</Text>
            <Select
              key="audit-choice"
              label="Decision "
              options={[
                { value: 'fix', label: 'fix it in this release' },
                { value: 'accept', label: 'accept the risk (reason required)' },
                { value: 'post-v1', label: 'move it to post-v1 (reason required)' },
              ]}
              value={view.choice}
              onSelect={choose}
            />
            <Input
              key="audit-reason"
              label="Reason "
              placeholder={view.choice === 'fix' ? 'optional · Enter records the decision' : 'required · Enter records the decision'}
              submitLabel="record"
              onSubmit={reason => void recordDecision($, reason).catch(ignoreFailure)}
            />
          </Box>
        )}
        {view.message !== '' && <Text color={view.message.startsWith('✓') ? 'green' : view.message.startsWith('✗') ? 'red' : undefined}>{view.message}</Text>}
        <Box flexDirection="row">
          <Button key="audit-send" label="Send decisions to Claude" hotkey="s" onPress={() => void $.prompt.fill({ text: decisionsTextOf(view), mode: 'insert' }).catch(ignoreFailure)} />
          <Button key="audit-reload" label="Reload the ledger" hotkey="r" onPress={() => void reloadAudit($, 'ledger reloaded').catch(ignoreFailure)} />
        </Box>
      </Box>
    )
  })
}
