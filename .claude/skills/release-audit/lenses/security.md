# Security lens cards (Phase 1)

Read by every `owasp-finder`. A finder owns one unit of `manifest.json` → `security_units`: a single
lens, or a bundle of four in a small run. It reads its own cards, the threat notes, the regression items
of its lenses, and the evidence files named on each card.

## The protocol's prompt (kept word for word)

> Analyze the entire provided source code based on the **OWASP Top 10**.
> 1. **Vulnerability Scan:** Identify potential attack vectors (SQL Injection, XSS, Deserialization, IDOR, CSRF).
> 2. **Input Validation:** Verify if input validation classes and sanitization methods are strict enough.
> 3. **Risk Assessment:** Classify identified risks by criticality (CRITICAL, HIGH, MEDIUM).
> Provide code snippets to show where the vulnerabilities are.

The edition is **OWASP Top 10:2025** (the current web edition; OWASP has published no web Top 10 for
2026). The 2026 list that applies to this repository is OWASP's **Top 10 for Agentic Applications
2026**, covered by the `AG` lens over the repository's own AI layer.

## How a finder works
1. Read `evidence/<repo>/SUMMARY.md` for every repository in scope. Psalm taint paths, `composer audit`
   advisories, igor KO lines and SEC-03 hits are candidates in their own right: confirm each in the code,
   or say why it does not hold.
2. Sweep the code for the card's patterns (`rg` first, then read). Follow a value from where it enters
   (PSR-7 request, CLI argument, queue payload, config, upstream response) to where it is used.
3. Check every control the card names. A control that holds goes under `## Checked` with its
   `path:line`, and that negative evidence is half the job.
4. Check the regression items of your lenses at their current code.
5. Write the candidates file (`templates/candidates.md`). A candidate needs a `path:line` at the
   manifest commit, a snippet, a one-sentence claim, a severity from the rubric, and a native fix.

Reachability decides severity. Name the entry point (route, middleware, CLI command, queue consumer)
or say "library code: reachable only when an application wires it so".

## Severity rubric
| Severity | Meaning in Waffle |
|---|---|
| CRITICAL | Exploitable in the shipped defaults (skeleton, gateway) by an unauthenticated remote attacker: code execution, authentication bypass, another user's data, secret disclosure. |
| HIGH | Exploitable through shipped code paths under realistic preconditions (an authenticated user, a documented configuration, a common extension point). |
| MEDIUM | A missing defence-in-depth layer, or exploitable only through an extension point or a non-default configuration. |
| LOW | Hardening with an unlikely or theoretical path; a misleading security claim in a docblock. |
| INFO | Worth recording, no risk: a control that holds but is undocumented, a test gap on a security path. |

## The lens cards

### A01 Broken Access Control (SSRF included)
- **ABAC, fail-closed** (RFC-002): `SecureContainer` denies an action that has neither a voter nor
  `#[PublicAccess]`. Voters default to `false` and receive real subjects, resolved lazily and only for
  voted actions (`[FIX-01]` 5). Look for IDOR: object-level rules that check ownership, not just a role.
- **CORS** fail-closed (SEC-04); **path traversal** through `Assert::safePath()` / `within()` on every
  file path built from input (SEC-05, `[FIX-01]` 3 for uploads).
- **SSRF** (part of A01 since 2025): `SsrfGuard` default-on in `http-client`, resolve (IPv4 and IPv6) →
  validate → pin with `CURLOPT_RESOLVE`, no automatic redirects, the allow-list
  `waffle.security.ssrf.allowed_hosts` only. It re-runs on **every retry** (`[NET-02]`).
- **Exposure of non-public routes:** `/_docs` and the Swagger UI return 404 outside debug (`[API-01]`);
  `/waffle-metrics` exposure; `/healthz` and `/readyz` sit before `TrustedHostMiddleware` on purpose:
  check that nothing else does.
- **Gateway:** `Host` recomputed, `X-Forwarded-*` appended and never trusted, egress pinned.
- Evidence: Psalm `TaintedSSRF`, `TaintedFile`, `TaintedInclude`.

### A02 Security Misconfiguration
- **Shipped defaults** in `skeleton/`, `workspace/` and the gateway:
  - production refuses to boot without `APP_SECRET` and `WAFFLE_AUTH_SECRET`;
  - `APP_ENV=prod` with `APP_DEBUG=true` fails closed (`[FIX-01]` 9);
  - debug-only routes and headers stay debug-only (`/_docs`, the `[DXP-01]` profiler headers);
  - no stack trace in a production error body.
- **Images:**
  - non-root (`[FIX-01]` 13), `read_only` and `no-new-privileges` in the production compose;
  - base images pinned by digest;
  - only the gateway publishes a port.
