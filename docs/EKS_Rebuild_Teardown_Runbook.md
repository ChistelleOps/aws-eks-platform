# AWS EKS Platform — Start-to-Finish Rebuild and Teardown Runbook

**Checkpoint:** October 27, 2026  
**Repository:** `ChistelleOps/aws-eks-platform`  
**Working directory:** repository root (`aws-eks-platform`)  
**AWS region:** `us-east-1`  
**EKS cluster:** `platform-dev-eks`  
**Domain:** `christelconsult.com` (registered with IONOS)  
**Expected finish line:** `https://api.christelconsult.com` and `https://www.christelconsult.com` work in a browser.

> **How to use:** Complete tasks **in order**. Each task has a reason, commands with nearby comments, and a **Done when** checkpoint. Commands with placeholders must be adapted to the repository and current AWS resources. Never reuse old ALB IDs, EBS IDs, certificate ARNs, or nameservers.
>
> **What is verified from our first build:** `env/dev`, `env/dns`, the cluster name, app names, two Ingresses, shared ALB, PostgreSQL PVC `dev-postgres-data`, Argo CD, Helm, GitHub Actions, ECR, S3 backend. **Exact paths to Argo CD manifests/Helm release commands and Terraform outputs were not captured in the closure notes**

---

# PART A — REBUILD: START HERE → FINISH IN THE BROWSER

## Task 0 — Open the project and control costs

**Why:** Confirm the AWS account and region before creating anything. EKS, EC2, NAT Gateway, ALB, and GPUs can cost money while running.

```bash
# Go to the project directory; adjust path to your local checkout.
cd ~/src/aws-eks-platform

# Check your branch and local changes before editing infrastructure.
git status

# Confirm which AWS account your CLI will modify.
aws sts get-caller-identity

# Confirm the region for this project.
aws configure get region

# Confirm Terraform is installed.
terraform version

# Confirm Kubernetes and Helm CLIs are available.
kubectl version --client
helm version --short
```

**Manual action:** Set or verify an AWS Budget alert in the Billing console. Decide how long the lab will run and whether GPU nodes are needed (not for the initial rebuild).

**Done when:** Correct AWS account, `us-east-1`, clean/understood Git working tree, and a budget alert.

## Task 1 — Verify the reusable Terraform state backend

**Why now:** Terraform must have its remote state available **before** creating the new platform. The `bootstrap/` resources were intentionally preserved.

```bash
# Inspect the bootstrap configuration; do not destroy or reapply it by default.
ls bootstrap

# Check the backend configuration used by the development stack.
grep -R -n 'backend "s3"' env/dev env/dns

# Initialize the dev stack against its existing backend.
terraform -chdir=env/dev init

# List current dev-managed resources; after successful teardown this should be empty.
terraform -chdir=env/dev state list
```

**Done when:** Backend initializes successfully, and you understand what the state currently manages. Do **not** delete the backend S3 bucket.

## Task 2 — Provision networking, EKS, IAM, and add-ons

**Why now:** Everything else depends on the VPC, cluster, worker nodes, and permissions.

```bash
# Check the Terraform configuration for syntax and provider issues.
terraform -chdir=env/dev validate

# Create a reviewable plan; nothing is provisioned yet.
terraform -chdir=env/dev plan -out=tfplan

# Apply exactly the reviewed plan to create the AWS platform.
terraform -chdir=env/dev apply tfplan

# Show available Terraform outputs such as cluster details or IAM role ARNs.
terraform -chdir=env/dev output
```

**Check:** VPC with public/private subnets, routes, NAT, EKS cluster, node group, EBS CSI and other configured add-ons, IAM access, and Secrets Manager resources. Check the plan rather than assuming each item is present.

**Done when:** Terraform apply succeeds, EKS is `ACTIVE`, and the node group is healthy.

## Task 3 — Connect kubectl to EKS

**Why now:** The cluster exists, but local `kubectl` needs credentials and an endpoint.

