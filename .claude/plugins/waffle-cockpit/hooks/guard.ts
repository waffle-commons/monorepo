/**
 * The Bash guard: the few rules a glob permission rule cannot express,
 * because they need the command's words rather than its prefix.
 *
 * - PHP tooling runs in Docker, never on the host (CLAUDE.md).
 * - `git submodule update --remote` is never a "sync" (AGENTS.md §6).
 * - Release tags are live: pushing one, or creating a GitHub release, fires
 *   the LIVE release wave (AGENTS.md §6).
 *
 * The guard only ever denies. Everything it lets through still meets the
 * permission rules in .claude/settings.json.
 */

/** PHP tools that must run inside `waffle-dev`. */
const HOST_PHP = new Set(['php', 'composer', 'phpunit', 'mago', 'igor-php', 'pie'])

/** Words that run the command after them (and their own options). */
const WRAPPERS = new Set(['env', 'command', 'exec', 'time', 'nohup', 'nice', 'builtin'])

/** Shells whose `-c` argument is itself a command line. */
const SHELLS = new Set(['sh', 'bash', 'zsh', 'dash'])

/** A version tag as the release wave cuts it: `0.1.0-beta7`, `1.0.0-RC1`, `1.0.0`. */
const VERSION_TAG = /^v?\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$/

/** `docker exec` options that take a separate value. */
const DOCKER_EXEC_OPTION_WITH_VALUE = new Set(['-e', '--env', '--env-file', '-u', '--user', '-w', '--workdir', '--detach-keys'])

/** Git's global options that take a separate value. */
const GIT_OPTION_WITH_VALUE = new Set(['-C', '-c', '--git-dir', '--work-tree', '--namespace', '--exec-path', '--config-env'])

const DOCKER_HINT = 'run it in the dev container: `wfl run <component> <command…>` or `docker exec -w /waffle-commons/<component> waffle-dev <command…>`'

/**
 * Splits a command line into simple commands, each a list of words, with
 * quotes and escapes resolved. Operators (`;` `&&` `||` `|` `&`, newlines),
 * subshell parentheses and command substitutions end a simple command.
 */
export function simpleCommandsOf(line: string): string[][] {
  const commands: string[][] = []
  let words: string[] = []
  let word = ''
  let hasWord = false

  const endWord = () => {
    if (hasWord) words.push(word)
    word = ''
    hasWord = false
  }
  const endCommand = () => {
    endWord()
    if (words.length > 0) commands.push(words)
    words = []
  }

  for (let i = 0; i < line.length; i++) {
    const c = line[i] ?? ''

    if (c === "'") {
      const close = line.indexOf("'", i + 1)
      word += close === -1 ? line.slice(i + 1) : line.slice(i + 1, close)
      hasWord = true
      i = close === -1 ? line.length : close
    } else if (c === '"') {
      i++
      while (i < line.length && line[i] !== '"') {
        if (line[i] === '\\' && i + 1 < line.length) i++
        word += line[i] ?? ''
        i++
      }
      hasWord = true
    } else if (c === '\\' && i + 1 < line.length) {
      word += line[i + 1] ?? ''
      hasWord = true
      i++
    } else if (c === ' ' || c === '\t') {
      endWord()
    } else if (c === ';' || c === '&' || c === '|' || c === '\n' || c === '(' || c === ')' || c === '`') {
      endCommand()
    } else if (c === '$' && line[i + 1] === '(') {
      endCommand()
      i++
    } else {
      word += c
      hasWord = true
    }
  }
  endCommand()

  return commands
}

/** The words after leading `VAR=value` assignments and wrapper commands. */
function commandWordsOf(words: string[]): string[] {
  let i = 0
  while (i < words.length) {
    const w = words[i] ?? ''
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(w)) {
      i++
    } else if (WRAPPERS.has(w)) {
      i++
      while (i < words.length && (words[i] ?? '').startsWith('-')) i++
    } else {
      break
    }
  }

  return words.slice(i)
}

const basenameOf = (path: string) => path.slice(path.lastIndexOf('/') + 1)

/** Why `git <args>` is refused, or undefined. */
function gitVerdictOf(args: string[]): string | undefined {
  let i = 0
  while (i < args.length && (args[i] ?? '').startsWith('-')) {
    i += GIT_OPTION_WITH_VALUE.has(args[i] ?? '') ? 2 : 1
  }
  const sub = args[i]
  const rest = args.slice(i + 1)

  if (sub === 'submodule' && rest[0] === 'update' && rest.includes('--remote')) {
    return 'never "sync" with `git submodule update --remote`: it detaches every submodule from its pre-release branch (AGENTS.md §6). Use `wfl sync:status` (read-only).'
  }

  if (sub === 'push') {
    const tagFlags = rest.filter(a => a === '--tags' || a === '--follow-tags' || a === '--mirror')
    const tagRefs = rest
      .filter(a => !a.startsWith('-'))
      .slice(1) // the first non-option word is the remote
      .filter(spec => spec.split(':').some(side => side.replace(/^\+/, '').startsWith('refs/tags/') || VERSION_TAG.test(side.replace(/^\+/, ''))))

    if (tagFlags.length > 0 || tagRefs.length > 0) {
      return `tags are live: pushing ${[...tagFlags, ...tagRefs].join(' ')} fires the LIVE release wave (AGENTS.md §6). Release tags are pushed by the human.`
    }
  }

  return undefined
}

/** The command a `docker exec [options] <container> <command…>` runs, or undefined. */
function dockerExecCommandOf(args: string[]): string[] | undefined {
  if (args[0] !== 'exec') return undefined
  let i = 1
  while (i < args.length && (args[i] ?? '').startsWith('-')) {
    i += DOCKER_EXEC_OPTION_WITH_VALUE.has(args[i] ?? '') ? 2 : 1
  }
  return args.slice(i + 1) // past the container name
}

/** Why one simple command is refused, or undefined. */
function verdictOfWords(words: string[], depth: number, isInContainer = false): string | undefined {
  const cmd = commandWordsOf(words)
  const head = cmd[0]
  if (head === undefined) return undefined

  const name = basenameOf(head)
  const args = cmd.slice(1)

  if (!isInContainer && (HOST_PHP.has(name) || /(^|\/)vendor\/bin\//.test(head))) {
    return `\`${name}\` would run on the host, and PHP never runs on the host here: ${DOCKER_HINT}.`
  }

  // PHP belongs in the container; git and release rules apply there all the same.
  const inner = name === 'docker' ? dockerExecCommandOf(args) : undefined
  if (inner !== undefined && depth < 3) return verdictOfWords(inner, depth + 1, true)

  if (name === 'git') return gitVerdictOf(args)

  if (name === 'gh' && args[0] === 'release' && args[1] === 'create') {
    return 'creating a GitHub release creates its tag on the remote, which fires the LIVE release wave (AGENTS.md §6). Releases are cut by the human.'
  }

  if (SHELLS.has(name) && depth < 3) {
    const c = args.indexOf('-c')
    const script = c === -1 ? undefined : args[c + 1]
    if (script !== undefined) return verdictOf(script, depth + 1)
  }

  return undefined
}

/**
 * Why the guard refuses a Bash command line, or undefined to let it through.
 *
 * @param line the command as the Bash tool received it
 * @param depth how many `sh -c` levels deep this line sits
 */
export function verdictOf(line: string, depth = 0): string | undefined {
  for (const words of simpleCommandsOf(line)) {
    const verdict = verdictOfWords(words, depth)
    if (verdict !== undefined) return verdict
  }

  return undefined
}
