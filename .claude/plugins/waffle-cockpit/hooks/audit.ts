/**
 * The release audit as the cockpit shows it (the release-audit skill, scripts/release-audit.py): the
 * status line's segment, read from `wfl audit:status --json`, and the /audit pane's rows, read from the
 * run's `ledger.json`. Pure, so it is tested without an engine.
 *
 * The pane records the maintainer's decisions through `wfl audit:sign`; the guard refuses that command
 * to Claude (guard.ts) and refuses Claude's edits of a ledger's decisions (strict.ts).
 */
import type { AuditFinding, AuditStatus, AuditView } from '../types'

const SEVERITIES = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO']

/** A release version as the audit takes it: `0.1.0-beta8`, `1.0.0-RC1`, `1.1.0`. */
export const AUDIT_VERSION = /^\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$/

/** A run name: lowercase letters, digits and hyphens. */
export const AUDIT_RUN = /^[a-z0-9][a-z0-9-]*$/

/** The release version of a `pre-release/<version>` branch, or undefined. */
export function branchVersionOf(branch: string): string | undefined {
  return /^pre-release\/(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)$/.exec(branch.trim())?.[1]
}

/**
 * Whether a release waits for its audit before the tag, as `wfl pre-release --all` holds it: beta8 and
 * later betas, every minor or major release and its RCs. A patch release is exempt.
 */
export function requiresAudit(version: string): boolean {
  const beta = /^0\.1\.0-beta(\d+)$/.exec(version)
  if (beta !== null) return Number(beta[1]) >= 8
  return /^\d+\.\d+\.0(-RC\d+)?$/.test(version)
}

/** `0.1.0-beta8` → `beta8`, `1.0.0-RC1` → `RC1`; any other version as given. */
export function shortVersion(version: string): string {
  return /-(beta\d+|RC\d+)$/.exec(version)?.[1] ?? version
}

type Json = Record<string, unknown>

function objectOf(value: unknown): Json {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Json) : {}
}

function numberOf(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0
}

function stringOf(value: unknown): string {
  return typeof value === 'string' ? value : ''
}

function parsed(text: string): unknown {
  try {
    return JSON.parse(text)
  } catch {
    return undefined
  }
}

/** The phase's progress in a few words, from the status report. */
function progressOf(phase: string, report: Json, ledger: Json): string {
  const pair = (part: Json, done: string, total: string) => `${numberOf(part[done])}/${numberOf(part[total])}`
  if (phase === 'evidence') return `${pair(objectOf(report.evidence), 'done', 'total')} repos`
  if (phase === 'finders') return `${pair(objectOf(report.finders), 'done', 'total')} finders`
  if (phase === 'verification') return `${numberOf(objectOf(report.verification).verified)}/${numberOf(report.candidates)} verified`
  if (phase === 'decisions') return `decided ${pair(ledger, 'decided', 'findings')}`
  if (phase === 'integration') return `${pair(ledger, 'integrated', 'fix')} in the roadmap`
  if (phase === 'closure') return `fixed ${pair(ledger, 'fixed', 'fix')}`
  return ''
}

/** What the status line shows, from `wfl audit:status --json`; undefined when the text is not that report. */
export function auditStatusOf(json: string): AuditStatus | undefined {
  const report = objectOf(parsed(json))
  if (typeof report.version !== 'string' || typeof report.phase !== 'string') return undefined
  const ledger = objectOf(report.ledger)
  const open = objectOf(ledger.open)
  return {
    version: report.version,
    run: stringOf(report.run) || 'release-audit',
    profile: stringOf(report.profile),
    phase: report.phase,
    progress: progressOf(report.phase, report, ledger),
    openCritical: numberOf(open.CRITICAL),
    openHigh: numberOf(open.HIGH),
    gate: report.gate === 'pass' || report.gate === 'fail' ? report.gate : null,
  }
}

