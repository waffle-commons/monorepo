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
    }
  }
}
