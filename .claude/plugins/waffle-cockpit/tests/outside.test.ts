import { expect, test } from 'claude-code/testing'

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
