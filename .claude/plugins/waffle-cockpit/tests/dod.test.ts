import { describe, expect, test } from 'claude-code/testing'

import { applyLine, emptyRun, excerptOf, LineSplitter, summaryOf } from '../hooks/dod'

const PASS = [
  '═══ Definition of Done — contracts ═══',
  '→ 1/5 composer mago (must be ZERO output)…',
  '✓ mago clean (zero diagnostics)',
  '→ 2/5 composer tests…',
  '✓ tests green',
  '→ 3/5 line coverage (≥ 95%)…',
  '✓ coverage 97.2% (≥ 95%)',
  '→ 4/5 composer igor (0 KO, auditor 0.9.7)…',
  '✓ igor 0 KO',
  '→ 5/5 compare-audit skipped (pass --compare-audit to include)',
  '───────────────────────────────────────',
  '✓ DoD PASS — contracts',
]

const ISSUES = [
  '═══ Definition of Done — security ═══',
  '→ 1/5 composer mago (must be ZERO output)…',
  '✓ mago clean (zero diagnostics)',
  '→ 2/5 composer tests…',
  '! tests passed with PHPUnit issues — only a clean "OK (…)" run is green',
  '      OK, but there were issues!',
  '      Tests: 120, Assertions: 300, PHPUnit Notices: 1.',
  '      details: docker exec -w /waffle-commons/security waffle-dev vendor/bin/phpunit --no-coverage --display-all-issues',
  '→ 3/5 line coverage (≥ 95%)…',
  '✓ coverage 96.1% (≥ 95%)',
  '→ 4/5 composer igor (0 KO, auditor 0.9.7)…',
  '✓ igor 0 KO',
  '→ 5/5 compare-audit skipped (pass --compare-audit to include)',
  '✗ DoD FAIL — security (see findings above)',
]

const runOf = (lines: string[], component: string) => lines.reduce(applyLine, emptyRun(component))

describe('applyLine', () => {
  test('a green run passes every gate it ran', () => {
    const run = runOf(PASS, 'contracts')
    expect(run.verdict).toBe('pass')
    expect(run.steps.map(step => step.state)).toEqual(['pass', 'pass', 'pass', 'pass', 'skipped'])
    expect(summaryOf([run])).toBe('wfl dod contracts: PASS (coverage 97.2% (≥ 95%))')
  })

  test('PHPUnit issues fail the tests gate and keep their detail lines', () => {
    const run = runOf(ISSUES, 'security')
    const tests = run.steps.find(step => step.name === 'tests')
    expect(run.verdict).toBe('fail')
    expect(tests?.state).toBe('fail')
    expect(tests?.excerpt).toHaveLength(3)
    expect(summaryOf([run])).toContain('FAIL at tests')
    expect(excerptOf([run])).toContain('# security — tests')
  })

  test('a failure before the gates is the run error', () => {
    const run = runOf(["✗ container 'waffle-dev' not running (state: exited). Try: wfl up"], 'http')
    expect(run.verdict).toBe('fail')
    expect(run.error).toContain('not running')
    expect(summaryOf([run])).toContain('FAIL before the gates')
  })

  test('colour codes parse the same', () => {
    const coloured = PASS.map(line => `\u001b[0;32m${line}\u001b[0m`)
    expect(runOf(coloured, 'contracts')).toEqual(runOf(PASS, 'contracts'))
  })
})

describe('LineSplitter', () => {
  test('holds a partial line until its newline', () => {
    const splitter = new LineSplitter()
    expect(splitter.push('→ 1/5 com')).toEqual([])
    expect(splitter.push('poser mago…\n✓ ma')).toEqual(['→ 1/5 composer mago…'])
    expect(splitter.flush()).toEqual(['✓ ma'])
    expect(splitter.flush()).toEqual([])
  })
})
