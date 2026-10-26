# AWS Container Platform — Project Roadmap

> **Current focus:** Amazon EKS platform. The earlier ECS Fargate proof of concept is complete.
>
> **Status as of October 26, 2026:** EKS platform, GitOps, storage, secrets, application deployments, and monitoring have been tested. Public ingress and custom-domain HTTPS remain planned. The current EKS environment is running and should be torn down when testing is finished to control costs.

## Goal

Build a reproducible, cost-conscious AWS platform engineering lab that demonstrates infrastructure as code, container delivery, Kubernetes operations, GitOps, secrets, persistent storage, observability, incident response, and secure public application access.

## Completed: ECS Fargate proof of concept

- [x] Containerize FastAPI and portfolio applications.
- [x] Build and publish images to Amazon ECR.
- [x] Deploy and test applications on ECS Fargate with Terraform.
- [x] Destroy the ECS test infrastructure after validation.

## Milestone 1 — EKS infrastructure (completed)

- [x] Terraform remote state in S3.
- [x] VPC, public/private subnets, route tables, internet gateway, NAT gateway.
- [x] EKS cluster and managed worker nodes.
- [x] IAM, EKS access entries, and Pod Identity agent.
- [x] EBS CSI driver.
- [x] Validate worker nodes and cluster access.

## Milestone 2 — CI/CD and GitOps (completed)

- [x] GitHub Actions with AWS OIDC authentication and ECR image publishing.
- [x] Helm charts for FastAPI and portfolio.
- [x] Argo CD App-of-Apps deployment structure.
- [x] Verify application sync and health.

## Milestone 3 — Storage and secrets (completed)

- [x] PostgreSQL deployment.
- [x] `gp3` StorageClass and persistent volume claim.
- [x] AWS Secrets Manager and External Secrets Operator.
- [x] Validate database volume binding and synchronized credentials.

## Milestone 4 — Observability (completed)

- [x] Deploy kube-prometheus-stack (Prometheus, Grafana, Alertmanager).
- [x] Expose FastAPI `/metrics` and configure ServiceMonitor.
- [x] Verify Prometheus scrape target and HTTP request counters.
- [x] Create and view FastAPI Grafana dashboard.
- [x] Verify alert rules: `FastAPIDown`, `FastAPIHighErrorRate`, `FastAPIHighLatency`.
- [ ] Document Grafana OOM/login troubleshooting and dashboard provisioning details.

## Milestone 5 — Ingress, DNS, and HTTPS (next)

**Domain:** `christelconsult.com`  
**Registrar:** IONOS  
**Planned DNS hosting:** Amazon Route 53  
**Region:** `us-east-1`

- [ ] Configure AWS Load Balancer Controller IAM permissions and install the controller.
- [ ] Create Kubernetes Ingress rules for the applications.
- [ ] Provision and verify an internet-facing Application Load Balancer (ALB).
- [ ] Create a Route 53 public hosted zone.
- [ ] Update domain nameservers at IONOS **after** reviewing existing DNS records and email dependencies.
- [ ] Request an ACM certificate and validate it using DNS.
- [ ] Configure HTTPS on ALB and HTTP-to-HTTPS redirect.
- [ ] Route `api.christelconsult.com` to FastAPI.
- [ ] Route `www.christelconsult.com` to the portfolio; decide whether the apex domain should redirect there.
- [ ] Test DNS, TLS, ALB health checks, application routing, and GitOps rollback.

> Domain registration stays at IONOS. Route 53 can host DNS without transferring the registration.

## Milestone 6 — Reliability and security (planned)

- [ ] Review readiness/liveness probes and CPU/memory requests/limits.
- [ ] Test horizontal pod autoscaling under load.
- [ ] Practice failure diagnosis and recovery; capture incident reports.
- [ ] Review IAM least privilege, RBAC, network exposure, and secrets access.
- [ ] Validate PostgreSQL backup/restore strategy.
- [ ] Test rebuild and rollback procedures.

## Milestone 7 — Documentation and portfolio (in progress)

- [x] Record External Secrets IAM and PostgreSQL PVC incidents.
- [ ] Maintain root `README.md` with actual project status.
- [ ] Write `docs/architecture.md` (deployed versus planned components).
- [ ] Write `docs/monitoring.md` (queries, dashboards, rules, validation).
- [ ] Write `docs/grafana-troubleshooting.md`.
- [ ] Write and test `docs/aws-eks-teardown-rebuild-runbook.md`.
- [ ] Add architecture diagrams and interview-ready project walkthrough.

## Cost and teardown checklist

- [ ] Review PVCs, PVs, reclaim policies, and retained EBS volumes.
- [ ] Before destroying the cluster, review any ALBs, target groups, or other Kubernetes-created AWS resources (once ingress is deployed).
- [ ] Follow the documented teardown order, then run Terraform destroy for the development environment.
- [ ] Verify EC2, EBS, load balancers, NAT gateways, and other chargeable resources are cleaned up as intended.
- [ ] Check Secrets Manager and Route 53 resources separately: these may remain outside the EKS Terraform state and incur charges.
- [ ] Review AWS billing; keep only intentionally retained resources, such as the S3 Terraform backend and domain registration.

## Definition of done

The lab can be recreated from version-controlled infrastructure and GitOps configuration; both applications can be deployed and observed; public traffic reaches them securely via HTTPS and the chosen domain; recovery and teardown steps are documented and tested.
