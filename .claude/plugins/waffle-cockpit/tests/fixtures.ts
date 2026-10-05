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

/** The band above the prompt on a 160-column terminal. */
export const BAND: RenderInput<'AbovePrompt', 'terminal'> = {
  surface: 'terminal',
  component: 'AbovePrompt',
  requestId: 'above-prompt',
  viewport: { columns: 160, rows: 40 },
  props: { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 150, scroll: { offset: 0, bodyRows: 6 }, view: {} },
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

/**
 * Answers what the cockpit asks of the machine inside the umbrella: its
 * start, its commands, the files that mark the root, git, docker and the
 * changed-components report. Toasts and opened panes are recorded.
 */
export function inUmbrella(on: On, answers: { branch?: string; container?: string; changed?: string } = {}): World {
  const world: World = { runs: [], toasts: [], opened: [], clock: mock.clock(on, { now: 0 }) }

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('session.cwd', () => ({ value: ROOT }))
  on('fs.exists', ($, e) => ({ value: e.path === `${ROOT}/bin/wfl` || e.path === `${ROOT}/.gitmodules` }))
  on('fs.read', () => ({ value: '0.9.7\n' }))
  on('process.run', ($, e) => {
    world.runs.push([...e.argv])
    const head = e.argv[0]
    const stdout =
      head === 'git' ? (answers.branch ?? 'pre-release/0.1.0-beta7\n')
      : head === 'docker' ? (answers.container ?? 'running\n')
      : (answers.changed ?? CHANGED)
    return { value: ok(stdout) }
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
