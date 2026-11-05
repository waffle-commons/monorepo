/**
 * The Bash guard: the few rules a glob permission rule cannot express,
 * because they need the command's words rather than its prefix.
 *
 * - PHP tooling runs in Docker, never on the host (CLAUDE.md).
 * - `git submodule update --remote` is never a "sync" (AGENTS.md §6).
 * - Release tags are live: pushing one, or creating a GitHub release, fires
 *   the LIVE release wave (AGENTS.md §6). The one exception is the version the
 *   person names in the `releaseTag` option: pushed by name, never in bulk,
 *   forced or deleted. A `v` prefix, or moving or deleting a release tag, is
 *   always refused.
 * - Pushes are never forced: `-f`, `--force`, `--force-with-lease` or a `+`
 *   refspec (AGENTS.md §6).
 * - A push deletes a remote ref only through `--delete`, the spelling the
 *   permission rules ask the person about: `:ref`, `-d`, a prefix such as
 *   `--del`, and `--prune` are refused (AGENTS.md §6).
 * - Push options are read as git reads them: a short cluster's letters (`-uf`
 *   is `-u -f`) and the long option a prefix expands to (`--tag` is `--tags`,
 *   `--m` is `--mirror`).
 * - Merges are merge commits: a squash or rebase merge orphans the gitlink the
 *   release wave checks (AGENTS.md §6).
 * - No `cd` / `pushd` / `popd` on the host: the Bash tool's working directory
 *   persists and is shared with the person's `!` commands, so every path is
 *   absolute (`git -C`, `docker exec -w`). Inside the container it is harmless.
 * - A heredoc's start line never ends in `\`: the continuation joins the next
 *   line to the command and the heredoc swallows the wrong text (it ate a commit
 *   subject once). One heredoc command per line, chained with `set -e`.
 * - Secret files (`.env`, keys, certificates' private halves) are never read
 *   through the shell: a Read deny rule does not cover `cat`.
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

/** Shell options that take a separate value. */
const SHELL_OPTION_WITH_VALUE = new Set(['-o', '+o', '-O', '+O', '--rcfile', '--init-file'])

/** A version tag as the release wave cuts it: `0.1.0-beta7`, `1.0.0-RC1`, `1.0.0`. */
const VERSION_TAG = /^v?\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$/

/** `docker exec` options that take a separate value. */
const DOCKER_EXEC_OPTION_WITH_VALUE = new Set(['-e', '--env', '--env-file', '-u', '--user', '-w', '--workdir', '--detach-keys'])

/** Git's global options that take a separate value. */
const GIT_OPTION_WITH_VALUE = new Set(['-C', '-c', '--git-dir', '--work-tree', '--namespace', '--exec-path', '--config-env'])

/** Commands that read, copy or ship a file named among their arguments. */
const FILE_READERS = new Set([
  'cat', 'less', 'more', 'head', 'tail', 'bat', 'grep', 'egrep', 'fgrep', 'rg', 'ag', 'sed', 'awk', 'cut', 'sort', 'uniq',
  'scp', 'rsync', 'base64', 'xxd', 'od', 'hexdump', 'strings', 'openssl', 'curl', 'wget', 'jq', 'yq', 'tar',
  'zip', 'gzip', 'source', '.', 'diff', 'nl', 'tac', 'pbcopy', 'python', 'python3', 'node', 'ruby', 'perl',
])

/**
 * A file that holds secrets: `.env` and its variants (but not the committed
 * `.example`, `.dist`, `.sample` or `.template`), private keys and key stores,
 * SSH identities.
 */
const SECRET_FILE = /(^|\/)(\.env(\.(?!example$|dist$|sample$|template$)[\w.-]+)?|[^/]+\.(pem|key|p12|pfx|jks|keystore)|id_(rsa|dsa|ecdsa|ed25519)(?!\.pub$)[^/]*)$/

/** Whether a word names a secret file: `x.pem`, `@x.pem` (curl), `file=@.env`, `--key=x.pem`. */
export function isSecretPath(word: string): boolean {
  const path = word.replace(/^[^=]*=/, '').replace(/^@/, '')
  return path !== '' && SECRET_FILE.test(path)
}

const DOCKER_HINT = 'run it in the dev container: `wfl run <component> <command…>` or `docker exec -w /waffle-commons/<component> waffle-dev <command…>`'

/**
 * The command line with every heredoc body taken out, so a commit message or
 * a script fed on stdin is never read as commands. A body runs from the line
 * after its `<<TAG` (`<<-TAG`, `<<'TAG'`, `<<"TAG"`) to the line that holds
 * TAG alone (leading tabs allowed after `<<-`); a here-string (`<<<`) has none.
 */
export function withoutHeredocBodies(line: string): string {
  const out: string[] = []
  const pending: { tag: string; isIndented: boolean }[] = []
  for (const row of line.split('\n')) {
    const open = pending[0]
    if (open !== undefined) {
      if ((open.isIndented ? row.replace(/^\t+/, '') : row) === open.tag) pending.shift()
      continue
    }
    out.push(row)
    for (const match of row.matchAll(/(?<!<)<<(-?)\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\2/g)) {
      pending.push({ tag: match[3] ?? '', isIndented: match[1] === '-' })
    }
  }
  return out.join('\n')
}

