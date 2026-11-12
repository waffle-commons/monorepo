# Regression list (Phase 1, full mode)

Read by every `owasp-finder` in full mode, after its lens cards (`lenses/security.md`). Each finder checks
the items of its lenses as they stand today. A regression is a candidate with `- regression: <item>` among
its fields.

A calibration finder reads no file under `lenses/`: this list and the lens cards name the defects the
calibration replays.

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
