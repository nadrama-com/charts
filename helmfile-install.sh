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

# Ensure any patched webhooks are restored to fail-closed state on error/cancellation
cleanup_webhooks() {
    echo "Restoring temporarily-patched webhooks (since FORCE_NO_HOOKS=true)..."
    # Restore cert-manager webhooks
    kubectl patch mutatingwebhookconfiguration/system-cert-manager-webhook --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/failurePolicy', 'value': 'Fail'}]" &> /dev/null || true
    kubectl patch validatingwebhookconfiguration/system-cert-manager-webhook --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/failurePolicy', 'value': 'Fail'}]" &> /dev/null || true
    kubectl patch validatingwebhookconfiguration/system-cert-manager-approver-policy --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/failurePolicy', 'value': 'Fail'}]" &> /dev/null || true
    # Restore trust-manager webhooks
    kubectl patch validatingwebhookconfiguration/system-trust-manager --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/failurePolicy', 'value': 'Fail'}]" &> /dev/null || true
    echo "Webhooks restored successfully."
}
if [[ "$FORCE_NO_HOOKS" == "true" ]]; then
    trap cleanup_webhooks EXIT
fi

# Export environment variables for hooks
export FORCE_NO_HOOKS="${FORCE_NO_HOOKS:-false}"

# Apply webhook patches before installation if needed
patch_webhooks_ignore

# Install specific chart if provided
if [[ -n "${1}" ]]; then
    echo "Installing specific chart: ${1}"
    helmfile -l "name=${1}" sync
else
    echo "Installing all charts with helmfile..."
    helmfile sync
fi
