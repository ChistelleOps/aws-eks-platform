
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Checking Kubernetes connection..."
kubectl cluster-info

echo "Current Kubernetes context:"
kubectl config current-context

echo "Checking Argo CD installation..."
kubectl wait \
  --for=condition=Available \
  deployment/argocd-server \
  --namespace argocd \
  --timeout=300s

echo "Checking External Secrets Operator..."
kubectl wait \
  --for=condition=Available \
  deployment/external-secrets \
  --namespace external-secrets \
  --timeout=300s

echo "Registering the parent Argo CD Application..."
kubectl apply -f gitops/argocd/root-app.yaml

echo "GitOps bootstrap completed!"
echo "Next: wait for the ExternalSecret and verify PostgreSQL credentials."
