#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd  
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")

# Check dependencies
deps=(
    kubectl
    helm
    helmfile
    jq
    yq
    gcsplit
)
for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        echo "Error: $dep command not found. Please install '$dep' first. Exiting..."
        exit 1
    fi
done

# Check setup was run
if [ ! -d "${CURRENT}/_values" ]; then
    echo "Error: _values directory not found. Please run setup.sh first. Exiting..."
    exit 1
fi

RENDERED_DIR="${CURRENT}/_rendered"

# Clean up previous rendered files
rm -rf "${RENDERED_DIR}"

# Export environment variables for hooks
export FORCE_NO_HOOKS="${FORCE_NO_HOOKS:-false}"
export HELMFILE_OFFLINE="true"

# Set up offline mode flags for rendering (always skip hooks and cluster ops)
HELMFILE_FLAGS="--skip-deps --skip-tests --skip-needs --no-hooks"
if [[ "${HELMFILE_OFFLINE:-false}" == "true" ]]; then
    echo "Running in offline mode..."
fi

# Render specific chart if provided
if [[ -n "${1}" ]]; then
    echo "Rendering specific chart: ${1}"
    helmfile -l "name=${1}" template ${HELMFILE_FLAGS} --output-dir="${RENDERED_DIR}"
else
    echo "Rendering all charts with helmfile..."
    helmfile template ${HELMFILE_FLAGS} --output-dir="${RENDERED_DIR}"
fi

# Split any multi-document YAML files into individual files
echo "Splitting multi-document files..."
find "${RENDERED_DIR}" -type f \( -name "*.yml" -o -name "*.yaml" \) | while read -r manifest_path; do
    # Get relative path and chart name
    relative_path="${manifest_path#${RENDERED_DIR}/}"
    manifest_chart="${relative_path%%/*}"
    manifest_file=$(basename "$manifest_path")
    # Check if file has multiple documents using yq + jq
    doc_count=$(yq eval 'select(tag != "!!null")' -o=json "$manifest_path" | jq -s 'length')
    # If more than one document, split the file
    if [ "$doc_count" -gt 1 ]; then
        # Remove file extension to get split path
        if [[ "$manifest_file" == *.yml ]]; then
            split_path="${manifest_path%.yml}"
        else
            split_path="${manifest_path%.yaml}"
        fi
        echo "Splitting $split_path"
        # Create directory for split files
        mkdir -p "$split_path"
        # Split using yq with proper naming - two-step process to avoid empty files
        cd "$split_path" || exit 1
        # First, split all documents into numbered files
        yq eval-all --split-exp '"doc-" + (document_index | tostring) + ".yaml"' "$manifest_path"
        # Then rename files based on metadata.name if it exists
        for doc_file in doc-*.yaml; do
            if [[ -f "$doc_file" ]]; then
                # Get metadata.name from the document
                name=$(yq eval '.metadata.name // ""' "$doc_file")
                if [[ -n "$name" && "$name" != "null" ]]; then
                    # Rename to use the actual name
                    mv "$doc_file" "${name}.yaml"
                fi
            fi
        done
        # Clean up any empty files
        find . -name "*.yaml" -size 0 -delete 2>/dev/null
        # Remove original file
        rm "$manifest_path"
        cd - > /dev/null || exit 1
    fi
done
