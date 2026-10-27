# AWS Container Platform — Architecture

**Last reviewed:** October 27, 2026  
**Implementation status:** End-to-end ECS and EKS platform successfully implemented and tested.  
**Deployment status:** ECS lab torn down; latest EKS `env/dev` and DNS `env/dns` Terraform destroys succeeded. The public applications are currently offline. Final billing and orphan-resource audit remains pending.

## 1. Overview

This document describes **the architecture that was built and validated**, not an environment that is currently running. The repository progresses from an ECS Fargate proof of concept to a Terraform-provisioned Amazon EKS platform in `us-east-1`. Helm and Argo CD manage workloads, GitHub Actions delivers container images through ECR, AWS Secrets Manager supplies PostgreSQL credentials through External Secrets Operator, EBS provides persistent storage, and Prometheus/Grafana provide observability.

## 2. Implemented architecture

### 2.1 Platform and delivery architecture

```text
Developer push to GitHub
         |
         v
GitHub Actions (AWS OIDC, tests/build/push)
         |                          \
         v                           \ updates image tag in Git
     Amazon ECR                      v
         |                     Helm values in Git
         |                           |
         +---------------------------+
                                     |
                                     v
                             Argo CD GitOps
                                     |
                           Amazon EKS (env/dev)
                                     |
                  +------------------+--------------------+
                  |                  |                    |
             FastAPI/Portfolio   PostgreSQL          Monitoring
                  |                  |                    |
           ClusterIP Services   PVC / EBS gp3      Prometheus/Grafana
                  |                  |
            Kubernetes Ingress  External Secrets
                  |                  |
         AWS Load Balancer       Secrets Manager
             Controller
                  |
          Shared internet ALB
                  |
         Route 53 + ACM (env/dns)
                  |
            Browser over HTTPS
```

The AWS Load Balancer Controller is bootstrapped separately from the parent Argo CD App-of-Apps, using a generated configuration with the VPC ID from Terraform output. The parent `platform-apps` manages the other child Applications.

### 2.2 Public request path

```text
Browser
  |
  +-- https://www.christelconsult.com --+
  |                                      |
  +-- https://api.christelconsult.com ---+--> Route 53 alias
                                                 |
                                      Shared ALB (ACM TLS :443)
                                                 |
                                         Host-based Ingress
                                                 |
                          +----------------------+-------------------+
                          |                                          |
                   Portfolio Service :80                     API Service :8000
                          |                                          |
                      Nginx Pod                                  FastAPI Pod
                                                                      |
                                                                  PostgreSQL
```

Both Ingress resources used the `platform-public` group and an internet-facing ALB with `ip` targets. The AWS Load Balancer Controller managed the ALB lifecycle; Terraform **did not** directly create the ALB. Both public HTTPS URLs were verified in a browser on October 26, 2026. They are no longer active after teardown.

### 2.3 Resource ownership

| Component | Owner |
|---|---|
| VPC, EKS, worker nodes, IAM, add-ons | Terraform `env/dev` |
| Route 53 hosted zone, ACM certificate, validation and app aliases | Terraform `env/dns` |
| ALB and target groups | AWS Load Balancer Controller via Kubernetes Ingress |
| Workloads, storage configuration, monitoring | Argo CD and Helm |
| Images and image-tag promotion | GitHub Actions, ECR, Git repository |
| PostgreSQL volume | EBS CSI; reclaim policy `Retain` |
| Credentials | AWS Secrets Manager, External Secrets Operator |
| Remote Terraform state | Retained S3 backend, separate from lab stacks |
| Domain registration | IONOS (retained) |

## 3. Infrastructure

Terraform `env/dev` provisioned a VPC across two Availability Zones, public and private subnets, route tables, internet gateway, NAT gateway, security groups, EKS managed node group, EKS access entries, EBS CSI driver, and EKS Pod Identity agent. Two worker nodes were confirmed Ready in the initial implementation. Remote state uses S3 with versioning and encryption.

The project uses two Terraform stacks with different lifecycles. **`env/dns` depends on an ALB created by the Kubernetes controller**: `data.aws_lb.platform_public` looks up the ALB by tag `ingress.k8s.aws/stack = platform-public`.

## 4. CI/CD and GitOps

GitHub Actions authenticates with AWS through OIDC and pushes application images to ECR. The project initially used a manually dispatched ECR publishing workflow. An automated code-push delivery path was later implemented and tested:

```text
Code push -> GitHub Actions -> ECR image -> Helm image-tag update in Git
          -> Argo CD sync -> new application version on EKS
```

An automated deployment reached the HTTPS API successfully. **Remaining improvements:** review exact workflow triggers/path filters, test gates, concurrency, prevention of recursive runs, deployment verification, and rollback safety. These are implementation tasks, not completed architecture features.

The Argo CD parent Application is `platform-apps`. Child Applications included `external-secrets-config`, `storage`, `postgres`, `platform-api`, `portfolio`, `monitoring`, and `monitoring-dashboards`. The `aws-load-balancer-controller` Application was bootstrapped separately. All nine Applications were confirmed Synced and Healthy during the running lab.

## 5. Storage and secrets

AWS Secrets Manager held PostgreSQL credentials. External Secrets Operator, with IAM/EKS Pod Identity, synchronized a Kubernetes Secret through a ClusterSecretStore and ExternalSecret.

PostgreSQL used a 20 GiB `gp3` EBS-backed PersistentVolumeClaim. The StorageClass used `WaitForFirstConsumer` and **`Retain`**, so deleting the PVC alone did not remove the billable EBS volume. The volume required deliberate cleanup during teardown.

