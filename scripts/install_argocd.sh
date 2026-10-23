
#!/usr/bin/env bash
set -euo pipefail

# Replace this with the exact chart version you downloaded.
ARGOCD_CHART_VERSION="10.11.1"

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version "$ARGOCD_CHART_VERSION" \
  --values gitops/argocd/install/values.yaml \
  --wait \
  --timeout 10m
