#!/bin/bash

# List of components
COMPONENTS=(
    "cache"
    "config"
    "console"
    "container"
    "contracts"
    "error-handler"
    "event-dispatcher"
    "http"
    "http-client"
    "log"
    "pipeline"
    "routing"
    "runtime"
    "security"
    "skeleton"
    "utils"
    "waffle"
    "workspace"
)

CONTAINER_NAME="waffle-dev"
WORK_DIR_BASE="/waffle-commons"
MODE="docker"
OUTPUT_MODE="SILENT"

# Parse leading flag (--silent/-s or --verbose/-v). Anything after is the command.
if [ "$1" = "--silent" ] || [ "$1" = "-s" ]; then
    OUTPUT_MODE="SILENT"
    shift
elif [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
    OUTPUT_MODE="VERBOSE"
    shift
fi

CMD_ARGS=("$@")

if [ ${#CMD_ARGS[@]} -eq 0 ]; then
    echo "💡 Usage: ./run-all.sh [--silent|-s | --verbose|-v] <command>"
    echo "   Example (Silent, default): ./run-all.sh composer mago"
    echo "   Example (Verbose):         ./run-all.sh --verbose ls -la"
    exit 1
fi

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL=${#COMPONENTS[@]}
INDEX=0
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
FAILED_COMPONENTS=()

for COMP in "${COMPONENTS[@]}"; do
    INDEX=$((INDEX + 1))

    if [ ! -d "$COMP" ]; then
        if [ "$OUTPUT_MODE" = "VERBOSE" ]; then
            echo "⚠️  Directory $COMP not found, skipping."
            echo "---------------------------------------------------"
        else
            printf "[%2d/%2d] %-20s ⏭️  ${YELLOW}SKIP${NC} (directory not found)\n" "$INDEX" "$TOTAL" "$COMP"
        fi
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    if [ "$OUTPUT_MODE" = "VERBOSE" ]; then
        echo "🚀 [$COMP] Running command..."
        (cd "$COMP" && "${CMD_ARGS[@]}")
        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
            echo "💥 Command failed in $COMP with exit code $EXIT_CODE"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_COMPONENTS+=("$COMP")
        else
            echo "✅ [$COMP] Done."
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
        echo "---------------------------------------------------"
    else
        # SILENT mode: per-component progress, command output suppressed
        printf "[%2d/%2d] %-20s ⏳ ${BLUE}running...${NC}" "$INDEX" "$TOTAL" "$COMP"
        (cd "$COMP" && "${CMD_ARGS[@]}") > /dev/null 2>&1
        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
            printf "\r[%2d/%2d] %-20s ❌ ${RED}FAIL${NC} (exit %d)   \n" "$INDEX" "$TOTAL" "$COMP" "$EXIT_CODE"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_COMPONENTS+=("$COMP")
        else
            printf "\r[%2d/%2d] %-20s ✅ ${GREEN}OK${NC}              \n" "$INDEX" "$TOTAL" "$COMP"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    fi
done

# Final state
if [ "$OUTPUT_MODE" = "SILENT" ]; then
    echo ""
    echo "==================================================="
    printf "📊 Summary: ${GREEN}✅ %d ok${NC} / ${RED}❌ %d failed${NC} / ${YELLOW}⏭️  %d skipped${NC} (total %d)\n" \
        "$SUCCESS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$TOTAL"
    echo "==================================================="
    if [ $FAIL_COUNT -gt 0 ]; then
        printf "💥 Final state: ${BOLD}${RED}FAIL${NC}\n"
        printf "   Failed components: %s\n" "${FAILED_COMPONENTS[*]}"
        exit 1
    else
        printf "🎉 Final state: ${BOLD}${GREEN}SUCCESS${NC}\n"
        exit 0
    fi
fi

if [ $FAIL_COUNT -gt 0 ]; then
    echo "💥 Done with failures."
    exit 1
fi
echo "🎉 Done."
exit 0
