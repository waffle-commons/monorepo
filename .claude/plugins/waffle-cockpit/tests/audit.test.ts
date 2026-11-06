import type { On } from 'claude-code'
import { describe, expect, test } from 'claude-code/testing'

import { auditStatusOf, branchVersionOf, decisionsTextOf, findingsOf, requiresAudit, shortVersion } from '../hooks/audit'
import { verdictOf } from '../hooks/guard'
import { isLedgerPath, ledgerVerdictOf } from '../hooks/strict'
import { auditGroup } from '../hooks/view'
import type { AuditView } from '../types'
import { commandOf, HINT, inUmbrella, PANE, ROOT, SESSION, textOf, until } from './fixtures'
import type { World } from './fixtures'

const DIR = 'project_system/Audits/Beta8/release-audit'
const LEDGER_PATH = `${ROOT}/${DIR}/ledger.json`

/** What `wfl audit:status --json` prints for a run in its decisions phase. */
function statusJson(phase: string, extra: Record<string, unknown> = {}): string {
  return JSON.stringify({
    version: '0.1.0-beta8',
    run: 'release-audit',
    dir: DIR,
    scope: 'full',
    evidence: { done: 27, total: 27 },
    finders: { done: 5, total: 12, missing: [] },
    candidates: 20,
    verification: { verified: 14, unverified: [], disputed: [], confirmed: 10, plausible: 2, refuted: 2 },
    ledger: { findings: 3, by_severity: { HIGH: 1, MEDIUM: 2 }, open: { CRITICAL: 0, HIGH: 1, MEDIUM: 2 }, decided: 1, fix: 1, fixed: 0, integrated: 0 },
    gate: 'fail',
    phase,
    next: '…',
    ...extra,
  })
}

function finding(id: string, severity: string, decision: object | null = null): object {
  return {
    id, title: `title of ${id}`, phase: 'security', lens: 'A05', component: 'data', where: `data/src/X.php:${id.length}`,
    severity, verdict: 'CONFIRMED', moscow: 'MUST', proposal: 'fix', summary: `summary of ${id}`, fix: `fix of ${id}`,
    status: decision === null ? 'open' : 'accepted', decision,
  }
}

const SIGNED = { choice: 'accept', reason: 'demo only', by: 'Maintainer', at: '2026-11-05T12:00:00+01:00' }

function ledgerText(...findings: object[]): string {
  return JSON.stringify({ version: '0.1.0-beta8', run: 'release-audit', findings }, null, 2)
}

describe('reading the audit', () => {
  test('which releases wait for their audit, as wfl pre-release --all holds them', () => {
    expect(['0.1.0-beta8', '0.1.0-beta12', '1.0.0-RC1', '1.0.0', '1.1.0', '2.0.0-RC2'].every(requiresAudit)).toBe(true)
    expect(['0.1.0-beta7', '1.0.1', '1.2.3'].some(requiresAudit)).toBe(false)
    expect(branchVersionOf('pre-release/0.1.0-beta8')).toBe('0.1.0-beta8')
    expect(branchVersionOf('main')).toBeUndefined()
    expect([shortVersion('0.1.0-beta8'), shortVersion('1.0.0-RC1'), shortVersion('1.1.0')]).toEqual(['beta8', 'RC1', '1.1.0'])
  })

  test('the status report becomes the line: phase, progress, open CRITICAL and HIGH', () => {
    const seen = auditStatusOf(statusJson('decisions'))
    expect(seen).toEqual({ version: '0.1.0-beta8', run: 'release-audit', profile: '', phase: 'decisions', progress: 'decided 1/3', openCritical: 0, openHigh: 1, gate: 'fail' })
    expect(auditStatusOf(statusJson('finders'))?.progress).toBe('5/12 finders')
    expect(auditStatusOf('not json')).toBeUndefined()
    const drawn = auditGroup(seen).map(segment => segment.text).join('')
    expect(drawn).toBe('audit beta8 · decided 1/3 · 1 HIGH')
    expect(auditGroup({ ...seen!, phase: 'not-started' }).map(s => s.text).join('')).toBe('audit beta8 not started')
    expect(auditGroup({ ...seen!, phase: 'done', gate: 'pass' }).map(s => s.text).join('')).toBe('audit beta8 ✓')
    expect(auditGroup({ ...seen!, profile: 'economy' }).map(s => s.text).join('')).toBe('audit beta8 · economy · decided 1/3 · 1 HIGH')
    expect(auditGroup(null)).toEqual([])
  })

  test('the ledger lists most severe first, with the decision on one line', () => {
    const rows = findingsOf(ledgerText(finding('S-B1-02', 'MEDIUM'), finding('S-B1-01', 'HIGH', SIGNED), finding('M-x-01', 'LOW')))!
    expect(rows.map(f => f.id)).toEqual(['S-B1-01', 'S-B1-02', 'M-x-01'])
    expect(rows[0]?.decision).toBe('accept · Maintainer · 2026-11-05 · demo only')
    expect(findingsOf('{"no": "findings"}')).toBeUndefined()
    const view: AuditView = { version: '0.1.0-beta8', run: 'release-audit', dir: DIR, findings: rows, selected: '', choice: 'fix', message: '', recorded: ['S-B1-01 accept'], isBusy: false }
    expect(decisionsTextOf(view)).toContain('1/3 findings decided')
    expect(decisionsTextOf(view)).toContain('Recorded just now: S-B1-01 accept.')
  })
})

