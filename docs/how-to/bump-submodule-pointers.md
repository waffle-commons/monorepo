# How-To: Bump submodule pointers in the umbrella

> **Diátaxis quadrant:** How-To.
> **Release:** `0.1.0-beta3`.
> **Answers:** A component released a new version. How do I make the umbrella point at it?

## The umbrella's job

The umbrella repository (this repo) tracks **which commit of each submodule** it considers canonical. When someone clones with `--recurse-submodules`, the submodules check out at exactly those pinned SHAs. Bumping pointers is the act of moving those pins forward.

## One submodule

```bash
cd <component>
git fetch origin
git switch main
git pull --ff-only

cd ..
git diff --submodule
# Submodule <component> <oldsha>..<newsha>:
#   > <commit message>

git add <component>
git commit -m "Bump <component> to <newsha-short>"
```

Push when ready.

## Many submodules at once

After a release pass:

```bash
git submodule foreach 'git fetch origin && git switch main && git pull --ff-only'
git diff --submodule
git add .
git commit -m "Bump submodule pointers to 0.1.0-beta3"
```

Verify before pushing:

```bash
git show HEAD --submodule
# shows every submodule pointer change
```

## "I bumped a pointer and now CI is failing"

Two common causes:

1. **The submodule's new SHA isn't reachable from `main` of that submodule.** Pointers must point at commits that exist on the submodule's default branch and are accessible to anyone with read access — not at force-pushed branches or topic branches you haven't merged yet.
2. **Cross-component breakage.** The submodule's new code uses a feature from another component's older version. Either bump the other component too, or revert this pointer until the consumer side catches up.

Recover by reverting the pointer commit:

```bash
git revert HEAD
```

…or, if you've not pushed yet, by re-pointing to the previous SHA:

```bash
cd <component>
git switch --detach <oldsha>
cd ..
git add <component>
git commit --amend --no-edit
```

## Atomic multi-component bumps

When two components must move together (e.g. `contracts` adds a method that `security` consumes), bump both pointers in **one umbrella commit**:

```bash
# Both contracts and security have been released to 0.1.0-beta3.
cd contracts && git pull --ff-only && cd ..
cd security  && git pull --ff-only && cd ..
git add contracts security
git commit -m "Bump contracts + security to 0.1.0-beta3"
```

Anyone cloning the umbrella at this commit sees the coherent pair.

## What NOT to commit at the umbrella

The umbrella is **not** for code changes. If `git status` at the umbrella root shows file-level diffs *inside* a submodule directory (rather than just the submodule pointer being modified), something is wrong:

- you may have edited code inside the submodule but forgotten to commit it there;
- or your submodule is on a branch that is ahead of `main` and you don't actually want to bump the pointer yet.

Resolve by either committing inside the submodule first, or by `git submodule update --force` to discard the local divergence (be sure you don't lose work).

## Related

- [Release a component](release-a-component.md) — the per-submodule release flow that precedes a pointer bump.
- [Update a submodule](update-a-submodule.md) — pulling without bumping.
- [Repository layout](../reference/repository-layout.md) — what the umbrella tracks.
