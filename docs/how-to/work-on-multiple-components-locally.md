# How-To: Work on multiple components locally

> **Diátaxis quadrant:** How-To.
> **Release:** `0.1.0-beta4`.
> **Answers:** I'm changing `contracts` and need `security` to see those changes before I publish. How?

## The problem

Component A consumes Component B via Composer. By default, A's `vendor/waffle-commons/B/` is a snapshot of B at the last published version. If you're editing B locally, A doesn't see your changes.

There are three solutions, in increasing order of permanence.

## Option 1 — Transient: rsync the source

For a one-off verification:

```bash
rsync -a /Users/<you>/waffle-commons/contracts/src/ \
        /Users/<you>/waffle-commons/security/vendor/waffle-commons/contracts/src/
```

Now security's autoloader sees your in-progress contracts code. Run mago and tests:

```bash
docker exec -it -w /waffle-commons/security waffle-dev composer mago
docker exec -it -w /waffle-commons/security waffle-dev composer tests
```

> **Transient.** Do not commit `vendor/`. The rsynced files will be wiped on the next `composer install` and replaced with the published version.

Best for: "I just want to confirm my contracts patch works in security before pushing either."

## Option 2 — Per-session: Composer path repository

If you're iterating on a cross-component change over a longer session, wire up a Composer path repository on the consumer side. The existing pattern is in `security/composer.json`:

```json
"repositories": [
  {
    "name": "utils-local",
    "type": "path",
    "canonical": false,
    "url": "../utils",
    "options": {
      "versions": { "waffle-commons/utils": "0.1.0-beta1" },
      "symlink": true
    }
  }
]
```

Add a similar block for `contracts`:

```json
{
  "name": "contracts-local",
  "type": "path",
  "canonical": false,
  "url": "../contracts",
  "options": {
    "versions": { "waffle-commons/contracts": "0.1.0-beta1" },
    "symlink": true
  }
}
```

Then:

```bash
docker exec -it -w /waffle-commons/security waffle-dev composer update waffle-commons/contracts
```

With `symlink: true`, `security/vendor/waffle-commons/contracts` becomes a symlink into `../contracts`. Every save in `contracts/src/` is immediately visible in `security`. No rsync churn.

> **Don't commit this.** The path repository points at `../contracts`, which is a local relative path. It will not resolve on CI or for someone cloning the umbrella for the first time. Either commit it on a topic branch that you intend to revert before merging, or use the workspace approach (option 3).

Best for: "I'm doing a multi-day cross-component refactor."

## Option 3 — Permanent: the `workspace` submodule

The `workspace` submodule is the **canonical** dev environment. Its `composer.json` already declares path repositories for every `waffle-commons/*` package, all pointing at `../<component>`. It's the only submodule where committing path-repo entries is appropriate.

```bash
cd workspace
docker exec -it -w /waffle-commons/workspace waffle-dev composer install
docker exec -it -w /waffle-commons/workspace waffle-dev composer tests
```

The `workspace`'s test suite (smoke tests, integration tests) runs against your live local code in every component. This is where you validate that a cross-component refactor actually holds together.

Best for: integration testing the full ecosystem locally.

## Which to use when

| Situation | Use |
| :--- | :--- |
| One-off "does this even compile?" sanity check. | Option 1 (rsync). |
| Multi-day refactor across two or three components. | Option 2 (per-session path repo). |
| Cross-ecosystem integration testing; "does the kernel still boot?". | Option 3 (`workspace`). |

## Don't forget

When you push:

- Option 1: no cleanup needed; vendor is gitignored.
- Option 2: revert the `composer.json` path-repo block before opening the consumer's PR. Reviewers will reject path-repo entries in component repositories.
- Option 3: no cleanup needed; `workspace`'s path repos are intentional and committed.

## Related

- [Update a submodule](update-a-submodule.md) — pulling once a change has actually shipped to the consumer's published version.
- [Make your first cross-component change](../tutorials/make-your-first-cross-component-change.md) — the introductory tutorial uses option 1.
- [The Component Agnosticism rule](../explanation/component-agnosticism.md) — *why* cross-component changes need this dance in the first place.
