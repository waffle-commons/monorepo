# waffle-cockpit

A Claude Code **mod**: a plugin whose TypeScript hooks run inside Claude Code. It is listed in the
repository marketplace (`.claude-plugin/marketplace.json`) and enabled in `.claude/settings.json`, so it
loads in place for anyone who trusts the folder; no install step. Mods need Claude Code ≥ 2.1.287.

Inside the waffle-commons umbrella it adds:

| Feature | What it does |
|---|---|
| Status band | A row above the prompt: release phase (from the umbrella branch), branch, `waffle-dev` state, dirty repositories, igor pin. Refreshed at start, after git / `wfl` / docker commands, and every 5 minutes. `[Hide]` or `/cockpit hide`. |
| `/dod <component…>` or `/dod --changed` | Runs `wfl dod` in a pane as a checklist (Mago, PHPUnit verdict, coverage, igor), with **no model turn**. When it ends: *Send verdict to Claude* fills the prompt with a one-line verdict; *Copy failing excerpt* copies the details. |
| `/cockpit [show\|hide]` | Refreshes the band and prints the status line. |
| Bash guard | Refuses, with the reason: PHP tooling on the host (`php`, `composer`, `mago`, `phpunit`, `vendor/bin/*`), `git submodule update --remote`, and pushing or creating release tags (`N.N.N[-x]`, `--tags`, `refs/tags/`, `gh release create`). It parses chains, `env` prefixes, `git -C` and `sh -c`. It never approves anything: every other command still meets the permission rules. |

Outside the umbrella it draws nothing and lets every command through.

## Trust and safety

A mod is not sandboxed: it runs with your permissions. This one only runs `git`, `docker inspect`,
`scripts/changed-components.sh` and `bin/wfl dod`, and makes no network call. Check with
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
