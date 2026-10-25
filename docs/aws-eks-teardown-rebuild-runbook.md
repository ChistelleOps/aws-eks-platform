# AWS EKS Platform Lab

*Teardown & Rebuild Runbook  |  October 2026*

Repository: github.com/ChistelleOps/aws-eks-platform  •  Cluster: platform-dev-eks  •  Region: us-east-1

Purpose: remove billable lab resources when not in use, then restore the working EKS → Argo CD → External Secrets → PostgreSQL → FastAPI + Portfolio environment. Commands must be run locally; this document does not execute them.

## 1. Before teardown — decide what to retain

- Terraform destroy is not a pause. It deletes infrastructure and will cause downtime.
- Keep GitHub source code and the separately bootstrapped S3 Terraform state backend; never destroy the backend while it is in use.
- PostgreSQL data: gp3 StorageClass uses Retain. A retained EBS volume can still incur charges. Delete only if you do NOT need its data.
- Secrets Manager: Terraform destroy may schedule the PostgreSQL secret for deletion. Restoring a secret later may require importing it into Terraform state, as happened during this rebuild.
- Confirm AWS account and region before proceeding.
```bash
cd ~/src/aws-eks-platform/env/dev
aws sts get-caller-identity
aws configure get region
terraform state list
kubectl get pvc,pv -A
```

### Optional: record the database EBS volume ID

If you might want the data later, record the PV and EBS volume ID before destroying. Do not delete the volume.

```bash
kubectl get pvc dev-postgres-data -n default -o wide
kubectl get pv
kubectl get pv "$(kubectl get pvc dev-postgres-data -n default -o jsonpath='{.spec.volumeName}')" -o yaml
```

## 2. Tear down the lab

Review the planned deletion before approving. Terraform will prompt for confirmation.

```bash
cd ~/src/aws-eks-platform/env/dev
terraform init
terraform plan -destroy
terraform destroy
```

If the plan includes the S3 state backend or anything you intend to keep, STOP and review before confirming.

### Check for residual billable resources

```bash
terraform state list
aws eks list-clusters --region us-east-1
aws ec2 describe-instances --region us-east-1 --filters Name=instance-state-name,Values=pending,running,stopping,stopped --query "Reservations[].Instances[].[InstanceId,State.Name]" --output table
aws ec2 describe-volumes --region us-east-1 --query "Volumes[].[VolumeId,State,Size,Tags]" --output table
aws ec2 describe-nat-gateways --region us-east-1 --filter Name=state,Values=available,pending,deleting --query "NatGateways[].[NatGatewayId,State]" --output table
```

Review remaining EBS volumes, NAT gateways, load balancers, EIPs, Secrets Manager secrets, CloudWatch logs and other resources in AWS. These checks are not exhaustive; review AWS Billing/Cost Explorer as well. Do not delete unrelated resources.

### Only if PostgreSQL data can be discarded

A retained EBS volume can be manually deleted after verifying it belongs to this lab and is detached. This is irreversible.

```bash
aws ec2 describe-volumes --region us-east-1 --volume-ids <VERIFIED_VOLUME_ID>
# ONLY after confirming data is expendable and volume is available:
aws ec2 delete-volume --region us-east-1 --volume-id <VERIFIED_VOLUME_ID>
```

## 3. Rebuild — Terraform infrastructure

On the next lab session, use the existing code; do not recreate the Terraform modules.

