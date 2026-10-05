#!/usr/bin/env bash
# =============================================================================
# scripts/claude/vendor-mattpocock.sh — vendor a pinned, curated copy of
# github.com/mattpocock/skills as the `mattpocock-skills` Claude Code plugin.
#
# Why vendored rather than `/plugin install` from the official marketplace:
#   - the official entry auto-updates, so third-party prompts would change
#     under us without review;
#   - a plugin's skills cannot be switched off one by one (`skillOverrides`
#     ignores plugin skills), so the ones that conflict with AGENTS.md §6
#     could not be dropped;
#   - a relative-path plugin in the repo marketplace loads for every clone
#     with no install step.
#
# Usage:   scripts/claude/vendor-mattpocock.sh <40-char-commit-sha>
# Effect:  rewrites .claude/plugins/mattpocock-skills/ from that commit and
#          prints what changed. Review the diff before committing it.
# =============================================================================
set -euo pipefail

UPSTREAM="https://github.com/mattpocock/skills.git"
REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="$REPO_ROOT/.claude/plugins/mattpocock-skills"

# Kept skills, as <category>/<name> under the upstream skills/ directory.
KEEP=(
  engineering/ask-matt
  engineering/codebase-design
  engineering/diagnosing-bugs
  engineering/domain-modeling
  engineering/grill-with-docs
  engineering/improve-codebase-architecture
  engineering/pr
  engineering/research
  engineering/retro
  engineering/tdd
  engineering/to-spec
  engineering/to-tickets
  engineering/wizard
  productivity/grill-me
  productivity/grilling
  productivity/handoff
  productivity/teach
  productivity/to-questionnaire
  productivity/wait-what
  productivity/writing-for-agents
)

sha="${1:-}"
if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'usage: %s <40-char-commit-sha>\n' "$0" >&2
  exit 2
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/mp-skills.XXXXXX")"
trap 'rm -rf "$work"' EXIT

printf '→ fetching %s at %s\n' "$UPSTREAM" "$sha"
git init -q "$work/src"
git -C "$work/src" fetch -q --depth 1 "$UPSTREAM" "$sha"
git -C "$work/src" checkout -q FETCH_HEAD
version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$work/src/.claude-plugin/plugin.json")"
date="$(git -C "$work/src" log -1 --format=%cs)"

stage="$work/plugin"
mkdir -p "$stage/.claude-plugin" "$stage/skills"
for k in "${KEEP[@]}"; do
  [ -f "$work/src/skills/$k/SKILL.md" ] || { printf '✗ upstream has no skills/%s/SKILL.md\n' "$k" >&2; exit 1; }
  mkdir -p "$stage/skills/$(dirname "$k")"
  cp -R "$work/src/skills/$k" "$stage/skills/$k"
  rm -rf "$stage/skills/$k/agents"   # Codex-only agent descriptors (openai.yaml)
done
cp "$work/src/LICENSE" "$stage/LICENSE"

python3 - "$stage" "$version" "$sha" "${KEEP[@]}" <<'PY'
import json, sys
stage, version, sha, keep = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
manifest = {
    "name": "mattpocock-skills",
    "version": version,
    "description": f"Matt Pocock's engineering skills, vendored at {sha[:7]} and curated for waffle-commons (see VENDORED.md).",
    "author": {"name": "Matt Pocock", "url": "https://www.aihero.dev"},
    "repository": "https://github.com/mattpocock/skills",
    "license": "MIT",
    "skills": [f"./skills/{k}" for k in keep],
}
with open(f"{stage}/.claude-plugin/plugin.json", "w") as fh:
    json.dump(manifest, fh, indent=2)
    fh.write("\n")
PY

cat > "$stage/VENDORED.md" <<EOF
# Vendored: mattpocock/skills

| | |
|---|---|
| Upstream | <https://github.com/mattpocock/skills> |
| Commit | \`$sha\` |
| Upstream version | \`$version\` ($date) |
| License | MIT, see [\`LICENSE\`](LICENSE) |
| Refresh | \`scripts/claude/vendor-mattpocock.sh <sha>\`, then review the diff |

Files are copied verbatim, except the Codex-only \`agents/openai.yaml\` descriptors, which are
dropped. The manifest lists only the kept skills, so Claude Code loads nothing else.

## Kept (${#KEEP[@]})

$(printf -- '- `%s`\n' "${KEEP[@]}")

## Excluded, and why

- \`implement\`: ends with "Commit your work to the current branch". Commits are the human's
  (\`AGENTS.md\` §6).
- \`implement-spec\`: creates an integration branch, worktrees and merges, and opens draft PRs. It
  also does not fit a monorepo of submodules.
- \`triage\` and \`wayfinder\`: post comments, labels and maps on the issue tracker, and research
  branches.
- \`prototype\`: commits the prototype to a throwaway branch.
- \`setup-matt-pocock-skills\`: writes an "Agent skills" block into CLAUDE.md. The configuration it
  produces is written by hand instead: \`docs/agents/\` and \`AGENTS.md\` → "Third-party skills".
- \`code-review\`: clashes with the project's own \`code-review\` skill, which carries its two-axis
  idea (standards and spec).

\`AGENTS.md\` §6 overrides any step of a kept skill that would commit, branch, push, open a PR or
publish an issue: Claude stops and asks.
EOF

if [ -d "$DEST" ]; then
  printf '→ changes against the current copy:\n'
  diff -rq "$DEST" "$stage" | sed 's/^/  /' || true
fi
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -R "$stage" "$DEST"
printf '✓ vendored mattpocock-skills %s (%s) → %s\n' "$version" "${sha:0:7}" "${DEST#"$REPO_ROOT"/}"
