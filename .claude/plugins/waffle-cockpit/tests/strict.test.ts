import { describe, expect, test } from 'claude-code/testing'

import { DEFAULTS, optionsOf } from '../hooks/options'
import { entropyOf, mixedCountOf, mixedVerdictOf, secretsOf, secretVerdictOf } from '../hooks/strict'

describe('mixed', () => {
  test('counts the type in signatures, properties and docblocks, not in strings or longer names', () => {
    const php = [
      'public function get(mixed $key): mixed',
      'private mixed $value;',
      '/** @param array<string, mixed> $data */',
      "throw new Exception('mixed is forbidden');",
      '$mixed = 1; $this->mixedValue = 2; Mixed\\Thing::x(); mixed_case();',
    ].join('\n')
    expect(mixedCountOf(php)).toBe(4)
  })

  test('only what the change adds is refused', () => {
    expect(mixedVerdictOf('', 'function f(mixed $x): void {}')).toContain('forbidden in waffle-commons')
    expect(mixedVerdictOf('function f(mixed $x): void {}', 'function f(mixed $x): int { return 1; }')).toBeUndefined()
    expect(mixedVerdictOf('function f(mixed $x) {}', 'function f(int $x) {}')).toBeUndefined()
  })
})

describe('secrets', () => {
  // Built from pieces so this file itself holds no token-shaped literal.
  const ghToken = `ghp_${'a1B2'.repeat(9)}`
  const awsKey = 'AKIA' + 'Q3EGWZ7RXN4TLKPM'

  test('provider tokens are found anywhere, test fixtures included', () => {
    expect(secretsOf(`token: ${ghToken}`, 'src/A.php')).toEqual(['a GitHub token'])
    expect(secretsOf(`'${awsKey}'`, 'tests/Fixtures/aws.php')).toEqual(['an AWS access key id'])
  })

  test('a private key block is allowed under tests/ and fixtures/', () => {
    const pem = ['-----BEGIN EC ', 'PRIVATE KEY-----\nMHc…\n-----END EC PRIVATE KEY-----'].join('')
    expect(secretsOf(pem, 'src/Keys.php')).toEqual(['a private key block'])
    expect(secretsOf(pem, 'auth/tests/Fixtures/passkey.pem')).toEqual([])
  })

  test('a high-entropy value assigned to a secret name, but not a placeholder or an env lookup', () => {
    const key = ['q8Zr2LmX', '7vB4nT1k', 'Pw9sYc3H'].join('')
    expect(secretsOf(`'api_key' => '${key}'`, 'config/app.php')).toEqual(['a high-entropy value assigned to a secret name'])
    expect(secretsOf("'api_key' => 'CHANGE_ME_CHANGE_ME_CHANGE_ME'", 'config/app.php')).toEqual([])
    expect(secretsOf("password: '${DB_PASSWORD_FROM_THE_ENV}'", 'compose.yaml')).toEqual([])
    expect(secretsOf("'password' => 'aaaaaaaaaaaaaaaaaaaaaaaa'", 'config/app.php')).toEqual([])
  })

  test('only a secret the file did not hold is refused', () => {
    expect(secretVerdictOf('', `x = "${ghToken}"`, 'a.ts')).toContain('a GitHub token')
    expect(secretVerdictOf(`x = "${ghToken}"`, `x = "${ghToken}" // kept`, 'a.ts')).toBeUndefined()
  })

  test('entropy', () => {
    expect(entropyOf('aaaa')).toBe(0)
    expect(entropyOf(['q8Zr2LmX', '7vB4nT1k', 'Pw9sYc3H'].join(''))).toBeGreaterThan(4)
  })
})

describe('options', () => {
  test('defaults, then valid stored values, invalid ones ignored', () => {
    expect(optionsOf(undefined)).toEqual(DEFAULTS)
    const set = optionsOf({ contextWarn: 70, contextAlert: 65, instantLint: 'lint', guard: 'loose', secretScan: false, jobLingerSeconds: -1 })
    expect(set.contextWarn).toBe(70)
    expect(set.contextAlert).toBe(71)
    expect(set.instantLint).toBe('lint')
    expect(set.guard).toBe('strict')
    expect(set.secretScan).toBe(false)
    expect(set.jobLingerSeconds).toBe(60)
  })
})
