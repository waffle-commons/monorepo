import { describe, expect, test } from 'claude-code/testing'

import { commandOf, inUmbrella, PANE, ROOT, SESSION, textOf, until } from './fixtures'

const DOD_PASS = '═══ Definition of Done — security ═══\n→ 1/5 composer mago…\n✓ mago clean (zero diagnostics)\n→ 3/5 line coverage (≥ 95%)…\n✓ coverage 97.4% (≥ 95%)\n✓ DoD PASS — security\n'

describe('Edit and Write checks', () => {
  test('an Edit that adds mixed to umbrella PHP is refused before it runs', async ($, on) => {
    inUmbrella(on)
    let isReached = false
    on('tool.call', () => {
      isReached = true
      return { result: { filePath: '', oldString: '', newString: '', originalFile: '', structuredPatch: [], userModified: false, replaceAll: false } }
    })
    await $.session.start(SESSION)

    const ran = await $.tool.call({ tool: 'Edit', file_path: `${ROOT}/security/src/A.php`, old_string: 'int $x', new_string: 'mixed $x' })

    expect(isReached).toBe(false)
    expect(ran.deny).toContain('`mixed` is forbidden')
  })

  test('a Write that adds a token is refused, anywhere', async ($, on) => {
    inUmbrella(on)
    await $.session.start(SESSION)

    const token = `ghp_${'x9Y8'.repeat(9)}`
    const ran = await $.tool.call({ tool: 'Write', file_path: `${ROOT}/docs/notes.md`, content: `token=${token}\n` })

    expect(ran.deny).toContain('a GitHub token')
  })

  test('Read of a secret file is refused', async ($, on) => {
    inUmbrella(on)
    await $.session.start(SESSION)

    const ran = await $.tool.call({ tool: 'Read', file_path: `${ROOT}/workspace/.env` })

    expect(ran.deny).toContain('holds secrets')
  })

  test('an edit of component PHP gets Mago findings as context, and nothing when clean', async ($, on) => {
    const world = inUmbrella(on, { mago: 'warning[no-isset]: Use of isset\n' })
    on('agent.list', () => ({ value: [] }))
    on('tool.call', () => ({ result: { filePath: '', oldString: '', newString: '', originalFile: '', structuredPatch: [], userModified: false, replaceAll: false } }))
    await $.session.start(SESSION)
    await $.command.run(commandOf('cockpit'))

    const ran = await $.tool.call({ tool: 'Edit', file_path: `${ROOT}/security/src/A.php`, old_string: 'a', new_string: 'b' })

    expect((ran.context ?? []).join('\n')).toContain('Mago on security/src/A.php is not clean')
    expect(world.runs).toContainEqual(['docker', 'exec', '-w', '/waffle-commons/security', 'waffle-dev', 'vendor/bin/mago', 'analyze', 'src/A.php'])
  })
})

describe('done means evidence', () => {
  test('a stop after a component edit is held once, and lets go after a green dod', async ($, on) => {
    const world = inUmbrella(on)
    on('agent.list', () => ({ value: [] }))
    on('classic.Stop', () => ({}))
    on('tool.call', ($, e) =>
      e.tool === 'Bash'
        ? { result: { stdout: DOD_PASS, stderr: '', interrupted: false } }
        : { result: { filePath: '', oldString: '', newString: '', originalFile: '', structuredPatch: [], userModified: false, replaceAll: false } },
    )
    await $.session.start(SESSION)

    await $.tool.call({ tool: 'Edit', file_path: `${ROOT}/security/src/A.php`, old_string: 'a', new_string: 'b' })
    const held = await $.classic.Stop({ stop_hook_active: false })
    expect(held.block).toContain('security changed since its last green `wfl dod`')
    expect((await $.classic.Stop({ stop_hook_active: false })).block).toBeUndefined()

    await $.tool.call({ tool: 'Edit', file_path: `${ROOT}/security/src/B.php`, old_string: 'a', new_string: 'b' })
    await $.tool.call({ tool: 'Bash', command: `${ROOT}/bin/wfl dod security` })
    await until(world, () => false, 20)
    expect((await $.classic.Stop({ stop_hook_active: false })).block).toBeUndefined()

    await $.command.run(commandOf('dod', '--history'))
    const pane = textOf(await $.ui.render(PANE))
    expect(pane).toContain('Last DoD per component')
    expect(pane).toContain('✓ security')
    expect(pane).toContain('coverage 97.4%')
  })

  test('an edit of docs or of the umbrella holds nothing', async ($, on) => {
    inUmbrella(on)
    on('classic.Stop', () => ({}))
    on('tool.call', () => ({ result: { filePath: '', oldString: '', newString: '', originalFile: '', structuredPatch: [], userModified: false, replaceAll: false } }))
    await $.session.start(SESSION)

    await $.tool.call({ tool: 'Edit', file_path: `${ROOT}/security/README.md`, old_string: 'a', new_string: 'b' })
    await $.tool.call({ tool: 'Edit', file_path: `${ROOT}/scripts/dod.sh`, old_string: 'a', new_string: 'b' })

    expect((await $.classic.Stop({ stop_hook_active: false })).block).toBeUndefined()
  })
})

describe('the model-callable tools', () => {
  test('dod answers a structured verdict and records it', async ($, on) => {
    inUmbrella(on)
    on('process.spawn', async function* () {
      yield { stream: 'stdout' as const, text: DOD_PASS }
      return { value: { code: 0, signal: null } }
    })
    await $.session.start(SESSION)

    const ran = await $.tool.call({ tool: 'mcp__waffle-cockpit__dod', components: ['security'] })
    const history = await $.tool.call({ tool: 'mcp__waffle-cockpit__dod_history' })

    expect(String(ran.result)).toContain('"verdict": "pass"')
    expect(String(ran.result)).toContain('wfl dod security: PASS (coverage 97.4%')
    expect(String(history.result)).toContain('"component": "security"')
  })

  test('dod refuses a name that is not a component', async ($, on) => {
    inUmbrella(on)
    await $.session.start(SESSION)

    const ran = await $.tool.call({ tool: 'mcp__waffle-cockpit__dod', components: ['../etc'] })

    expect(String(ran.result)).toContain('Not valid: ../etc')
  })
})

describe('the local-only segment', () => {
  test('shows the commits on no remote and the backup age', async ($, on) => {
    inUmbrella(on)
    await $.session.start(SESSION)

    await $.command.run(commandOf('cockpit'))

    expect(textOf(await $.ui.render({ ...PANE, component: 'PromptHint', requestId: 'prompt-hint', props: { isDraft: false, isWorking: false, hint: '' } }))).toContain('⇡91 · backup 2h00 ago')
  })
})
