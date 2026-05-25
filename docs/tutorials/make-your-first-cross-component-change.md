# Tutorial — Make your first cross-component change

> **Diátaxis quadrant:** Tutorial (learning-oriented).
> **Release:** `v0.1.0-beta1`.
> **You'll end with:** a tiny feature that touches `contracts` and `security`, all checks green, two per-submodule commits prepared, and a clean understanding of the umbrella pointer bump.
> **Time:** ~30 minutes.
> **Prerequisites:** the [workspace setup tutorial](setup-your-monorepo-workspace.md).

## Why this tutorial exists

The single most surprising thing about contributing to Waffle is that **the umbrella is not where code lives**. Every component is its own Git repository. When a change spans two components, you make two commits in two repositories — and then a *third* commit in the umbrella to point at the new sub-repo SHAs. This tutorial walks you through that exact dance.

You will:

1. Add a new typed constant to `contracts`.
2. Reference it from `security`.
3. Run the quality bar in both.
4. Stage commits in both submodules.
5. (Stop short of pushing — this is a tutorial, not a release.)

## 1. Identify the affected components

Open two terminals. In each, `cd` into the relevant component and verify you're on `main`:

```bash
# terminal 1
cd /Users/<you>/waffle-commons/contracts
git status
# On branch main
# Your branch is up to date with 'origin/main'.

# terminal 2
cd /Users/<you>/waffle-commons/security
git status
# On branch main
```

> **About branches in submodules.** Each submodule is a normal Git repo. Make your changes on a topic branch in *each* affected component: `git switch -c add-greeting-constant` in both terminals.

```bash
# both terminals
git switch -c add-greeting-constant
```

## 2. Add the new constant in `contracts`

Edit `contracts/src/Constant/Constant.php` and add:

```php
public const string DEFAULT_GREETING = 'Welcome to Waffle!';
```

Verify the change is valid:

```bash
docker exec -it -w /waffle-commons/contracts waffle-dev composer mago
docker exec -it -w /waffle-commons/contracts waffle-dev composer tests
```

Both must be green. If they aren't, fix the issue before moving on — no commit can land otherwise.

## 3. Make `security` see the new constant

The `security` component has a private `vendor/waffle-commons/contracts` snapshot frozen at the last tagged release. Until `contracts` is released and `security` runs `composer update`, the new constant is invisible from inside the `security/` tree.

The cleanest local workaround uses Composer **path repositories**. The [`workspace`](../how-to/work-on-multiple-components-locally.md) submodule already does this for integration testing — for a quick single-component test, you can sync the contracts source into security's vendor cache:

```bash
rsync -a /Users/<you>/waffle-commons/contracts/src/ \
        /Users/<you>/waffle-commons/security/vendor/waffle-commons/contracts/src/
```

> This is a **transient** verification artifact. Do not commit it. Long-term, set up a path repository in `security/composer.json` — see [Work on multiple components locally](../how-to/work-on-multiple-components-locally.md).

Now reference the constant from any sensible spot in `security` — for the tutorial, add a docblock note to `security/src/Security.php`:

```php
/**
 * Default greeting: {@see \Waffle\Commons\Contracts\Constant\Constant::DEFAULT_GREETING}
 */
```

(That doesn't *use* the constant, but it does require `security`'s autoloader to resolve it, which is enough to confirm the wiring.)

Run the bar in `security`:

```bash
docker exec -it -w /waffle-commons/security waffle-dev composer mago
docker exec -it -w /waffle-commons/security waffle-dev composer tests
```

Both green? Move on. Red? Investigate before continuing.

## 4. Stage commits in each submodule

In each terminal, review and stage:

```bash
# terminal 1: contracts
cd /Users/<you>/waffle-commons/contracts
git diff
git add src/Constant/Constant.php
git commit -m "feat: add DEFAULT_GREETING constant"

# terminal 2: security
cd /Users/<you>/waffle-commons/security
git diff   # should be a tiny docblock change only — NOT the vendor/ rsync
git add src/Security.php
git commit -m "docs: reference DEFAULT_GREETING"
```

> **Do not** include the `vendor/waffle-commons/contracts/src/` files you rsynced in step 3 — those are local verification noise. If they show in `git status`, your `.gitignore` may need attention; consult [Work on multiple components locally](../how-to/work-on-multiple-components-locally.md).

## 5. See what the umbrella thinks

Now `cd` back to the umbrella root:

```bash
cd /Users/<you>/waffle-commons
git status
```

You'll see something like:

```
On branch main
Changes not staged for commit:
        modified:   contracts (new commits)
        modified:   security  (new commits)
```

The umbrella **does not see your code changes** — it sees that each submodule is pointing at a new SHA. The umbrella's job is to record those pinned SHAs so anyone cloning gets a coherent snapshot of the whole ecosystem.

```bash
git diff --submodule
# Submodule contracts <oldsha>..<newsha>:
#   > feat: add DEFAULT_GREETING constant
# Submodule security <oldsha>..<newsha>:
#   > docs: reference DEFAULT_GREETING
```

That's the diff.

## 6. (Don't) bump the umbrella

In a real change, you'd:

1. Push each submodule's branch and open per-component PRs.
2. After both merge to their submodule's `main`, in each submodule run `git checkout main && git pull`.
3. Back in the umbrella, the submodule directories now point at the new `main` SHAs — `git add contracts security && git commit -m "Bump submodule pointers"` and push.

That dance lives in [How-To: Bump submodule pointers](../how-to/bump-submodule-pointers.md). For this tutorial **stop here** — you don't want to push, and you definitely don't want to leave an umbrella commit pointing at branches that don't exist on `origin`.

## 7. Clean up

Unstage and undo the tutorial:

```bash
cd /Users/<you>/waffle-commons/contracts
git reset --hard HEAD^   # remove the tutorial commit
git switch main
git branch -D add-greeting-constant

cd /Users/<you>/waffle-commons/security
git reset --hard HEAD^
git switch main
git branch -D add-greeting-constant

# Vendor sync was transient. If anything sneaked into git, the next composer
# install will overwrite it cleanly.
docker exec -it -w /waffle-commons/security waffle-dev composer install --no-scripts
```

## What you've learned

- The umbrella tracks **submodule pointers**, not file contents.
- A change in one component is invisible to its consumers until either (a) the consumer's vendor cache is synced or (b) Composer path repositories are wired ([how-to](../how-to/work-on-multiple-components-locally.md)).
- The canonical commit flow is: per-submodule branches → per-submodule PRs → per-submodule merge → umbrella pointer bump.
- `git diff --submodule` shows the cross-component story.

## Where next

- [**Work on multiple components locally**](../how-to/work-on-multiple-components-locally.md) — set up path repositories so you don't have to rsync vendor caches.
- [**Bump submodule pointers**](../how-to/bump-submodule-pointers.md) — the umbrella-side commit you skipped.
- [**Release a component**](../how-to/release-a-component.md) — tagging, Packagist, and the production cycle.
- [**The Component Agnosticism rule**](../explanation/component-agnosticism.md) — why `security` can only ever depend on `contracts`.
