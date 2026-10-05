/** What the band shows about the umbrella checkout. */
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
      dod: DodView | null
      isBandHidden: boolean
    }
  }
}
