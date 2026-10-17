import { describe, expect, test } from 'claude-code/testing'

import type { Job } from '../types'
import { ended, evented, jobOf, LINGER_MS, liveOf, notificationsOf, oneLine, pruned, started, stateOf, withAgents } from '../hooks/jobs'
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
  test('none without jobs', () => {
    expect(jobsLine([], 0)).toEqual([])
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

  test('a foreground Bash command adds no job', async ($, on) => {
    const world = inUmbrella(on)
    on('agent.list', () => ({ value: [] }))
    on('tool.call', () => ({ result: { stdout: 'ok', stderr: '', interrupted: false } }))
    await $.session.start(SESSION)

    await $.tool.call({ tool: 'Bash', command: 'ls' })
    await until(world, () => false, 20)

    expect(textOf(await $.ui.render(HINT))).not.toContain('⧗')
  })
})
