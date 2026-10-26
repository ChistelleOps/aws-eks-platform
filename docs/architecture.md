# AWS Container Platform — Architecture

> **Last reviewed:** October 26, 2026  
> **Current state:** ECS Fargate proof of concept completed and torn down. EKS, GitOps, applications, storage, secrets, and monitoring implemented and tested. **Public Ingress, custom-domain DNS, and HTTPS are planned, not deployed.** The current EKS lab is running; verify cleanup before leaving it idle.

## 1. Overview

This repository demonstrates a progression from a containerized Amazon ECS Fargate proof of concept to a reproducible Amazon EKS platform. Terraform provisions AWS infrastructure; GitHub Actions builds application images; Amazon ECR stores images; Helm and Argo CD deploy Kubernetes workloads; AWS Secrets Manager and External Secrets Operator supply credentials; EBS provides persistent storage; and Prometheus/Grafana provide observability.

## 2. Implemented architecture

```text
GitHub repository
  |-- Terraform ------------------> AWS VPC / IAM / EKS / managed nodes
  |                                  |-- EBS CSI driver + EBS volumes
  |                                  `-- EKS Pod Identity agent
  |
  |-- GitHub Actions (OIDC) ------> Amazon ECR (FastAPI + portfolio images)
  |
  `-- GitOps manifests -----------> Argo CD (App of Apps)
                                       |
                                       |-- External Secrets Operator
                                       |      `--> AWS Secrets Manager
                                       |              `--> PostgreSQL Kubernetes Secret
                                       |
                                       |-- gp3 StorageClass --> EBS PVC/PV
                                       |                          `--> PostgreSQL
                                       |
                                       |-- FastAPI (ClusterIP :8000)
                                       |      |-- /health
                                       |      `-- /metrics --> ServiceMonitor
                                       |
                                       |-- Portfolio (ClusterIP :80)
                                       |
                                       `-- kube-prometheus-stack
                                              |-- Prometheus <-- FastAPI metrics
                                              |-- Grafana dashboards
                                              `-- Prometheus alert rules
```

**Important:** The diagram above shows implemented components. Applications are currently accessed for testing using `kubectl port-forward`, not public domain URLs.

## 3. AWS infrastructure — Terraform

The development environment in `us-east-1` includes a VPC spanning two Availability Zones, two public and two private subnets, an internet gateway, NAT gateway, route tables, and security groups. Terraform provisions Amazon EKS, a managed EC2 node group, IAM roles/policies, EKS access entries, the EBS CSI driver, and the EKS Pod Identity agent. The cluster was validated with two Ready worker nodes on Kubernetes 1.34.

Terraform state uses an S3 backend with versioning and encryption. Backend resources may have a separate lifecycle from the EKS development environment.

## 4. Image delivery and application workloads

GitHub Actions uses AWS OIDC to authenticate without storing long-lived AWS credentials, builds Docker images, and publishes them to Amazon ECR. Application deployments use Helm charts and Argo CD; image tags are managed in the repository.

| Workload | Kubernetes exposure | Validation |
|---|---|---|
| FastAPI (`platform-api`) | ClusterIP Service, port 8000 | `/`, `/health`, `/metrics` via port-forward |
| Portfolio (Nginx) | ClusterIP Service, port 80 | Browser via port-forward |
| PostgreSQL | Internal database workload, port 5432 | Pod health, credentials, bound PVC |

Automatic promotion of new image tags from CI into GitOps remains a potential improvement; publishing an image does not by itself guarantee Argo CD deploys the new tag.

## 5. GitOps — Argo CD

The parent Argo CD Application `platform-apps` discovers child Application definitions under `gitops/argocd/applications/`. The platform includes Applications for external-secrets configuration, PostgreSQL, storage, FastAPI, portfolio, monitoring, and monitoring dashboards. Eight Applications including the parent were observed Synced and Healthy during testing.

Argo CD reconciles manifests from Git; some bootstrap tasks still require scripts or manual intervention. The repository includes scripts for Argo CD installation, External Secrets installation, and GitOps bootstrap.

## 6. Secrets and persistent storage

AWS Secrets Manager stores PostgreSQL credentials. External Secrets Operator, authorized through AWS IAM and EKS Pod Identity, synchronizes credentials into a Kubernetes Secret through a ClusterSecretStore and ExternalSecret.

The EBS CSI driver dynamically provisions encrypted `gp3` storage for PostgreSQL. The PostgreSQL claim bound to a 20 GiB persistent volume. The StorageClass uses `WaitForFirstConsumer`, supports expansion, and has a **Retain** reclaim policy. Deleting a PVC or destroying EKS may leave a chargeable EBS volume; check and clean it up deliberately.

## 7. Observability — implemented and tested

`kube-prometheus-stack` is deployed to the `monitoring` namespace using Argo CD, with Prometheus, Grafana, Prometheus Operator, Alertmanager, node-exporter, and kube-state-metrics.