- **`php.ini`** (`skeleton/docker/frankenphp/conf.d/app.ini` and its siblings):
  - `expose_php`, `display_errors`;
  - the PHP2Shell interim settings: `session.upload_progress.enabled=0` and, on PHP 8.5,
    `fatal_error_backtraces=0` (threat notes). Waffle uses no PHP sessions, so turning upload progress
    off costs nothing.
- **Headers:** a CSP with `form-action` and `base-uri` (`[FIX-01]` 15), and `X-Content-Type-Options`.
- **Caddyfile:** `FRANKENPHP_CONFIG` honoured (`[CARRY-09]`), `shutdown_delay` and the drain.

### A03 Software Supply Chain Failures
- `composer audit` is clean in every lock (evidence). Locks include the 2026-11-04 Symfony fixes (threat
  notes).
- **The PHP runtime is 8.5.12 or later everywhere a request is served:** the skeleton, the workspace,
  `waffle-dev`, the gateway, the CI images. Check `ARG` lines, `FROM` tags and digests, and
  `wfl images:pin --verify` (report-only).
- `composer.json` `php` constraints: does any package still allow a PHP release that PHP2Shell affects?
- `minimum-stability` and `prefer-stable` (the `[FIX-01]` 10 pattern); path repositories pinned by commit.
- **Pinned tools:**
  - the igor bootstrapper downloads a binary, and `.igor-version` pins it;
  - Mago, Psalm and Infection versions are pinned;
  - TruffleHog runs in CI;
  - Actions are pinned in workflows.
- The release wave: the `RELEASE_INCLUDE` allowlist, the ancestry check, the release-tag guard.

### A04 Cryptographic Failures
- Secrets of 32 bytes or more (`Constant::MIN_SECRET_BYTES`), enforced at boot.
- HS256 keys have a floor (`[FIX-01]` 8).
- The CSRF key derives from `APP_SECRET` through HKDF-SHA256 unless `WAFFLE_CSRF_SECRET` is set
  (`SecretFactory`).
- HMAC-SHA256 over canonical payloads.
- `random_bytes` for every token; `password_hash` / `password_verify`.
- JWT: algorithms allow-listed, no `alg:none`, no HS/RS key confusion, `exp` / `nbf` / `iss` / `aud`.
- No home-made crypto. One Base64url implementation, not several.

### A05 Injection
- **SQL and identifiers:** every dialect compiler quotes identifiers and binds values
  (`[FIX-01]` 1, 14). That includes SQL Server and Oracle, which have generation tests only.
- **Other query languages:** the GraphQL, Mongo, KV and Cassandra compilers.
- **Header and CRLF injection** in response headers, redirects and the gateway's forwarded headers.
- **SSE frames:** `SseBroadcastTransport` strips CR, LF, NUL and C0 controls from the raw channel
  (REACTIVE-01).
- **Log injection.**
- **Code generation:** Waffle Maker allow-lists identifiers and runs `php -l` before writing
  (`[FIX-01]` 17); compiled artefacts (`serializer:compile`, `container:compile`, `route:compile`) embed
  no unescaped input.
- **Output escaping:** a controller's bare string return is escaped by default (`[FIX-01]` 15).
- Evidence: Psalm `TaintedSql`, `TaintedHtml`, `TaintedHeader`, `TaintedShell`, `TaintedEval`,
  `TaintedTextWithQuotes`.

### A06 Insecure Design
- **Fail-open choices, deliberate or not:**
  - the rate limiter fails open while Redis is down (warning and metric; `closed` is configurable);
  - the circuit breaker's state is shared, so check whether tenants that should be isolated share a key;
  - the dead-letter store keeps the full envelope, so check who can read it.
- **Retries:** non-idempotent methods are never replayed without an opt-in; the total time across
  attempts is bounded; `RetryPolicy` has no ceiling (a known beta8 question: record it, do not
  re-discover it).
- **Trust boundaries:** `APP_SECRET` as the root secret; the gateway in front of a legacy monolith; the
  stateless design (no PHP sessions anywhere).

### A07 Authentication Failures
- Read the `auth-bridge-audit` checklist first: JWT and JWKS, OAuth2/OIDC with PKCE, HMAC identity
  assertions (5 s TTL, IP binding, replay), API keys, Basic auth, `AuthenticatedClient`.
- Basic auth is constant-time, with no username enumeration (`[FIX-01]` 7).
- Rate limiting now exists (`[NET-01]`): is it wired in front of every authentication scheme in the
  skeleton?
- Authentication failures are logged on the `SECURITY` channel (`[FIX-01]` 6).
- Passkeys: UV enforced, challenges single-use, counters monotonic. Leave the depth to the
  `webauthn-auditor` agent, which the orchestrator dispatches for `auth`.

