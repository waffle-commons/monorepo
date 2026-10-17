import type { CommandRunInput, On, ProcessRunResult, RenderInput, SessionStartInput } from 'claude-code'
import { mock } from 'claude-code/testing'
import type { MockClock } from 'claude-code/testing'

/** The umbrella checkout the tests pretend to run in. */
export const ROOT = '/work'

export const SESSION: SessionStartInput = { surface: 'terminal', isInteractive: true, cwd: ROOT }

/** A slash command as the person types it, in the fullscreen layout. */
export function commandOf(command: string, args = ''): CommandRunInput {
  return { command, args, origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 160 } }
}

/** The hint line under the prompt on a 160-column terminal: where the cockpit draws. */
export const HINT: RenderInput<'PromptHint', 'terminal'> = {
  surface: 'terminal',
  component: 'PromptHint',
  requestId: 'prompt-hint',
  viewport: { columns: 160, rows: 40 },
  props: { isDraft: false, isWorking: false, hint: '? for shortcuts' },
}

/** What `$.session.usage()` answers: 58% of 200k, $4.12, 1h52 in, two limit windows. */
export const USAGE = {
  startedAt: -6_720_000,
  context: { tokens: 116_000, window: 200_000, percent: 58 },
  rateLimits: [
    { kind: 'five_hour', percentUsed: 31, resetsAt: '2026-10-05T14:20:00Z' },
    { kind: 'seven_day', percentUsed: 52 },
  ],
  cost: { usd: 4.12 },
}

/** The DoD pane, docked. */
export const PANE: RenderInput<'Pane', 'terminal'> = {
  surface: 'terminal',
  component: 'Pane',
  requestId: 'waffle-dod',
  viewport: { columns: 160, rows: 40 },
  props: { title: 'DoD', isFocused: false, bodyColumns: 80, placement: 'dock', scroll: { offset: 0, bodyRows: 30 }, view: {} },
}

/** A drawn tree's text, in order: its strings and its labels. */
export function textOf(tree: unknown): string {
  if (typeof tree === 'string' || typeof tree === 'number') return String(tree)
  if (Array.isArray(tree)) return tree.map(textOf).join('')
  if (typeof tree !== 'object' || tree === null) return ''
  const props: unknown = Reflect.get(tree, 'props')
  const label = typeof props === 'object' && props !== null ? Reflect.get(props, 'label') : undefined
  return `${typeof label === 'string' ? label : ''}${textOf(Reflect.get(tree, 'children') ?? [])}`
}

function ok(stdout: string): ProcessRunResult {
  return { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
}

export const CHANGED = [
  '═══ uncommitted changes (umbrella + submodules) ═══',
  '  ● (umbrella root)           12 change(s)',
  '  ● security                   3 change(s)',
  '  ● http                       1 change(s)',
  '───────────────────────────────────────────────────',
  '● 3 location(s) with uncommitted changes',
  '',
].join('\n')

export type World = { runs: string[][]; toasts: string[]; opened: string[]; clock: MockClock }

/** What the machine answers, where a test needs something else than the defaults. */
export type Answers = { branch?: string; container?: string; changed?: string; mago?: string; dod?: string }

/** What git, gh, docker and the changed-components report answer, by command. */
function stdoutOf(argv: readonly string[], answers: Answers): string {
  const line = argv.join(' ')
  if (line.includes('list-components.sh')) return 'contracts\nsecurity\nhttp\n'
  if (line.includes('local-only.sh')) return 'local-only 91\nbackup-age-s 7200\n'
  if (argv.includes('vendor/bin/mago')) return answers.mago ?? ' INFO No issues found.\n'
  if (argv[0]?.endsWith('/bin/wfl') && argv[1] === 'dod') return answers.dod ?? ''
  if (line.includes('--show-toplevel')) return `${ROOT}\n`
  if (line.includes('--abbrev-ref')) return answers.branch ?? 'pre-release/0.1.0-beta7\n'
  if (line.includes('status --porcelain')) return ' M AGENTS.md\n M README.md\n?? notes.md\n'
  if (line.includes('diff --shortstat')) return ' 2 files changed, 812 insertions(+), 95 deletions(-)\n'
  if (argv[0] === 'gh') return '{"number":12,"reviewDecision":"APPROVED","isDraft":false}\n'
  if (argv[0] === 'docker') return answers.container ?? 'running\n'
  return answers.changed ?? CHANGED
}

/**
 * Answers what the cockpit asks of the machine inside the umbrella: its
 * start, its commands, the files that mark the root, git, docker and the
 * changed-components report. Toasts and opened panes are recorded.
 */
export function inUmbrella(on: On, answers: Answers = {}): World {
  const world: World = { runs: [], toasts: [], opened: [], clock: mock.clock(on, { now: 0 }) }
  mock.store(on)

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('session.cwd', () => ({ value: ROOT }))
  on('session.model', () => ({ value: 'claude-opus-5-5' }))
  on('session.usage', () => ({ value: USAGE }))
  on('fs.exists', ($, e) => ({ value: e.path === `${ROOT}/bin/wfl` || e.path === `${ROOT}/.gitmodules` }))
  on('fs.read', () => ({ value: '0.9.7\n' }))
  on('process.run', ($, e) => {
    world.runs.push([...e.argv])
    return { value: ok(stdoutOf(e.argv, answers)) }
  })
  on('ui.toast', ($, e) => {
    world.toasts.push(e.text)
    return { value: undefined }
  })
  on('ui.open', ($, e) => {
    world.opened.push(e.id)
    return { value: { isPlaced: true } }
  })
  // What the engine draws where the cockpit draws nothing of its own.
  on('ui.render', () => ({ type: 'Text', children: ['engine'] }))

  return world
}

/** Moves the mocked clock a millisecond at a time until `isDone`, so detached work settles. */
export async function until(world: World, isDone: () => boolean, tries = 300): Promise<void> {
  for (let i = 0; i < tries && !isDone(); i++) await world.clock.advance(1)
}
