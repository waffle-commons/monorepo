---
name: maker-scaffold
description: Generate zero-debt PHP 8.5 code with Waffle Maker (RFC-020) — controllers, DTOs, middleware, voters, commands, HTTP clients, event pairs
compatibility: opencode
---

## What I do
I drive **Waffle Maker** (RFC-020), the scaffolding engine in `waffle-commons/console`
(`Waffle\Commons\Console\Maker`), to generate perfectly-formed, zero-debt PHP 8.5 structures. I run
the `make:*` commands and guarantee the output passes the Mago Purge Protocol with no manual edits.

## When to use
"Scaffold / generate / make a …": controller, DTO, middleware, voter, console command, HTTP client,
or PSR-14 event pair.

## Commands (`bin/waffle make:[command] [args] [--options]`)
| Command | Generates |
|---------|-----------|
| `make:controller [Name] [--route=/path] [--priority=0]` | `final` controller extending `BaseController`, one `#[Route]` method + JSON response. |
| `make:dto [Name] [field:type …]` | `final readonly` `#[Dto]` with promoted props; `PropertyHookGenerator` adds a `set` hook per field (e.g. `FILTER_VALIDATE_EMAIL`) throwing `ValidationException`. |
| `make:middleware [Name]` | `final readonly` PSR-15 middleware; `#[\Override] process()` with forward-chained delegation. |
| `make:voter [Name]` | `final readonly` `VoterInterface`; `decide()` **defaults to `false`** (fail-closed). |
| `make:http-client [Name] [--base-uri=…]` | `final readonly` PSR-18 wrapper; maps network failures to `HttpClientExceptionInterface`. |
| `make:command [Name] [--command-name=app:task]` | `final` class extending `AbstractCommand`; `configure()` + `execute()` returning an `ExitCode`. |
| `make:event-pair [Name]` | `final` event extending `AbstractStoppableEvent` + `final readonly` listener with `#[AsEventListener]` on `__invoke`. |

## Generation rules (RFC-020 §5)
- **Zero-debt output:** every stub passes `mago lint` + `mago analyze` with **zero errors/warnings,
  no baselines** — strict types, Property Hooks, `readonly`, asymmetric visibility, `#[\Override]`.
- **Anti-overwrite shield:** abort on `stderr` if the target exists, unless `--force` / `-f`.
- **Atomic writing:** compile to a temp file, then `rename()` into place (OWASP A05). New dirs `0755`.
- **Namespace from `composer.json`:** parse the local package's `autoload.psr-4` — never hardcode.
- **Stateless engine:** `TemplateRenderer` is stateless and memory-bounded; no shared worker state.
- **Language:** generated comments and display logs are **English** by default; write **French only
  when the target package is a template app — `skeleton`, `workspace`, or `academy`**. Code,
  namespaces, and contracts stay English even there. RFC-020 sets no localization requirement.
- **Registration:** new commands are explicitly registered in the console factory ("zero-magic").

## Verify (RFC-020 §6, in Docker)
```bash
docker exec -it -w /waffle-commons/console waffle-dev composer mago
docker exec -it -w /waffle-commons/console waffle-dev composer tests   # in-memory virtual FS, ≥95%
```
