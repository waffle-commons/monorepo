---
name: webauthn-passkeys
description: "[Beta5 / RFC-021 AUTH-01 — SHIPPED] WebAuthn / passkeys in waffle-commons/auth: WebAuthnLibAdapter is the sole webauthn-lib importer, stateless authenticator (app-provided challenge store), configurable UV, fail-closed"
compatibility: opencode
---

## What I do
I maintain the **shipped** WebAuthn / passkey scheme (AUTH-01, beta5) inside `waffle-commons/auth` —
the inbound passwordless authentication leg of the Universal Authentication Bridge. The cryptographic
core wraps the audited `web-auth/webauthn-lib`; everything stateful is app-provided. Authorization
(ABAC/voters/CSRF) is out of scope — that is `[[security-audit]]`. Cross-reference
`[[auth-bridge-audit]]` for the wider bridge audit checklist (this skill is the WebAuthn-specific
extension of it).

## When to use
"passkey / WebAuthn / FIDO2", "attestation / assertion verification", "registration vs login
ceremony", "user-verification requirement", "AUTH-01", auditing or extending the passkey scheme.

## Shipped surface (read these before touching anything)
- **`contracts/src/Auth/WebAuthn/`** — `WebAuthnVerifierInterface` (the crypto port:
  `createRegistrationOptions` / `verifyRegistration` / `createAssertionOptions` / `verifyAssertion`),
  `RegistrationOptionsInterface` / `AssertionOptionsInterface`, `RegisteredCredentialInterface`,
  `WebAuthnUserInterface`, `CredentialRepositoryInterface` (app-provided storage), and the
  `Exception/` interfaces.
- **`auth/src/WebAuthn/`** — `WebAuthnLibAdapter` (crypto core), `WebAuthnAuthenticator` (the
  `AuthenticatorInterface` scheme), `WebAuthnChallengeStoreInterface` (app-provided, single-use
  challenge store), plus the option/credential/user value objects + `OptionsCodec` and the
  `Exception/` concretes.

## Invariants that MUST hold (regression guards)
- **Single audited-library importer:** `WebAuthnLibAdapter` is the ONLY class that imports
  `web-auth/webauthn-lib` (`Webauthn\**`), so the framework never hand-rolls CBOR/COSE/attestation
  parsing. `auth/mago.toml` narrows the perimeter to EXACTLY the namespaces the adapter needs —
  `Webauthn\**`, `Symfony\Component\Serializer\**` (the library's serializer),
  `Symfony\Component\Uid\**` (the zero-AAGUID `NilUuid`). Never widen that permit list to make a new
  importer compile; keep the SDK usage inside the adapter.
- **Stateless authenticator — challenge store is app-provided, NEVER worker memory:**
  `WebAuthnAuthenticator` (`final readonly`) holds only the injected verifier, challenge store, and
  credential repository. The challenge is persisted in the app's storage (cache/session/db) keyed by
  an opaque ceremony id (the `X-Wfl-Webauthn-Ceremony` header), `take()`-n single-use on assertion —
  so nothing survives in worker memory across requests (FrankenPHP rule). The adapter itself builds
  the serializer + both ceremony validators ONCE at construction from the relying-party config and
  reuses them read-only across requests.
- **Configurable user verification (UV):** `WebAuthnLibAdapter` accepts `$userVerification` =
  `'preferred'` (default) or `'required'`, validated at construction (untyped config may reach it) and
  applied to BOTH ceremonies (`authenticatorSelection` on registration, `userVerification` on
  assertion). `'discouraged'` is deliberately NOT offered — the framework never weakens UV below the
  protocol default. Set `'required'` for passwordless logins so the library's `CheckUserVerification`
  step rejects any response missing the UV flag.
- **Fail-closed everywhere:** every missing piece (unknown/expired ceremony, unknown credential,
  malformed JSON body, missing credential id, unusable user handle) or verification failure throws an
  `AuthenticationExceptionInterface` (`InvalidWebAuthnAssertionException` /
  `InvalidWebAuthnRegistrationException` / `WebAuthnException`) — never a silent anonymous downgrade.
  The PSR-7 body is the scheme's untyped wire boundary, so `WebAuthnAuthenticator::credentialId()`
  narrows the `json_decode` shape with `is_string()` before use; a bad UV config value or a
  non-base64url stored credential field is rejected fail-closed.
- **Clone detection:** `verifyAssertion()` returns the new signature counter and the authenticator
  advances the stored counter via `CredentialRepositoryInterface::updateSignCount()`.
- **FIXED-KEYPAIR test-fixture rule:** `auth/tests/src/WebAuthn/Helper/WebAuthnFixtureFactory.php`
  plays the authenticator role end-to-end with the SAME audited primitives the adapter verifies with,
  using a **FIXED, hardcoded P-256 keypair** (raw 32-byte components in base64 constants —
  `PRIVATE_SCALAR_B64`/`PUBLIC_X_B64`/`PUBLIC_Y_B64`). Do **NOT** mint a fresh key per run with
  `openssl_pkey_new()` — a freshly generated scalar/coordinate occasionally has a leading zero byte
  that gets stripped, producing an intermittent crypto failure. The hardcoded keypair eliminates that
  flake entirely (left-padding only prepends zero bytes without changing the scalar). This is a
  reviewed, documented deviation from literal W3C/FIDO vectors (recorded in `auth/CHANGELOG.md`):
  because the same library performs both production verification and the fixture crypto, an accept is
  cryptographically equivalent to passing a literal vector — only WHO minted the keypair differs.
  If a passkey test ever flakes, run **`wfl flake-hunt`** to re-run it and confirm it is reproducible
  before assuming a code regression (a returned-flake usually means a fixture reintroduced per-run key
  generation).

## Execution (in Docker)
```bash
docker exec -it -w /waffle-commons/auth     waffle-dev composer mago    # incl. the narrowed guard perimeter
docker exec -it -w /waffle-commons/auth     waffle-dev composer tests
docker exec -it -w /waffle-commons/auth     waffle-dev composer igor
docker exec -it -w /waffle-commons/contracts waffle-dev composer mago
```
Verify: tampered challenge/origin/UV-flag/signature/counter/userHandle ⇒ verification failure (genuine
cryptographic rejection, not mocks); unknown/expired ceremony or credential ⇒ fail-closed throw;
unsupported UV requirement ⇒ fatal at construction; coverage ≥95%. Definition of done unchanged:
`composer mago` zero output, `composer tests` ≥95%, `wfl igor` 0 KO (`wfl dod` runs the full gate).

> **Language note:** the auth bridge lives in framework components — all comments, logs, and
> exceptions are **English** (French only in the `skeleton/`, `workspace/`, and `academy/` template
> apps).