The FastAPI application exposes `/metrics` using `prometheus-fastapi-instrumentator`. A `ServiceMonitor` lets Prometheus discover and scrape the API approximately every 30 seconds. Validation confirmed:

- `up{namespace="default",service="platform-api"}` returned `1`.
- `http_requests_total` included `/metrics` and `/health` traffic.
- A batch of 20 requests to `/` appeared in the HTTP request counter.
- The FastAPI Grafana dashboard was visible and looked correct.
- The rules `FastAPIDown`, `FastAPIHighErrorRate`, and `FastAPIHighLatency` were loaded in Prometheus.

**Scope of validation:** These checks confirm metric collection, dashboard visibility, and rule loading; they do not prove every alert notification path or every dashboard panel under sustained traffic.

Grafana login troubleshooting identified a memory-limit-related `OOMKilled` restart. Grafana resource requests/limits were increased, an accidental invalid memory value was corrected, Argo CD was resynchronized, and login succeeded. This will be documented separately in `docs/grafana-troubleshooting.md`.

Useful access commands:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
kubectl port-forward -n default svc/platform-api 8000:8000
```

## 8. Planned architecture — domain, Ingress, and HTTPS

The domain `christelconsult.com` is registered at **IONOS**. The next milestone is to use Amazon Route 53 for DNS while retaining IONOS as the registrar, and ACM for TLS certificates.

```text
Public users
     |
     v
christelconsult.com DNS (planned Route 53 hosted zone)
     |
     v
AWS Application Load Balancer (planned)
  |-- HTTPS :443 / ACM certificate (planned)
  `-- Kubernetes Ingress rules (planned)
          |-- api.christelconsult.com --> FastAPI Service :8000
          `-- www.christelconsult.com --> Portfolio Service :80
```

Planned implementation steps:

1. Configure IAM and install AWS Load Balancer Controller.
2. Create and validate Kubernetes Ingress resources and ALB target groups.
3. Create a Route 53 public hosted zone and update nameservers at IONOS.
4. Request an ACM certificate and complete DNS validation.
5. Configure HTTPS on the ALB and redirect HTTP to HTTPS.
6. Test DNS, TLS, application health checks, routing, and GitOps rollback.

**Not yet deployed:** AWS Load Balancer Controller, public ALB, Route 53 delegation, ACM certificate, and public HTTPS application endpoints. These resources may incur additional charges when provisioned.

## 9. Deployment and validation sequence

1. Run Terraform validation/plan, then provision AWS infrastructure for a test session.
2. Configure `kubectl` access and confirm worker nodes are Ready.
3. Install Argo CD and External Secrets Operator using repository scripts.
4. Ensure the PostgreSQL Secrets Manager value is initialized.
5. Bootstrap the GitOps parent Application; reconcile child Applications.
6. Validate ExternalSecret, StorageClass, PVC/PV, PostgreSQL, FastAPI, and portfolio.
7. Verify monitoring targets, Grafana dashboard, and Prometheus alert rules.
8. In a future session, validate Ingress, DNS, and HTTPS after implementing milestone 6.
9. Tear down chargeable resources when testing is complete.

Example commands:

```bash
terraform fmt -check
terraform validate
terraform plan
kubectl get nodes
kubectl get applications -n argocd
kubectl get pods -A
kubectl get externalsecrets -A
kubectl get pvc,pv -A
kubectl get servicemonitor,prometheusrule -A
```

## 10. Troubleshooting and incident learning

Existing incident reports:

- [`incidents&RCA/001-external-secrets-iam-access-denied.md`](incidents%26RCA/001-external-secrets-iam-access-denied.md): IAM/Secrets Manager access troubleshooting.
- [`incidents&RCA/002-PostgreSQLPending.md`](incidents%26RCA/002-PostgreSQLPending.md): PostgreSQL Pending/PVC and StorageClass troubleshooting.

The Grafana memory/login incident is a separate documentation task. Keep incident timelines and fixes distinct from planned architecture.

## 11. Cost management and lifecycle

The ECS Fargate POC and an earlier EKS lab were torn down after testing. **The current EKS environment is running**, so earlier teardown results do not describe its current AWS resource inventory.

Before destroying the environment, inspect persistent volumes and their reclaim policies. During teardown, verify EBS volumes, load balancers, NAT gateways, EC2 instances, Secrets Manager resources, and any other resources that may survive Terraform destroy. The S3 state backend may be retained intentionally. Review AWS billing separately; successful Terraform destroy alone does not prove zero ongoing charges.

## 12. Next steps

See [`project-roadmap.md`](project-roadmap.md). The next implementation milestone is **AWS Load Balancer Controller → ALB Ingress → Route 53 → ACM → HTTPS** for `christelconsult.com`, followed by SRE resilience/security exercises and final portfolio documentation.
