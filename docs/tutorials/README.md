# Tutorials

> Learning-oriented. End-to-end walkthroughs for contributors who have never used the monorepo before.

If you already know the project and just need a recipe, you want [How-To Guides](../how-to/) instead.

## Available tutorials

| Tutorial | What you'll do | Prerequisites |
| :--- | :--- | :--- |
| [**Set up your monorepo workspace**](setup-your-monorepo-workspace.md) | Clone the umbrella with submodules, boot the `waffle-dev` Docker container, run your first `composer mago` + `composer tests`. | Git, Docker (Compose), a shell. |
| [**Make your first cross-component change**](make-your-first-cross-component-change.md) | Add a tiny feature that spans `contracts` and `security`, run the checks, prepare the per-submodule commits and the umbrella pointer bump. | Setup tutorial completed. |

## Why so few?

Tutorials are deliberately scarce. They are expensive to keep in sync with the codebase, and most of what contributors need fits better as a focused [How-To](../how-to/) recipe. If a workflow shows up in 3+ "how do I…" support questions, that's the signal it deserves a tutorial — open a doc PR.
