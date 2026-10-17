/**
 * What the cockpit checks in a file before an Edit or Write lands: `mixed`
 * added to waffle-commons PHP (AGENTS.md §1, an absolute rule), and secrets
 * written into any file. Pure, so it is tested without an engine.
 *
 * Both checks look at what the change adds, never at what the file already
 * holds: an edit next to a PSR-forced `mixed`, or beside a test fixture's key,
 * goes through.
 */

/** PHP string literals, single- or double-quoted, so a message that says "mixed" is not counted. */
const PHP_STRINGS = /'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"/gs

/** `mixed` as a type: a word on its own, not a variable, a namespace segment or part of a longer name. */
const MIXED = /(?<![\w$\\-])mixed(?![\w-])/g

/** How many times PHP source names the `mixed` type, docblocks included, string literals left out. */
export function mixedCountOf(php: string): number {
  return php.replace(PHP_STRINGS, "''").match(MIXED)?.length ?? 0
}

/** Why an Edit or Write of PHP is refused for adding `mixed`, or undefined. */
export function mixedVerdictOf(before: string, after: string): string | undefined {
  const added = mixedCountOf(after) - mixedCountOf(before)
  if (added <= 0) return undefined
  return `the change adds ${added} \`mixed\` and \`mixed\` is forbidden in waffle-commons (AGENTS.md §1): params, returns, properties, closures, docblocks and @var alike. Solve the type: a precise union, or keep an untyped value in an array and narrow it in place (\`(array $data, string|int $key)\`). If a PSR signature truly forces it, stop and tell the person instead of writing it.`
}

/** One kind of secret: a name for the message and the pattern that finds it. */
type SecretRule = { name: string; pattern: RegExp; isFixtureSafe: boolean }

const RULES: readonly SecretRule[] = [
  { name: 'a private key block', pattern: /-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----/, isFixtureSafe: true },
  { name: 'an AWS access key id', pattern: /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/, isFixtureSafe: false },
  { name: 'a GitHub token', pattern: /\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b/, isFixtureSafe: false },
  { name: 'a Slack token', pattern: /\bxox[abprs]-[A-Za-z0-9-]{10,}/, isFixtureSafe: false },
  { name: 'a Stripe live key', pattern: /\b[rs]k_live_[A-Za-z0-9]{16,}/, isFixtureSafe: false },
  { name: 'a Google API key', pattern: /\bAIza[0-9A-Za-z_-]{35}\b/, isFixtureSafe: false },
  { name: 'an Anthropic API key', pattern: /\bsk-ant-[A-Za-z0-9_-]{20,}/, isFixtureSafe: false },
  { name: 'an OpenAI API key', pattern: /\bsk-(?:proj-)?[A-Za-z0-9_-]{40,}/, isFixtureSafe: false },
  { name: 'an npm token', pattern: /\bnpm_[A-Za-z0-9]{36}\b/, isFixtureSafe: false },
  { name: 'a Packagist token', pattern: /\bpackagist_[ou]ut_[A-Za-z0-9]{40,}\b/, isFixtureSafe: false },
]

/** A secret-looking value assigned to a secret-looking name: `password = "…"`, `'api_key' => '…'`. */
const ASSIGNED = /\b(?:password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|private[_-]?key|client[_-]?secret)\w*['"]?\s*(?:=>|=|:)\s*['"]([^'"\s]{20,})['"]/gi

/** Paths where fixture keys and fake secrets live on purpose. */
const FIXTURE_PATH = /(^|\/)(tests?|fixtures?|__fixtures__|testdata|spec)(\/|$)|\.(example|dist|sample|template)$/

/** Shannon entropy in bits per character: random keys sit above 4, words and placeholders below. */
export function entropyOf(text: string): number {
  const counts = new Map<string, number>()
  for (const c of text) counts.set(c, (counts.get(c) ?? 0) + 1)
  let bits = 0
  for (const n of counts.values()) {
    const p = n / text.length
    bits -= p * Math.log2(p)
  }
  return bits
}

/** The kinds of secret a text holds. */
export function secretsOf(text: string, path: string): string[] {
  const isFixture = FIXTURE_PATH.test(path)
  const found = RULES.filter(rule => !(isFixture && rule.isFixtureSafe) && rule.pattern.test(text)).map(rule => rule.name)
  if (!isFixture) {
    for (const match of text.matchAll(ASSIGNED)) {
      const value = match[1] ?? ''
      if (!/^\$|^%|\{\{|\$\{|^<|^env\(|getenv|^CHANGE|^xxx/i.test(value) && entropyOf(value) >= 4) {
        found.push('a high-entropy value assigned to a secret name')
        break
      }
    }
  }
  return found
}

/** Why a change is refused for writing a secret the file did not already hold, or undefined. */
export function secretVerdictOf(before: string, after: string, path: string): string | undefined {
  const had = new Set(secretsOf(before, path))
  const added = secretsOf(after, path).filter(name => !had.has(name))
  if (added.length === 0) return undefined
  return `the change writes ${added.join(', ')} into ${path}. Secrets never go into files Claude writes: read it from the environment (a \`.env\` the person fills, \`wfl secret-gen\`), or use \`bin2hex(random_bytes(…))\` in a test. If this is a deliberate fixture, put it under tests/ or fixtures/, or ask the person.`
}
