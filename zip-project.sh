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
    "skeleton"
    "utils"
    "waffle"
    "workspace"
)

ZIP_NAME="build/framework-audit-$(date +"%Y%m%d%H%M%S").zip"
ROOT_DIR=$(pwd)

# Remove existing zip if it exists
if [ -f "$ZIP_NAME" ]; then
    rm "$ZIP_NAME"
fi

echo "Creating $ZIP_NAME..."

# Loop through components
for COMP in "${COMPONENTS[@]}"; do
    if [ ! -d "$COMP" ]; then
        echo "Warning: Directory $COMP not found, skipping."
        continue
    fi

    echo "Processing component: $COMP..."

    # Build list of files to include for this component
    # We want to include them with the component prefix (e.g. waffle/src)
    # So we pass the relative path from ROOT_DIR
    FILES_TO_ZIP=""

    if [ -d "$COMP/src" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/src"
    fi

    if [ -d "$COMP/tests" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/tests"
    fi

    if [ -d "$COMP/app" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/app"
    fi

    if [ -d "$COMP/config" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/config"
    fi

    if [ -d "$COMP/docker" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/docker"
    fi

    if [ -d "$COMP/docs" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/docs"
    fi

    if [ -f "$COMP/composer.json" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/composer.json"
    fi

    if [ -f "$COMP/docker-compose.yml" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/docker-compose.yml"
    fi

    if [ -f "$COMP/README.md" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/README.md"
    fi

    if [ -f "$COMP/CHANGELOG.md" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $COMP/CHANGELOG.md"
    fi

    # Check for mago toml files
    for f in "$COMP"/mago*.toml; do
        if [ -e "$f" ]; then
            FILES_TO_ZIP="$FILES_TO_ZIP $f"
        fi
    done

    if [ -n "$FILES_TO_ZIP" ]; then
        # Zip appends by default.
        # We run zip from ROOT_DIR so paths like 'waffle/src' are preserved.
        zip -r -q "$ZIP_NAME" $FILES_TO_ZIP
    else
        echo "No relevant files found in $COMP."
    fi
done

echo "Successfully created $ZIP_NAME at $ROOT_DIR/build/"
