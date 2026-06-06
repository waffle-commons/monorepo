#!/bin/bash

# List of components
COMPONENTS=(
    "auth"
    "cache"
    "config"
    "console"
    "container"
    "contracts"
    "data"
    "error-handler"
    "event-dispatcher"
    "http"
    "http-client"
    "log"
    "pipeline"
    "routing"
    "runtime"
    "security"
    "utils"
    "waffle"
)

THRESHOLD=95

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

TOTAL=${#COMPONENTS[@]}
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
MISSING_COUNT=0
BELOW_THRESHOLD=()

echo "==================================================="
printf "📊 ${BOLD}Code Coverage Report${NC} (threshold: ${BOLD}%d%%${NC})\n" "$THRESHOLD"
echo "==================================================="
printf "  %-4s %-20s %s\n" "" "Component" "Coverage"
echo "---------------------------------------------------"

for COMP in "${COMPONENTS[@]}"; do
    REPORT_FILE="$COMP/var/data/phpunit-coverage/index.html"

    if [ ! -d "$COMP" ]; then
        continue
    fi

    if [ -f "$REPORT_FILE" ]; then
        # Extract percentage using grep
        # Matches aria-valuenow="95.22" and extracts 95.22
        PERCENT=$(grep -o 'aria-valuenow="[^"]*"' "$REPORT_FILE" | head -n 1 | cut -d'"' -f2)

        if [ -z "$PERCENT" ]; then
             PERCENT="0.00"
        fi

        # Pick emoji + color based on coverage tier
        if awk -v p="$PERCENT" 'BEGIN { exit !(p >= 100) }'; then
            ICON="🏆"
            COLOR="${GREEN}"
            NOTE=""
            PASS_COUNT=$((PASS_COUNT + 1))
        elif awk -v p="$PERCENT" -v t="$THRESHOLD" 'BEGIN { exit !(p >= t) }'; then
            ICON="✅"
            COLOR="${GREEN}"
            NOTE=""
            PASS_COUNT=$((PASS_COUNT + 1))
        elif awk -v p="$PERCENT" -v t="$THRESHOLD" 'BEGIN { exit !(p >= t - 10) }'; then
            ICON="⚠️ "
            COLOR="${YELLOW}"
            NOTE="(below threshold)"
            WARN_COUNT=$((WARN_COUNT + 1))
            BELOW_THRESHOLD+=("$COMP ($PERCENT%)")
        else
            ICON="❌"
            COLOR="${RED}"
            NOTE="(critical)"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            BELOW_THRESHOLD+=("$COMP ($PERCENT%)")
        fi

        printf "  %s  %-20s ${COLOR}%6s%%${NC}  %s\n" "$ICON" "$COMP" "$PERCENT" "$NOTE"
    else
        printf "  %s  %-20s ${YELLOW}%-7s${NC}  %s\n" "❓" "$COMP" "N/A" "(no report found)"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

echo "==================================================="
printf "📊 Summary: ${GREEN}✅ %d ok${NC} / ${YELLOW}⚠️  %d warn${NC} / ${RED}❌ %d critical${NC} / ${YELLOW}❓ %d missing${NC} (total %d)\n" \
    "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "$MISSING_COUNT" "$TOTAL"
echo "==================================================="

if [ $WARN_COUNT -gt 0 ] || [ $FAIL_COUNT -gt 0 ]; then
    printf "💥 Final state: ${BOLD}${RED}FAIL${NC} (threshold ${BOLD}%d%%${NC} not met)\n" "$THRESHOLD"
    printf "   Below threshold: %s\n" "${BELOW_THRESHOLD[*]}"
elif [ $MISSING_COUNT -gt 0 ]; then
    printf "⚠️  Final state: ${BOLD}${YELLOW}INCOMPLETE${NC} (some components have no coverage report)\n"
else
    printf "🎉 Final state: ${BOLD}${GREEN}SUCCESS${NC} (all components ≥ ${BOLD}%d%%${NC})\n" "$THRESHOLD"
fi
