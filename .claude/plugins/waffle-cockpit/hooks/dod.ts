/**
 * Reads `wfl dod <component>` output (scripts/dod.sh) into a checklist.
 *
 * dod.sh writes plain lines when piped: `→ N/6 …` as a gate starts, `✓ …` on
 * stdout or `! …` on stderr with its result, six-space-indented details under
 * a failure, and `✓ DoD PASS — c` or `✗ DoD FAIL — c` last. A gate is told by
 * its keyword rather than by position, so interleaved stdout and stderr parse
 * the same.
 */
import type { DodRun, DodStep, DodStepName } from '../types'

const STEPS: readonly DodStepName[] = ['mago', 'tests', 'coverage', 'igor', 'audit', 'compare-audit']

/** How many detail lines a failing gate keeps. */
export const EXCERPT_LINES = 40

const ANSI = /\u001b\[[0-9;]*m/g

/** The gate a start line (`→ 2/5 composer tests…`) or a result line names. */
function stepOf(text: string): DodStepName | undefined {
  if (/compare-audit/i.test(text)) return 'compare-audit'
  if (/composer audit|advisor/i.test(text)) return 'audit'
  if (/\bmago\b/i.test(text)) return 'mago'
  if (/\btests?\b/i.test(text)) return 'tests'
  if (/\bcoverage\b/i.test(text)) return 'coverage'
  if (/\bigor\b/i.test(text)) return 'igor'
  return undefined
}

/** A run that has not printed anything yet. */
export function emptyRun(component: string): DodRun {
  return {
    component,
    verdict: 'running',
    error: '',
    steps: STEPS.map((name): DodStep => ({ name, state: 'pending', message: '', excerpt: [] })),
  }
}

function withStep(run: DodRun, name: DodStepName, change: (step: DodStep) => DodStep): DodRun {
  return { ...run, steps: run.steps.map(step => (step.name === name ? change(step) : step)) }
}

/**
 * The run after one more output line.
 *
 * @param run the run so far
 * @param raw one line, without its newline
 */
export function applyLine(run: DodRun, raw: string): DodRun {
  const line = raw.replace(ANSI, '')
  const text = line.trim()
  if (text === '') return run

  // A detail line under the last failing gate.
  if (/^\s{4,}\S/.test(line)) {
    const failing = [...run.steps].reverse().find(step => step.state === 'fail')
    if (failing === undefined || failing.excerpt.length >= EXCERPT_LINES) return run
    return withStep(run, failing.name, step => ({ ...step, excerpt: [...step.excerpt, text] }))
  }

  const marker = text[0]
  const body = text.slice(1).trim()

  if (marker === '✓' && /^DoD PASS/.test(body)) return { ...run, verdict: 'pass' }
  if (marker === '✗') {
    return /^DoD FAIL/.test(body) ? { ...run, verdict: 'fail' } : { ...run, verdict: 'fail', error: body }
  }

  const name = stepOf(body)
  if (name === undefined) return run

  if (marker === '→') {
    const state = /skipped/i.test(body) ? 'skipped' : 'running'
    return withStep(run, name, step => ({ ...step, state, message: state === 'skipped' ? body : step.message }))
  }
  if (marker === '✓') return withStep(run, name, step => ({ ...step, state: 'pass', message: body }))
  if (marker === '!') return withStep(run, name, step => ({ ...step, state: 'fail', message: body }))

  return run
}

/**
 * Feeds streamed text through `applyLine`, holding a partial last line back
 * until its newline arrives.
 */
export class LineSplitter {
  private pending = ''

  /** The complete lines in `text`, after any held-back part. */
  push(text: string): string[] {
    const lines = (this.pending + text).split('\n')
    this.pending = lines.pop() ?? ''
    return lines
  }

  /** What is left once the stream has ended. */
  flush(): string[] {
    const rest = this.pending
    this.pending = ''
    return rest === '' ? [] : [rest]
  }
}

/** One line per run, for the model: the verdict and what failed. */
export function summaryOf(runs: readonly DodRun[]): string {
  return runs
    .map(run => {
      if (run.verdict === 'running') return `wfl dod ${run.component}: still running`
      if (run.error !== '') return `wfl dod ${run.component}: FAIL before the gates (${run.error})`
      const failed = run.steps.filter(step => step.state === 'fail')
      if (run.verdict === 'pass' && failed.length === 0) {
        const coverage = run.steps.find(step => step.name === 'coverage')?.message ?? ''
        return `wfl dod ${run.component}: PASS (${coverage || 'all gates green'})`
      }
      return `wfl dod ${run.component}: FAIL at ${failed.map(step => `${step.name} (${step.message})`).join('; ')}`
    })
    .join('\n')
}

/** The detail lines of every failing gate, for the clipboard. */
export function excerptOf(runs: readonly DodRun[]): string {
  return runs
    .flatMap(run =>
      run.steps
        .filter(step => step.state === 'fail')
        .map(step => [`# ${run.component} — ${step.name}: ${step.message}`, ...step.excerpt].join('\n')),
    )
    .join('\n\n')
}
