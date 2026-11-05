/**
 * Evidence: what the cockpit remembers about the definition of done.
 *
 * - Which components an edit touched since their last green `wfl dod`, so the
 *   turn does not end on "done" without the gate (AGENTS.md §7).
 * - Each component's last DoD verdict, kept across sessions.
 * - The instant Mago check after an edit, as the model reads it.
 * - The local-only commit count and the age of the last backup.
 *
 * Pure, so it is tested without an engine.
 */
import type { DodRecord, DodRun, Evidence } from '../types'
import { applyLine, emptyRun } from './dod'

/** Files whose change the DoD gate has to see: PHP, and the files that configure the gates. */
const GATED_FILE = /\.php$|(^|\/)(composer\.json|composer\.lock|mago\.toml|phpunit\.xml(\.dist)?|igor\.json)$/

/** Paths inside a component the gate never reads. */
const UNGATED_DIR = /(^|\/)(vendor|var|node_modules|\.git)\//

/**
 * The component a path belongs to, and its path inside it, when the path sits
 * in one of the umbrella's components; undefined otherwise.
 */
export function placeOf(root: string, path: string, components: ReadonlySet<string>): { component: string; inner: string } | undefined {
  const prefix = `${root.replace(/\/+$/, '')}/`
  if (!path.startsWith(prefix)) return undefined
  const rest = path.slice(prefix.length)
  const cut = rest.indexOf('/')
  if (cut <= 0) return undefined
  const component = rest.slice(0, cut)
  const inner = rest.slice(cut + 1)
  if (!components.has(component) || UNGATED_DIR.test(inner)) return undefined
  return { component, inner }
}

/** Whether a component-relative path is one the DoD gate has to see again after a change. */
export function isGated(inner: string): boolean {
  return GATED_FILE.test(inner)
}

export const EMPTY_EVIDENCE: Evidence = { edited: {}, gated: {} }

/** The evidence after an edit of a gated file in `component`. */
export function withEdit(evidence: Evidence, component: string, at: number): Evidence {
  return { ...evidence, edited: { ...evidence.edited, [component]: at } }
}

/** The evidence after a green DoD for `component`. */
export function withGreen(evidence: Evidence, component: string, at: number): Evidence {
  return { ...evidence, gated: { ...evidence.gated, [component]: at } }
}

/** The components edited since their last green DoD, sorted. */
export function staleOf(evidence: Evidence): string[] {
  return Object.entries(evidence.edited)
    .filter(([component, at]) => at > (evidence.gated[component] ?? -1))
    .map(([component]) => component)
    .sort()
}

/** What the model reads when the turn would end with stale components. */
export function stopReasonOf(stale: readonly string[]): string {
  const list = stale.join(', ')
  return [
    `waffle-cockpit: ${list} changed since ${stale.length === 1 ? 'its' : 'their'} last green \`wfl dod\` (AGENTS.md §7: done means evidence).`,
    `Run \`bin/wfl dod <component>\` (absolute path; or the mcp__waffle-cockpit__dod tool) for ${list} and report the verdict,`,
    'or say plainly that the gate was not run and why. This reminder comes once per stop.',
  ].join(' ')
}

/** Every `wfl dod` run in a command's output, one per `═══ Definition of Done — c ═══` header. */
export function runsOfOutput(output: string): DodRun[] {
  const runs: DodRun[] = []
  let run: DodRun | undefined
  for (const line of output.split('\n')) {
    const header = /Definition of Done — ([a-z0-9][a-z0-9-]*)/.exec(line)?.[1]
    if (header !== undefined) {
      if (run !== undefined) runs.push(run)
      run = emptyRun(header)
      continue
    }
    if (run !== undefined) run = applyLine(run, line)
  }
  if (run !== undefined) runs.push(run)
  return runs.filter(one => one.verdict !== 'running')
}

/** A finished run as the history keeps it. */
export function recordOf(run: DodRun, at: number): DodRecord {
  const coverage = /([\d.]+)%/.exec(run.steps.find(step => step.name === 'coverage')?.message ?? '')?.[1] ?? ''
  return {
    component: run.component,
    verdict: run.verdict === 'pass' ? 'pass' : 'fail',
    at,
    coverage,
    failed: run.error !== '' ? ['before the gates'] : run.steps.filter(step => step.state === 'fail').map(step => step.name),
  }
}

/** The history with these records in, newest per component. */
export function withRecords(history: Readonly<Record<string, DodRecord>>, records: readonly DodRecord[]): Record<string, DodRecord> {
  const next = { ...history }
  for (const record of records) next[record.component] = record
  return next
}

/** Mago's own all-clear and Composer's echo, which are not findings. */
const BENIGN = /^\s*$|^\s*INFO\s|^> /

/**
 * What the model reads after an edit when Mago finds something in the file;
 * undefined when both runs are clean (zero output beyond the all-clear).
 */
export function lintContextOf(component: string, inner: string, outputs: readonly string[], maxLines = 60): string | undefined {
  const findings = outputs.flatMap(output => output.split('\n')).filter(line => !BENIGN.test(line))
  if (findings.length === 0) return undefined
  const shown = findings.slice(0, maxLines)
  const more = findings.length > maxLines ? [`… ${findings.length - maxLines} more line(s): run \`wfl mago ${component}\``] : []
  return [
    `waffle-cockpit instant check: Mago on ${component}/${inner} is not clean (zero output is the bar; this is an early warning, not the gate):`,
    ...shown,
    ...more,
  ].join('\n')
}

/** `scripts/local-only.sh` output: commits on no remote, and seconds since the last backup (null when never). */
export function localOf(output: string): { localOnly: number | null; backupAgeS: number | null } {
  const local = /^local-only\s+(\d+)\s*$/m.exec(output)?.[1]
  const age = /^backup-age-s\s+(\d+)\s*$/m.exec(output)?.[1]
  return { localOnly: local === undefined ? null : Number(local), backupAgeS: age === undefined ? null : Number(age) }
}
