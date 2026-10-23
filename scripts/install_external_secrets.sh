
#!/usr/bin/env bash
set -euo pipefail

# Move to the project root
cd "$(dirname "$0")/.."

ESO_CHART_VERSION="2.14.0"

echo "Adding External Secrets Helm repository..."

helm repo add external-secrets \
  https://charts.external-secrets.io \
  --force-update

helm repo update

echo "Installing External Secrets Operator..."

helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --version "$ESO_CHART_VERSION" \
  --values gitops/external-secrets/install/values.yaml \
  --wait \
  --timeout 10m

echo "External Secrets Operator installation completed!"
