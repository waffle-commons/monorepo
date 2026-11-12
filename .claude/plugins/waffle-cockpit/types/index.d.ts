/** The Waffle segments: what the cockpit knows about the umbrella checkout. */
export type CockpitStatus = {
  /** The umbrella's current branch, e.g. `pre-release/0.1.0-beta7`. */
  branch: string
  /** The release phase the branch implies, e.g. `beta7 build`; empty when none. */
  phase: string
  /** `docker inspect` state of `waffle-dev`: `running`, `exited`, … or `absent`. */
  container: string
  /** Locations with uncommitted changes (umbrella + submodules); null when unknown. */
  dirty: number | null
  /** The igor-php version pinned in `.igor-version`; empty when unreadable. */
  igor: string
  /** Commits on no remote, umbrella and every repository under it; null when unknown. */
  localOnly: number | null
  /** Seconds since the last `wfl backup`; null when none is recorded. */
  backupAgeS: number | null
  /** The release audit the line shows (`wfl audit:status --json`); absent or null when there is none to show. */
  audit?: AuditStatus | null
}

/** A release audit's progress, as the status line draws it. */
export type AuditStatus = {
  /** The release audited, e.g. `0.1.0-beta8`. */
  version: string
  /** The run's name, `release-audit` unless a rehearsal. */
  run: string
  /** Who runs its agents: `balanced`, `economy`, `thorough`, `custom`, `inherited`; empty before a run exists. */
  profile: string
  /**
   * `not-started`, `evidence`, `calibration`, `finders`, `verification`, `triage`, `decisions`, `integration`,
   * `closure`, `done`, or `unreadable` when the run's files do not parse.
   */
  phase: string
  /** One short progress text for the phase (`5/12 finders`, `decided 3/40`); empty when none. */
  progress: string
  /** Findings of that severity whose status is still open. */
  openCritical: number
  openHigh: number
  /** `wfl audit:check --gate` as the status report reads it; null before the ledger exists. */
  gate: 'pass' | 'fail' | null
}

/** One ledger finding, as the /audit pane lists it. */
export type AuditFinding = {
  id: string
  severity: string
  title: string
  where: string
  lens: string
  verdict: string
  moscow: string
  /** The triager's proposal: `fix`, `accept` or `post-v1`. */
  proposal: string
  summary: string
  fix: string
  /** `open`, `fixed`, `accepted` or `deferred`. */
  status: string
  /** The maintainer's decision as one line (`accept · Leslie Petrimaux · 2026-11-20 · demo only`); empty while undecided. */
  decision: string
}

/** What the /audit pane draws. */
export type AuditView = {
  version: string
  run: string
  /** The run folder, relative to the umbrella root. */
  dir: string
  findings: AuditFinding[]
  /** The id of the finding the controls act on; empty when the ledger has none. */
  selected: string
  /** The decision the reason field records on Enter. */
  choice: 'fix' | 'accept' | 'post-v1'
  /** The last action's outcome, under the controls; empty before any. */
  message: string
  /** The decisions recorded from this pane, `<id> <choice>`, for "Send decisions to Claude". */
  recorded: string[]
  /** True while a decision is being recorded. */
  isBusy: boolean
  /** What the Reason field holds, so the Record button can send it; absent in a view stored before 0.5.1. */
  reason?: string
  /** What the Residual risk field holds (accept and post-v1 need it); absent in a view stored before 0.6.0. */
  residual?: string
}

/** Which components changed since their last green DoD: `$.clock.now()` of the last edit and of the last pass. */
export type Evidence = {
  edited: Record<string, number>
  gated: Record<string, number>
}

/** A component's last `wfl dod` verdict, kept across sessions. */
export type DodRecord = {
  component: string
  verdict: 'pass' | 'fail'
  /** Milliseconds since the epoch. */
  at: number
  /** Line coverage as printed, e.g. `98.71`; empty when not measured. */
  coverage: string
  /** The gates that failed (`mago`, `tests`, …); empty on a pass. */
  failed: string[]
}

