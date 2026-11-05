/**
 * What the status band says, read from the umbrella checkout.
 */

/** What each release on the v1 train is for (AGENTS.md §5b). */
const PHASES: Record<string, string> = {
  beta7: 'build',
  beta8: 'freeze',
}

/**
 * The release phase a branch implies: `pre-release/0.1.0-beta7` is
 * `beta7 build`, `pre-release/1.0.0-RC1` is `RC1 certification`; empty for a
 * branch outside the train.
 */
export function phaseOf(branch: string): string {
  const version = /^pre-release\/(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)$/.exec(branch.trim())?.[1]
  if (version === undefined) return ''

  const label = /-(beta\d+|RC\d+)$/.exec(version)?.[1]
  if (label === undefined) return version
  if (label.startsWith('RC')) return `${label} certification`

  const phase = PHASES[label]
  return phase === undefined ? label : `${label} ${phase}`
}

/**
 * How many locations `scripts/changed-components.sh` reports with
 * uncommitted changes: 0 for a clean tree, undefined when the output says
 * neither.
 */
export function dirtyCountOf(output: string): number | undefined {
  if (/working tree clean/.test(output)) return 0
  const count = /●\s*(\d+)\s+location\(s\) with uncommitted changes/.exec(output)?.[1]
  return count === undefined ? undefined : Number(count)
}

/**
 * The components with uncommitted changes, from the same report's
 * `  ● <name>  N change(s)` lines; the umbrella root is left out.
 */
export function dirtyComponentsOf(output: string): string[] {
  return [...output.matchAll(/^\s*●\s+(\S+)\s+\d+\s+change\(s\)\s*$/gm)]
    .map(match => match[1] ?? '')
    .filter(name => name !== '' && !name.startsWith('('))
}
