import { describe, expect, test } from 'claude-code/testing'

import type { Job } from '../types'
import {
  backgrounded,
  COMMAND_LINGER_MS,
  dropped,
  ended,
  evented,
  jobOf,
  LINGER_MS,
  liveOf,
  notificationsOf,
  oneLine,
  pruned,
  started,
  startedCommand,
  stateOf,
  withAgents,
} from '../hooks/jobs'
import { jobsLine } from '../hooks/view'
import type { Line } from '../hooks/view'
import { commandOf, HINT, inUmbrella, PANE, SESSION, textOf, until } from './fixtures'

/** A notification as the session delivers it (recorded 2026-10-17), wrapped as a delivered reminder. */
const DONE = [
  '<system-reminder>',
  '<task-notification>',
  '<task-id>bj6nu5jbi</task-id>',
  '<tool-use-id>toolu_01PoRAWxVRTpArAUWqahX1bS</tool-use-id>',
  '<output-file>/private/tmp/tasks/bj6nu5jbi.output</output-file>',
  '<status>completed</status>',
  '<summary>Background command "Run TP2 step 2" completed (exit code 0)</summary>',
  '</task-notification>',
  '</system-reminder>',
].join('\n')

const text = (line: Line) => line.map(segment => segment.text).join('')

describe('the job records', () => {
  test('a notification names its task and status; a batch names each', () => {
    expect(notificationsOf(DONE)).toEqual([{ id: 'bj6nu5jbi', status: 'completed' }])
    const event = '<task-notification>\n<task-id>bmon1</task-id>\n<event>ci: green</event>\n</task-notification>'
    expect(notificationsOf(`${DONE}\n${event}`)).toEqual([
      { id: 'bj6nu5jbi', status: 'completed' },
      { id: 'bmon1', status: '' },
    ])
    expect(notificationsOf('a plain prompt')).toEqual([])
  })

  test('status words map to states', () => {
    expect(stateOf('completed')).toBe('completed')
    expect(stateOf('failed')).toBe('failed')
    expect(stateOf('killed')).toBe('killed')
    expect(stateOf('timeout')).toBe('killed')
    expect(stateOf('something-new')).toBe('completed')
  })

  test('start, count events, end once, then linger and go', () => {
    let jobs: Job[] = started([], jobOf('monitor', 'm1', 'CI   watch\nfor PR', 'gh run watch', 0))
    expect(jobs[0]?.label).toBe('CI watch for PR')
    jobs = evented(evented(jobs, 'm1'), 'm1')
    expect(jobs[0]?.events).toBe(2)
    jobs = ended(jobs, 'm1', 'completed', 1_000)
    jobs = ended(jobs, 'm1', 'killed', 2_000)
    expect(jobs[0]?.state).toBe('completed')
    expect(jobs[0]?.endedAt).toBe(1_000)
    expect(liveOf(jobs)).toHaveLength(0)
    expect(pruned(jobs, 1_000 + LINGER_MS - 1)).toHaveLength(1)
    expect(pruned(jobs, 1_000 + LINGER_MS)).toHaveLength(0)
  })

  test('a wakeup goes once its time has come', () => {
    const wakeup: Job = { ...jobOf('wakeup', 'wakeup', 'watch CI', '', 0), dueAt: 60_000 }
    expect(pruned([wakeup], 59_999)).toHaveLength(1)
    expect(pruned([wakeup], 60_000)).toHaveLength(0)
  })

  test('agents: a live one starts a job, an ended or dropped one ends it', () => {
    let jobs = withAgents([], [{ id: 'a1', type: 'Explore', description: 'find the pool', status: 'running' }], 0)
    expect(jobs[0]).toMatchObject({ kind: 'agent', label: 'find the pool', detail: 'Explore', state: 'running' })
    jobs = withAgents(jobs, [{ id: 'a1', type: 'Explore', description: 'find the pool', status: 'failed' }], 5_000)
    expect(jobs[0]).toMatchObject({ state: 'failed', endedAt: 5_000 })

    jobs = withAgents([], [{ id: 'a2', type: 'gate-runner', description: '', status: 'waiting' }], 0)
    jobs = withAgents(jobs, [], 9_000)
    expect(jobs[0]).toMatchObject({ label: 'gate-runner', state: 'completed', endedAt: 9_000 })
    expect(withAgents([], [{ id: 'a3', type: 'x', description: 'done already', status: 'completed' }], 0)).toHaveLength(0)
  })

  test('long labels are cut on one line', () => {
    expect(oneLine('x'.repeat(60))).toHaveLength(48)
    expect(oneLine('x'.repeat(60)).endsWith('…')).toBe(true)
  })
})

