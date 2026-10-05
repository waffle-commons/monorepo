import { describe, expect, test } from 'claude-code/testing'

import { simpleCommandsOf, verdictOf } from '../hooks/guard'

const DENIED = [
  'composer install',
  'php -v',
  './vendor/bin/phpunit',
  'vendor/bin/mago lint',
  'cd security && composer mago',
  'FOO=1 composer tests',
  'env -i composer validate',
  'bash -c "cd security && composer install"',
  "sh -c 'php -r 1'",
  'git submodule update --init --remote',
  'git -C security submodule update --remote',
  'git push origin 0.1.0-beta7',
  'git push origin --tags',
  'git push --follow-tags',
  'git -C contracts push origin refs/tags/0.1.0-beta7',
  'git push origin HEAD:refs/tags/1.0.0-RC1',
  'git push origin :0.1.0-beta7',
  'git push origin +1.0.0',
  'gh release create 0.1.0-beta7 --notes x',
  'git status && git push origin 1.0.0',
  'docker exec -w /waffle-commons waffle-dev git push origin 0.1.0-beta7',
  'docker exec -it waffle-dev git submodule update --remote',
]

const ALLOWED = [
  'docker exec -w /waffle-commons/security waffle-dev composer mago',
  'wfl mago security',
  'bin/wfl dod contracts',
  'wfl run contracts composer install',
  'git push origin pre-release/0.1.0-beta7',
  'git -C security push',
  'git submodule update --init -- academy',
  'echo "git push --tags"',
  "grep -rn 'composer install' docs",
  'gh release view 0.1.0-beta6',
  'git tag -l',
  'ls vendor/bin',
  'cat composer.json',
]

describe('verdictOf', () => {
  for (const line of DENIED) {
    test(`denies: ${line}`, () => {
      expect(verdictOf(line)).toBeDefined()
    })
  }

  for (const line of ALLOWED) {
    test(`allows: ${line}`, () => {
      expect(verdictOf(line)).toBeUndefined()
    })
  }

  test('the host-PHP refusal names the Docker way', () => {
    expect(verdictOf('composer install')).toContain('waffle-dev')
  })

  test('the tag refusal names the live wave', () => {
    expect(verdictOf('git push origin 0.1.0-beta7')).toContain('LIVE release wave')
  })
})

describe('simpleCommandsOf', () => {
  test('quotes, escapes, operators and substitutions split into simple commands', () => {
    expect(simpleCommandsOf(`a 'b c' "d \\"e\\"" | f && g; h $(i j) \`k\``)).toEqual([
      ['a', 'b c', 'd "e"'],
      ['f'],
      ['g'],
      ['h'],
      ['i', 'j'],
      ['k'],
    ])
  })
})