```bash
# Add the EKS cluster context to your local kubeconfig.
aws eks update-kubeconfig --region us-east-1 --name platform-dev-eks

# Confirm the API server can be reached and nodes are Ready.
kubectl get nodes -o wide

# Review system pods and installed controllers.
kubectl get pods -A
```

**Done when:** Nodes are `Ready`, and critical system pods are healthy.

## Task 4 — Restore platform prerequisites (storage, secrets, controllers)

**Why now:** Apps depend on storage, secrets, and ingress controllers. Do this before application deployment.

```bash
# Verify the EBS CSI driver add-on exists for dynamic EBS provisioning.
aws eks describe-addon --cluster-name platform-dev-eks \
  --addon-name aws-ebs-csi-driver --region us-east-1

# List storage classes; verify the intended gp3 StorageClass exists.
kubectl get storageclass

# Inspect namespaces already present before applying platform manifests.
kubectl get namespaces

# Locate the actual repo manifests and Helm charts; don't invent paths.
find . -maxdepth 5 \( -iname '*argocd*' -o -iname '*load-balancer*' \
  -o -iname '*external-secret*' -o -iname '*storage*' \) -print
```

**Action:** Install/reconcile **Argo CD**, **AWS Load Balancer Controller**, the StorageClass, and External Secrets using the **existing repository files**. Check controller IAM/Pod Identity and Secrets Manager secret values. If the secret was deleted during teardown, recreate its value securely; do not commit credentials.

```bash
# Verify Argo CD is running after installation.
kubectl get pods -n argocd

# Find the AWS Load Balancer Controller deployment and verify readiness.
kubectl get deployments -A | grep -i load-balancer

# Inspect secret synchronization without printing secret values.
kubectl get externalsecrets -A
```

**Done when:** Argo CD and load-balancer controller are healthy; storage and secret dependencies are ready.

## Task 5 — Deploy PostgreSQL, FastAPI, portfolio, and monitoring

**Why now:** Applications and their Services must be healthy before public traffic is routed to them.

**Action:** Apply the repository's Argo CD parent `platform-apps` Application or child Applications in dependency order. On the first rebuild, check what will sync before enabling automated sync. Known applications: `postgres`, `platform-api`, `portfolio`, `storage`, `external-secrets-config`, `monitoring`, and `monitoring-dashboards`. AWS Load Balancer Controller was managed separately in the first build.

```bash
# Locate Argo CD Application manifests in the repository.
grep -R -n 'kind: Application' . --include='*.yaml' --include='*.yml'

# After applying the correct repo manifests, review GitOps sync and health.
kubectl get applications -n argocd

# Check application workloads and Services in the default namespace.
kubectl get deployments,pods,services -n default

# Verify PostgreSQL's claim is Bound; inspect storage if it is Pending.
kubectl get pvc -n default

# Inspect application logs if a deployment is not Ready.
kubectl logs deployment/platform-api -n default --tail=50
```

**Done when:** PostgreSQL, FastAPI, and portfolio pods are healthy, and FastAPI can connect to PostgreSQL. Monitoring can be brought up after the core apps.

## Task 6 — Create the shared ALB using Kubernetes Ingress

**Why now:** `env/dns/main.tf` contains `data.aws_lb.platform_public`. **DNS Terraform cannot look up an ALB that does not exist.**

```bash
# Confirm both Ingress resources exist and have correct hosts.
kubectl get ingress platform-api portfolio -n default -o wide

# Look for controller events if an Ingress has no address.
kubectl describe ingress platform-api -n default

# Confirm AWS has created the shared ALB; identify it by tags/Ingress ownership.
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[*].[LoadBalancerName,DNSName,State.Code]' \
  --output table
```

**Important HTTPS dependency:** An ALB **HTTP** listener can be established before ACM issuance. If the Ingress configuration requires an ACM certificate ARN for HTTPS at creation time, first use an HTTP-only/bootstrap configuration or split DNS/certificate provisioning into phases. After ACM is issued, attach the certificate to the HTTPS listener via the Ingress configuration/controller. Do not assume HTTPS is already ready.

