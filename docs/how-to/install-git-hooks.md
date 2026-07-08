# How-To: Install Git hooks

> **Diátaxis quadrant:** How-To.
> **Release:** `0.1.0-beta5`.
> **Answers:** How do I install the Project Graphify pre-commit / post-checkout / post-merge / post-rewrite hooks in every submodule?

## The one-liner

```bash
./scripts/install-git-hooks.sh
```

The script walks every submodule (any directory whose `.git` exists at depth 2-3), creates the four hooks, and chmod-+x's them. The script itself is `scripts/install-git-hooks.sh`.

## What the hooks do

All four hooks contain a single guarded block:

```bash
# BEGIN PROJECT GRAPHIFY PRE-COMMIT HOOK
if [ -x "../../scripts/update-project-graphify.sh" ]; then
  (cd ../../ && ./scripts/update-project-graphify.sh)
fi
# END PROJECT GRAPHIFY PRE-COMMIT HOOK
```

Project Graphify keeps a graph of inter-component relations up-to-date (`graphify-out/` at the umbrella root). The hooks ensure the graph stays in sync without anyone having to remember to regenerate it.

## When you need to run this

- **First time setup**, after cloning the umbrella.
- **After adding a new component**, to wire its `.git/hooks/`.
- **After a force-checkout that wiped a submodule's hooks** (e.g., a `git clean -fdx` inside a submodule).

The script is idempotent — running it twice does the right thing. It detects existing Graphify blocks via the `BEGIN PROJECT GRAPHIFY` markers and doesn't duplicate them.

## Skipping the hooks for one commit

If a hook is misbehaving and you need to ship a commit immediately:

```bash
git commit --no-verify -m "..."
```

> **Avoid.** Pre-commit hooks exist to catch problems before they reach the remote. Bypassing them is a temporary tactic; fix the root cause.

## Uninstalling

The hooks are plain bash files. To remove them:

```bash
for d in */; do
    rm -f "$d.git/hooks/pre-commit" \
          "$d.git/hooks/post-checkout" \
          "$d.git/hooks/post-merge" \
          "$d.git/hooks/post-rewrite"
done
```

This removes the *entire* hook files, not just the Graphify blocks. If you have other pre-commit hooks you care about, edit the files manually and delete only the `# BEGIN PROJECT GRAPHIFY` → `# END PROJECT GRAPHIFY` block.

## Related

- [Repository layout](../reference/repository-layout.md) — where `scripts/install-git-hooks.sh` lives.
- [Set up your monorepo workspace](../tutorials/setup-your-monorepo-workspace.md) — installing hooks is step 7.
