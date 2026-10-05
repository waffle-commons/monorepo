/**
 * The cockpit's lines under the prompt, as data: three lines of coloured
 * segments built from what the session, the repository and the umbrella
 * report. Pure, so the layout is tested without an engine.
 *
 *   1. model · effort │ repo ⎇ branch ●dirty │ phase · waffle-dev · igor
 *   2. context bar, tokens │ prompt cache │ cost · duration · diff
 *   3. 5h / 7d limits │ PR │ the engine's own hint (shortcuts, esc to interrupt)
 */
import type { CockpitStatus, RepoInfo, SessionInfo } from '../types'

export type Tone = 'plain' | 'dim' | 'bold' | 'green' | 'yellow' | 'red' | 'cyan' | 'magenta' | 'blue'

export type Segment = { text: string; tone: Tone }

export type Line = Segment[]

export type ViewInput = {
  session: SessionInfo | null
  repo: RepoInfo | null
  waffle: CockpitStatus | null
  /** `$.clock.now()`, for durations and "ago". */
  now: number
  /** The engine's own hint line (`? for shortcuts`, `esc to interrupt`); empty for none. */
  hint: string
}

const SEPARATOR: Segment = { text: ' │ ', tone: 'dim' }
const DOT: Segment = { text: ' · ', tone: 'dim' }

/** `claude-opus-5-5` → `Opus 5.5`; `claude-haiku-4-5-20251001` → `Haiku 4.5`; anything else as given. */
export function modelLabel(id: string): string {
  const match = /^claude-([a-z]+)-(\d+)(?:-(\d{1,2}))?(?:-\d{8})?(\[1m\])?$/.exec(id)
  if (match === null) return id
  const [, family = '', major = '', minor, wide] = match
  const name = family.charAt(0).toUpperCase() + family.slice(1)
  return `${name} ${minor === undefined ? major : `${major}.${minor}`}${wide === undefined ? '' : ' 1M'}`
}

/** Green under `warn`, yellow under `alert`, red from `alert` on. */
export function level(percent: number, warn = 60, alert = 80): Tone {
  return percent >= alert ? 'red' : percent >= warn ? 'yellow' : 'green'
}

export function bar(percent: number, width = 10): string {
  const filled = Math.max(0, Math.min(width, Math.round((percent / 100) * width)))
  return '▓'.repeat(filled) + '░'.repeat(width - filled)
}

export function tokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1000) return `${Math.round(n / 1000)}k`
  return String(n)
}

export function duration(ms: number): string {
  const minutes = Math.floor(ms / 60_000)
  return minutes >= 60 ? `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, '0')}` : `${minutes}m`
}

