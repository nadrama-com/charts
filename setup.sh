#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")

if [ -z "${1}" ]; then
    echo "Usage: $0 <ingress-hostname>"
    exit 1
fi
INGRESS_HOSTNAME="${1}"

if [ -d "${CURRENT}/_values" ]; then
    echo "${CURRENT}/_values directory already exists. Please remove it before running this script."
    exit 1
fi

INGRESS_PORT=""
if [[ "${INGRESS_HOSTNAME}" = "local.env.cool" ]]; then
    # Nadrama dev-specific override
    INGRESS_PORT=":4433"
fi

# Create _values directory
mkdir -p "${CURRENT}/_values"

# Default value for all CSI drivers apps
CSI_ALL="false"
if [[ "${CSI_ALL}" == "true" ]] || [[ "${CSI_ALL}" == 1 ]]; then
    CSI_ALL="true"
fi

# Create values files

cat > "${CURRENT}/_values/apps.yaml" <<EOF
apps:
  system:
    # CRDs
    cilium-crds:
      enabled: true
    snapshot-crds:
      enabled: true
    cert-manager-crds:
      enabled: true
    trust-manager-crds:
      enabled: true
    gateway-api-crds:
      enabled: true
    traefik-crds:
      enabled: true
    argocd-crds:
      enabled: true
    sealed-secrets-crds:
      enabled: true
    # Apps
    namespaces:
      enabled: true
    rbac:
      enabled: true
    cilium:
      enabled: true
    coredns:
      enabled: true
    snapshot:
      enabled: true
    csi-aws-ebs:
      enabled: ${CSI_ALL}
    cert-manager:
      enabled: true
    trust-manager:
      enabled: true
    traefik:
      enabled: true
    trust-bundles:
      enabled: true
    sealed-secrets:
      enabled: true
    argocd:
      enabled: true
    apps:
      enabled: true
EOF

cat > "${CURRENT}/_values/argocd.yaml" <<EOF
argo-cd:
  global:
    domain: argocd.${INGRESS_HOSTNAME}${INGRESS_PORT}
EOF

cat > "${CURRENT}/_values/csi-aws-ebs.yaml" <<EOF
aws-ebs-csi-driver:
  controller:
    podAnnotations:
      iam.amazonaws.com/role: arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/nadrama-YOUR_CLUSTER_SLUG-ebs-csi
EOF

cat > "${CURRENT}/_values/nadrama-hello.yaml" <<EOF
nadrama:
  ingress:
    hostname: ${INGRESS_HOSTNAME}
    letsencrypt: false
EOF

# Create empty values files for charts that don't need configuration
for chart in namespaces rbac cilium coredns snapshot cert-manager trust-manager traefik trust-bundles sealed-secrets apps; do
  touch "${CURRENT}/_values/${chart}.yaml"
done

echo "Setup complete. Created _values directory with individual chart values files."
