# Reference — `component-ruleset.json`

> **Release:** `0.1.0-beta5`.
> **Scope:** `<umbrella>/component-ruleset.json`.
> **Purpose:** the canonical GitHub branch-protection ruleset applied to every `waffle-commons/*` component repository.

## What it is

A GitHub Rulesets JSON payload. Apply via the GitHub API:

```bash
gh api -X POST /repos/waffle-commons/<component>/rulesets --input component-ruleset.json
```

(This is step 3 of [adding a new component](../how-to/add-a-new-component.md).)

## Top-level shape

```json
{
  "name": "main",
  "target": "branch",
  "source_type": "Repository",
  "source": "waffle-commons/waffle",
  "enforcement": "active",
  "conditions": { ... },
  "rules": [ ... ],
  "bypass_actors": [ ... ]
}
```

The `id` field is the ruleset's GitHub-side identifier for the existing canonical ruleset on `waffle-commons/waffle`. When applying the ruleset to a new repo, that ID changes — GitHub assigns a new one. Treat the existing `id` as informational.

## Conditions

```json
"conditions": {
  "ref_name": {
    "exclude": [],
    "include": [ "~DEFAULT_BRANCH" ]
  }
}
```

Applies to whatever the repo's default branch is (`main` everywhere we care about).

## Rules enforced

| Rule type | Effect |
| :--- | :--- |
| `deletion` | Default branch cannot be deleted. |
| `non_fast_forward` | No force-pushes to the default branch. |
| `pull_request` | All changes must go through a PR. See sub-parameters below. |
| `required_signatures` | All commits on the default branch must be signed. |

### `pull_request` sub-parameters

| Parameter | Value | Meaning |
| :--- | :--- | :--- |
| `required_approving_review_count` | `1` | At least one approval. |
| `dismiss_stale_reviews_on_push` | `true` | New commits invalidate previous approvals. |
| `require_code_owner_review` | `true` | A `CODEOWNERS`-matched reviewer must approve. |
| `require_last_push_approval` | `true` | Whoever made the last push cannot also be the sole approver. |
| `required_review_thread_resolution` | `true` | All PR review threads must be resolved before merge. |
| `automatic_copilot_code_review_enabled` | `false` | No automatic AI review. |
| `allowed_merge_methods` | `["merge", "squash"]` | No rebase-merge. |

## Bypass actors

```json
"bypass_actors": [
  { "actor_type": "OrganizationAdmin", "bypass_mode": "always" },
  { "actor_type": "DeployKey",          "bypass_mode": "always" },
  { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
]
```

Org admins, deploy keys, and the role with ID 5 (look it up in the GitHub UI for the org) can bypass these rules. **Avoid bypass in practice.** It's there for emergency hot-fixes and tooling, not routine work.

## Applying to a new component

```bash
gh api -X POST /repos/waffle-commons/<component>/rulesets --input ../component-ruleset.json
```

Verify the ruleset took effect:

```bash
gh api /repos/waffle-commons/<component>/rulesets | jq '.[] | {id, name, enforcement}'
```

## Updating the canonical ruleset

If you change the policy (e.g. require two approvers instead of one):

1. Edit `component-ruleset.json` in this repo.
2. Re-apply to every `waffle-commons/*` repository:

```bash
gh api /orgs/waffle-commons/repos --paginate \
  | jq -r '.[].name' \
  | while read repo; do
      ruleset_id=$(gh api /repos/waffle-commons/$repo/rulesets | jq '.[0].id // empty')
      if [ -n "$ruleset_id" ]; then
        gh api -X PUT /repos/waffle-commons/$repo/rulesets/$ruleset_id --input component-ruleset.json
      fi
    done
```

3. Commit the change in the umbrella with a release-note-worthy message.

## Related

- [`CODEOWNERS` reference](codeowners.md) — the review-routing companion file.
- [Release a component](../how-to/release-a-component.md) — signed tags are required by this ruleset.
- [Add a new component](../how-to/add-a-new-component.md) — applies this ruleset in step 3.
