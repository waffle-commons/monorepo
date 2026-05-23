# How-To Guides

> Task-oriented recipes. Each guide answers a single "how do I…" question with the minimum number of steps.

These guides assume you've already set up the workspace — if not, start with the [tutorials](../tutorials/).

## Guides

| Guide | Answers |
| :--- | :--- |
| [**Add a new component**](add-a-new-component.md) | How do I scaffold a new `waffle-commons/*` package from `component-template`? |
| [**Run checks across all components**](run-checks-across-components.md) | How do I fan a command (`composer mago`, `composer tests`, …) out across every submodule? |
| [**Check coverage across components**](check-coverage-across-components.md) | How do I see which components are below the 95% threshold? |
| [**Update a submodule**](update-a-submodule.md) | A change merged in `<component>` — how do I pull it into my local checkout? |
| [**Bump submodule pointers in the umbrella**](bump-submodule-pointers.md) | I've cut a release in `<component>` — how do I commit the new pointer here? |
| [**Work on multiple components locally**](work-on-multiple-components-locally.md) | How do I make `security` consume my in-progress `contracts` changes without publishing them? |
| [**Install Git hooks**](install-git-hooks.md) | How do I wire the Project Graphify pre-commit / post-checkout hooks into every submodule? |
| [**Release a component**](release-a-component.md) | I'm ready to ship `waffle-commons/security@v0.1.0-beta2`. What's the process? |

## When to pick which

| Symptom | Read |
| :--- | :--- |
| "I cloned the umbrella but the component dirs are empty." | [Update a submodule](update-a-submodule.md). |
| "Mago is unhappy in five components at once." | [Run checks across components](run-checks-across-components.md) (`./run-all.sh composer mago`). |
| "Coverage in CI dropped to 91%." | [Check coverage across components](check-coverage-across-components.md). |
| "I want to test my `contracts` patch from inside `security` before pushing." | [Work on multiple components locally](work-on-multiple-components-locally.md). |
| "We're ready to tag v0.1.0-beta2." | [Release a component](release-a-component.md) → [Bump submodule pointers](bump-submodule-pointers.md). |
