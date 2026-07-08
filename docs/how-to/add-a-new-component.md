# How-To: Add a new component

> **Diátaxis quadrant:** How-To.
> **Release:** `0.1.0-beta5`.
> **Answers:** I want to ship a new `waffle-commons/<thing>` package. What's the process?

## When to add a component vs extend an existing one

Add a new component when:

- The new code is **independently useful** (a consumer outside the framework could `composer require` it).
- It has a clean PSR-x or W3C contract you can point at.
- It will only depend on `waffle-commons/contracts` (and possibly the PSR interface packages).

If those aren't all true, extend an existing component instead. New components have ongoing release / CI / coverage cost.

## 1. Bootstrap from `component-template`

The `component-template` submodule is the canonical scaffold. It ships pinned Mago/PHPUnit/Psalm config, a CI workflow, a `mago.toml` with the ecosystem's `[guard]` rules, an `igor.json` + `composer igor` memory-neutrality gate (see [The Mago Purge Protocol](../explanation/mago-purge-protocol.md#the-memory-neutrality-companion-gate-igor-php)), and placeholder files.

```bash
# At the umbrella root
cd component-template
./configure-component.sh MyThing
```

The script:

- replaces every `HttpClient` placeholder (the original component the template was extracted from) with your PascalCase name;
- renames files / directories accordingly;
- updates the PSR-4 namespaces in `composer.json`;
- updates badge URLs.

Read the script's output carefully and confirm everything was rewritten.

## 2. Move the scaffold into place

The template generates the new component **in place**. Move it to the umbrella root as a sibling of the other components:

```bash
cd ..
mv component-template/MyThing my-thing
```

> The exact mechanics depend on how your team prefers to bootstrap. Some teams clone the template to a separate repo first, then add it as a submodule. The pragmatic local-first variant above is fine for prototyping.

## 3. Create the upstream repository

Create `git@github.com:waffle-commons/my-thing.git` on GitHub (`waffle-commons` org). Push the scaffolded code:

```bash
cd my-thing
git init
git remote add origin git@github.com:waffle-commons/my-thing.git
git add .
git commit -m "chore: scaffold from component-template"
git branch -M main
git push -u origin main
```

Apply the canonical branch ruleset:

```bash
gh api -X POST /repos/waffle-commons/my-thing/rulesets \
    --input ../component-ruleset.json
```

See [`component-ruleset` reference](../reference/component-ruleset.md) for what that JSON enforces.

## 4. Add it as a submodule of the umbrella

Back at the umbrella root:

```bash
git submodule add git@github.com:waffle-commons/my-thing.git my-thing
git add .gitmodules my-thing
git commit -m "chore: add waffle-commons/my-thing submodule"
```

The umbrella now tracks `my-thing` at its initial commit.

## 5. Register it in the cross-component scripts

Both `loop.sh` and `coverage.sh` derive the component set (today, via `scripts/list-components.sh`, which discovers every `waffle-commons/*` directory). The set grows over time — Beta5 added three new releasable packages: `async`, `telemetry`, and `telemetry-otel`. If your scripts still carry a hardcoded `COMPONENTS=( … )` array, append your component:

```bash
# loop.sh + coverage.sh, alphabetical insertion
COMPONENTS=(
    "cache"
    "config"
    ...
    "my-thing"
    ...
)
```

Verify:

```bash
./loop.sh ls composer.json
# my-thing should appear with a ✅
```

## 6. Wire the documentation entries

| File | Add |
| :--- | :--- |
| `README.md` (this repo's root) | New row in the **What's inside** matrix. |
| `documentation/reference/index.md` | New row in the components table (framework-user perspective). |
| `documentation/reference/<my-thing>.md` | New reference page describing the component's public surface. |
| `docs/reference/repository-layout.md` | Mention the new directory. |

If the new component introduces user-facing concepts (an attribute, a middleware, a service contract), it likely also needs an explanation page under `documentation/explanation/` and possibly a how-to under `documentation/how-to/`.

## 7. Open the umbrella PR

Per-PR checklist:

- [ ] New submodule exists on GitHub at `waffle-commons/<thing>` with the canonical ruleset applied.
- [ ] `.gitmodules` and the submodule pointer committed in the umbrella.
- [ ] `loop.sh` + `coverage.sh` arrays updated.
- [ ] `README.md` matrix and `documentation/reference/index.md` updated.
- [ ] New `documentation/reference/<thing>.md` reference page.
- [ ] `./loop.sh composer mago` and `./loop.sh composer tests` still green.
- [ ] `composer igor` green for the new component (it inherits the memory-neutrality gate from the template).

## Related

- [Release a component](release-a-component.md) — for the first real release of the new package.
- [`component-template` reference](../reference/repository-layout.md) — the scaffold's contents.
- [The Component Agnosticism rule](../explanation/component-agnosticism.md) — why your new component must only depend on `contracts`.
