
#!/usr/bin/env bash
set -euo pipefail

echo "Waiting for PostgreSQL credentials..."

kubectl wait \
  --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True \
  externalsecret/postgres-credentials \
  --namespace default \
  --timeout=300s

echo "Checking Kubernetes Secret..."

kubectl get secret postgres-credentials \
  --namespace default \
  > /dev/null

echo "PostgreSQL credentials are available!"
