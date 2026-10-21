import { describe, expect, test } from 'claude-code/testing'

import type { RepoInfo, SessionInfo } from '../types'
import { bar, level, linesOf, modelLabel, tokens } from '../hooks/view'
import type { Line } from '../hooks/view'

const SESSION: SessionInfo = {
  model: 'claude-opus-5-5',
  effort: 'max',
  contextPercent: 85,
  contextTokens: 850_000,
  contextWindow: 1_000_000,
  costUsd: 0.4,
  startedAt: 0,
  limits: [],
  cacheRead: 94,
  cacheInput: 100,
  lastTurnAt: 60_000,
}

const REPO: RepoInfo = { repo: 'site', branch: 'main', dirty: 0, added: 0, removed: 0, pr: null }

const text = (line: Line | undefined) => (line ?? []).map(segment => segment.text).join('')

describe('linesOf', () => {
  test('outside the umbrella: no Waffle segment, the rest stays', () => {
    const lines = linesOf({ session: SESSION, repo: REPO, waffle: null, now: 120_000, hint: '' })
    expect(lines).toHaveLength(3)
    expect(text(lines[0])).toBe('Opus 5.5 · max │ site ⎇ main ✓')
    expect(text(lines[1])).toContain('ctx ▓▓▓▓▓▓▓▓▓░ 85% 850k/1.0M')
    expect(text(lines[1])).toContain('cache 94% · last turn 1m ago')
    expect(text(lines[1])).toContain('$0.40 · 2m')
  })

  test('context turns red from 80%', () => {
    const lines = linesOf({ session: SESSION, repo: null, waffle: null, now: 0, hint: '' })
    expect(lines[1]?.find(segment => segment.text.includes('85%'))?.tone).toBe('red')
  })

  test('before the first response: a dash, no cache, no limits', () => {
    const fresh: SessionInfo = { ...SESSION, contextPercent: null, cacheInput: 0, cacheRead: 0, costUsd: null, startedAt: null }
    const lines = linesOf({ session: fresh, repo: null, waffle: null, now: 0, hint: '? for shortcuts' })
    expect(text(lines[1])).toBe('ctx —')
    expect(text(lines[2])).toBe('⧗ 0 │ no background shell, monitor or subagent')
    expect(text(lines[3])).toBe('? for shortcuts')
  })

  test('with no session data yet it still draws a model line', () => {
    expect(text(linesOf({ session: null, repo: null, waffle: null, now: 0, hint: '' })[0])).toBe('Claude')
  })
})

describe('helpers', () => {
  test('model labels', () => {
    expect(modelLabel('claude-opus-5-5')).toBe('Opus 5.5')
    expect(modelLabel('claude-haiku-4-5-20251001')).toBe('Haiku 4.5')
    expect(modelLabel('claude-sonnet-5-5[1m]')).toBe('Sonnet 5.5 1M')
    expect(modelLabel('claude-fable-5-1')).toBe('Fable 5.1')
    expect(modelLabel('gpt-x')).toBe('gpt-x')
  })

  test('bars, levels and token counts', () => {
    expect(bar(58)).toBe('▓▓▓▓▓▓░░░░')
    expect(bar(31, 6)).toBe('▓▓░░░░')
    expect(level(59)).toBe('green')
    expect(level(60)).toBe('yellow')
    expect(level(80)).toBe('red')
    expect(tokens(116_000)).toBe('116k')
    expect(tokens(1_000_000)).toBe('1.0M')
  })
})
