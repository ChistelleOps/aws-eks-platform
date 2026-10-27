# AWS Container Platform — Project Roadmap

> **Status — October 27, 2026:** ECS Fargate and the end-to-end EKS platform were built and tested. Both `env/dev` and `env/dns` Terraform environments were subsequently destroyed to control costs. Completed features remain checked because they worked during the lab. The GitHub repository, S3 Terraform backend, and IONOS domain registration are retained. Final AWS billing/orphan-resource audit is pending.

## Goal

Build a reproducible AWS container platform using Terraform, Kubernetes, GitOps, CI/CD, persistent storage, secrets management, observability, and secure HTTPS access. Track **implemented features** and **unfinished platform work**, not personal learning exercises or separate cloud projects.

## ECS Fargate proof of concept — Completed

- [x] Containerize FastAPI and portfolio applications.
- [x] Publish container images to Amazon ECR.
- [x] Deploy and validate ECS Fargate services with Terraform.
- [x] Inspect CloudWatch logs and application access.
- [x] Destroy the ECS lab after testing.

## Milestone 1 — AWS infrastructure and EKS — Completed

- [x] Configure S3 remote Terraform state.
- [x] Create VPC, public/private subnets, route tables, internet gateway, NAT Gateway, and security groups.
- [x] Provision EKS and managed worker nodes.
- [x] Configure IAM, EKS access entries, Pod Identity agent, and EBS CSI driver.
- [x] Verify cluster connectivity and Ready nodes.

## Milestone 2 — Kubernetes applications and GitOps — Completed

- [x] Build Helm charts for FastAPI and portfolio.
- [x] Install Argo CD and configure `platform-apps` App-of-Apps.
- [x] Deploy FastAPI and portfolio through Argo CD.
- [x] Verify application sync, health, and internal Service access.

## Milestone 3 — Persistent storage and secrets — Completed

- [x] Deploy PostgreSQL with Helm and Argo CD.
- [x] Configure `gp3` StorageClass, PVC, and EBS-backed storage.
- [x] Configure AWS Secrets Manager, External Secrets Operator, and Pod Identity access.
- [x] Validate PVC binding and credential synchronization.

## Milestone 4 — Monitoring and alerting — Core completed

- [x] Deploy kube-prometheus-stack (Prometheus, Grafana, Alertmanager, Prometheus Operator).
- [x] Instrument FastAPI `/metrics` and configure ServiceMonitor.
- [x] Validate Prometheus target and HTTP request counters.
- [x] Create Grafana panels for request rate, errors, and latency.
- [x] Validate `FastAPIDown`, `FastAPIHighErrorRate`, and `FastAPIHighLatency` rules.
- [x] Access Grafana and Prometheus locally using port-forwarding.
- [ ] Decide whether secured browser URLs are needed for monitoring.
- [ ] If selected, implement authenticated and access-restricted Grafana/Prometheus access; do not expose dashboards publicly without protection.

## Milestone 5 — Public Ingress, DNS, and HTTPS — Completed

**Domain:** `christelconsult.com` (registered at IONOS) · **AWS region:** `us-east-1`

- [x] Configure AWS Load Balancer Controller.
- [x] Create Kubernetes Ingress resources for FastAPI and portfolio.
- [x] Provision and validate a shared internet-facing ALB.
- [x] Configure Route 53 hosted zone and DNS aliases in `env/dns`.
- [x] Delegate DNS from IONOS to Route 53 for the lab.
- [x] Issue and validate ACM certificate; configure HTTPS.
- [x] Open `https://api.christelconsult.com` in the browser.
- [x] Open `https://www.christelconsult.com` in the browser.

> These URLs **worked during the lab** and are **offline after teardown**. Domain registration remains active at IONOS.

## Milestone 6 — CI/CD automation and release safety — In progress

**Goal:** Application code changes should automatically build, test, publish, and deploy without manually invoking the ECR publishing workflow.

