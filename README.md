# AWS Container Platform — From ECS Fargate to EKS

A hands-on DevOps and Platform Engineering project built to learn AWS infrastructure, container orchestration, GitOps, CI/CD, security integrations, observability, and real-world troubleshooting.

The project started with an **Amazon ECS Fargate proof of concept** and evolved into a working **Amazon EKS platform** with public HTTPS applications. Both phases were temporary labs: infrastructure was tested and then torn down to control costs.

> **Current status — October 27, 2026:** Both the ECS proof of concept and EKS end-to-end lab have been completed. The latest EKS `env/dev` and DNS `env/dns` Terraform destroys succeeded. The application URLs are **not currently live**. Final account-wide billing/orphan-resource verification remains a separate check.

## Project outcomes

- Provisioned AWS infrastructure with **Terraform**, including VPC networking, EKS, IAM, and cluster add-ons.
- Deployed **FastAPI**, a static **portfolio website**, and **PostgreSQL** on Kubernetes.
- Managed applications using **Helm, Argo CD, and an App-of-Apps GitOps pattern**.
- Integrated **AWS Secrets Manager**, **External Secrets Operator**, and **EKS Pod Identity**.
- Configured **EBS CSI** and a `gp3` StorageClass for PostgreSQL persistent storage.
- Implemented **Prometheus, Grafana, ServiceMonitor, and FastAPI alerting rules**.
- Exposed the API and portfolio using **Kubernetes Ingress, AWS Load Balancer Controller, a shared ALB, Route 53, and ACM HTTPS**.
- Validated a **GitHub Actions → Amazon ECR → Helm image update → Argo CD deployment** workflow.
- Practiced incident troubleshooting and completed an infrastructure teardown.

## Phases and status

| Phase | Scope | Status |
|---|---|---|
| 1 — ECS Fargate POC | Docker images, ECR, ECS services, Terraform, public IPv4 testing | Completed, tested, torn down |
| 2 — EKS platform | Terraform EKS, GitOps, PostgreSQL, secrets, monitoring, ALB, DNS, HTTPS, CI/CD | Completed, tested, torn down |
| 3 — AWS rebuild | Rebuild from scratch, then add DevSecOps and GPU workloads | Planned |
| 4 — GCP rebuild | Recreate equivalent platform on GKE | Planned |

## Applications and endpoints

| Application | Technology | Kubernetes port | Endpoint used during the EKS lab |
|---|---|---:|---|
| Platform API | Python / FastAPI | 8000 | `https://api.christelconsult.com` |
| Portfolio | HTML / Nginx | 80 | `https://www.christelconsult.com` |
| PostgreSQL | PostgreSQL | 5432 | Internal only |
| Grafana | kube-prometheus-stack | Chart-configured | Accessed through local port-forwarding |
| Prometheus | kube-prometheus-stack | Chart-configured | Accessed through local port-forwarding |

**The public API and portfolio endpoints were verified during the lab, but are offline after teardown.** Public monitoring endpoints such as `grafana.christelconsult.com` and `prometheus.christelconsult.com` are **future options**, not completed features. Any public monitoring access must be protected with authentication and appropriate network restrictions.

## Technology stack

| Area | Tools and services |
|---|---|
| Cloud | AWS |
| Infrastructure as Code | Terraform, S3 remote state |
| Containers | Docker, Amazon ECR |
| Orchestration | ECS Fargate, Amazon EKS |
| CI/CD | GitHub Actions, AWS OIDC |
| GitOps | Argo CD App-of-Apps |
| Packaging | Helm |
| Networking | VPC, subnets, IGW, NAT Gateway, security groups, ALB, Kubernetes Ingress |
| DNS and TLS | Route 53, ACM, IONOS domain registration |
| IAM | IAM roles and policies, EKS access entries, EKS Pod Identity |
| Secrets | Secrets Manager, External Secrets Operator |
| Storage | Amazon EBS, EBS CSI Driver, `gp3` StorageClass |
| Monitoring | Prometheus, Grafana, Alertmanager, ServiceMonitor, PrometheusRule |
| Logging | CloudWatch |

## Architecture

