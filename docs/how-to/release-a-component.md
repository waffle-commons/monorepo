# How-To: Release a component

> **Diátaxis quadrant:** How-To.
> **Release:** `0.1.0-beta4`.
> **Answers:** I'm ready to ship `waffle-commons/<component>@vX.Y.Z`. What's the process?

## Pre-flight

Before tagging anything, in the component repository:

```bash
cd <component>
git switch main
git pull --ff-only

docker exec -it -w /waffle-commons/<component> waffle-dev composer mago
docker exec -it -w /waffle-commons/<component> waffle-dev composer tests
docker exec -it -w /waffle-commons/<component> waffle-dev composer audit
```

All four must be green. If any fails, fix it before tagging.

Also bump the **version field** in `composer.json` if your team maintains it explicitly (some submodules use the `self.version` trick and rely on the Git tag alone — check this component's `composer.json`):

```json
{
  "name": "waffle-commons/<component>",
  "version": "0.1.0-beta4",
  ...
}
```

Commit the bump:

```bash
git add composer.json
git commit -m "chore: bump version to 0.1.0-beta4"
git push origin main
```

## Tag the release

```bash
git tag -a 0.1.0-beta4 -m "0.1.0-beta4: <short description>"
git push origin 0.1.0-beta4
```

Tags MUST be **signed** if the component's ruleset requires it (`component-ruleset.json` includes `required_signatures` — see [reference](../reference/component-ruleset.md)). Configure `git config --global commit.gpgsign true` and `git config --global tag.gpgsign true` once and forget about it.

## Trust Packagist auto-discovery

`waffle-commons/<component>` is registered on Packagist with the GitHub webhook integration. Pushing a tag triggers Packagist to detect the new version within seconds.

Verify:

```bash
curl -s https://repo.packagist.org/p2/waffle-commons/<component>.json | jq '.packages."waffle-commons/<component>"[0].version'
# "0.1.0-beta4"
```

If the new tag does not appear within ~30 seconds, the webhook may be stuck — manually re-trigger via Packagist's web UI (Settings → Update).

## Cascade into consumers

The new version is now available, but no consumer is using it yet. For each downstream component (anything that has `"waffle-commons/<component>"` in its `composer.json` require):

```bash
cd <consumer>
git switch -c bump-<component>-to-0.1.0-beta4
# Update composer.json constraint if pinned, e.g. "self.version" components
# need their own version bump first.
docker exec -it -w /waffle-commons/<consumer> waffle-dev composer update waffle-commons/<component>
docker exec -it -w /waffle-commons/<consumer> waffle-dev composer mago
docker exec -it -w /waffle-commons/<consumer> waffle-dev composer tests
git add composer.json composer.lock
git commit -m "chore: bump waffle-commons/<component> to 0.1.0-beta4"
git push origin bump-<component>-to-0.1.0-beta4
# Open PR, merge, release the consumer too.
```

> **`self.version` cascade.** Many `waffle-commons` packages express inter-component constraints as `"waffle-commons/contracts": "self.version"`. That means consumer X at version V requires producer Y at exactly version V. To release X at beta4, every transitive Y has to also be at beta4. Plan releases in topological order: `contracts` → `utils` → leaf components → `waffle` → `skeleton`.

## Bump the umbrella pointer

After consumer PRs merge, run [bump submodule pointers](bump-submodule-pointers.md) to commit the new SHAs in the umbrella.

## Release checklist

- [ ] `composer mago`, `composer tests`, `composer audit` green in the component.
- [ ] `composer.json` `version` bumped (if used).
- [ ] Signed annotated tag pushed.
- [ ] Packagist shows the new version (< 30s).
- [ ] Downstream consumer PRs opened and merged.
- [ ] Umbrella submodule pointers bumped.
- [ ] Release notes published (GitHub Releases page, optional but encouraged).

## Related

- [Bump submodule pointers](bump-submodule-pointers.md) — the umbrella-side commit.
- [The release cycle](../explanation/release-cycle.md) — semver policy and beta-tag conventions.
- [`component-ruleset` reference](../reference/component-ruleset.md) — required signatures, PR review rules.