/** Why a heredoc start line is refused: it ends in a `\` continuation. */
export function heredocVerdictOf(line: string): string | undefined {
  const bad = withoutHeredocBodies(line)
    .split('\n')
    .find(row => /(?<!<)<<-?\s*['"]?[A-Za-z_][A-Za-z0-9_]*['"]?.*\\\s*$/.test(row))
  if (bad === undefined) return undefined
  return 'a heredoc start line ends in `\\`: the continuation joins the next line to the command, so the heredoc swallows the wrong text (it ate a commit subject on 2026-10-07). Put each heredoc command on its own line and chain them with `set -e`.'
}

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

/** Whether a push refspec only ever names the authorised release tag: `T`, `refs/tags/T`, `T:refs/tags/T`. */
function isReleaseTagSpec(spec: string, releaseTag: string): boolean {
  return releaseTag !== '' && spec.split(':').every(side => side.replace(/^refs\/tags\//, '') === releaseTag)
}

/** The `git push` options the push rules read, spelled in full. */
const PUSH_OPTIONS = ['--delete', '--prune', '--tags', '--follow-tags', '--mirror', '--force', '--force-with-lease']

/** The short `git push` options the push rules read, by letter. */
const PUSH_LETTERS: Readonly<Record<string, string>> = { d: '--delete', f: '--force' }

/**
 * The options of `PUSH_OPTIONS` a `git push` word turns on, as git reads it.
 * A short cluster sets each letter up to an `o`, which takes the rest as its
 * value: `-uf` is `-u -f`, `-od` is `-o d`. A long word is every option it is
 * a prefix of: `--tag` is `--tags`, `--m` is `--mirror`. Git stops on a prefix
 * two options share (`--fo`), so reading it as both refuses nothing git runs.
 */
function pushOptionsOf(word: string): string[] {
  if (/^-[^-]/.test(word)) return [...(word.slice(1).split('o')[0] ?? '')].flatMap(letter => PUSH_LETTERS[letter] ?? [])
  const name = word.replace(/=.*$/s, '')
  return word.startsWith('--') && name.length > 2 ? PUSH_OPTIONS.filter(option => option.startsWith(name)) : []
}

/** Whether a `git push` word turns on one of the options. */
const turnsOn = (word: string, ...options: string[]) => pushOptionsOf(word).some(option => options.includes(option))

/** What the tag refusal tells Claude it may do instead. */
function tagHintOf(releaseTag: string): string {
  return releaseTag === ''
    ? 'Release tags are pushed by the human, or by Claude once the person sets the cockpit\'s `releaseTag` option to that version.'
    : `Only \`${releaseTag}\` (the cockpit's \`releaseTag\`) may be pushed, by name, never forced or deleted.`
}

/** Why `git <args>` is refused, or undefined. */
function gitVerdictOf(args: string[], releaseTag: string): string | undefined {
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
    const specs = rest.filter(a => !a.startsWith('-')).slice(1) // the first non-option word is the remote
    const tagFlags = rest.filter(a => turnsOn(a, '--tags', '--follow-tags', '--mirror'))
    const isDelete = rest.some(a => turnsOn(a, '--delete'))
    const tagRefs = specs.filter(spec => spec.split(':').some(side => side.replace(/^\+/, '').startsWith('refs/tags/') || VERSION_TAG.test(side.replace(/^\+/, ''))))
    const refused = [...tagFlags, ...tagRefs.filter(spec => isDelete || !isReleaseTagSpec(spec, releaseTag))]

    if (refused.length > 0) {
      return `tags are live: pushing ${refused.join(' ')} fires the LIVE release wave (AGENTS.md §6). ${tagHintOf(releaseTag)}`
    }

    const forced = [...rest.filter(a => turnsOn(a, '--force', '--force-with-lease')), ...specs.filter(spec => spec.startsWith('+'))]
    if (forced.length > 0) {
      return `\`${forced.join(' ')}\`: pushes are never forced: a forced push rewrites history on the remote, and the permission rules deny it (AGENTS.md §6). Ask the person.`
    }

    // The ask rule matches the `--delete` word alone: any other spelling of a delete would run unasked.
    const deletes = [...rest.filter(a => a !== '--delete' && turnsOn(a, '--delete', '--prune')), ...specs.filter(spec => /^:./.test(spec))]
    if (deletes.length > 0) {
      return `\`${deletes.join(' ')}\`: a push deletes remote refs only through \`--delete\`, the spelling the permission rules ask the person about. Name each ref with \`git push <remote> --delete <ref>\` (AGENTS.md §6).`
    }
  }

  if (sub === 'tag') {
    const versions = rest.filter(a => VERSION_TAG.test(a))
    const prefixed = versions.find(a => a.startsWith('v'))
    if (prefixed !== undefined) {
      return `\`${prefixed}\`: release tags carry no \`v\` prefix, and the release wave's tag gate rejects one (AGENTS.md §5b).`
    }
    const movesOrDeletes = rest.some(a => a === '--delete' || a === '--force' || /^-[A-Za-z]*[df][A-Za-z]*$/.test(a))
    if (movesOrDeletes && versions.length > 0) {
      return `release tags are never moved or deleted: \`${versions.join(' ')}\` may already have fired the wave (AGENTS.md §6). Ask the person.`
    }
  }

  if (sub === 'merge' && rest.includes('--squash')) {
    return 'merges are merge commits, never squash: a squash orphans the commit the umbrella gitlink pins, and the release wave exits 3 (AGENTS.md §6).'
  }

  return undefined
}

/**
 * The script a shell runs: the first word after its options when one of them
 * is `-c`, alone or in a cluster (`-lc`, `-ec`, `-eo pipefail -c`). Undefined
 * when the shell runs no `-c` script.
 */
function shellScriptOf(args: string[]): string | undefined {
  let runsScript = false
  let i = 0
  while (i < args.length) {
    const a = args[i] ?? ''
    if (a === '--') {
      i++
      break
    }
    if (SHELL_OPTION_WITH_VALUE.has(a)) {
      i += 2
    } else if (/^[-+][A-Za-z]+$/.test(a)) {
      if (a.startsWith('-') && a.includes('c')) runsScript = true
      i += /[oO]$/.test(a) ? 2 : 1 // `-eo pipefail`: the cluster's last option takes the next word
    } else if (a.startsWith('--')) {
      i++
    } else {
      break
    }
  }

  return runsScript ? args[i] : undefined
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
function verdictOfWords(words: string[], depth: number, isInContainer: boolean, isStrict: boolean, releaseTag: string): string | undefined {
  const cmd = commandWordsOf(words)
  const head = cmd[0]
  if (head === undefined) return undefined

  const name = basenameOf(head)
  const args = cmd.slice(1)

  if (!isInContainer && (HOST_PHP.has(name) || /(^|\/)vendor\/bin\//.test(head))) {
    return `\`${name}\` would run on the host, and PHP never runs on the host here: ${DOCKER_HINT}.`
  }

  if (isStrict && !isInContainer && (name === 'cd' || name === 'pushd' || name === 'popd')) {
    return `\`${name}\` moves the shell's working directory for every later command, the person's \`!\` commands included: use absolute paths (\`git -C /abs/repo …\`, \`docker exec -w /waffle-commons/<component> …\`, the tool's own directory flag).`
  }

  if (FILE_READERS.has(name)) {
    const secret = args.find(isSecretPath)
    if (secret !== undefined) {
      return `\`${secret}\` holds secrets and is never read through the shell. Ask the person for the one value needed, or read the committed \`.env.example\`.`
    }
  }

  // PHP belongs in the container; git and release rules apply there all the same.
  const inner = name === 'docker' ? dockerExecCommandOf(args) : undefined
  if (inner !== undefined && depth < 3) return verdictOfWords(inner, depth + 1, true, isStrict, releaseTag)

  if (name === 'git') return gitVerdictOf(args, releaseTag)

  if (name === 'gh' && args[0] === 'release' && args[1] === 'create') {
    const versions = args.slice(2).filter(a => VERSION_TAG.test(a))
    if (versions.length !== 1 || versions[0] !== releaseTag) {
      return `creating a GitHub release creates its tag on the remote, which fires the LIVE release wave (AGENTS.md §6). ${tagHintOf(releaseTag)}`
    }
  }

  if (name === 'gh' && args[0] === 'pr' && args[1] === 'merge') {
    const way = args.find(a => a === '--squash' || a === '-s' || a === '--rebase' || a === '-r')
    if (way !== undefined) {
      return `\`gh pr merge ${way}\`: merges are merge commits (\`--merge\`), never squash or rebase, which orphan the commit the umbrella gitlink pins; the release wave exits 3 (AGENTS.md §6).`
    }
  }

  // A `sh -c` script runs where its shell runs: inside the container when a `docker exec` started it.
  if (SHELLS.has(name) && depth < 3) {
    const script = shellScriptOf(args)
    if (script !== undefined) return verdictOf(script, depth + 1, isInContainer, isStrict, releaseTag)
  }

  return undefined
}

/**
 * Why the guard refuses a Bash command line, or undefined to let it through.
 *
 * @param line the command as the Bash tool received it
 * @param depth how many `sh -c` levels deep this line sits
 * @param isInContainer whether a `docker exec` above this line runs it inside the container
 * @param isStrict the `strict` guard: also refuses `cd` on the host and a `\` after a heredoc start
 * @param releaseTag the one release tag Claude may push or release by name; empty refuses them all
 */
export function verdictOf(line: string, depth = 0, isInContainer = false, isStrict = true, releaseTag = ''): string | undefined {
  const heredoc = isStrict ? heredocVerdictOf(line) : undefined
  if (heredoc !== undefined) return heredoc

  for (const words of simpleCommandsOf(withoutHeredocBodies(line))) {
    const verdict = verdictOfWords(words, depth, isInContainer, isStrict, releaseTag)
    if (verdict !== undefined) return verdict
  }

  return undefined
}