```text
Developer pushes code
       |
       v
GitHub Actions -- AWS OIDC --> Amazon ECR (container images)
       |                            |
       | Helm image reference       |
       v                            |
GitOps repository / Argo CD --------+
       |
       v
Amazon EKS (private worker nodes)
       |
       +-- FastAPI Deployment + ClusterIP Service --+
       |                                             |
       +-- Portfolio Deployment + ClusterIP Service -+--> Kubernetes Ingress
       |                                                      |
       +-- PostgreSQL + PVC --> EBS gp3                       v
       |                                              AWS Load Balancer
       +-- External Secrets --> AWS Secrets Manager           |
       |                                                      v
       +-- Prometheus / Grafana                        Route 53 + ACM
                                                              |
                                                api.christelconsult.com
                                                www.christelconsult.com
```

The domain is registered at **IONOS**. Route 53 hosted zone, ACM certificate, and application alias records were managed in a **separate Terraform DNS stack**.

## Implementation details

### 1. ECS Fargate proof of concept

- Built and pushed Docker images for FastAPI and portfolio.
- Created ECR repositories and ECS services using Terraform.
- Configured VPC, routing, security groups, and ECS task execution IAM.
- Tested applications through public IPv4 addresses and inspected CloudWatch logs.
- Destroyed the ECS lab after validation.

See [ECS POC documentation](env/ecs-poc/README.md).

### 2. EKS infrastructure

The `env/dev` Terraform stack provisioned VPC networking across two Availability Zones, an EKS cluster, managed EC2 worker nodes, IAM access, and EKS add-ons including EBS CSI and Pod Identity Agent.

The cluster used the name `platform-dev-eks` in `us-east-1`. Two worker nodes were confirmed Ready during the initial implementation.

### 3. GitOps and applications

Argo CD was installed using Helm. A parent Application named `platform-apps` discovered child Application definitions in `gitops/argocd/applications/`.

Managed child applications included:

- `external-secrets-config`
- `storage`
- `postgres`
- `platform-api`
- `portfolio`
- `monitoring`
- `monitoring-dashboards`

The AWS Load Balancer Controller was deployed separately. Helm charts for the applications live under `helm/`.

### 4. Secrets and storage

External Secrets Operator synchronized PostgreSQL credentials from AWS Secrets Manager into Kubernetes using IAM/Pod Identity access.

PostgreSQL used a 20 GiB EBS-backed PersistentVolumeClaim and a `gp3` StorageClass. Its reclaim policy was **Retain**, which required explicit cleanup of the underlying EBS volume during teardown.

### 5. Observability

The `kube-prometheus-stack` deployed Prometheus, Grafana, Alertmanager, and Prometheus Operator.

- FastAPI exposed Prometheus metrics at `/metrics`.
- A `ServiceMonitor` scraped the API.
- `up{namespace="default",service="platform-api"}` was verified as `1`.
- A Grafana dashboard displayed request rate, error rate, and latency.
- Three rules were loaded: `FastAPIDown`, `FastAPIHighErrorRate`, and `FastAPIHighLatency`.
- Grafana and Prometheus were accessed using **local port-forwarding**, not public DNS.

### 6. Public Ingress, DNS, and HTTPS

This milestone was **completed after the earlier README snapshot**:

- Deployed AWS Load Balancer Controller and configured Kubernetes Ingress for the two applications.
- Used a shared Application Load Balancer for external routing.
- Created Route 53 hosted zone and application records with `env/dns`.
- Configured an ACM certificate and HTTPS.
- Used IONOS-registered `christelconsult.com` with AWS DNS.
- Verified the API and portfolio through their public HTTPS URLs.

**Important dependency:** `env/dns` uses `data.aws_lb.platform_public` to find the existing ALB. The ALB must exist before normal DNS provisioning or a refresh-based DNS destroy.

### 7. CI/CD

GitHub Actions authenticated to AWS through OIDC, built/tested application changes, pushed images to ECR, and updated Helm image references for Argo CD to deploy. An end-to-end application update was verified during the lab.

This does **not** mean the entire cluster and platform were bootstrapped by a single workflow; infrastructure provisioning and platform setup still had separate steps.

## Troubleshooting and lessons

| Incident | Root cause | Resolution |
|---|---|---|
| External Secrets failed to synchronize | Incorrect AWS region in IAM resource ARN; secret had no stored value | Corrected policy and populated secret |
| PostgreSQL PVC stuck `Pending` | Missing `gp3` StorageClass | Added storage manifest to GitOps |
| Grafana login/session instability | Grafana container OOM restarts | Corrected memory configuration and synced |
| DNS destroy failed | ALB had already been deleted; `data.aws_lb.platform_public` lookup returned zero results | Used `terraform -chdir=env/dns destroy -refresh=false` after reviewing the plan |
| Retained PostgreSQL EBS volume | PV reclaim policy `Retain` | Stopped PostgreSQL, removed PVC, verified detach, deleted EBS volume and PV |

