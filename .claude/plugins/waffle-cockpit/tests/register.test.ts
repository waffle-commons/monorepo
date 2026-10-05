import type { On } from 'claude-code'
import { describe, expect, test } from 'claude-code/testing'

import { BAND, commandOf, inUmbrella, PANE, ROOT, SESSION, textOf, until } from './fixtures'
import type { World } from './fixtures'

const DOD_PASS = [
  '═══ Definition of Done — contracts ═══\n→ 1/5 composer mago (must be ZERO output)…\n✓ mago clean (zero diagnostics)\n',
  '→ 2/5 composer tests…\n✓ tests green\n→ 3/5 line coverage (≥ 95%)…\n✓ coverage 97.2% (≥ 95%)\n',
  '→ 4/5 composer igor (0 KO, auditor 0.9.7)…\n✓ igor 0 KO\n→ 5/5 compare-audit skipped (pass --compare-audit to include)\n✓ DoD PASS — contracts\n',
]

/** Answers `wfl dod` with a recorded green run, in three pieces. */
function dodPasses(on: On, world: World): void {
  on('process.spawn', async function* ($, e) {
    world.runs.push([...e.argv])
    for (const text of DOD_PASS) yield { stream: 'stdout' as const, text }
    return { value: { code: 0, signal: null } }
  })
}

describe('the guard', () => {
  test('refuses host-side composer, naming the Docker way', async ($, on) => {
    inUmbrella(on)
    await $.session.start(SESSION)

    const ran = await $.tool.call({ tool: 'Bash', command: 'cd security && composer install' })

    expect(ran.deny).toContain('waffle-dev')
  })

  test('refuses a release-tag push', async ($, on) => {
    inUmbrella(on)
    await $.session.start(SESSION)

    const ran = await $.tool.call({ tool: 'Bash', command: 'git push origin 0.1.0-beta7' })

    expect(ran.deny).toContain('LIVE release wave')
  })

  test('lets a docker exec through to the rest of the chain', async ($, on) => {
    inUmbrella(on)
    let isReached = false
    on('tool.call', () => {
      isReached = true
      return { deny: 'beneath' }
    })
    await $.session.start(SESSION)

    const ran = await $.tool.call({ tool: 'Bash', command: 'docker exec -w /waffle-commons/security waffle-dev composer mago' })

    expect(isReached).toBe(true)
    expect(ran.deny).toBe('beneath')
  })
})

describe('the band', () => {
  test('/cockpit refreshes it with phase, branch, container and dirty count', async ($, on) => {
    inUmbrella(on)
    await $.session.start(SESSION)

    const { text } = await $.command.run(commandOf('cockpit'))
    const drawn = textOf(await $.ui.render(BAND))

    expect(text).toContain('beta7 build')
    expect(drawn).toContain('beta7 build')
    expect(drawn).toContain('pre-release/0.1.0-beta7')
    expect(drawn).toContain('waffle-dev ●')
    expect(drawn).toContain('3 dirty')
    expect(drawn).toContain('igor 0.9.7')
  })

  test('a stopped container is drawn as stopped', async ($, on) => {
    inUmbrella(on, { container: 'exited\n' })
    await $.session.start(SESSION)

    await $.command.run(commandOf('cockpit'))

    expect(textOf(await $.ui.render(BAND))).toContain('waffle-dev ○')
  })

  test('/cockpit hide takes it down', async ($, on) => {
    inUmbrella(on)
    await $.session.start(SESSION)
    await $.command.run(commandOf('cockpit'))

    await $.command.run(commandOf('cockpit', 'hide'))

    expect(textOf(await $.ui.render(BAND))).not.toContain('beta7 build')
  })
})

describe('/dod', () => {
  test('streams the gate into the pane and toasts the verdict', async ($, on) => {
    const world = inUmbrella(on)
    dodPasses(on, world)
    await $.session.start(SESSION)

    const { text } = await $.command.run(commandOf('dod', 'contracts'))
    await until(world, () => world.toasts.some(toast => toast.startsWith('DoD')))

    expect(text).toContain('contracts')
    expect(world.opened).toContain('waffle-dod')
    expect(world.runs).toContainEqual([`${ROOT}/bin/wfl`, 'dod', 'contracts'])
    expect(world.toasts).toContain('DoD PASS: contracts')

    const drawn = textOf(await $.ui.render(PANE))
    expect(drawn).toContain('contracts  PASS')
    expect(drawn).toContain('coverage 97.2%')
    expect(drawn).toContain('Send verdict to Claude')
  })

  test('--changed runs the dirty components only', async ($, on) => {
    const world = inUmbrella(on)
    dodPasses(on, world)
    await $.session.start(SESSION)

    await $.command.run(commandOf('dod', '--changed'))
    await until(world, () => world.toasts.some(toast => toast.startsWith('DoD')))

    const dods = world.runs.filter(argv => argv[1] === 'dod').map(argv => argv[2])
    expect(dods).toEqual(['security', 'http'])
  })

  test('refuses a name that is not a component', async ($, on) => {
    inUmbrella(on)
    await $.session.start(SESSION)

    const { text } = await $.command.run(commandOf('dod', '../etc'))

    expect(text).toContain('Not a component name')
  })
})