**Done when:** The intended shared ALB exists, and target groups point to healthy app Services/pods.

## Task 7 — Rebuild Route 53 DNS and ACM certificate

**Why now:** The ALB exists, so the `data.aws_lb.platform_public` lookup can succeed. The Route 53 zone and ACM cert were destroyed in the previous teardown.

```bash
# Initialize the separate DNS Terraform stack.
terraform -chdir=env/dns init

# Check the DNS stack configuration.
terraform -chdir=env/dns validate

# Inspect the DNS plan; confirm it references the new ALB, not the old one.
terraform -chdir=env/dns plan -out=tfplan

# Apply the reviewed DNS plan to create the hosted zone, records, and certificate.
terraform -chdir=env/dns apply tfplan
```

**Possible pause:** ACM validation may wait for DNS delegation. If the apply is waiting, **do not keep waiting indefinitely**. Obtain the new Route 53 hosted zone nameservers (AWS Console → Route 53 → Hosted zones → `christelconsult.com`), update IONOS, then allow validation to complete or rerun the apply.

```bash
# Show the nameservers currently advertised publicly for the domain.
dig NS christelconsult.com +short

# Check whether the app subdomains resolve publicly.
dig api.christelconsult.com +short
dig www.christelconsult.com +short

# List ACM certificates in the same region as the ALB.
aws acm list-certificates --region us-east-1
```

**Manual action:** At IONOS, set the domain's authoritative nameservers to the **four new Route 53 hosted zone nameservers**. Old nameservers from the prior build may no longer work.

**Done when:** The public NS records match the new Route 53 zone, ACM certificate is `ISSUED`, and `api`/`www` records point to the new ALB.

## Task 8 — Enable and verify HTTPS

**Why now:** A DNS record alone does not provide TLS. The ALB must have an HTTPS listener with the **new** ACM certificate.

```bash
# List ALBs to identify the current ALB ARN.
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn]' \
  --output table

# Review Kubernetes Ingress configuration, including TLS/ACM annotations.
kubectl describe ingress platform-api -n default
kubectl describe ingress portfolio -n default

# Test the API HTTPS endpoint (HTTP headers and TLS validation).
curl -I https://api.christelconsult.com

# Test the portfolio HTTPS endpoint.
curl -I https://www.christelconsult.com
```

If either fails, troubleshoot in this order: DNS delegation → ACM status → ALB HTTPS listener/certificate → target group health → Ingress → Service → pod logs.

**Done when:** Both URLs load successfully in a **browser**, show a valid HTTPS certificate, and serve the correct applications.

## Task 9 — Expose monitoring dashboards in the browser (optional)

**Why here:** Prometheus and Grafana may already run inside Kubernetes, but that does not make them reachable from a browser outside the cluster. Decide whether to keep them **private** (recommended for practice) or expose them securely with DNS and HTTPS. Do **not** expose Prometheus or Grafana publicly without authentication and access restrictions.

### Option A — Private browser access through port-forwarding (simplest and safest)

```bash
# Find the actual monitoring namespaces, Services, and their port numbers.
kubectl get svc -A | grep -Ei 'grafana|prometheus'

# Example ONLY: forward a Grafana Service to your laptop.
# Replace <NAMESPACE>, <GRAFANA_SERVICE>, and <SERVICE_PORT> with real values.
kubectl -n <NAMESPACE> port-forward svc/<GRAFANA_SERVICE> 3000:<SERVICE_PORT>

# Open http://localhost:3000 in your browser while port-forward is running.
```

In a **second terminal**:

```bash
# Example ONLY: forward the Prometheus Service locally.
# Replace placeholders with values from kubectl get svc -A.
kubectl -n <NAMESPACE> port-forward svc/<PROMETHEUS_SERVICE> 9090:<SERVICE_PORT>

# Open http://localhost:9090 in your browser while port-forward is running.
```

