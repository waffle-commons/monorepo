# waffle-cockpit

A Claude Code **mod**: a plugin whose TypeScript hooks run inside Claude Code. It is listed in the
repository marketplace (`.claude-plugin/marketplace.json`) and enabled in `.claude/settings.json`, so it
loads in place for anyone who trusts the folder; no install step. Mods need Claude Code ≥ 2.1.287.

It adds:

| Feature | Where | What it does |
|---|---|---|
| Lines under the prompt | every project | Drawn in the hint line under the prompt (it replaces a custom `statusLine`):<br>1. model · effort │ repo ⎇ branch ●dirty │ *(umbrella)* release phase · `waffle-dev` ● · igor pin · `⇡N · backup 6h ago` (commits on no remote, age of the last `wfl backup`; yellow past 24 h, red past 72 h, hidden when everything is pushed)<br>2. context bar and tokens (yellow from 60 %, red from 80 %, configurable) │ prompt-cache hit ratio · last turn │ cost · session time · working-tree diff<br>3. work, always drawn (`⧗ 0 │ no command, background shell, monitor or subagent` while idle) — see below<br>4. 5-hour / 7-day limits (subscribers) │ the branch's open PR (`gh`) │ the engine's own hint (shortcuts, `esc to interrupt`).<br>Model and effort follow each main-loop request; the rest refreshes after each turn, after git / `gh` / `wfl` / docker commands, and every 30 s. `/cockpit hide` gives the line back to the engine. |
| Work line | every project | Always drawn, idle as `⧗ 0 │ no command, background shell, monitor or subagent` until a job starts: `⧗ N` running, then each job with its age — `▶` a foreground command while it runs (each Bash call, and the `dod` / `xref` / `coverage_gaps` tools' scripts; the line redraws every second meanwhile, and the ended command stays up to 10 s, ticked or crossed with its duration, until the next one replaces it), `$` a shell (`run_in_background` or Ctrl+B), `◉` a Monitor (with its event count), `◆` a subagent (foreground or background, from `$.agent.list()`), `⏰` the next `/loop` wakeup. An ended job stays a minute, `✓` or `✗ failed/killed`; a failed one raises a toast. The engine gives a mod no task list, so the cockpit records each start from its tool call and each end from the task notification (or `TaskStop`). |
| `/cockpit [show\|hide\|jobs]` | every project | Refreshes the lines and prints a one-line summary, hides / shows them, or opens the *Background* pane: every job with its full command, state, age and task id. |
| `/dod <component…>`, `/dod --changed`, `/dod --history` | the umbrella | Runs `wfl dod` in a pane as a checklist (Mago, PHPUnit verdict, coverage and its floor, igor, `composer audit`), with **no model turn**. When it ends: *Send verdict to Claude* fills the prompt with a one-line verdict; *Copy failing excerpt* copies the details. `--history` shows the last verdict per component (kept across sessions, from `/dod`, the `dod` tool and any `wfl dod` Claude runs), marking those edited since. |
| Tools Claude calls | the umbrella | `mcp__waffle-cockpit__dod` (structured verdict per gate, with the failing excerpt), `…__xref` (`{file, line, text}` rows), `…__coverage_gaps`, `…__dod_history`: structured answers instead of terminal text to parse. |
| Edit / Write checks | every project (secrets) · the umbrella (`mixed`) | Refuses a change that **adds** a secret (private key outside tests/fixtures, GitHub / AWS / Slack / Stripe / Google / Anthropic / OpenAI / npm / Packagist tokens, a high-entropy value assigned to a secret name), and an umbrella PHP change that **adds** `mixed` (AGENTS.md §1). What the file already held is never held against an edit. `Read` of `.env`, keys and SSH identities is refused too. |
| Instant Mago check | the umbrella | After each Edit / Write of component PHP, runs `mago lint` then `mago analyze` on that file in `waffle-dev` (about 3 s) and hands any finding to Claude with the tool result: an early warning, not the gate. It first waits (up to 1.5 s) until the container reports the file at the host's size: Docker's file sharing can briefly show a just-written file at its old length, which Mago would read as parse errors or unused imports. A copy that never catches up is not checked. |
| Done means evidence | the umbrella | When a turn would end with components whose PHP (or gate config) changed since their last green `wfl dod`, Claude is reminded once (`classic.Stop`) to run the gate or say why not. A green run clears it; the reminder never repeats for the same edits. |
| Bash guard | the umbrella | Refuses, with the reason: PHP tooling on the host (`php`, `composer`, `mago`, `phpunit`, `vendor/bin/*`), `git submodule update --remote`, pushing or creating release tags (`N.N.N[-x]`, `--tags`, `refs/tags/`, `gh release create`) except the one named by the `releaseTag` option (by name only, never forced or deleted), a `v`-prefixed release tag, moving or deleting a release tag (`git tag -f|-d`), squash or rebase merges (`git merge --squash`, `gh pr merge -s|-r`), a push that deletes a ref in any spelling but `--delete` (`:ref`, `-d`, `-qd`, `--del`, `--prune`; `--delete` itself meets the ask rule), `cd` / `pushd` / `popd` on the host (absolute paths only), a heredoc start line ending in `\\`, and reading secret files through the shell (`cat .env`, `curl -d @key.pem`; the last also outside the umbrella), also inside `docker exec`. Heredoc bodies (commit messages) are never read as commands. It parses chains, `env` prefixes, `git -C` and `sh -c` (also flag clusters such as `bash -lc`); a script run through `docker exec` counts as inside the container. It never approves anything: every other command still meets the permission rules. |

Settings (`/config`, or `pluginConfigs` in settings.json): `contextWarn` / `contextAlert` (60 / 80 %), `jobLingerSeconds` (60), `instantLint` (`off` · `lint` · `lint+analyze`), `evidenceAtStop` (on), `guard` (`strict` · `standard`: the latter drops the `cd`, heredoc and `mixed` rules), `secretScan` (on), `backupWarnHours` (24), `releaseTag` (empty: the release version Claude may tag and release, e.g. `0.1.0-beta7`; set it in your **user** settings when the release is ready, clear it once the wave has shipped).

In this repository the team settings enable it. To have the lines in **every** project, install it once at
user scope from the repository marketplace: `claude plugin install waffle-cockpit@waffle-commons --scope user`.

## Trust and safety

A mod is not sandboxed: it runs with your permissions. This one only runs `git`, `gh pr view`,
`docker inspect`, `docker exec … vendor/bin/mago lint|analyze <file>`, `scripts/changed-components.sh`,
`scripts/list-components.sh`, `scripts/local-only.sh`, `scripts/xref.sh` and `bin/wfl dod|coverage:gaps`, and makes no network call of its own
(`gh` asks GitHub for the branch's PR, at most every five minutes). Check with
`claude plugin validate .claude/plugins/waffle-cockpit`, which lists every hook and engine call.

Turn it off with `/plugin` → *Installed* → disable `waffle-cockpit@waffle-commons`, for one session with
`claude --safe-mode`, or for this machine with `"waffle-cockpit@waffle-commons": false` under
`enabledPlugins` in `.claude/settings.local.json`.

## Develop

```bash
claude plugin validate .claude/plugins/waffle-cockpit   # manifest, hooks, calls, state contract
claude plugin test .claude/plugins/waffle-cockpit       # tests/*.test.ts against the engine
```

In a session, `/reload-plugins` picks up an edit. The mod API is early access: run the tests after every
Claude Code update (`wfl ai:check` does).