### A08 Software or Data Integrity Failures
- **`unserialize()` anywhere** (route cache: `[FIX-01]` 2, now `var_export` or `allowed_classes`).
- **Queue payloads:**
  - never `unserialize`, never a class name taken from a payload;
  - envelope fields (attempts, available-at) validated;
  - trace-context headers sanitized.
- **Serializer:** hydration never bypasses a `set` hook; depth and size are bounded (`[API-02]`).
- **AOT artefacts:** a missing or corrupt `CompiledContainer` or route trie falls back to reflection
  safely (`aot-compilation`).
- **Caches:** no shared caching of `Authorization` or `Cookie` responses, in the PSR-16 adapters and in
  the gateway's shield.

### A09 Security Logging and Alerting Failures
- CSRF and authentication failures reach the `SECURITY` channel with the client IP (`[FIX-01]` 6).
- `ErrorHandlerMiddleware` logs by rendered status: 5xx at `critical` with the trace, 4xx at `notice`
  (`[CARRY-10]`).
- Secrets never reach a log: tokens, `Authorization`, cookies, DSNs.
- **Alerting signals:**
  - breaker transitions are counted on `/waffle-metrics`;
  - a Redis outage under the limiter emits a warning and a metric;
  - fatal errors and memory exhaustion in a worker are visible, which PHP2Shell detection depends on.

### A10 Mishandling of Exceptional Conditions
- **Fail-secure** (AGENTS.md §1): no `@`, no generic catch that swallows. `YamlParser` no longer
  swallows its parse exception (`[FIX-01]` 12).
- **Code that must never throw:** a finish-request deferral, a broadcast flush, a health check (each
  with its own timeout).
- **Limits:** no timeout of 0 or infinity; outages become a cache miss, not a crash (the 2026-11-04
  router fix).
- **Memory exhaustion:** `queue:work` exits at its memory ceiling, and `MAX_REQUESTS` recycles workers.
  Check how the kernel handles a request that dies on its memory limit; CVE-2026-109618 lives on that
  path.
- PHP 8.5.12's SimpleXML regression (php-src #24488): no component source used SimpleXML on 2026-11-05.
  Check that this still holds.

### W1 Worker-state leaks across requests
- **igor:** 0 KO, read from the evidence. Every WARN is reviewed.
- **`#[WorkerSafe]`:** each one carries a reason that still holds; spot-check the 78 from `[CARRY-05]`.
- **Resetting:** a class that mutates per-request state implements `ResettableInterface` directly.
  Check DBAL pool reset and request affinity, `RequestBroadcastBuffer`, and `kernel->reset()`.
- **No hidden state:** no superglobals outside `GlobalsFactory`, no mutable statics, no
  `sys_get_temp_dir()`.
- **PHP2Shell CVE-2026-109619 lives at the engine level:** freed state from one request is reused by
  the next request on the same worker. The framework cannot fix the engine. It can make sure that:
  - every image runs PHP 8.5.12 or later;
  - an upgrade restarts every worker (the `[OPS-02]` rolling restart and drain);
  - `MAX_REQUESTS` recycling bounds a worker's life;
  - the deployment docs say so.

### W2 Timing-safe comparisons
- **SEC-03:** the evidence's `compare-audit.txt`, then the sites the scanner cannot see.
- `hash_equals` for every secret, token, HMAC, signature and CSRF comparison.
- No early return on a length mismatch before the constant-time compare.
- **Lookups that leak timing:** an API key found by an array key or SQL `WHERE` on the raw key is a
  lookup oracle; compare digests instead. The Basic-auth dummy-hash path (`[FIX-01]` 7).

### AG Agentic layer (OWASP Top 10 for Agentic Applications 2026)
- **Scope:** the umbrella only:
  - `.claude/`: skills, agents, `settings.json`, and the plugins (the `waffle-cockpit` hooks and the
    vendored `mattpocock-skills`);
  - `.mcp.json` and `scripts/mcp/`;
  - `AGENTS.md` and `CLAUDE.md`;
  - `scripts/claude/`;
  - the agent helpers in `bin/wfl`.
- **Evidence:** `evidence/umbrella/SUMMARY.md` (`wfl ai:check`).
- **Category names:** from the OWASP GenAI Security Project (published December 2025). Check the
  wording at genai.owasp.org before quoting it.