**Done when:** Grafana dashboards and the Prometheus UI load locally. Check targets and metrics, not just the login screen.

### Option B — Secure public HTTPS URLs (only if we deliberately choose this)

**Proposed names, not previously verified:** `grafana.christelconsult.com` and `prometheus.christelconsult.com`.

1. Confirm the monitoring Services and ports, and create Ingress resources in their **actual namespace**, sharing the intended ALB group if appropriate.
2. Require authentication and restrict access (for example, identity-aware access or a private network). Prometheus should generally remain private.
3. Add both names to the Route 53 Terraform record configuration, and include them in the ACM certificate's covered hostnames if needed. **The existing DNS code only covered the API and portfolio in the original build; these additions require code changes.**
4. Run the DNS Terraform plan/apply **after** the ALB exists; complete ACM validation and HTTPS listener configuration.

```bash
# Discover the real monitoring Services before writing Ingress rules.
kubectl get svc -A | grep -Ei 'grafana|prometheus'

# Check the monitoring Ingress resources after creating them.
kubectl get ingress -A

# Review DNS changes, including new monitoring aliases and certificate coverage.
terraform -chdir=env/dns plan

# Apply DNS changes only after reviewing the plan and access controls.
terraform -chdir=env/dns apply

# Verify DNS resolution once the records have propagated.
dig grafana.christelconsult.com +short
dig prometheus.christelconsult.com +short

# Check HTTPS responses; login redirects can be normal.
curl -I https://grafana.christelconsult.com
curl -I https://prometheus.christelconsult.com
```

**Done when:** The chosen monitoring access method works in the browser, Grafana displays live dashboards, Prometheus has healthy scrape targets, and public endpoints (if enabled) are secured.

## Task 10 — Verify GitHub Actions CI/CD end to end

**Why last:** The platform must already work before testing automated delivery.

```bash
# Locate the repository's CI/CD workflows.
ls .github/workflows

# Check the current Argo CD Applications before a test deployment.
kubectl get applications -n argocd

# After pushing a small safe change, confirm pods remain healthy.
kubectl get pods -n default

# Re-test the live URLs after the workflow finishes.
curl -I https://api.christelconsult.com
curl -I https://www.christelconsult.com
```

**Manual action:** Make a small application change, push it, and verify the actual GitHub Actions sequence: tests → build → ECR push → Helm image tag update → Argo CD sync → new version in browser. Confirm AWS OIDC role, ECR repository, and workflow permissions; don't assume they survived teardown.

**REBUILD FINISH LINE:** API and portfolio HTTPS URLs work in the browser, PostgreSQL is connected, Grafana and Prometheus are reachable through the selected safe browser access method (local port-forward or secured HTTPS), monitoring shows real data, and a GitHub Actions change deploys successfully.

---

# PART B — TEARDOWN: START HERE → FINISH WITH NO ACTIVE LAB INFRASTRUCTURE

**Objective:** Stop AWS lab charges while **keeping** GitHub source, Terraform code, the S3 state backend, and the IONOS domain registration. This teardown intentionally deletes practice DNS, cluster, workloads, and any disposable PostgreSQL data.

## Task 0 — Confirm scope and stop new deployments

**Why first:** Prevent GitHub Actions or Argo CD from recreating resources while you remove them.

```bash
# Confirm you are in the intended repository.
pwd

# Confirm the AWS account before any destructive command.
aws sts get-caller-identity

# Inspect the Argo CD parent application before changing auto-sync.
kubectl get application platform-apps -n argocd -o yaml
```

**Action:** Pause/disable relevant GitHub Actions workflows or avoid pushes. Disable parent automated sync **only if configured**:

```bash
# Remove parent automated sync if present; inspect first to avoid patch errors.
kubectl patch application platform-apps -n argocd --type=json \
  -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
```

**Done when:** No automated process will redeploy the apps during teardown.

