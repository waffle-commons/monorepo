import { expect, mock, test } from 'claude-code/testing'

import type { SessionStartInput } from 'claude-code'

const OUTSIDE: SessionStartInput = { surface: 'terminal', isInteractive: true, cwd: '/elsewhere' }

test('outside the umbrella the guard lets everything through', async ($, on) => {
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.cwd', () => ({ value: '/elsewhere' }))
  on('fs.exists', () => ({ value: false }))
  let isReached = false
  on('tool.call', () => {
    isReached = true
    return { deny: 'beneath' }
  })
  await $.session.start(OUTSIDE)

  const ran = await $.tool.call({ tool: 'Bash', command: 'composer install' })

  expect(isReached).toBe(true)
  expect(ran.deny).toBe('beneath')
})

test('outside the umbrella the lines draw without the Waffle segment', async ($, on) => {
  mock.clock(on, { now: 0 })
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.cwd', () => ({ value: '/elsewhere' }))
  on('session.model', () => ({ value: 'claude-sonnet-5-5' }))
  on('session.usage', () => ({ value: { startedAt: 0, context: { window: 200_000, percent: 12 }, rateLimits: [] } }))
  on('fs.exists', () => ({ value: false }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('process.run', () => ({ value: { exitCode: 128, stdout: '', stderr: 'not a git repository', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('ui.render', () => ({ type: 'Text', children: ['engine'] }))
  await $.session.start(OUTSIDE)

  await $.command.run({ command: 'cockpit', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 160 } })
  const tree = JSON.stringify(
    await $.ui.render({
      surface: 'terminal',
      component: 'PromptHint',
      requestId: 'prompt-hint',
      viewport: { columns: 160, rows: 40 },
      props: { isDraft: false, isWorking: false, hint: '' },
    }),
  )

  expect(tree).toContain('Sonnet 5.5')
  expect(tree).toContain('12%')
  expect(tree).not.toContain('waffle-dev')
})
