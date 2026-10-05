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

export type DodStepName = 'mago' | 'tests' | 'coverage' | 'igor' | 'compare-audit'

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

declare module 'claude-code' {
  interface PluginState {
    'waffle-cockpit': {
      status: CockpitStatus | null
      session: SessionInfo | null
      repo: RepoInfo | null
      dod: DodView | null
      isHidden: boolean
    }
  }
}