| ID | Risk | What to check here |
|---|---|---|
| ASI01 | Agent Goal Hijack | Untrusted text (issues, PR bodies, fetched pages, vendored skills, MCP results, subagent reports) is treated as data; AGENTS.md §6 and §9 rules hold. |
| ASI02 | Tool Misuse | The permission rules (allow / ask / deny) and the cockpit Bash guard cover what AGENTS.md §6 promises: release tags, force pushes, squash merges, host PHP, secret reads, `wfl audit:sign`. |
| ASI03 | Identity and Privilege Abuse | The GitHub MCP server is read-only; tokens are scoped; `gh auth token` is denied; each agent's `disallowedTools` matches its contract. |
| ASI04 | Agentic Supply Chain | MCP launchers pinned by digest; the vendored skills pinned to a commit and curated; the cockpit's code reviewed and validated. |
| ASI05 | Unexpected Code Execution | Hooks run only repository scripts; the mod runs only the commands its README lists; the guard parses chains, `sh -c` and `env` prefixes. |
| ASI06 | Memory and Context Poisoning | What agents load as trusted (`CLAUDE.md` imports, skills, memory) can be changed only through review. |
| ASI07 | Insecure Inter-Agent Communication | Subagent hand-backs and messages carry no authority; no permission is granted through them. |
| ASI08 | Cascading Failures | Background agents, loops and the release wave stop on failure instead of continuing. |
| ASI09 | Human-Agent Trust Exploitation | Human-only steps stay human: risk sign-off, release tags, merges; "done" means evidence. |
| ASI10 | Rogue Agents | Guard rails, not a sandbox (stated in the catalogue): is every irreversible action covered twice? |

## Regression list
Each finder checks the items of its lenses, as they stand today. A regression is a candidate with
`- regression: <item>` among its fields.
- **beta4:** SEC-01 CSRF (stateless HMAC double-submit), SEC-02 SSRF (default-on guard), SEC-03
  timing-safe comparisons, SEC-04 CORS fail-closed, SEC-05 path containment.
- **beta5 AXE 0** (`Roadmap_Beta5.md`): `[AUTHZ-01]`, context-aware voters, and the hardening backlog
  listed there.
- **beta6 `[FIX-01]`** (`Roadmap_Beta6.md`, 17 items): 1 SQL identifier quoting · 2 route-cache
  `unserialize` · 3 upload path containment · 4 container reset parity (AOT) · 5 `#[PublicAccess]` and
  voter subjects · 6 CSRF and authentication logging · 7 Basic-auth timing · 8 HS256 key floor ·
  9 prod with debug fails closed · 10 workspace stability flags · 11 demo endpoint `INSERT` ·
  12 `YamlParser` swallowing · 13 non-root image · 14 Cassandra write-path quoting · 15 escaping and
  CSP · 16 route-parameter coercion · 17 Maker code generation.
- **beta8 `[AUD-01]` surfaces** (the `security-audit` skill): the rate limiter, the resilient client and
  breaker, queue payloads, health endpoints, OpenAPI dev routes, the serializer, `/waffle-metrics`,
  pooling, WebAuthn, the EcoShield proxy path.

## Threat notes (dated: refresh before each run)
**2026-11-05**
- **PHP2Shell** (PHP security release of 2026-10-21, CVSS 4.0 9.2 for both CVEs, exploited in the
  wild; CVE-2026-109618 has been in CISA's KEV catalogue since 2026-10-26, and sources differ on
  CVE-2026-109619):
  - CVE-2026-109618: memory exhaustion interrupts PHP while request data is half initialized, and the
    cleanup trusts it, so remote code execution.
  - CVE-2026-109619: state left by one request points at freed memory, and the next request on the same
    worker uses it, so remote code execution and memory disclosure.
  - Every SAPI that serves web requests is affected, FrankenPHP included. Fixed in 8.5.12 (8.4.27,
    8.3.36, 8.2.35).
  - Upgrading is the only complete fix, and **every worker must restart** afterwards.
  - PHP's interim settings: `memory_limit=-1` that applications cannot override (CVE-2026-109618);
    `session.upload_progress.enabled=0`, plus `fatal_error_backtraces=0` on 8.5 (CVE-2026-109619).
- **CVE-2026-115560** (advisory of 2026-10-23): an unlikely code-execution path in session upload
  progress, **not fixed in 8.5.12**. Until the next regular release PHP suggests
  `session.upload_progress.enabled=0`.
- **CVE-2026-111497**: the Brotli decoder bundled in PHP's Windows builds (fixed in `8.5.12-1`). Linux
  images are not those builds. Still check whether any shipped image decodes Brotli request bodies, and
  through which library.
- **php-src #24488:** 8.4.27 and 8.5.12 can crash SimpleXML applications (a separate garbage-collector
  change).
- **Symfony security releases of 2026-11-04:**
  - `symfony/filesystem` GHSA-6prc-h956-hxjq (fixed in 8.1.11);
  - `symfony/serializer` CVE-2026-118515 and two more;
  - `symfony/http-client` GHSA-gq53-v8w2-gjhj and GHSA-c7hm-wqwp-f9v8.

  Every lock was refreshed on 2026-11-05; check that none regressed.
- Sources: PHP's 2026 news archive (php.net/archive/2026.php), Tenable's PHP2Shell FAQ, watchTowr's
  CVE-2026-109618 FAQ, Help Net Security (2026-10-21), and Log_Beta7 §5 for the Symfony releases.
