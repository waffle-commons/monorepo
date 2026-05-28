# CLAUDE.md — waffle-commons (PHP 8.5 · FrankenPHP · monorepo of independent submodules)

> ⚡ Thin CLI router. **All** standards, architecture, and agent behaviour live in
> **[`/AGENTS.md`](./AGENTS.md)** and **`.opencode/skills/<skill>/SKILL.md`**. Do not add standards here.

## Canonical commands (always in Docker — never run PHP on the host)

```bash
docker exec -it -w /waffle-commons/{component} waffle-dev {command}
```

| Intent | `{command}` |
|--------|-------------|
| Format | `composer formatter` (`vendor/bin/mago fmt`) |
| Lint | `composer linter` (`vendor/bin/mago lint`) |
| Analyze | `composer analyzer` (`vendor/bin/mago analyze`) |
| Guard (dependency perimeter) | `composer guard` (`vendor/bin/mago guard`) |
| All static gates | `composer mago` (fmt + lint + analyze + guard) |
| Tests (≥95% coverage) | `composer tests` |

**Definition of done (per modified component):** `composer mago && composer tests` both green.

## 🧭 Redirection directive (NON-NEGOTIABLE)

Before planning or editing **anything**, READ:

1. **[`/AGENTS.md`](./AGENTS.md)** — PHP 8.5 strict standards, FrankenPHP statelessness mandate,
   the Mago Purge Protocol, and the **Skills Routing Table** (intent → skill).
2. The matching **`.opencode/skills/<skill>/SKILL.md`** for the task. When unsure, start with `tech-lead`.

Hard invariants: components depend **only** on `waffle-commons/contracts`; zero Mago baselines; stateless across requests.
