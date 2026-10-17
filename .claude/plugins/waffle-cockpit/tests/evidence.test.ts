import { describe, expect, test } from 'claude-code/testing'

import { EMPTY_EVIDENCE, isGated, lintContextOf, localOf, placeOf, recordOf, runsOfOutput, staleOf, stopReasonOf, withEdit, withGreen, withRecords } from '../hooks/evidence'
import { localGroup } from '../hooks/view'

const COMPONENTS = new Set(['security', 'contracts'])

describe('where an edit lands', () => {
  test('a component and its inner path; vendor, unknown dirs and the umbrella root are not components', () => {
    expect(placeOf('/work', '/work/security/src/A.php', COMPONENTS)).toEqual({ component: 'security', inner: 'src/A.php' })
    expect(placeOf('/work/', '/work/security/vendor/x/B.php', COMPONENTS)).toBeUndefined()
    expect(placeOf('/work', '/work/scripts/dod.sh', COMPONENTS)).toBeUndefined()
    expect(placeOf('/work', '/work/AGENTS.md', COMPONENTS)).toBeUndefined()
    expect(placeOf('/work', '/elsewhere/security/src/A.php', COMPONENTS)).toBeUndefined()
  })

  test('PHP and the gate configuration are gated; docs are not', () => {
    expect(isGated('src/A.php')).toBe(true)
    expect(isGated('composer.json')).toBe(true)
    expect(isGated('mago.toml')).toBe(true)
    expect(isGated('README.md')).toBe(false)
  })
})

describe('evidence', () => {
  test('an edit after the last green run is stale; a green run clears it', () => {
    let ev = withEdit(EMPTY_EVIDENCE, 'security', 10)
    ev = withEdit(ev, 'contracts', 20)
    ev = withGreen(ev, 'contracts', 30)
    expect(staleOf(ev)).toEqual(['security'])
    expect(staleOf(withEdit(ev, 'contracts', 40))).toEqual(['contracts', 'security'])
    expect(stopReasonOf(['security'])).toContain('security changed since its last green `wfl dod`')
  })
})

const PASS = '═══ Definition of Done — contracts ═══\n→ 1/5 composer mago…\n✓ mago clean (zero diagnostics)\n→ 3/5 line coverage (≥ 95%)…\n✓ coverage 98.71% (≥ 95%)\n✓ DoD PASS — contracts\n'
const FAIL = '═══ Definition of Done — security ═══\n→ 2/5 composer tests…\n! tests FAILED\n      1) RateLimiterTest::testX\n✗ DoD FAIL — security (see findings above)\n'

describe('DoD output', () => {
  test('one run per header, finished runs only', () => {
    const runs = runsOfOutput(`${PASS}${FAIL}═══ Definition of Done — http ═══\n→ 1/5 composer mago…\n`)
    expect(runs.map(run => [run.component, run.verdict])).toEqual([
      ['contracts', 'pass'],
      ['security', 'fail'],
    ])
  })

  test('records keep the coverage and the failed gates, newest per component', () => {
    const [pass, fail] = runsOfOutput(`${PASS}${FAIL}`)
    if (pass === undefined || fail === undefined) throw new Error('two runs expected')
    expect(recordOf(pass, 5)).toEqual({ component: 'contracts', verdict: 'pass', at: 5, coverage: '98.71', failed: [] })
    expect(recordOf(fail, 6).failed).toEqual(['tests'])
    const history = withRecords({}, [recordOf(fail, 6)])
    expect(withRecords(history, [{ ...recordOf(fail, 9), verdict: 'pass', failed: [] }]).security?.at).toBe(9)
  })
})

describe('the instant check', () => {
  test('clean runs say nothing', () => {
    expect(lintContextOf('security', 'src/A.php', [' INFO No issues found.\n', '\n INFO No issues found.\n'])).toBeUndefined()
  })

  test('findings reach the model, capped', () => {
    const out = lintContextOf('security', 'src/A.php', ['warning[no-isset]: Use of isset\n  ┌─ src/A.php:12:9'], 60)
    expect(out).toContain('Mago on security/src/A.php is not clean')
    expect(out).toContain('no-isset')
    const many = Array.from({ length: 80 }, (_, i) => `error: finding ${i}`).join('\n')
    expect(lintContextOf('security', 'src/A.php', [many], 60)).toContain('20 more line(s)')
  })
})

describe('local-only and backup', () => {
  test('the script output', () => {
    expect(localOf('local-only 91\nbackup-age-s 21600\n')).toEqual({ localOnly: 91, backupAgeS: 21600 })
    expect(localOf('local-only 0\nbackup-age-s none\n')).toEqual({ localOnly: 0, backupAgeS: null })
  })

  test('the segment: hidden when all is pushed, then dim, yellow, red with age', () => {
    const text = (n: number | null, age: number | null) =>
      localGroup(n, age, 24)
        .map(segment => segment.text)
        .join('')
    expect(text(0, 100)).toBe('')
    expect(text(91, null)).toBe('⇡91 · no backup')
    expect(text(91, 6 * 3600)).toBe('⇡91 · backup 6h00 ago')
    expect(localGroup(91, 30 * 3600, 24).at(-1)?.tone).toBe('yellow')
    expect(localGroup(91, 80 * 3600, 24).at(-1)?.tone).toBe('red')
  })
})
