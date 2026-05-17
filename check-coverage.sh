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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

printf "${BLUE}%-20s %-15s %-20s${NC}\n" "Component" "Coverage"
printf "%-20s %-15s %-20s\n" "-------------------" "---------------"

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

        printf "%-20s %-20s\n" "$COMP" "$PERCENT%"
    else
        printf "%-20s %-15s %-20s\n" "$COMP" "N/A" "No Report Found"
    fi
done
