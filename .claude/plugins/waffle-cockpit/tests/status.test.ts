import { describe, expect, test } from 'claude-code/testing'

import { dirtyComponentsOf, dirtyCountOf, phaseOf } from '../hooks/status'
import { CHANGED } from './fixtures'

describe('phaseOf', () => {
  test('the v1 train', () => {
    expect(phaseOf('pre-release/0.1.0-beta7')).toBe('beta7 build')
    expect(phaseOf('pre-release/0.1.0-beta8')).toBe('beta8 freeze')
    expect(phaseOf('pre-release/1.0.0-RC1')).toBe('RC1 certification')
  })

  test('outside the train', () => {
    expect(phaseOf('pre-release/0.1.0-beta6')).toBe('beta6')
    expect(phaseOf('pre-release/1.0.0')).toBe('1.0.0')
    expect(phaseOf('main')).toBe('')
  })
})

describe('the changed-components report', () => {
  test('counts the dirty locations', () => {
    expect(dirtyCountOf(CHANGED)).toBe(3)
    expect(dirtyCountOf('✓ working tree clean across all tracked locations')).toBe(0)
    expect(dirtyCountOf('something else')).toBeUndefined()
  })

  test('names the dirty components, never the umbrella root', () => {
    expect(dirtyComponentsOf(CHANGED)).toEqual(['security', 'http'])
  })
})