- [x] Configure GitHub Actions authentication to AWS with OIDC.
- [x] Create ECR image publishing workflow, initially triggered by `workflow_dispatch`.
- [x] Implement and test a push-triggered path to build/publish an image, update the Helm image reference, and let Argo CD deploy it.
- [x] Verify a deployed commit SHA and successful HTTPS API response.
- [ ] Review the actual `.github/workflows/` files and document final trigger conditions and workflow names.
- [ ] Confirm automatic tests must pass before publishing; add any missing test gates.
- [ ] Configure reliable path filters for FastAPI and portfolio changes.
- [ ] Prevent recursive workflow execution from automated Helm tag commits.
- [ ] Verify immutable commit-SHA tags, concurrency controls, and failure handling.
- [ ] Test rollback to a known-good application image and document the procedure.
- [ ] Add deployment verification and troubleshooting guidance.

**Last checkpoint:** The push-triggered pipeline was successfully tested; the next unfinished exercise was **rollback safety**. The original manual workflow's exact filename and current triggers should be confirmed in the repository.

## Milestone 7 — DevSecOps and platform security — Planned

- [ ] Add secret scanning (for example, Gitleaks) to CI.
- [ ] Add Terraform/IaC scanning (for example, Checkov).
- [ ] Add dependency and container image scanning (for example, Trivy).
- [ ] Define which security findings block a deployment.
- [ ] Review AWS OIDC trust, IAM least privilege, Kubernetes RBAC, Pod Identity, and secrets access.
- [ ] Review network policies, container security contexts, and image provenance.
- [ ] Document security findings and remediation.

## Milestone 8 — Reliability and recovery — Planned

- [ ] Review readiness/liveness probes and CPU/memory requests and limits.
- [ ] Test horizontal pod autoscaling and node autoscaling under load.
- [ ] Practice Argo CD drift, unhealthy deployments, OOMKilled pods, and target-group failures.
- [ ] Test PostgreSQL backup and restore.
- [ ] Test application rollback and record incident reports.
- [ ] Review monitoring alerts and runbooks for common incidents.

## Milestone 9 — Documentation and operational runbooks — In progress

- [x] Document External Secrets and PostgreSQL PVC troubleshooting incidents.
- [x] Prepare an updated root README reflecting public HTTPS and teardown.
- [x] Draft a task-by-task rebuild/teardown runbook with commented commands.
- [x] Commit and verify the updated README and runbook in the repository.
- [ ] Validate runbook commands against actual repo paths and workflow names.
- [ ] Complete `docs/architecture.md`, `docs/monitoring.md`, and `docs/grafana-troubleshooting.md`.


## Milestone 10 — Teardown and cost controls — Infrastructure teardown completed

- [x] Pause Argo CD automated synchronization during teardown.
- [x] Remove Kubernetes Ingress and verify the project ALB was deleted.
- [x] Handle the retained PostgreSQL EBS volume.
- [x] Destroy `env/dev` and `env/dns` Terraform resources.
- [x] Preserve Terraform source, GitHub repository, S3 state backend, and IONOS domain registration.
- [x] Document the DNS destroy failure after ALB deletion and the `-refresh=false` recovery.
- [x] Complete the account-wide residual-resource audit: ECR, CloudWatch, EBS snapshots, Elastic IPs, secrets, storage, and billing.

**Dependency lesson:** The DNS stack's `data.aws_lb.platform_public` requires the ALB to exist for normal refresh. Prefer **DNS teardown before Ingress/ALB removal**. If the ALB has already gone, carefully review the saved state before using `terraform -chdir=env/dns destroy -refresh=false`.

## Platform definition of done

- [x] Infrastructure provisioned using Terraform and applications deployed through GitOps.
- [x] PostgreSQL, secrets, and monitoring validated.
- [x] API and portfolio accessible through public HTTPS URLs during the lab.
- [x] An automated GitHub Actions → ECR → Helm → Argo CD application update verified.
- [ ] CI/CD release-safety checks and rollback validated.
- [ ] DevSecOps scanning gates implemented.
- [ ] Reliability and recovery exercises completed.
- [ ] Documentation and final cost audit completed.

**Scope:** This roadmap tracks the **AWS platform implementation** only. Personal AWS/GCP rebuild practice and GPU experiments are intentionally excluded.