## 6. Monitoring and alerting

The `monitoring` namespace hosted `kube-prometheus-stack`: Prometheus, Grafana, Alertmanager, Prometheus Operator, node-exporter, and kube-state-metrics. FastAPI exposed `/metrics` through `prometheus-fastapi-instrumentator`, scraped via a ServiceMonitor. The lab validated:

- `up{namespace="default",service="platform-api"} == 1`.
- HTTP request counters increased after test traffic.
- Grafana FastAPI dashboard with request rate, error rate, and latency panels.
- Loaded alert rules `FastAPIDown`, `FastAPIHighErrorRate`, and `FastAPIHighLatency`.

**Monitoring was accessed locally through port-forwarding**, not through public domains:

```bash
# Open the Prometheus UI at http://localhost:9090 while this runs.
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# In another terminal, open Grafana at http://localhost:3000.
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Optional future URLs `grafana.christelconsult.com` and `prometheus.christelconsult.com` would require new DNS/Ingress configuration **and authentication/access restrictions**. They have not been implemented.

A Grafana login issue was traced to `OOMKilled` restarts and resolved by correcting resource settings and resynchronizing Argo CD. Verified metric collection and loaded rules do not establish end-to-end alert notification testing.

## 7. DNS and HTTPS

The domain `christelconsult.com` is registered at IONOS. The `env/dns` Terraform stack created a Route 53 public hosted zone, ACM certificate for the domain and wildcard subdomains, DNS validation records, and alias records for `api` and `www`. The ALB had HTTP and HTTPS listeners and an ACM certificate.

**Rebuild dependency:** EKS -> controllers -> apps/Ingress -> shared ALB -> `env/dns` Terraform -> DNS delegation/ACM validation -> browser verification. If the Route 53 hosted zone is recreated, update IONOS to its **new** nameservers. HTTPS may need staged setup if Ingress initially requires a certificate that has not yet been issued.

**Teardown dependency:** Stop deployment automation -> destroy `env/dns` while the ALB exists -> delete app Ingress resources and wait for ALB deletion -> clean retained EBS -> destroy `env/dev` -> audit remaining AWS resources. In the last teardown, the ALB was already deleted before DNS destroy, so the normal DNS refresh failed with `Search returned 0 results` on `data.aws_lb.platform_public`. The reviewed recovery command was:

```bash
# Use the recorded Terraform state when the ALB lookup can no longer succeed.
# Review the destruction plan carefully because state may be stale.
terraform -chdir=env/dns destroy -refresh=false
```

The DNS stack **was destroyed** on October 27, 2026; contrary to the earlier design, it was not retained. The IONOS registration and Terraform source code remain.

## 8. Operational lifecycle and validation

### Build and validate

1. Verify AWS account, region, budget, and retained S3 backend.
2. Apply `env/dev` and connect `kubectl` to EKS.
3. Run `scripts/bootstrap_gitops.sh` after confirming its current behavior and dependencies.
4. Confirm Argo CD Applications, PostgreSQL PVC, Secrets, and monitoring are healthy.
5. Confirm Ingress has created the shared ALB.
6. Apply `env/dns`, delegate the domain if nameservers changed, and validate ACM.
7. Open `https://api.christelconsult.com` and `https://www.christelconsult.com` in a browser.
8. Access monitoring through port-forwarding; confirm real metrics and dashboards.
9. Push a test change and verify GitHub Actions -> ECR -> Argo CD -> browser.

### Tear down and verify

1. Pause automation and review destructive scope.
2. Destroy DNS while ALB still exists.
3. Remove Ingress and verify the ALB is deleted.
4. Stop PostgreSQL, delete PVC, and remove any retained EBS volume when detached.
5. Destroy `env/dev`, preserving `bootstrap/` and the S3 backend.
6. Audit ECR, CloudWatch logs, snapshots, Elastic IPs, Secrets Manager, Route 53, and AWS billing.

Detailed commented commands and completion checkpoints belong in the separate **rebuild/teardown runbook**. Architecture describes *what connects to what* and *why*, rather than duplicating every command.

## 9. Troubleshooting lessons

- External Secrets sync failed because of an IAM ARN region mismatch and an empty Secrets Manager secret.
- PostgreSQL PVC remained Pending until the `gp3` StorageClass was added through GitOps.
- Grafana login issues resulted from memory-related container restarts.
- DNS destroy failed after the ALB was deleted; `-refresh=false` allowed teardown without changing reusable Terraform code.
- A `Retain` PV reclaim policy required manual EBS cleanup.

## 10. Current status and remaining work

**Built and verified:** ECS POC, EKS networking and IAM, GitOps applications, PostgreSQL, secrets, monitoring, shared ALB, Route 53, ACM HTTPS, and push-triggered application delivery.

**Destroyed:** ECS POC and the latest EKS/DNS Terraform environments. Application endpoints are offline. **Not yet fully verified:** absence of all orphaned chargeable AWS resources.

**Remaining platform implementation:** CI/CD hardening and rollback tests; DevSecOps scans and policy gates; autoscaling and failure recovery; backup/restore; monitoring alert notification tests; optional secure monitoring browser endpoints; documentation and cost audit.

See `docs/project-roadmap.md` for feature status and the project runbook for exact commands. Rebuilding the same platform on AWS or GCP for personal practice is a separate learning activity, not an unfinished architecture feature.
