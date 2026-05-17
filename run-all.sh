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

CONTAINER_NAME="waffle-dev"
WORK_DIR_BASE="/waffle-commons"
MODE="docker"

# Parse arguments
CMD_ARGS=()
for arg in "$@"; do
    CMD_ARGS+=("$arg")
done

if [ ${#CMD_ARGS[@]} -eq 0 ]; then
    echo "Usage: ./run-all.sh <command>"
    echo "Example (Local):  ./run-all.sh ls -la"
    exit 1
fi

# Loop through components
for COMP in "${COMPONENTS[@]}"; do
    if [ ! -d "$COMP" ]; then
        echo "Warning: Directory $COMP not found, skipping."
        continue
    fi

    echo ">>> [$COMP] Running command..."
    
    (cd "$COMP" && "${CMD_ARGS[@]}")
    
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo "!!! Command failed in $COMP with exit code $EXIT_CODE"
    fi
    echo "---------------------------------------------------"
done

echo "Done."