describe('the background line', () => {
  test('idle, never empty, without jobs', () => {
    expect(text(jobsLine([], 0))).toBe('⧗ 0 │ no command, background shell, monitor or subagent')
    expect(jobsLine([], 0).every(segment => segment.tone === 'dim')).toBe(true)
  })

  test('running first, with durations, events, end marks and a wakeup', () => {
    const jobs: Job[] = [
      ended([jobOf('shell', 's0', 'npm test', 'npm test', 0)], 's0', 'failed', 10_000)[0] as Job,
      jobOf('shell', 's1', 'wfl dod contracts', 'bin/wfl dod contracts', 0),
      { ...jobOf('monitor', 'm1', 'CI watch', '', 30_000), events: 3 },
      { ...jobOf('wakeup', 'wakeup', 'check the deploy', '', 0), dueAt: 20 * 60_000 },
    ]
    const line = text(jobsLine(jobs, 150_000))
    expect(line).toBe('⧗ 3 │ $ wfl dod contracts 2m │ ◉ CI watch 2m · 3 ev │ ⏰ check the deploy in 17m │ ✗ failed $ npm test')
  })

  test('a running command comes first; an ended one says how long it took', () => {
    const jobs: Job[] = [
      jobOf('shell', 's1', 'wfl dod contracts', 'bin/wfl dod contracts', 0),
      jobOf('command', 'c1', 'composer tests', 'composer tests', 140_000),
    ]
    expect(text(jobsLine(jobs, 150_000))).toBe('⧗ 2 │ ▶ composer tests 10s │ $ wfl dod contracts 2m')
    const done = ended(jobs, 'c1', 'completed', 152_000)
    expect(text(jobsLine(done, 153_000))).toBe('⧗ 1 │ $ wfl dod contracts 2m │ ✓ ▶ composer tests 12s')
  })

  test('past four jobs it says how many more', () => {
    const jobs = ['a', 'b', 'c', 'd', 'e', 'f'].map(id => jobOf('shell', id, id, id, 0))
    expect(text(jobsLine(jobs, 5_000))).toContain('+2 more (/cockpit jobs)')
    expect(text(jobsLine(jobs, 5_000))).toContain('$ a 5s')
  })
})

