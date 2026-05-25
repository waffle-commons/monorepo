# How-To: Update a submodule

> **Diátaxis quadrant:** How-To.
> **Release:** `v0.1.0-beta1`.
> **Answers:** Someone merged a change to `<component>`. How do I pull it into my local checkout?

## Pull one submodule

```bash
cd <component>
git fetch origin
git switch main
git pull --ff-only
cd ..
```

The umbrella will now show the submodule as "modified" — that's expected; it just means the submodule is no longer pointing at the SHA the umbrella has pinned. **Do not commit that as a bump unless you intend to.** See [bump submodule pointers](bump-submodule-pointers.md).

## Pull every submodule at once

```bash
git submodule foreach 'git fetch origin && git switch main && git pull --ff-only'
```

Or, equivalently, with `loop.sh`:

```bash
./loop.sh --verbose git pull --ff-only origin main
```

(`--verbose` because you want to see merge conflicts the moment they happen.)

## Sync to the pointers the umbrella actually pins

If you want to throw away local divergence and reset every submodule to whatever the umbrella commits says:

```bash
git submodule update --init --recursive --force
```

This:

- initialises any submodules that are missing;
- checks out the pinned SHA in every submodule (detached HEAD);
- discards uncommitted changes in the submodule working trees (`--force`).

Use this after pulling the umbrella when someone has bumped the pointers in a way you don't have locally yet:

```bash
git pull --ff-only origin main          # update umbrella
git submodule update --init --recursive  # sync submodules to new pointers
```

## "I get errors about detached HEAD when I `cd` into a submodule"

That's normal after `git submodule update`. Submodules sit at a pinned SHA, not on a branch. If you want to commit a change, first put yourself on a branch:

```bash
cd <component>
git switch -c my-topic            # or `git switch main && git pull`
```

## "The submodule directory is empty"

Whoever cloned the umbrella forgot `--recurse-submodules`. Recover:

```bash
git submodule update --init --recursive
```

## Related

- [Bump submodule pointers](bump-submodule-pointers.md) — when you intentionally want the umbrella to track new SHAs.
- [Work on multiple components locally](work-on-multiple-components-locally.md) — when you need cross-component changes to see each other before publication.