```bash
cd ~/src/aws-eks-platform/env/dev
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### Known recovery: secret already scheduled for deletion

If apply fails because platform/dev/postgres is scheduled for deletion, restore it and import the existing ARN into Terraform state. Do not create a duplicate or expose secret values.

```bash
aws secretsmanager restore-secret --secret-id platform/dev/postgres --region us-east-1
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id platform/dev/postgres --region us-east-1 --query ARN --output text)
terraform import aws_secretsmanager_secret.postgres "$SECRET_ARN"
terraform plan
terraform apply
```

Run this recovery only if the secret exists and is scheduled for deletion; if the state already tracks it, do not import again. Verify the Terraform resource address matches the current code.

## 4. Configure kubectl and verify EKS

```bash
aws eks describe-cluster --name platform-dev-eks --region us-east-1 --query cluster.status --output text
aws eks update-kubeconfig --region us-east-1 --name platform-dev-eks --role-arn arn:aws:iam::452395238296:role/eks-platform-admin
kubectl get nodes -o wide
```

Expected: EKS ACTIVE and two nodes Ready (assuming the node group remains configured for two).

## 5. Restore Argo CD and External Secrets

Run existing repository scripts from the repository root, in this order.

```bash
cd ~/src/aws-eks-platform
bash scripts/install_argocd.sh
kubectl get pods -n argocd
bash scripts/install_external_secrets.sh
kubectl get pods -n external-secrets
```

Expected: six Argo CD pods and three External Secrets pods Running/Ready in the previous configuration. Check actual chart versions if the counts change.

## 6. Bootstrap GitOps and PostgreSQL

```bash
bash scripts/bootstrap_gitops.sh
kubectl get applications -n argocd
kubectl get storageclass
kubectl get clustersecretstore
kubectl get externalsecret -n default
```

The PostgreSQL child Application may initially show OutOfSync / Missing because it requires manual sync. Check conditions and events before syncing.

```bash
kubectl describe application postgres -n argocd
# If no blocking errors, request a sync:
kubectl patch application postgres -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
kubectl get applications -n argocd
kubectl get pods,pvc -n default
```

Expected: postgres Synced/Healthy; dev-postgres pod Running (1/1); dev-postgres-data PVC Bound to 20Gi gp3 EBS storage.

### If the parent Application is OutOfSync

First refresh and inspect, rather than changing working resources. In the last successful session, the parent became Synced after removing an unnecessary directory.recurse: false from the external-secrets-config child YAML and refreshing.

```bash
kubectl annotate application platform-apps -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl get application platform-apps -n argocd -o jsonpath='{range .status.resources[*]}{.kind}{" "}{.name}{" "}{.status}{"\n"}{end}'
kubectl get application platform-apps -n argocd -o jsonpath='{.status.sync.status}{" / "}{.status.health.status}{"\n"}'
```

## 7. Validate FastAPI and Portfolio

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get pods -n argocd
kubectl get pods -n external-secrets
kubectl get pods,pvc -n default
```

Last verified state (October 2026): all six Argo CD Applications Synced/Healthy, PostgreSQL pod Running 1/1, 20Gi gp3 PVC Bound, and both FastAPI and portfolio tested successfully.

The parent `platform-apps` discovers `platform-api` and `portfolio` child Applications from GitHub. If either is missing, confirm the chart and Application files were committed and pushed to `main`, then refresh the parent Application.

```bash
kubectl get applications -n argocd
kubectl get pods -l app=platform-api
kubectl get svc platform-api
kubectl get pods -l app=portfolio
kubectl get svc portfolio

# In one terminal, test FastAPI:
kubectl port-forward svc/platform-api 8000:8000
# In another terminal:
curl http://localhost:8000/
curl http://localhost:8000/health

# Stop the FastAPI port-forward with Ctrl+C. Then test portfolio:
kubectl port-forward svc/portfolio 8081:80
# Open http://localhost:8081 in a browser.
```

Port 8081 is used locally because Argo CD may already use 8080. Stop port-forward processes with Ctrl+C before teardown.

## 8. Final health checks and next milestone

After validating both apps, the next milestone is AWS Load Balancer Controller, Ingress, ACM HTTPS, and Route 53 routing. These are not yet implemented.

## Quick checklist

- Before destroy: confirm account, state backend and whether PostgreSQL data should survive.
- Destroy: terraform plan -destroy, then terraform destroy.
- After destroy: inspect EBS, NAT, EC2, EKS and Billing for leftovers.
- Rebuild: terraform init → validate → plan → apply.
- Cluster: update kubeconfig → verify nodes Ready.
- Services: install Argo CD → External Secrets → bootstrap GitOps.
- Database: manually sync PostgreSQL if required → verify pod and PVC.
- Applications: verify FastAPI and portfolio are Synced/Healthy → port-forward and test both.
- At end of next lab: repeat teardown to avoid overnight costs.