describe('tracking from the tool calls', () => {
  test('a backgrounded Bash command shows under the prompt and in the pane, and TaskStop ends it', async ($, on) => {
    const world = inUmbrella(on)
    on('agent.list', () => ({ value: [] }))
    on('tool.call', ($, e) =>
      e.tool === 'Bash'
        ? { result: { stdout: '', stderr: '', interrupted: false, backgroundTaskId: 'bk1' } }
        : { result: { success: true, message: 'stopped', task_id: 'bk1', task_type: 'local_bash' } },
    )
    await $.session.start(SESSION)

    await $.tool.call({ tool: 'Bash', command: 'bin/wfl check:all --with-tests', description: 'Full gate sweep', run_in_background: true })
    await until(world, () => false, 20)
    expect(textOf(await $.ui.render(HINT))).toContain('⧗ 1 │ $ Full gate sweep')

    const { text: said } = await $.command.run(commandOf('cockpit', 'jobs'))
    expect(said).toContain('1 background job(s) running')
    expect(world.opened).toContain('waffle-jobs')
    const pane = textOf(await $.ui.render({ ...PANE, requestId: 'waffle-jobs', props: { ...PANE.props, title: 'Background' } }))
    expect(pane).toContain('$ shell  Full gate sweep')
    expect(pane).toContain('bin/wfl check:all --with-tests')
    expect(pane).toContain('id bk1')

    await $.tool.call({ tool: 'TaskStop', task_id: 'bk1' })
    await until(world, () => false, 20)
    expect(textOf(await $.ui.render(HINT))).toContain('✗ killed $ Full gate sweep')
  })

  test('a foreground command is on the line while it runs, then ticked with its time, then gone', async ($, on) => {
    const world = inUmbrella(on)
    on('agent.list', () => ({ value: [] }))
    let finish: () => void = () => undefined
    const running = new Promise<void>(resolve => {
      finish = resolve
    })
    on('tool.call', async () => {
      await running
      return { result: { stdout: 'ok', stderr: '', interrupted: false } }
    })
    await $.session.start(SESSION)

    const call = $.tool.call({ tool: 'Bash', command: 'docker exec waffle-dev composer tests', description: 'Run the suite' })
    await until(world, () => false, 20)
    expect(textOf(await $.ui.render(HINT))).toContain('⧗ 1 │ ▶ Run the suite 0s')

    await world.clock.advance(3_000)
    expect(textOf(await $.ui.render(HINT))).toContain('▶ Run the suite 3s')
    finish()
    await call
    await until(world, () => false, 20)
    expect(textOf(await $.ui.render(HINT))).toContain('⧗ 0 │ ✓ ▶ Run the suite 3s')

    await world.clock.advance(COMMAND_LINGER_MS)
    expect(textOf(await $.ui.render(HINT))).toContain('⧗ 0 │ no command, background shell, monitor or subagent')
  })

  test('a failed command is crossed, a refused one leaves nothing, the next one replaces the last', async ($, on) => {
    const world = inUmbrella(on)
    on('agent.list', () => ({ value: [] }))
    on('tool.call', ($, e) => {
      if (e.tool !== 'Bash') return { result: {} }
      if (e.command === 'false') return { result: { stdout: '', stderr: 'boom', interrupted: false }, isError: true }
      if (e.command === 'rm -rf var') return { deny: 'The person refused the call.' }
      return { result: { stdout: 'ok', stderr: '', interrupted: false } }
    })
    await $.session.start(SESSION)

    await $.tool.call({ tool: 'Bash', command: 'false', description: 'Fail on purpose' })
    await until(world, () => false, 20)
    expect(textOf(await $.ui.render(HINT))).toContain('✗ failed ▶ Fail on purpose')

    await $.tool.call({ tool: 'Bash', command: 'rm -rf var' })
    await $.tool.call({ tool: 'Bash', command: 'git status' })
    await until(world, () => false, 20)
    const line = textOf(await $.ui.render(HINT))
    expect(line).toContain('✓ ▶ git status')
    expect(line).not.toContain('Fail on purpose')
    expect(line).not.toContain('rm -rf var')
  })

  test('a command sent to the background (Ctrl+B) becomes the shell its task id names', async ($, on) => {
    const world = inUmbrella(on)
    on('agent.list', () => ({ value: [] }))
    on('tool.call', () => ({ result: { stdout: '', stderr: '', interrupted: false, backgroundTaskId: 'bk9', backgroundedByUser: true } }))
    await $.session.start(SESSION)

    await $.tool.call({ tool: 'Bash', command: 'bin/wfl check:all', description: 'Full sweep' })
    await until(world, () => false, 20)

    expect(textOf(await $.ui.render(HINT))).toContain('⧗ 1 │ $ Full sweep')
    expect(textOf(await $.ui.render(HINT))).not.toContain('▶')
  })
})

describe('the command records', () => {
  test('a new command takes the place of the ended ones; a running one stays', () => {
    const done = ended([jobOf('command', 'c1', 'ls', 'ls', 0)], 'c1', 'completed', 1_000)
    const both = startedCommand([...done, jobOf('command', 'c2', 'pwd', 'pwd', 500)], jobOf('command', 'c3', 'id', 'id', 2_000))
    expect(both.map(job => job.id)).toEqual(['c2', 'c3'])
  })

  test('an ended command lingers less than background work', () => {
    const command = ended([jobOf('command', 'c1', 'ls', 'ls', 0)], 'c1', 'completed', 0)
    const shell = ended([jobOf('shell', 's1', 'ls', 'ls', 0)], 's1', 'completed', 0)
    expect(pruned([...command, ...shell], COMMAND_LINGER_MS)).toEqual(shell)
    expect(pruned(command, COMMAND_LINGER_MS - 1, 1_000)).toEqual([])
  })

  test('Ctrl+B turns the command into a shell; a refused one is dropped', () => {
    const jobs = [jobOf('command', 'c1', 'sweep', 'bin/wfl check:all', 0)]
    expect(backgrounded(jobs, 'c1', 'bk1')[0]).toMatchObject({ id: 'bk1', kind: 'shell', startedAt: 0, endedAt: null })
    expect(dropped(jobs, 'c1')).toEqual([])
  })
})
