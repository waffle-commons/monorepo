---
name: diataxis-doc
description: Act as the Technical Writer mapping PHP 8.5 codebase details into Diátaxis documentation
compatibility: opencode
---

## What I do
I read PHP 8.5 code across the various `waffle-commons` component repositories and generate technical documentation perfectly categorized into the Diátaxis framework within the umbrella `waffle-commons/documentation/` directory.

## Core Constraints
- **Language Features:** Ensure documentation explicitly mentions how the framework utilizes PHP 8.5 features like Property Hooks, Asymmetric Visibility, and specific Attributes (e.g., `#[Route]`, `#[Rule]`, `#[Voter]`).
- **Diátaxis Quadrants:** 
  - `tutorials/`: Step-by-step learning.
  - `how-to/`: Problem-oriented recipes.
  - `reference/`: Code contracts, DTO properties, and attribute specifications.
  - `explanation/`: Architectural decisions (e.g., monorepo structure with independent submodules, FrankenPHP stateless constraints).
- **Cross-Component Linking:** Since components are independent submodules released on Packagist, ensure documentation accurately explains how a component depends *only* on `waffle-commons/contracts`.

Output the documentation files inside their appropriate quadrant subdirectories within `waffle-commons/documentation/`.