/** The run a status report names: its release, its name, its folder (relative to the umbrella root) and its phase. */
export function auditRunOf(json: string): { version: string; run: string; dir: string; phase: string } | undefined {
  const report = objectOf(parsed(json))
  if (typeof report.version !== 'string' || typeof report.dir !== 'string') return undefined
  return { version: report.version, run: stringOf(report.run) || 'release-audit', dir: report.dir, phase: stringOf(report.phase) }
}

/** The status of a release that needs its audit and has no run yet. */
export function notStarted(version: string): AuditStatus {
  return { version, run: 'release-audit', profile: '', phase: 'not-started', progress: '', openCritical: 0, openHigh: 0, gate: null }
}

/** A decision as one line: `accept · Leslie Petrimaux · 2026-11-20 · demo only`; empty when there is none. */
export function decisionLabelOf(decision: unknown): string {
  const d = objectOf(decision)
  const choice = stringOf(d.choice)
  if (choice === '') return ''
  const reason = stringOf(d.reason).trim()
  return [choice, stringOf(d.by) || '?', stringOf(d.at).slice(0, 10) || '?', ...(reason === '' ? [] : [reason])].join(' · ')
}

/** The ledger's findings, most severe first; undefined when the text is not a ledger. */
export function findingsOf(ledgerJson: string): AuditFinding[] | undefined {
  const ledger = objectOf(parsed(ledgerJson))
  if (!Array.isArray(ledger.findings)) return undefined
  const rank = (severity: string) => {
    const at = SEVERITIES.indexOf(severity)
    return at === -1 ? SEVERITIES.length : at
  }
  return ledger.findings
    .map(objectOf)
    .filter(f => stringOf(f.id) !== '')
    .map(
      (f): AuditFinding => ({
        id: stringOf(f.id),
        severity: stringOf(f.severity),
        title: stringOf(f.title),
        where: stringOf(f.where),
        lens: stringOf(f.lens),
        verdict: stringOf(f.verdict),
        moscow: stringOf(f.moscow),
        proposal: stringOf(f.proposal),
        summary: stringOf(f.summary),
        fix: stringOf(f.fix),
        status: stringOf(f.status) || 'open',
        decision: decisionLabelOf(f.decision),
      }),
    )
    .sort((a, b) => rank(a.severity) - rank(b.severity) || a.id.localeCompare(b.id))
}

/** A choice the pane records, from the triager's proposal (fix when it proposes nothing usable). */
export function choiceOf(proposal: string): AuditView['choice'] {
  return proposal === 'accept' || proposal === 'post-v1' ? proposal : 'fix'
}

/** The finding the pane selects first: the most severe undecided one, else the first. */
export function firstOf(findings: readonly AuditFinding[]): AuditFinding | undefined {
  return findings.find(f => f.decision === '') ?? findings[0]
}

/** The picker's line for a finding: id, severity, decided or not, title. */
export function optionLabelOf(finding: AuditFinding): string {
  return `${finding.id}  ${finding.severity.padEnd(8)} ${finding.decision === '' ? '○' : '●'}  ${finding.title}`
}

/** What "Send decisions to Claude" puts in the prompt: the counts, this pane's decisions, the next step. */
export function decisionsTextOf(view: AuditView): string {
  const decided = view.findings.filter(f => f.decision !== '').length
  const run = view.run === 'release-audit' ? '' : ` --run ${view.run}`
  const lines = [`Release audit ${view.version} (${view.run}): ${decided}/${view.findings.length} findings decided in /audit.`]
  if (view.recorded.length > 0) lines.push(`Recorded just now: ${view.recorded.join(', ')}.`)
  lines.push(
    decided === view.findings.length
      ? `Every finding has its decision: continue the release audit with the integration step (wfl audit:status ${view.version}${run}).`
      : `${view.findings.length - decided} finding(s) still wait for my decision.`,
  )
  return `${lines.join('\n')}\n`
}
