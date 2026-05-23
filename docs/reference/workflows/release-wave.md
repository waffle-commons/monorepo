# Reference — `release-wave.yml`

> **Release:** `v0.1.0-beta1`.
> **Scope:** `.github/workflows/release-wave.yml` — the umbrella's release fan-out workflow.

## Purpose

Propagates an umbrella tag to every component repo listed in `.gitmodules`, then creates a GitHub Release on each newly-tagged ref with auto-generated notes. Existing Packagist webhooks pick up the new tags automatically, so no Packagist API call is required.

## Trigger

```yaml
on:
  push:
    tags:
      - '*'
```

Any tag pushed to the umbrella fires the workflow. Tag naming follows the project convention (e.g. `0.1.0-beta0`, `1.2.3-rc.4`, `1.2.3`); the leading `v` is **not** required.

## Required secret

| Name | Type | Permission |
| :--- | :--- | :--- |
| `WAFFLE_RELEASE_TOKEN` | fine-grained PAT or GitHub App installation token | `Contents: read & write` on every `waffle-commons/*` component repo |

The default `GITHUB_TOKEN` only has access to the umbrella repo and **cannot** push tags or create releases on other repositories. The workflow fails fast with an actionable error if the secret is missing.

## Configuration knobs

Both are workflow-level `env` variables — edit them in the workflow file (no UI input, because tag-push triggers cannot take inputs).

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `EXCLUDE_SUBMODULES` | `.github-private` | Comma-separated list of submodule paths to skip entirely (no tag, no release). |
| `PRERELEASE_REGEX` | `^[0-9]+\.[0-9]+\.[0-9]+-(alpha\|beta\|rc\|dev\|pre)([0-9.]*)?$` | POSIX ERE matched against the umbrella tag. A match marks every component release as a GitHub pre-release. |

### Pre-release classification examples

| Tag | Pre-release? |
| :--- | :--- |
| `0.1.0-beta0` | yes |
| `0.1.0-alpha1` | yes |
| `1.2.3-rc.4` | yes |
| `1.2.3` | no (stable) |
| `1.2.3-hotfix.1` | no (suffix not in regex) |

## Per-component flow

For each entry in `.gitmodules` (minus `EXCLUDE_SUBMODULES`):

1. Read the umbrella-pinned SHA via `git ls-tree HEAD -- <path>`.
2. Build a token-authenticated origin URL (supports both `git@host:` and `https://` forms).
3. Bare-clone into a tempdir; fetch all branch heads + the pinned SHA explicitly.
4. Verify the SHA is reachable from `origin/main` (or `origin/master`) using `git merge-base --is-ancestor`. **Fails loudly** if not — that's the signal that the contributor forgot to push the submodule branch.
5. **Tag step (idempotent)**: if the tag already exists at the same SHA, keep it; if it exists at a different SHA, fail and refuse to overwrite; otherwise create + push a lightweight tag at the SHA.
6. **Release step (idempotent)**: `gh release view <tag>` — if a release already exists, skip; otherwise `gh release create <tag> --target <sha> --title <tag> --generate-notes [--prerelease]`. Release notes come from GitHub's `/releases/generate-notes` endpoint, grouped per each component's optional `.github/release.yml` config.

## Per-component result classification

Each component lands in exactly one bucket:

| Bucket | Meaning |
| :--- | :--- |
| `released` | This run pushed the tag AND created the release. |
| `tagged` | This run did exactly one of {push tag, create release} — the other was already in the correct state. Covers the recovery path where a prior run pushed the tag but failed before creating the release. |
| `skipped` | Both the tag and the release already existed at the correct SHA — full idempotent no-op. |
| `excluded` | Submodule path is in `EXCLUDE_SUBMODULES`. |
| `failed` | Any error: missing SHA pointer, SHA not on main/master, tag mismatch, or `gh release create` failure. |

The workflow exits non-zero iff `failed > 0`. `excluded` never contributes to failure.

## Idempotency table

| State on component repo | Action taken | Bucket |
| :--- | :--- | :--- |
| No tag, no release | tag → release | `released` |
| Tag at correct SHA, no release | release only | `tagged` (recovery) |
| Tag at correct SHA, release exists | no-op | `skipped` |
| Tag at different SHA | fail | `failed` |
| Path in `EXCLUDE_SUBMODULES` | skipped before any network call | `excluded` |

This means a failed mid-flight run can be recovered simply by re-pushing the same tag and re-running — no manual cleanup needed.

## Security notes

- `WAFFLE_RELEASE_TOKEN` is `::add-mask::`'d in both the `Validate release token` and `Fan out tag to every submodule` steps so accidental echo is redacted from logs.
- Token-bearing URLs are passed to `git remote add` only; no step issues `git remote -v` or otherwise echoes the URL.
- `gh` reads the token from `GH_TOKEN` env scoped per-invocation, alongside `GH_REPO` set from each component's parsed owner/name.

## Operational tips

- **Adding a submodule to the exclude list** — edit `EXCLUDE_SUBMODULES` in the workflow (comma-separated). No restart, no secret change.
- **Broadening pre-release detection** — edit `PRERELEASE_REGEX` (e.g., to accept any `-suffix`, use `^[0-9]+\.[0-9]+\.[0-9]+-.+$`).
- **Tagging only some components** — combine `EXCLUDE_SUBMODULES` with a careful list, or split the workflow into two with different matrix scopes.
- **Recovering a partial run** — fix the cause (push the missing submodule SHA to main, etc.), then re-run the workflow on the same tag. Skips already-done work.

## Related

- [`umbrella-ci.yml`](umbrella-ci.md) — the gate that runs on PR and umbrella `main` pushes.
- [`scripts/install-git-hooks.sh`](../scripts/install-git-hooks.md) — local pre-push gate that catches the failures `release-wave` would otherwise surface in CI.
- [Release a component](../../how-to/release-a-component.md) — how-to from the contributor's perspective.
