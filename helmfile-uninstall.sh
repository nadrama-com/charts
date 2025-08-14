#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
# Helmfile-based replacement for uninstall.sh

set -eo pipefail

# Check dependencies
deps=(
    kubectl
    helm
    helmfile
)
for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        echo "Error: $dep command not found. Please install '$dep' first. Exiting..."
        exit 1
    fi
done

# Uninstall specific chart if provided
if [[ -n "${1}" ]]; then
    echo "Uninstalling specific chart: ${1}"
    helmfile -l "name=${1}" destroy
else
    echo "Uninstalling all charts with helmfile..."
    helmfile destroy
fi