Key takeaways: resource dependency order matters; GitOps only manages what its manifests define; Kubernetes events and logs are essential; IAM and secrets must be validated end to end; and storage reclaim policies affect costs.

## Rebuild and teardown runbook

The detailed **task-by-task** runbook is intended to cover the full path from an empty AWS lab to working HTTPS URLs, plus the reverse teardown. Each task includes **why it comes next**, commented commands, and a completion checkpoint.

Suggested location in the repository: `docs/aws-eks-rebuild-teardown-runbook.md`. Add the separately prepared runbook file there before turning this into a GitHub link.

### Rebuild order

1. Confirm AWS account, region, credentials, and budget.
2. Initialize existing S3 remote-state backend.
3. Apply `env/dev` Terraform for VPC, EKS, IAM, and add-ons.
4. Connect `kubectl`; verify worker nodes.
5. Install Argo CD, controllers, storage, and secret integrations.
6. Deploy PostgreSQL, FastAPI, portfolio, and monitoring through GitOps.
7. Create Kubernetes Ingress and the shared ALB.
8. Apply `env/dns` Terraform for Route 53 and ACM; update IONOS nameservers if the hosted zone changed.
9. Verify HTTPS for the API and portfolio; access Grafana and Prometheus safely through port-forwarding or secured endpoints.
10. Test GitHub Actions deployment from code change to browser.

**Rebuild finish line:** Both public application URLs load over HTTPS, PostgreSQL is healthy, monitoring displays live metrics, and CI/CD deploys a change.

### Teardown order

1. Pause automated deployment/sync to prevent recreation.
2. Destroy `env/dns` **while the ALB still exists**.
3. Delete Kubernetes Ingress and verify the ALB disappears.
4. Remove PostgreSQL PVC and any retained disposable EBS volume.
5. Destroy `env/dev` with Terraform.
6. Audit EKS, ALBs, NAT Gateways, EBS, ECR, CloudWatch, snapshots, Elastic IPs, and billing.

If the ALB was already removed, the normal DNS destroy can fail on its data source. The recovery used in this lab was:

```bash
# Destroy DNS using recorded Terraform state instead of refreshing a deleted ALB.
# Review the plan carefully because the state may be stale.
terraform -chdir=env/dns destroy -refresh=false
```

**Never destroy `bootstrap/` as part of the normal lab teardown.** Preserve the remote-state S3 backend, source code, and IONOS domain registration.

## Repository structure (key directories)

```text
aws-eks-platform/
├── apps/
│   ├── platform-api/
│   └── portfolio/
├── bootstrap/                   # Terraform remote-state infrastructure
├── env/
│   ├── ecs-poc/
│   ├── dev/                     # EKS and AWS platform resources
│   └── dns/                     # Route 53, ACM, app DNS records
├── modules/
│   ├── networking/
│   └── eks/
├── gitops/
│   ├── argocd/
│   │   ├── applications/
│   │   └── root-app.yaml
│   ├── external-secrets/
│   └── secrets/
├── helm/
│   ├── postgres/
│   ├── platform-api/
│   └── portfolio/
├── kubernetes/
│   ├── apps/
│   └── storage/
├── scripts/
├── docs/
└── README.md
```

This is a **high-level directory map**, not a verified exhaustive file listing.

## Cost management and current state

On October 27, 2026, both the `env/dev` and `env/dns` Terraform destroys completed successfully. The project ALB had already been confirmed removed, and the retained PostgreSQL EBS volume was handled separately.

The **source code, GitHub repository, S3 Terraform backend, and IONOS domain** are intended to remain. Terraform destroy success does not prove every manually created or billable resource is gone. Check ECR images, CloudWatch logs, snapshots, other regions, and Cost Explorer after each lab. Charges can appear with a delay.

## Next iterations

**AWS rebuild:** Recreate the same architecture independently, then add DevSecOps scans (for example, Trivy, Checkov, Gitleaks), image security gates, autoscaling, controlled failure drills, and GPU workloads with strict cost limits.

**GCP rebuild:** Implement the equivalent platform on GKE, comparing networking, IAM, persistent storage, GitOps, observability, security, and GPU scheduling with AWS.

The first iteration answered **“Can I make the whole platform work?”** The next iterations focus on **“Can I build, secure, troubleshoot, and operate it independently?”**

## Author

[ChistelleOps](https://github.com/ChistelleOps)