/** An ISO 8601 instant as local `HH:MM`; empty when it does not parse. */
export function clockOf(iso: string): string {
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ''
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

function joined(groups: Line[], separator: Segment): Line {
  return groups.filter(group => group.length > 0).flatMap((group, i) => (i === 0 ? group : [separator, ...group]))
}

function modelGroup(session: SessionInfo | null): Line {
  const group: Line = [{ text: session?.model ? modelLabel(session.model) : 'Claude', tone: 'bold' }]
  if (session?.effort) group.push(DOT, { text: session.effort, tone: 'magenta' })
  return group
}

function repoGroup(repo: RepoInfo | null): Line {
  if (repo === null) return []
  return [
    { text: repo.repo, tone: 'cyan' },
    { text: ` ⎇ ${repo.branch} `, tone: 'plain' },
    repo.dirty > 0 ? { text: `●${repo.dirty}`, tone: 'yellow' } : { text: '✓', tone: 'green' },
  ]
}

function waffleGroup(waffle: CockpitStatus | null): Line {
  if (waffle === null) return []
  const isUp = waffle.container === 'running'
  const group: Line = []
  if (waffle.phase !== '') group.push({ text: waffle.phase, tone: 'blue' }, DOT)
  group.push({ text: 'waffle-dev ', tone: 'plain' }, isUp ? { text: '●', tone: 'green' } : { text: `○ ${waffle.container}`, tone: 'red' })
  if (waffle.igor !== '') group.push(DOT, { text: `igor ${waffle.igor}`, tone: 'dim' })
  return group
}

function contextGroup(session: SessionInfo | null): Line {
  const percent = session?.contextPercent
  if (percent === null || percent === undefined) return [{ text: 'ctx —', tone: 'dim' }]
  const group: Line = [
    { text: 'ctx ', tone: 'plain' },
    { text: `${bar(percent)} ${Math.round(percent)}%`, tone: level(percent) },
  ]
  const window = session?.contextWindow
  if (window) {
    const used = session?.contextTokens ?? Math.round((window * percent) / 100)
    group.push({ text: ` ${tokens(used)}/${tokens(window)}`, tone: 'dim' })
  }
  return group
}

function cacheGroup(session: SessionInfo | null, now: number): Line {
  if (session === null || session.cacheInput === 0) return []
  const ratio = Math.round((session.cacheRead / session.cacheInput) * 100)
  const group: Line = [{ text: 'cache ', tone: 'plain' }, { text: `${ratio}%`, tone: level(100 - ratio, 30, 60) }]
  if (session.lastTurnAt !== null) group.push({ text: ` · last turn ${duration(now - session.lastTurnAt)} ago`, tone: 'dim' })
  return group
}

function spendGroup(session: SessionInfo | null, repo: RepoInfo | null, now: number): Line {
  const parts: Line[] = []
  if (session?.costUsd !== null && session?.costUsd !== undefined) parts.push([{ text: `$${session.costUsd.toFixed(2)}`, tone: 'plain' }])
  if (session?.startedAt !== null && session?.startedAt !== undefined) parts.push([{ text: duration(now - session.startedAt), tone: 'plain' }])
  if (repo !== null && (repo.added > 0 || repo.removed > 0)) {
    parts.push([
      { text: `+${repo.added}`, tone: 'green' },
      { text: ' ', tone: 'plain' },
      { text: `−${repo.removed}`, tone: 'red' },
    ])
  }
  return joined(parts, DOT)
}

function limitGroups(session: SessionInfo | null): Line[] {
  const labels: Record<string, string> = { five_hour: '5h', seven_day: '7d', spend_limit: 'spend' }
  return (session?.limits ?? []).map(limit => {
    const group: Line = [
      { text: `${labels[limit.kind] ?? limit.kind} `, tone: 'plain' },
      { text: `${bar(limit.percent, 6)} ${Math.round(limit.percent)}%`, tone: level(limit.percent, 50, 80) },
    ]
    const at = limit.kind === 'five_hour' ? clockOf(limit.resetsAt) : ''
    if (at !== '') group.push({ text: ` (resets ${at})`, tone: 'dim' })
    return group
  })
}

function prGroup(repo: RepoInfo | null): Line {
  if (repo?.pr === null || repo?.pr === undefined) return []
  const marks: Record<string, Segment> = {
    APPROVED: { text: ' ✓ approved', tone: 'green' },
    CHANGES_REQUESTED: { text: ' ✗ changes requested', tone: 'red' },
    REVIEW_REQUIRED: { text: ' … review pending', tone: 'yellow' },
    DRAFT: { text: ' draft', tone: 'dim' },
  }
  const mark = marks[repo.pr.review]
  return mark === undefined ? [{ text: `PR #${repo.pr.number}`, tone: 'plain' }] : [{ text: `PR #${repo.pr.number}`, tone: 'plain' }, mark]
}

/** The cockpit's lines; a line with nothing to say is left out. */
export function linesOf(input: ViewInput): Line[] {
  const { session, repo, waffle, now, hint } = input
  const lines: Line[] = [
    joined([modelGroup(session), repoGroup(repo), waffleGroup(waffle)], SEPARATOR),
    joined([contextGroup(session), cacheGroup(session, now), spendGroup(session, repo, now)], SEPARATOR),
    joined([...limitGroups(session), prGroup(repo), hint.trim() === '' ? [] : [{ text: hint.trim(), tone: 'dim' }]], SEPARATOR),
  ]
  return lines.filter(line => line.length > 0)
}