describe('only the maintainer decides', () => {
  test('the guard refuses wfl audit:sign and the script behind it, however spelled', () => {
    for (const command of [
      'wfl audit:sign 0.1.0-beta8 S-A05-01 accept "demo only"',
      '/work/bin/wfl audit:sign 0.1.0-beta8 S-A05-01 fix',
      'WFL_AUDIT_SIGNER=cockpit AI_AGENT= wfl audit:sign 0.1.0-beta8 S-A05-01 fix',
      'python3 -I scripts/release-audit.py sign 0.1.0-beta8 S-A05-01 fix',
      'scripts/release-audit.py sign 0.1.0-beta8 S-A05-01 fix',
      'bash bin/wfl audit:sign 0.1.0-beta8 S-A05-01 fix',
      "sh -c 'wfl audit:sign 0.1.0-beta8 S-A05-01 fix'",
      'wfl audit:status 0.1.0-beta8 && wfl audit:sign 0.1.0-beta8 S-A05-01 fix',
    ]) {
      expect(verdictOf(command)).toContain("maintainer's decision")
    }
    for (const command of ['wfl audit:status --latest --json', 'wfl audit:check 0.1.0-beta8 --gate', 'python3 scripts/release-audit.py claims 0.1.0-beta8 S-A05']) {
      expect(verdictOf(command)).toBeUndefined()
    }
  })

  test("a ledger edit that writes, changes or erases a decision is refused; the rest is Claude's", () => {
    const open = ledgerText(finding('S-A05-01', 'HIGH'))
    const decided = ledgerText(finding('S-A05-01', 'HIGH', SIGNED))
    expect(isLedgerPath(LEDGER_PATH)).toBe(true)
    expect(isLedgerPath(`${ROOT}/${DIR}/consolidated.md`)).toBe(false)
    expect(ledgerVerdictOf(LEDGER_PATH, '', open)).toBeUndefined() // the triager's first write
    expect(ledgerVerdictOf(LEDGER_PATH, open, decided)).toContain('S-A05-01')
    expect(ledgerVerdictOf(LEDGER_PATH, decided, open)).toContain('S-A05-01') // erasing a sign-off
    expect(ledgerVerdictOf(LEDGER_PATH, decided, ledgerText())).toContain('S-A05-01') // dropping the finding
    expect(ledgerVerdictOf(LEDGER_PATH, decided, decided.replace('"roadmap"', '"roadmap"').replace('"summary of S-A05-01"', '"a better summary"'))).toBeUndefined()
    expect(ledgerVerdictOf(LEDGER_PATH, open, `${open.slice(0, -2)} "choice": "fix"`)).toContain('decision') // broken JSON, one more decision field
    expect(ledgerVerdictOf(`${ROOT}/notes/ledger.json`, open, decided)).toBeUndefined()
  })
})

/** Answers `wfl audit:sign` by writing the decision into the ledger, as the script does. */
function signs(on: On, world: World, files: Record<string, string>, seen: { argv: string[]; env: Record<string, string> | undefined }[]): void {
  on('process.spawn', async function* ($, e) {
    world.runs.push([...e.argv])
    seen.push({ argv: [...e.argv], env: e.env === undefined ? undefined : { ...e.env } })
    const [, , , id, choice, reason] = e.argv
    const ledger = JSON.parse(files[LEDGER_PATH] ?? '{}') as { findings: { id: string; decision: object | null; status: string }[] }
    for (const one of ledger.findings) {
      if (one.id === id) {
        one.decision = { choice, reason: reason ?? '', by: 'Maintainer', at: '2026-11-05T12:00:00+01:00' }
        one.status = choice === 'accept' ? 'accepted' : choice === 'post-v1' ? 'deferred' : 'open'
      }
    }
    files[LEDGER_PATH] = JSON.stringify(ledger)
    yield { stream: 'stdout' as const, text: `✓ ${id}: ${choice} · Maintainer · 2026-11-05T12:00:00+01:00\n` }
    return { value: { code: 0, signal: null } }
  })
}

