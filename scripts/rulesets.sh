#!/usr/bin/env bash
# =============================================================================
# scripts/rulesets.sh — keep every waffle-commons repository on the canonical
# GitHub rulesets.
#
# The three JSON files at the umbrella root are the SINGLE SOURCE OF TRUTH
# (GitHub export format, importable from the UI as well):
#   component-ruleset.json  → "main"                   (default branch)
#   tags-ruleset.json       → "tags"                   (all tags)
#   fork-ruleset.json       → "Enforce Fork Workflow"  (all branches)
#
#   check [repo…]   read-only: compare each repo's live rulesets to the files
#   sync  [repo…]   create missing / update drifted rulesets to match the files
#
# Without repo arguments, every PUBLIC, non-archived repo of the org is
# covered, minus the intentional EXCEPTIONS below. Private repos are skipped:
# the org is on GitHub Free, where rulesets need a public repository.
# Rulesets that are not in the files are reported, never deleted.
# On a repo without .github/dependabot.yml the Dependabot bypass is dropped from
# the expected rulesets: Dependabot does not run there, so it would grant nothing.
#
# Comparison: name, target, enforcement, ref conditions, rule types, bypass
# actors, and every rule parameter present on BOTH sides (GitHub adds default
# parameters on its side and drops retired ones, so one-sided keys are ignored).
#
# Needs: gh (authenticated, repo admin) + jq.
# Exit:  0 = all aligned / synced, 1 = drift found or an API call failed.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ORG="waffle-commons"
TEMPLATES=("component-ruleset.json" "tags-ruleset.json" "fork-ruleset.json")
DEPENDABOT_APP_ID=29110

# Repos that deliberately run their own ruleset set.
EXCEPTIONS="devtool ecoshield-gateway .github"
exception_reason() {
  case "$1" in
    devtool)           echo "separate tool with its own ruleset set" ;;
    ecoshield-gateway) echo "standalone product, independent release process" ;;
    .github)           echo "community-profile repo, 'main' only" ;;
  esac
}

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_CYA=$'\033[0;36m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_CYA=""; C_DIM=""; C_RST=""
fi
die() { printf '%s✗ %s%s\n' "$C_RED" "$*" "$C_RST" >&2; exit 1; }

MODE="${1:-}"; shift || true
case "$MODE" in
  check|sync) : ;;
  *) die "usage: scripts/rulesets.sh check|sync [repo…]" ;;
esac
command -v gh >/dev/null || die "gh not found"
command -v jq >/dev/null || die "jq not found"
for t in "${TEMPLATES[@]}"; do
  jq -e .name "$REPO_ROOT/$t" >/dev/null 2>&1 || die "invalid or missing template: $t"
done

