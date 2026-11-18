# Modernization lens cards (Phase 2)

Read by every `modernization-finder`. A finder owns one group of `manifest.json` →
`modernization_units` and covers the three lenses below for every repository in it.

## The protocol's prompt (kept word for word)

> Analyze the code from a **'Modern PHP'** perspective.
> 1. **Modern Features:** List classes that are NOT yet using recent PHP 8.5+ features (e.g., Readonly classes, Typed constants, Property Hooks).
> 2. **Complexity:** Identify code areas with high Cyclomatic Complexity that require Refactoring.
> 3. **Patterns:** Are there any poorly implemented Design Patterns or Anti-patterns?

## M1 Modern features
**Binding standard (AGENTS.md §1).** A miss is a candidate:
- `declare(strict_types=1);` is the first statement;
- no `mixed`, in any parameter, return, property or docblock;
- typed class constants;
- property hooks for validation instead of getters and setters;
- asymmetric visibility and `readonly` on DTOs. A hooked property cannot be `readonly`: a hooked DTO is a
  `final class` with `public private(set)`;
- `#[\Override]` on every method that implements or overrides;
- fail-secure errors: no `@`, specific domain exceptions.

**Opportunities.** A candidate only where the change removes risk or real code:
- PHP 8.5:
  - the URI extension (`Uri\Rfc3986\Uri`, `Uri\WhatWg\Url`) where `parse_url()` feeds a security
    decision (SSRF, trusted hosts, redirects). A parser differential is also a security finding;
  - `array_first()` / `array_last()`;
  - the pipe operator;
  - `clone` with property overrides for wither methods on readonly classes;
  - `#[\NoDiscard]` on results that must not be ignored (a validation verdict, a lock).
- PHP 8.4:
  - `#[\Deprecated]` for the beta8 deprecations (the native way, which tools read);
  - `array_find()` / `array_any()` / `array_all()`;
  - `mb_trim()`, but mind the import swap Mago asks for;
  - lazy objects instead of hand-written proxies.
- PHP 8.2: `#[\SensitiveParameter]` on every parameter that carries a secret (keys, tokens,
  passwords), so a stack trace never prints it. This one is security-relevant: a candidate, LOW or more.

Check every newer API against the PHP manual's migration guide before naming it in a candidate. A wrong
API name is a defect of the report.

## M2 Complexity
- **Numbers come from Mago, not from estimates.** Read `evidence/<repo>/mago-metrics.json` and its
  summary. `wfl audit:evidence` ran these rules at Mago's defaults:
  - `cyclomatic-complexity`, `excessive-nesting`, `excessive-parameter-list`;
  - `halstead`, `kan-defect`;
  - `too-many-methods`, `too-many-properties`.

  The release gate itself only fails cyclomatic complexity above 50 (CPLX-04). These metrics are a
  reading list, not a gate.
- **Ranking:** a hotspot matters more on a security path (authentication, authorization, parsing,
  compilers) or a hot path (the kernel's request handling, routing, the pools) than in a console
  command.
- **Shape of a candidate:** quote Mago's message (it carries the measured value) and name the
  responsibilities that are fused together. The extraction must keep the behaviour.

## M3 Patterns and anti-patterns
- **Duplicated logic.** The beta6 review found 11 clusters. Flag a cluster that has started to drift.
  A primitive shared by several components belongs in `utils` (the `contracts` + `utils` perimeter).
- **Inconsistent error handling:** a swallowed exception on a fail-secure path is HIGH.
- **Dead code**, and god classes (the `Constant` pattern).
- **Coupling:** `mago guard` holds the import perimeter. Look for conceptual coupling it cannot see:
  string class names, magic keys, a service locator.
- **Primitive obsession and reinvented wheels:** hand-rolled Base64url, hand-rolled JWS assembly.
- **Oversized factories and orchestrators:** `AppKernelFactory`, dispatchers.
- Mutable static or per-request state belongs to the security finder's `W1` lens. Note it and leave it.

## Fields for a modernization candidate
`lens` is `M1`, `M2` or `M3`. Add `- public-api: yes|no`: does the fix change a public signature of a
released package? The triager uses it under the freeze rules.

**Severity:**
- INFO: style only.
- LOW: the default.
- MEDIUM: the item raises the risk of a defect, such as security logic that has drifted between copies,
  or a complex security path.
- HIGH: only when the pattern hides a defect.