const AUDIT_PANE = { ...PANE, plugin: 'waffle-cockpit', requestId: 'waffle-audit', props: { ...PANE.props, title: 'Release audit' } }

describe('the /audit pane', () => {
  test('without a run it says so and opens nothing', async ($, on) => {
    const world = inUmbrella(on)
    await $.session.start(SESSION)

    const { text } = await $.command.run(commandOf('audit'))

    expect(text).toContain('No release audit run yet')
    expect(world.opened).not.toContain('waffle-audit')
  })

  test('records the decisions the maintainer takes, through wfl audit:sign, with no model turn', async ($, on) => {
    const files: Record<string, string> = { [LEDGER_PATH]: ledgerText(finding('S-A05-01', 'HIGH'), finding('S-A07-01', 'MEDIUM')) }
    const world = inUmbrella(on, { auditStatus: statusJson('decisions'), files })
    const seen: { argv: string[]; env: Record<string, string> | undefined }[] = []
    signs(on, world, files, seen)
    await $.session.start(SESSION)

    const { text } = await $.command.run(commandOf('audit', '0.1.0-beta8'))
    expect(text).toContain('2 finding(s), 0 decided')
    expect(world.opened).toContain('waffle-audit')

    const ui = await $.ui.mount(AUDIT_PANE)
    expect((await ui.find({ type: 'Text', text: /S-A05-01 · HIGH/ }))?.text).toContain('title of S-A05-01')

    // Accepting the risk without a reason records nothing.
    await $.ui.select({ plugin: 'waffle-cockpit', key: 'audit-choice', value: 'accept' })
    await $.ui.input({ plugin: 'waffle-cockpit', key: 'audit-reason', text: '' })
    expect(seen).toHaveLength(0)
    expect((await ui.find({ type: 'Text', text: /needs a reason/ }))?.text).toContain('Accepting the risk')

    await $.ui.input({ plugin: 'waffle-cockpit', key: 'audit-reason', text: 'demo code path only' })
    await until(world, () => world.toasts.some(t => t.startsWith('Recorded')))

    expect(seen[0]?.argv).toEqual([`${ROOT}/bin/wfl`, 'audit:sign', '0.1.0-beta8', 'S-A05-01', 'accept', 'demo code path only'])
    expect(seen[0]?.env?.WFL_AUDIT_SIGNER).toBe('cockpit')
    expect(world.toasts).toContain('Recorded S-A05-01 accept')
    // The pane moves on to the next undecided finding.
    expect((await ui.find({ type: 'Text', text: /^S-A07-01 · MEDIUM/ }))?.text).toContain('title of S-A07-01')
    await ui.unmount()
  })

  test('the guard refuses a ledger edit that signs for the maintainer, and lets the rest through', async ($, on) => {
    const files: Record<string, string> = { [LEDGER_PATH]: ledgerText(finding('S-A05-01', 'HIGH')) }
    inUmbrella(on, { files })
    on('tool.call', () => ({ deny: 'beneath' }))
    await $.session.start(SESSION)

    const signing = await $.tool.call({ tool: 'Edit', file_path: LEDGER_PATH, old_string: '"decision": null', new_string: '"decision": {"choice": "fix", "by": "Claude", "at": "now"}' })
    expect(signing.deny).toContain("maintainer's decision")

    const plain = await $.tool.call({ tool: 'Edit', file_path: LEDGER_PATH, old_string: '"summary of S-A05-01"', new_string: '"a clearer summary"' })
    expect(plain.deny).toBe('beneath')

    const sign = await $.tool.call({ tool: 'Bash', command: 'wfl audit:sign 0.1.0-beta8 S-A05-01 fix' })
    expect(sign.deny).toContain("maintainer's decision")
  })

  test('the line under the prompt shows the audit of the branch release, or that it has not started', async ($, on) => {
    inUmbrella(on, { branch: 'pre-release/0.1.0-beta8\n', auditStatus: statusJson('finders') })
    await $.session.start(SESSION)

    await $.command.run(commandOf('cockpit'))
    expect(textOf(await $.ui.render(HINT))).toContain('audit beta8 · 5/12 finders · 1 HIGH')
  })

  test('a release that needs its audit and has none says not started', async ($, on) => {
    inUmbrella(on, { branch: 'pre-release/0.1.0-beta8\n' })
    await $.session.start(SESSION)

    await $.command.run(commandOf('cockpit'))
    expect(textOf(await $.ui.render(HINT))).toContain('audit beta8 not started')
  })
})
