/**
 * The cockpit's settings, from the manifest's `userConfig` (`/config`, or
 * `pluginConfigs` in settings.json), each checked and given its default.
 */
import type { PluginOptions } from 'claude-code'

export type InstantLint = 'off' | 'lint' | 'lint+analyze'

export type CockpitOptions = {
  /** Context bar: yellow from this percent. */
  contextWarn: number
  /** Context bar: red from this percent. */
  contextAlert: number
  /** How long an ended background job stays on its line, in seconds. */
  jobLingerSeconds: number
  /** Mago on each PHP file Claude edits: none, `lint`, or `lint` then `analyze`. */
  instantLint: InstantLint
  /** Remind the model before a turn ends with components edited since their last green DoD. */
  evidenceAtStop: boolean
  /** `strict` also refuses `cd` on the host, a `\` after a heredoc start and new `mixed`; `standard` keeps the release and PHP rules. */
  guard: 'strict' | 'standard'
  /** Refuse an Edit or Write that adds a secret, and shell reads of secret files. */
  secretScan: boolean
  /** The backup segment turns yellow past this many hours with local-only commits (red past three times it). */
  backupWarnHours: number
}

export const DEFAULTS: CockpitOptions = {
  contextWarn: 60,
  contextAlert: 80,
  jobLingerSeconds: 60,
  instantLint: 'lint+analyze',
  evidenceAtStop: true,
  guard: 'strict',
  secretScan: true,
  backupWarnHours: 24,
}

function numberOf(value: unknown, fallback: number, min: number, max: number): number {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max ? value : fallback
}

/** The options the module runs with: each stored value when valid, its default otherwise. */
export function optionsOf(raw: PluginOptions | undefined): CockpitOptions {
  const get = (key: string): unknown => raw?.[key]
  const lint = get('instantLint')
  const guard = get('guard')
  const warn = numberOf(get('contextWarn'), DEFAULTS.contextWarn, 1, 99)
  return {
    contextWarn: warn,
    contextAlert: Math.max(warn + 1, numberOf(get('contextAlert'), DEFAULTS.contextAlert, 2, 100)),
    jobLingerSeconds: numberOf(get('jobLingerSeconds'), DEFAULTS.jobLingerSeconds, 0, 3600),
    instantLint: lint === 'off' || lint === 'lint' || lint === 'lint+analyze' ? lint : DEFAULTS.instantLint,
    evidenceAtStop: typeof get('evidenceAtStop') === 'boolean' ? get('evidenceAtStop') === true : DEFAULTS.evidenceAtStop,
    guard: guard === 'standard' || guard === 'strict' ? guard : DEFAULTS.guard,
    secretScan: typeof get('secretScan') === 'boolean' ? get('secretScan') === true : DEFAULTS.secretScan,
    backupWarnHours: numberOf(get('backupWarnHours'), DEFAULTS.backupWarnHours, 1, 24 * 30),
  }
}
