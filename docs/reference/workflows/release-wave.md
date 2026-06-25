# Reference — `release-wave.yml`

> **Release:** `0.1.0-beta5`.
> **Scope:** `.github/workflows/release-wave.yml` — the umbrella's release fan-out workflow.

## Purpose

Propagates an umbrella tag to every **releasable** component repo, then creates a GitHub Release on each newly-tagged ref with auto-generated notes. Existing Packagist webhooks pick up the new tags automatically, so no Packagist API call is required.

"Releasable" is a **fail-closed allowlist** (`RELEASE_INCLUDE`): only the paths listed there are tagged. Everything else in `.gitmodules` (e.g. `workspace`, `component-template`) is reported as `excluded` and never touched.

## Triggers

```yaml
on:
  push:
    tags:
      - '[0-9]+.[0-9]+.[0-9]+'      # stable: 0.1.0
      - '[0-9]+.[0-9]+.[0-9]+-*'    # pre-release: 0.1.0-beta5, 1.2.3-rc.4
  workflow_dispatch:
    inputs:
      tag:      { required: true,  type: string  }   # must already exist on the umbrella
      dry_run:  { required: true,  type: boolean, default: true }
```

- **Tag push** — only canonical release-shaped tags fire the workflow. The leading `v` is **not** used by this project; a `v`-prefixed or junk tag (e.g. `tmp`) does **not** match the glob, and is additionally rejected by the tag-format gate (below). Tag pushes always run **live**.
- **Manual dispatch** — provide a pre-existing umbrella `tag` and choose `dry_run` (default **true**). A dry run validates everything and prints what *would* happen without pushing tags or creating releases.

## Required secret

| Name | Type | Permission |
| :--- | :--- | :--- |
| `WAFFLE_RELEASE_TOKEN` | fine-grained PAT **or** GitHub App installation token | `Contents: read & write` on every `waffle-commons/*` repo in `RELEASE_INCLUDE` |

The default `GITHUB_TOKEN` only has access to the umbrella repo and **cannot** push tags or create releases on other repositories. The workflow fails fast with an actionable error if the secret is missing. The token pre-flight uses `gh api rate_limit` (not `gh api user`), so a GitHub App installation token — which has no associated user — is **not** rejected.

## Configuration knobs (workflow-level `env`)

Edit these in the workflow file (tag-push triggers cannot take UI inputs).

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `RELEASE_INCLUDE` | `auth,cache,config,console,container,contracts,data,documentation,error-handler,event-dispatcher,http,http-client,log,pipeline,routing,runtime,security,skeleton,utils,waffle` | **Fail-closed allowlist** of submodule paths to tag/release. A path absent from this list is `excluded`. |
| `PRERELEASE_REGEX` | `^[0-9]+\.[0-9]+\.[0-9]+-(alpha\|beta\|rc\|dev\|pre)([0-9.]*)?$` | POSIX ERE matched against the umbrella tag. A match marks every component release as a GitHub **pre-release**. |
| `BACKOFF_SECONDS` | `2` | Sleep between components that did **live work**, to stay under GitHub's secondary rate limiter. `0` disables it. |

The tag-format gate is a separate, non-configurable safety check (`TAG_FORMAT_REGEX = ^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc|dev|pre)[0-9.]*)?$`) that aborts the run before any network call if the umbrella tag is not canonical.

### Pre-release classification examples

| Tag | Pre-release? |
| :--- | :--- |
| `0.1.0-beta5` | yes |
| `0.1.0-alpha1` | yes |
| `1.2.3-rc.4` | yes |
| `1.2.3` | no (stable) |
| `v0.1.0-beta5` | **rejected** by the tag-format gate (no `v` prefix) |
| `0.1.0-hotfix.1` | rejected (suffix not in the regex) |

## Authentication model

Auth is injected **per git command** via a masked HTTP Basic header, never embedded in a remote URL:

```text
-c http.https://github.com/.extraheader=AUTHORIZATION: basic <base64(x-access-token:TOKEN)>
```

Both the raw token and the derived base64 are `::add-mask::`'d. `git remote add origin` only ever stores a plain HTTPS URL (no credentials), so `git remote -v` — were it ever run — could not leak the token. SSH-form submodule URLs (`git@github.com:owner/repo.git`) are rewritten to HTTPS before use.