## Task 1 — Destroy DNS **while the ALB still exists**

**Why first:** The DNS stack reads the ALB through a Terraform **data source**. If you delete the ALB first, the normal DNS destroy may fail during refresh.

```bash
# See exactly which DNS resources Terraform manages.
terraform -chdir=env/dns state list

# Preview DNS-only destruction before approving it.
terraform -chdir=env/dns plan -destroy

# Destroy Route 53 hosted zone/records and ACM certificate while ALB still exists.
terraform -chdir=env/dns destroy
```

**Check before confirming:** The plan targets only the intended practice DNS resources. IONOS registration is separate and will **not** be cancelled. The domain will stop serving the lab.

**Done when:** DNS Terraform state contains no managed lab resources and the DNS destroy succeeds.

### Recovery if the ALB was already deleted (what happened on October 27)

```bash
# If normal DNS destroy fails because data.aws_lb.platform_public returns 0 results,
# use saved state instead of refreshing the now-missing ALB lookup.
terraform -chdir=env/dns destroy -refresh=false
```

**Caution:** `-refresh=false` trusts potentially stale state. Review the destroy plan carefully. This was successful in the first teardown. **Do not delete Terraform code blocks just to get past this error.**

## Task 2 — Remove Kubernetes Ingress (including any monitoring Ingress) so the controller can delete the ALB

**Why next:** The AWS Load Balancer Controller needs the cluster to be alive to clean up its AWS resources.

```bash
# Remove the two public Ingresses; controller should reconcile and delete the ALB.
kubectl delete ingress platform-api portfolio -n default --wait=false

# Check for remaining Ingresses, including optional Grafana/Prometheus routes.
# Remove project monitoring Ingresses too, if created, before deleting EKS.
kubectl get ingress -A

# Check AWS load balancers; wait until the project's ALB is gone.
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code]' \
  --output table
```

**Done when:** The project's shared ALB is absent in AWS. Do not delete unrelated ALBs.

## Task 3 — Release and remove PostgreSQL storage (data intentionally discarded)

**Why now:** A PVC with a `Retain` reclaim policy can leave a **billable EBS volume** behind even after EKS is deleted.

```bash
# Stop PostgreSQL so its disk can be released.
kubectl scale deployment dev-postgres --replicas=0 -n default

# Delete the PostgreSQL PVC if it still exists.
kubectl delete pvc dev-postgres-data -n default --ignore-not-found

# Inspect PVs; identify the PostgreSQL PV and its reclaim policy.
kubectl get pv

# For the identified PostgreSQL PV, read the EBS volume ID.
# Replace <PV_NAME> with the actual PV name from kubectl get pv.
kubectl get pv <PV_NAME> -o jsonpath='{.spec.csi.volumeHandle}{"\n"}'

# Confirm the corresponding volume is no longer attached.
# Replace <VOLUME_ID> with the ID from the previous command.
aws ec2 describe-volumes --volume-ids <VOLUME_ID> --region us-east-1 \
  --query 'Volumes[*].[VolumeId,State]' --output table

# Delete ONLY the identified disposable PostgreSQL EBS volume when it is available.
aws ec2 delete-volume --volume-id <VOLUME_ID> --region us-east-1

# Remove the now-orphaned Kubernetes PV object.
kubectl delete pv <PV_NAME>
```

**Safety:** Do not force-detach a volume that is still `in-use`. Wait for pods to stop and detach, then recheck. **Done when:** No disposable retained PostgreSQL EBS volume remains.

## Task 4 — Destroy the main AWS infrastructure

**Why now:** DNS, ALB, and retained EBS storage are handled. Terraform can now delete EKS, node groups, NAT Gateway, VPC, IAM, and managed add-ons.

```bash
# Preview exactly what will be removed from the dev environment.
terraform -chdir=env/dev plan -destroy -out=destroy.tfplan

# Apply the reviewed destruction plan.
terraform -chdir=env/dev apply destroy.tfplan

# Confirm Terraform has no remaining managed dev resources.
terraform -chdir=env/dev state list
```

