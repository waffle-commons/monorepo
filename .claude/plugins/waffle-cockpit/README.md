# waffle-cockpit

A Claude Code **mod**: a plugin whose TypeScript hooks run inside Claude Code. It is listed in the
repository marketplace (`.claude-plugin/marketplace.json`) and enabled in `.claude/settings.json`, so it
loads in place for anyone who trusts the folder; no install step. Mods need Claude Code ≥ 2.1.287.

It adds:

| Feature | Where | What it does |
|---|---|---|
| Three lines under the prompt | every project | Drawn in the hint line under the prompt (it replaces a custom `statusLine`):<br>1. model · effort │ repo ⎇ branch ●dirty │ *(umbrella)* release phase · `waffle-dev` ● · igor pin<br>2. context bar and tokens (yellow from 60 %, red from 80 %) │ prompt-cache hit ratio · last turn │ cost · session time · working-tree diff<br>3. 5-hour / 7-day limits (subscribers) │ the branch's open PR (`gh`) │ the engine's own hint (shortcuts, `esc to interrupt`).<br>Model and effort follow each main-loop request; the rest refreshes after each turn, after git / `gh` / `wfl` / docker commands, and every 30 s. `/cockpit hide` gives the line back to the engine. |
| `/cockpit [show\|hide]` | every project | Refreshes the lines and prints a one-line summary, or hides / shows them. |
| `/dod <component…>` or `/dod --changed` | the umbrella | Runs `wfl dod` in a pane as a checklist (Mago, PHPUnit verdict, coverage, igor), with **no model turn**. When it ends: *Send verdict to Claude* fills the prompt with a one-line verdict; *Copy failing excerpt* copies the details. |
| Bash guard | the umbrella | Refuses, with the reason: PHP tooling on the host (`php`, `composer`, `mago`, `phpunit`, `vendor/bin/*`), `git submodule update --remote`, and pushing or creating release tags (`N.N.N[-x]`, `--tags`, `refs/tags/`, `gh release create`), also inside `docker exec`. It parses chains, `env` prefixes, `git -C` and `sh -c` (also flag clusters such as `bash -lc`); a script run through `docker exec` counts as inside the container. It never approves anything: every other command still meets the permission rules. |

In this repository the team settings enable it. To have the lines in **every** project, install it once at
user scope from the repository marketplace: `claude plugin install waffle-cockpit@waffle-commons --scope user`.

## Trust and safety

A mod is not sandboxed: it runs with your permissions. This one only runs `git`, `gh pr view`,
`docker inspect`, `scripts/changed-components.sh` and `bin/wfl dod`, and makes no network call of its own
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