## Per-component flow

For each entry in `.gitmodules`:

1. **Allowlist gate** — if the path is not in `RELEASE_INCLUDE`, mark `excluded` and skip (no network call).
2. **Pin SHA** — read the umbrella-pinned commit via `git ls-tree HEAD -- <path>`.
3. **Fetch** — `git init` an isolated workdir, add the HTTPS origin, fetch all branch heads + the pinned SHA.
4. **Reachability** — detect the remote default branch via `ls-remote --symref origin HEAD` (falling back to `main`/`master`), then assert the pinned SHA is an ancestor with `git merge-base --is-ancestor`. **Fails loudly** (`rc=3`) if not — the signal that the submodule bump was never pushed/merged.
5. **Tag (idempotent)** — if the tag already exists at the same SHA, keep it; at a different SHA, fail (`rc=4`) and refuse to overwrite; otherwise create + push a lightweight tag (or `push --dry-run` under DRY_RUN).
6. **Release (idempotent)** — `gh release view` → skip if it already exists; otherwise `gh release create <tag> --title <tag> --generate-notes [--prerelease]` (skipped entirely under DRY_RUN). The tag already exists on the remote, so `gh` binds the release to it.

All of steps 3–6 run in a subshell captured as `( … ) || rc=$?`, and the per-component log is **always** printed — one component's failure never aborts the wave or hides its error.

## Per-component result classification

| Bucket | Meaning |
| :--- | :--- |
| `released` | This run created the release (or, under DRY_RUN, would have). |
| `tagged` | Exactly one of {tag, release} was done this run — the other was already correct (covers the recovery path where a prior run pushed the tag but failed before the release). |
| `skipped` | Both tag and release already existed at the correct SHA — full idempotent no-op. |
| `excluded` | Path is **not** in `RELEASE_INCLUDE`. Never contributes to failure. |
| `failed` | Any error: missing SHA pointer, SHA not reachable on the default branch, tag-SHA mismatch, or `gh release create` failure. |

The workflow exits non-zero iff `failed > 0`.

## Idempotency table

| State on component repo | Action taken | Bucket |
| :--- | :--- | :--- |
| No tag, no release | tag → release | `released` |
| Tag at correct SHA, no release | release only | `tagged` (recovery) |
| Tag at correct SHA, release exists | no-op | `skipped` |
| Tag at different SHA | fail (`rc=4`) | `failed` |
| Path not in `RELEASE_INCLUDE` | skipped before any network call | `excluded` |

A failed mid-flight run is recovered by re-running on the same tag — no manual cleanup. The back-off only sleeps after components that did live work, so a recovery run that skips the already-done components is fast.

## Security notes

- `WAFFLE_RELEASE_TOKEN` **and** the derived base64 Basic credential are both `::add-mask::`'d before first use.
- Authentication is via `http.extraheader` scoped to `github.com`, not a token-in-URL; no step runs `git remote -v` or echoes a token-bearing string.
- `gh` reads the token from a per-invocation `GH_TOKEN`, alongside `GH_REPO` parsed from each component's owner/name.

## Operational tips

- **Changing the release set** — edit `RELEASE_INCLUDE` (comma-separated allowlist). Adding a path opts it in; removing one opts it out. Verify with a dry run first.
- **Broadening pre-release detection** — edit `PRERELEASE_REGEX`.
- **Dry run before a live wave** — Actions → *release-wave* → **Run workflow**, set `tag` (no `v` prefix) and leave `dry_run = true`. Inspect the summary; any `failed` entry must be resolved before the live run.
- **Recovering a partial run** — fix the cause (e.g. push the missing submodule SHA to its default branch), then re-run on the same tag.

## Related

- [`umbrella-ci.yml`](umbrella-ci.md) — the gate that runs on PR and umbrella `main` pushes.
- [`scripts/install-git-hooks.sh`](../scripts/install-git-hooks.md) — local pre-push gate that catches the failures `release-wave` would otherwise surface in CI.
- [Release a component](../../how-to/release-a-component.md) — how-to from the contributor's perspective.