/** One rate-limit window as the session reports it. */
export type SessionLimit = {
  /** `five_hour`, `seven_day` or `spend_limit`. */
  kind: string
  percent: number
  /** ISO 8601, when it resets; empty when unknown. */
  resetsAt: string
}

/** What the session reports about itself: model, effort, context, cost, limits, cache. */
export type SessionInfo = {
  /** The model id, e.g. `claude-opus-5-5`; empty until known. */
  model: string
  /** The effort level of the last main-loop request; empty until known or when the model has none. */
  effort: string
  contextPercent: number | null
  contextTokens: number | null
  contextWindow: number | null
  costUsd: number | null
  /** When the session began, in `$.clock.now()` milliseconds. */
  startedAt: number | null
  limits: SessionLimit[]
  /** Input tokens served from the prompt cache, summed over the main loop's turns. */
  cacheRead: number
  /** All input tokens of those turns: uncached, cache writes and cache reads. */
  cacheInput: number
  /** `$.clock.now()` of the last main-loop turn that ended; null before the first. */
  lastTurnAt: number | null
}

/** The git repository of the session's working directory. */
export type RepoInfo = {
  repo: string
  branch: string
  /** Changed paths in the working tree (submodules excluded). */
  dirty: number
  /** Lines added and removed in the working tree against HEAD. */
  added: number
  removed: number
  /** The open pull request of the branch, from `gh`; null when none or unknown. */
  pr: { number: number; review: string } | null
}

export type DodStepName = 'mago' | 'tests' | 'coverage' | 'igor' | 'audit' | 'compare-audit'

export type DodStepState = 'pending' | 'running' | 'pass' | 'fail' | 'skipped'

/** One gate of `wfl dod`. */
export type DodStep = {
  name: DodStepName
  state: DodStepState
  /** The gate's own result line, without its marker. */
  message: string
  /** The indented detail lines printed under a failing gate. */
  excerpt: string[]
}

/** One `wfl dod <component>` run. */
export type DodRun = {
  component: string
  verdict: 'running' | 'pass' | 'fail'
  /** Why the run stopped before its gates (unknown component, container down, …). */
  error: string
  steps: DodStep[]
}

/** What the DoD pane draws: the runs of the last /dod, in order. */
export type DodView = {
  runs: DodRun[]
  isActive: boolean
}

/**
 * What kind of work: a foreground command (a Bash call, or a cockpit tool running a repository script) while
 * it runs, a backgrounded Bash command, a Monitor watch, a subagent, a /loop wakeup.
 */
export type JobKind = 'command' | 'shell' | 'monitor' | 'agent' | 'wakeup'

export type JobState = 'running' | 'completed' | 'failed' | 'killed'

/** One piece of work of this session, as the cockpit saw it start and end. */
export type Job = {
  /**
   * The id the engine gave it (the call's `tool_use_id` for a command, `backgroundTaskId`, the Monitor
   * `taskId`, the agent id); `wakeup` for the loop.
   */
  id: string
  kind: JobKind
  /** The call's own description, else its command or prompt, on one line. */
  label: string
  /** The full command, the agent type, or the watch target; empty when none. */
  detail: string
  state: JobState
  /** `$.clock.now()` when the cockpit saw it start. */
  startedAt: number
  /** `$.clock.now()` when it ended; null while it runs. */
  endedAt: number | null
  /** A wakeup's fire time, in `$.clock.now()` milliseconds; null for the rest. */
  dueAt: number | null
  /** Notifications a monitor delivered so far (one per stdout line). */
  events: number
}

declare module 'claude-code' {
  interface PluginState {
    'waffle-cockpit': {
      status: CockpitStatus | null
      session: SessionInfo | null
      repo: RepoInfo | null
      dod: DodView | null
      jobs: Job[]
      /** Bumped every second while a command runs, so the lines redraw its running time. */
      pulse: number
      evidence: Evidence
      history: Record<string, DodRecord>
      isHidden: boolean
      /** The /audit pane's ledger and controls; null until /audit opens it. */
      auditView: AuditView | null
    }
  }
}
