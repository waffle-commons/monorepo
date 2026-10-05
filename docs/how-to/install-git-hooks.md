# How-To: Install Git hooks

> **Diátaxis quadrant:** How-To.
> **Release:** `0.1.0-beta7`.
> **Answers:** How do I install the Waffle pre-commit and pre-push gates in the umbrella and every submodule?

## The one-liner

```bash
./scripts/install-git-hooks.sh
```

`wfl init` runs it for you. The script installs the hooks in the umbrella and in every submodule's
hooks directory (wherever `git rev-parse --git-dir` puts it), except `component-template`, which ships
to downstream projects hook-free.

## What the hooks do

| Hook | Payload | What it runs |
| :--- | :--- | :--- |
| `pre-commit` | `scripts/hooks/pre-commit-mago.sh` | An incremental Mago gate on the **staged** PHP files only, grouped by component, inside `waffle-dev` (~1–3 s on a small commit). |
| `pre-push` | `scripts/hooks/pre-push-sanity.sh` | For every component with PHP changes in the pushed range: `composer mago`, then `composer tests` where the component defines it. A no-op when nothing is ahead. |

Each hook file holds one marked block (`# BEGIN WAFFLE PRE-COMMIT HOOK` … `# END WAFFLE PRE-COMMIT HOOK`),
so your own hook code can sit beside it.

## When you need to run this

- **First-time setup**: `wfl init` does it.
- **After adding a new component**, to wire its hooks.
- **After something wiped a submodule's hooks**, or a hook stopped running.

The script is idempotent and doubles as a repair: every run removes and rewrites its own blocks and
restores the executable bit (Git silently skips a non-executable hook). It also removes the retired
Project Graphify blocks that older installers added, and deletes a hook file left with nothing else
in it; a hook with your own content is kept.

## Skipping the gate for one commit or push

```bash
SKIP_MAGO=1 git commit -m "..."
SKIP_MAGO=1 git push
```

> **Avoid.** The hooks catch problems before they reach the remote, and CI runs the full gate anyway.
> Bypassing them is a temporary tactic; fix the root cause.

## Uninstalling

Delete the marked blocks (`# BEGIN WAFFLE …` → `# END WAFFLE …`) from `pre-commit` and `pre-push` in the
hooks directories, or delete those files if they hold nothing else.

## Related

- [Repository layout](../reference/repository-layout.md) — where `scripts/install-git-hooks.sh` and its payloads live.
- [Set up your monorepo workspace](../tutorials/setup-your-monorepo-workspace.md) — `wfl init` installs the hooks.