# Differences between a template ($t) and a live ruleset ($l), one per line.
# shellcheck disable=SC2016
JQ_DIFF='
  def norm: if type == "array" and all(.[]; type != "object") then sort else . end;
  def bypass: [.bypass_actors[]? | "\(.actor_type):\(.actor_id // "-"):\(.bypass_mode)"] | sort;
  def rules: [.rules[]? | {key: .type, value: (.parameters // {})}] | from_entries;
  ($t[0]) as $t | ($l[0]) as $l
  | [ ( "target", "enforcement" ) as $k
      | select($t[$k] != $l[$k]) | "\($k): \($l[$k]) → \($t[$k])" ]
  + [ ( "include", "exclude" ) as $k
      | select(($t.conditions.ref_name[$k] | norm) != ($l.conditions.ref_name[$k] | norm))
      | "ref \($k): \($l.conditions.ref_name[$k]) → \($t.conditions.ref_name[$k])" ]
  + ( ($t | rules) as $tr | ($l | rules) as $lr
      | [ $tr | keys[] | select($lr[.] == null) | "rule missing: \(.)" ]
      + [ $lr | keys[] | select($tr[.] == null) | "rule extra: \(.)" ]
      + [ $tr | keys[] as $r | select($lr[$r] != null)
          | $tr[$r] | keys[] as $p | select($lr[$r] | has($p))
          | select(($tr[$r][$p] | norm) != ($lr[$r][$p] | norm))
          | "\($r).\($p): \($lr[$r][$p] | tojson) → \($tr[$r][$p] | tojson)" ] )
  + ( ($t | bypass) as $tb | ($l | bypass) as $lb
      | [ $tb[] | select(. as $a | $lb | index($a) | not) | "bypass missing: \(.)" ]
      + [ $lb[] | select(. as $a | $tb | index($a) | not) | "bypass extra: \(.)" ] )
  | .[]'

if [ "$#" -gt 0 ]; then
  REPOS=("$@")
else
  REPOS=()   # while-read, not mapfile: macOS ships bash 3.2
  while IFS= read -r r; do [ -n "$r" ] && REPOS+=("$r"); done < <(
    gh repo list "$ORG" --limit 500 --json name,visibility,isArchived \
      --jq '.[] | select(.visibility == "PUBLIC" and (.isArchived | not)) | .name' | sort)
  [ "${#REPOS[@]}" -gt 0 ] || die "no public repositories found in $ORG (gh auth?)"
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
drift=0; failed=0; aligned=0; changed=0

for repo in "${REPOS[@]}"; do
  if [ "$#" -eq 0 ] && [[ " $EXCEPTIONS " == *" $repo "* ]]; then
    printf '%s- %-20s skipped: %s%s\n' "$C_DIM" "$repo" "$(exception_reason "$repo")" "$C_RST"
    continue
  fi
  if ! gh api "repos/$ORG/$repo/rulesets" > "$TMP/list.json" 2> "$TMP/err"; then
    printf '%s✗ %-20s %s%s\n' "$C_RED" "$repo" "$(head -c 160 "$TMP/err")" "$C_RST"
    failed=$((failed + 1)); continue
  fi

  # Without a Dependabot config, Dependabot never pushes here: its bypass would be
  # a standing exception that grants nothing, so it is not expected.
  drop_dependabot=false
  if ! gh api "repos/$ORG/$repo/contents/.github/dependabot.yml" > /dev/null 2>&1 \
    && ! gh api "repos/$ORG/$repo/contents/.github/dependabot.yaml" > /dev/null 2>&1; then
    drop_dependabot=true
  fi

  issues=(); expected=()
  for t in "${TEMPLATES[@]}"; do
    tpl="$TMP/tpl.json"
    jq --argjson drop "$drop_dependabot" \
      'if $drop then .bypass_actors |= map(select(.actor_id != '"$DEPENDABOT_APP_ID"')) else . end' \
      "$REPO_ROOT/$t" > "$tpl"
    name="$(jq -r .name "$tpl")"; expected+=("$name")
    id="$(jq -r --arg n "$name" 'map(select(.name == $n)) | first | .id // empty' "$TMP/list.json")"
    body="$TMP/body.json"; jq 'del(.id, .source, .source_type)' "$tpl" > "$body"

    if [ -z "$id" ]; then
      if [ "$MODE" = sync ]; then
        if gh api -X POST "repos/$ORG/$repo/rulesets" --input "$body" > "$TMP/err" 2>&1; then
          issues+=("${C_GRN}created '$name'${C_RST}"); changed=$((changed + 1))
        else
          issues+=("${C_RED}create '$name' failed: $(tr -s "\n " " " < "$TMP/err" | head -c 400)${C_RST}"); failed=$((failed + 1))
        fi
      else
        issues+=("'$name' missing"); drift=$((drift + 1))
      fi
      continue
    fi

    gh api "repos/$ORG/$repo/rulesets/$id" > "$TMP/live.json" 2> "$TMP/err" \
      || { issues+=("${C_RED}read '$name' failed${C_RST}"); failed=$((failed + 1)); continue; }
    diffs=()
    while IFS= read -r d; do [ -n "$d" ] && diffs+=("$d"); done < <(
      jq -rn --slurpfile t "$tpl" --slurpfile l "$TMP/live.json" "$JQ_DIFF")
    [ "${#diffs[@]}" -eq 0 ] && continue

    if [ "$MODE" = sync ]; then
      if gh api -X PUT "repos/$ORG/$repo/rulesets/$id" --input "$body" > "$TMP/err" 2>&1; then
        issues+=("${C_GRN}updated '$name'${C_RST} ${C_DIM}($(IFS=';'; echo "${diffs[*]}"))${C_RST}"); changed=$((changed + 1))
      else
        issues+=("${C_RED}update '$name' failed: $(tr -s "\n " " " < "$TMP/err" | head -c 400)${C_RST}"); failed=$((failed + 1))
      fi
    else
      for d in "${diffs[@]}"; do issues+=("'$name' $d"); done
      drift=$((drift + 1))
    fi
  done

  while IFS= read -r extra; do
    [[ " ${expected[*]} " == *" $extra "* ]] && continue
    issues+=("${C_YEL}extra ruleset '$extra' (left alone)${C_RST}")
  done < <(jq -r '.[].name' "$TMP/list.json")

  if [ "${#issues[@]}" -eq 0 ]; then
    printf '%s✓ %-20s aligned%s\n' "$C_GRN" "$repo" "$C_RST"; aligned=$((aligned + 1))
  else
    printf '%s● %-20s%s\n' "$C_CYA" "$repo" "$C_RST"
    for i in "${issues[@]}"; do printf '    %s\n' "$i"; done
  fi
done

printf '──────────────────────────────────────────\n'
printf '%s: %d aligned, %d drifted, %d changed, %d failed\n' "$MODE" "$aligned" "$drift" "$changed" "$failed"
[ "$drift" -eq 0 ] && [ "$failed" -eq 0 ]