**Do not run destroy from `bootstrap/`**. That would risk the reusable Terraform backend.

**Done when:** Terraform reports successful destruction and the dev state has no managed lab resources.

## Task 5 — Check for billable leftovers

**Why last:** Terraform does not necessarily manage ECR images, manually created resources, snapshots, logs, or every AWS service. These can remain after EKS deletion.

```bash
# Confirm the EKS cluster is gone.
aws eks list-clusters --region us-east-1

# Check for any remaining ALBs/NLBs in this region.
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code]' --output table

# Check active or provisioning NAT gateways.
aws ec2 describe-nat-gateways --region us-east-1 \
  --filter Name=state,Values=available,pending \
  --query 'NatGateways[*].[NatGatewayId,State]' --output table

# Check for EBS volumes that may still be billed.
aws ec2 describe-volumes --region us-east-1 \
  --query 'Volumes[*].[VolumeId,State,Size]' --output table

# List ECR repositories, which may retain billable container images.
aws ecr describe-repositories --region us-east-1 \
  --query 'repositories[*].repositoryName' --output table

# Check CloudWatch log groups for retained logs.
aws logs describe-log-groups --region us-east-1 \
  --query 'logGroups[*].[logGroupName,storedBytes]' --output table

# Check snapshots that may remain after EBS volume deletion.
aws ec2 describe-snapshots --owner-ids self --region us-east-1 \
  --query 'Snapshots[*].[SnapshotId,VolumeSize]' --output table

# Check allocated Elastic IP addresses.
aws ec2 describe-addresses --region us-east-1 \
  --query 'Addresses[*].[PublicIp,AllocationId,AssociationId]' --output table
```

**Manual check:** AWS Billing / Cost Explorer, Secrets Manager, S3 storage, and any other regions used. Delete **only** leftovers belonging to this lab. Keep the S3 Terraform backend and domain registration. Billing can lag, so charges already accumulated may still appear.

**TEARDOWN FINISH LINE:** `env/dev` and `env/dns` destroyed; EKS, project ALB, NAT Gateway, and retained lab EBS volumes absent; leftover storage/logs reviewed; no active lab resources generating unexpected costs.

---

# PART C — THE DEPENDENCY RULE TO REMEMBER

**Rebuild (create dependencies first):**

`S3 backend → VPC/EKS → kubectl → controllers/storage/secrets → apps/services → Ingress/ALB → Route 53/ACM/IONOS → HTTPS browser test → CI/CD test`

**Teardown (remove external dependencies while controllers still run):**

`Pause automation → DNS/ACM → Ingress/ALB → retained EBS storage → Terraform env/dev → orphan-resource/billing audit`

**Why the order matters:** The DNS Terraform stack **reads** the ALB, so the ALB must exist when rebuilding DNS and when normally destroying DNS. Kubernetes AWS controllers should still be running when removing cloud load balancers.

## Notes from our first build

- The original `env/dev` and `env/dns` Terraform destroys succeeded on October 27, 2026.
- Because we had already removed the ALB, normal `env/dns destroy` failed on `data.aws_lb.platform_public` with **“Search returned 0 results.”** Recovery was `terraform -chdir=env/dns destroy -refresh=false`.
- PostgreSQL PVC had `Retain`; we had to release and delete its EBS volume separately.
- The first lab proved end-to-end operation. Future rebuilds should add **Trivy, Checkov, Gitleaks, GPU workloads, autoscaling, security gates, incident simulations, and cost controls** as separate milestones, *after* the baseline works.

## Next-session prompt

“Open my AWS EKS Platform task-by-task runbook. Help me rebuild **one task at a time**, starting at Task 0. Ask me to explain why each component is needed, let me write the commands/configuration, and review my results before we advance. Our finish line is both HTTPS URLs working in the browser and CI/CD deploying a change.”
