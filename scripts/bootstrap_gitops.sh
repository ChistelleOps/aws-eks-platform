
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

echo "Reading VPC ID from Terraform..."
VPC_ID="$(terraform -chdir=env/dev output -raw vpc_id)"

if [[ ! "$VPC_ID" =~ ^vpc-[0-9a-f]+$ ]]; then
  echo "ERROR: Invalid VPC ID: $VPC_ID" >&2
  exit 1
fi

echo "Generating AWS Load Balancer Controller Application..."

sed "s/\${VPC_ID}/${VPC_ID}/g" \
  gitops/bootstrap/aws-load-balancer-controller.yaml.tpl \
  > /tmp/aws-load-balancer-controller-app.yaml

echo "Applying controller Application..."
kubectl apply -f /tmp/aws-load-balancer-controller-app.yaml

echo "Registering the parent Argo CD Application..."
kubectl apply -f gitops/argocd/root-app.yaml

echo "GitOps bootstrap completed!"
echo "Next: wait for the ExternalSecret and verify PostgreSQL credentials."
