# AWS Container Platform — Architecture

**Last reviewed:** October 26, 2026

**Current state:** ECS Fargate proof of concept completed and torn down. The AWS EKS platform is deployed and operational, including Terraform infrastructure, GitOps, application workloads, persistent storage, secrets management, Prometheus/Grafana monitoring, a shared Application Load Balancer, Route 53 DNS, and HTTPS using ACM.

The portfolio and Platform API are accessible through their public HTTPS domains. The EKS development environment is currently running and incurs AWS charges.

## 1. Overview

This repository demonstrates a progression from a containerized Amazon ECS Fargate proof of concept to a reproducible Amazon EKS platform. Terraform provisions AWS infrastructure; GitHub Actions builds application images; Amazon ECR stores images; Helm and Argo CD deploy Kubernetes workloads; AWS Secrets Manager and External Secrets Operator supply credentials; EBS provides persistent storage; and Prometheus/Grafana provide observability.

## 2. Implemented architecture

The platform runs containerized applications on Amazon EKS in `us-east-1`. Terraform provisions AWS infrastructure, GitHub Actions builds application images, and Argo CD manages Kubernetes workloads through GitOps.

### 2.1 Platform architecture

```text
                         GitHub Repository
                                |
               +----------------+----------------+
               |                                 |
          GitHub Actions                       Terraform
               |                                 |
          Amazon ECR                    +--------+--------+
               |                        |                 |
               |                     env/dev           env/dns
               |                        |                 |
               |                    VPC + EKS       Route 53 + ACM
               |                        |
               |                  EKS Managed Nodes
               |                        |
               +------------------------+
                                        |
                                  Argo CD GitOps
                                        |
                    +-------------------+-------------------+
                    |                   |                   |
                Applications         Data Layer         Observability
                    |                   |                   |
                FastAPI              PostgreSQL         Prometheus
                Portfolio            EBS gp3            Grafana
                                        |
                                  Secrets Manager
                                  External Secrets
```

### 2.2 Public application traffic

```text
                         Internet Users
                               |
                               v
                     Amazon Route 53
                               |
                 +-------------+-------------+
                 |                           |
     www.christelconsult.com     api.christelconsult.com
                 |                           |
                 +-------------+-------------+
                               |
                               v
                  Shared AWS Application
                      Load Balancer
                               |
                        HTTPS :443
                     ACM Certificate
                               |
                      Kubernetes Ingress
                               |
                 +-------------+-------------+
                 |                           |
             Portfolio                   Platform API
          ClusterIP :80                ClusterIP :8000
                 |                           |
             Nginx Pod                   FastAPI Pod
                                             |
                                         PostgreSQL
```

The AWS Load Balancer Controller provisions and manages the shared ALB from Kubernetes Ingress resources.

Both applications use the Ingress group `platform-public`, allowing them to share one ALB.

The public endpoints are:

- `https://www.christelconsult.com` — Portfolio website
- `https://api.christelconsult.com` — FastAPI application

Route 53 alias records point both hostnames to the shared ALB. An ACM certificate covers the domain and its subdomains.

### 2.3 Infrastructure ownership

| Component | Managed by |
|---|---|
| VPC, subnets, EKS, IAM | Terraform (`env/dev`) |
| Route 53, ACM, DNS aliases | Terraform (`env/dns`) |
| AWS Application Load Balancer | AWS Load Balancer Controller |
| Kubernetes applications | Argo CD |
| Application images | GitHub Actions and Amazon ECR |
| PostgreSQL persistent volumes | Kubernetes and EBS CSI |
| Application secrets | AWS Secrets Manager and External Secrets Operator |
| Metrics and dashboards | Prometheus and Grafana |

### 2.4 Rebuild considerations

The EKS development environment and DNS infrastructure have separate Terraform configurations.

The AWS Load Balancer Controller is bootstrapped separately from the parent Argo CD App-of-Apps. Its bootstrap template receives the VPC ID from Terraform output, avoiding a hardcoded VPC ID in Git.

After an EKS rebuild:

1. Provision the EKS infrastructure.
2. Bootstrap the required Kubernetes controllers and Argo CD applications.
3. Wait for the shared ALB to be created.
4. Run Terraform for `env/dns` to update the application DNS aliases if the ALB has changed.
5. Validate DNS resolution, HTTPS, and application availability.

The Route 53 hosted zone and ACM certificate are intended to persist across EKS rebuilds. DNS aliases must be reviewed during teardown and rebuild because they depend on the lifecycle of the ALB.


## 3. AWS infrastructure — Terraform

The development environment in `us-east-1` includes a VPC spanning two Availability Zones, two public and two private subnets, an internet gateway, NAT gateway, route tables, and security groups. Terraform provisions Amazon EKS, a managed EC2 node group, IAM roles/policies, EKS access entries, the EBS CSI driver, and the EKS Pod Identity agent. The cluster was validated with two Ready worker nodes on Kubernetes 1.34.

Terraform state uses an S3 backend with versioning and encryption. Backend resources may have a separate lifecycle from the EKS development environment.

## 4. Image delivery and application workloads

GitHub Actions uses AWS OIDC to authenticate without storing long-lived AWS credentials, builds Docker images, and publishes them to Amazon ECR. Application deployments use Helm charts and Argo CD; image tags are managed in the repository.

| Workload | Kubernetes exposure | Validation |
|---|---|---|
| FastAPI (`platform-api`) | ClusterIP Service, port 8000; public ALB Ingress | `https://api.christelconsult.com`; `/health` and `/metrics` also tested internally |
| Portfolio (Nginx) | ClusterIP Service, port 80; public ALB Ingress | `https://www.christelconsult.com` verified in browser |
| PostgreSQL | Internal database workload, port 5432 | Pod health, credentials, bound PVC |

Automatic promotion of new image tags from CI into GitOps remains a potential improvement; publishing an image does not by itself guarantee Argo CD deploys the new tag.

## 5. GitOps — Argo CD

The parent Argo CD Application `platform-apps` discovers child Application
definitions under `gitops/argocd/applications/`.

The AWS Load Balancer Controller Application is bootstrapped separately using
a generated manifest containing the VPC ID from Terraform output. This prevents
the parent App-of-Apps from conflicting with the generated configuration.

On October 26, 2026, all nine Argo CD Applications were verified as
Synced and Healthy.

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

## 8. Public networking — ALB, Route 53, and HTTPS

**Status:** Implemented and tested on October 26, 2026.

### 8.1 AWS Load Balancer Controller

The AWS Load Balancer Controller runs in Amazon EKS and provisions AWS load balancers based on Kubernetes Ingress resources.

The controller uses EKS Pod Identity for AWS permissions. Its Argo CD Application is generated during bootstrap using the VPC ID retrieved from Terraform output.

This avoids hardcoding a VPC ID that may change after rebuilding the EKS environment.

### 8.2 Shared Application Load Balancer

The FastAPI and portfolio applications use Kubernetes Ingress resources with:

- Ingress class: `alb`
- Ingress group: `platform-public`
- ALB scheme: internet-facing
- Target type: `ip`
- HTTP listener: port 80
- HTTPS listener: port 443
- ACM certificate for HTTPS

Both Ingress resources share one AWS Application Load Balancer.

The AWS Load Balancer Controller manages the ALB lifecycle. Terraform does not create the ALB directly.

### 8.3 Route 53 and ACM

The domain `christelconsult.com` is registered with IONOS.

Terraform in `env/dns` manages:

- The Route 53 public hosted zone
- The ACM certificate covering `christelconsult.com` and `*.christelconsult.com`
- ACM DNS validation records
- Route 53 alias records for the applications

The DNS aliases are:

| Domain | Destination |
|---|---|
| `api.christelconsult.com` | Shared AWS ALB |
| `www.christelconsult.com` | Shared AWS ALB |

Terraform discovers the ALB through the AWS tag:

`ingress.k8s.aws/stack = platform-public`

This avoids hardcoding the ALB's generated name or DNS address in Terraform.

### 8.4 Validation

On October 26, 2026:

- Both Kubernetes Ingress resources received the same ALB DNS address.
- Both Route 53 aliases were created successfully using Terraform.
- DNS queries returned IP addresses for both domains.
- Both public HTTPS application URLs were accessible in a browser.
- All nine Argo CD Applications were Synced and Healthy.

These checks confirm public DNS resolution and successful browser access over HTTPS. Additional testing of HTTP-to-HTTPS redirects, ALB target health, and failure recovery can be performed as reliability exercises.

### 8.5 Rebuild dependency

The DNS infrastructure is intended to persist independently of the EKS cluster.

When EKS is rebuilt, the AWS Load Balancer Controller may create a new ALB with a different DNS address.

The correct recovery sequence is:

1. Rebuild EKS using Terraform.
2. Bootstrap the AWS Load Balancer Controller and Argo CD.
3. Deploy the application Ingress resources.
4. Wait until the shared ALB exists.
5. Apply `env/dns` Terraform to update the Route 53 aliases.
6. Verify DNS resolution and HTTPS access.

During teardown, check whether DNS aliases still reference an ALB that has been deleted. Persistent Route 53 and ACM resources should be managed separately from temporary EKS resources.

## 9. Deployment and validation sequence

The platform uses two Terraform environments:

- `env/dev` — EKS, networking, IAM, and supporting infrastructure.
- `env/dns` — Persistent Route 53, ACM, and application DNS records.

The deployment order matters because some resources depend on infrastructure created by Kubernetes.

### 9.1 Provision AWS infrastructure

Validate and provision the EKS development environment:

```bash
terraform -chdir=env/dev init
terraform -chdir=env/dev validate
terraform -chdir=env/dev plan
terraform -chdir=env/dev apply
```

Configure Kubernetes access using the EKS platform administrator role:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name platform-dev-eks \
  --role-arn arn:aws:iam::452395238296:role/eks-platform-admin
```

Verify cluster connectivity:

```bash
kubectl get nodes
```

### 9.2 Bootstrap platform controllers

Install Argo CD and External Secrets Operator using the repository's installation scripts.

Ensure the PostgreSQL credential exists in AWS Secrets Manager before deploying dependent workloads.

Run:

```bash
bash scripts/bootstrap_gitops.sh
```

The bootstrap script retrieves the current VPC ID from Terraform and generates the AWS Load Balancer Controller Application.

It then applies the parent Argo CD Application, `platform-apps`.

### 9.3 Verify GitOps applications

```bash
kubectl get applications -n argocd
```

The expected applications include:

- `platform-apps`
- `aws-load-balancer-controller`
- `external-secrets-config`
- `storage`
- `postgres`
- `platform-api`
- `portfolio`
- `monitoring`
- `monitoring-dashboards`

Verify that applications are Synced and Healthy.

### 9.4 Verify workloads and persistent storage

```bash
kubectl get pods -A
kubectl get externalsecrets -A
kubectl get pvc -A
kubectl get pv
```

Confirm that PostgreSQL is running, its PVC is bound, and application pods are healthy.

### 9.5 Verify the shared ALB

```bash
kubectl get ingress -A
```

Confirm that both `platform-api` and `portfolio` have the same ALB address.

The AWS Load Balancer Controller creates the ALB from Kubernetes Ingress resources.

### 9.6 Configure DNS

After the ALB exists, run:

```bash
terraform -chdir=env/dns init
terraform -chdir=env/dns validate
terraform -chdir=env/dns plan
terraform -chdir=env/dns apply
```

Terraform discovers the ALB using its `ingress.k8s.aws/stack` tag and manages the Route 53 alias records.

Review the Terraform plan before applying changes, especially when working with persistent DNS infrastructure.

### 9.7 Validate public endpoints

Check DNS resolution:

```bash
dig +short api.christelconsult.com
dig +short www.christelconsult.com
```

Check HTTPS:

```bash
curl -I https://api.christelconsult.com
curl -I https://www.christelconsult.com
```

An application-specific HTTP status, such as `404` for an undefined API route, does not necessarily indicate an infrastructure failure.

Verify the application routes separately.

### 9.8 Verify monitoring

Confirm that Prometheus is collecting application metrics and that Grafana dashboards are accessible.

```bash
kubectl get servicemonitor,prometheusrule -A
```

Review the monitoring documentation for dashboard access and metric validation.

### 9.9 Teardown and rebuild

Use `docs/aws-eks-teardown-rebuild-runbook.md` for the detailed teardown and rebuild procedure.

Before destroying EKS, review resources that may survive cluster deletion, including retained EBS volumes, Secrets Manager secrets, DNS records, and the Terraform state backend.

The DNS environment has a separate lifecycle and should not be destroyed as part of routine EKS testing.

After rebuilding EKS, repeat the ALB and DNS validation steps because the new ALB may have a different DNS address.


## 10. Troubleshooting and incident learning

Existing incident reports:

- [`incidents&RCA/001-external-secrets-iam-access-denied.md`](incidents%26RCA/001-external-secrets-iam-access-denied.md): IAM/Secrets Manager access troubleshooting.
- [`incidents&RCA/002-PostgreSQLPending.md`](incidents%26RCA/002-PostgreSQLPending.md): PostgreSQL Pending/PVC and StorageClass troubleshooting.

The Grafana memory/login incident is documented separately in
`docs/grafana-troubleshooting.md`. It covers the OOMKilled restart,
resource-limit adjustments, Argo CD reconciliation, and successful
Grafana login.

## 11. Cost management and lifecycle

The ECS Fargate POC and an earlier EKS lab were torn down after testing. **The current EKS environment is running**, so earlier teardown results do not describe its current AWS resource inventory.

Before destroying the environment, inspect persistent volumes and their reclaim policies. During teardown, verify EBS volumes, load balancers, NAT gateways, EC2 instances, Secrets Manager resources, and any other resources that may survive Terraform destroy. The S3 state backend may be retained intentionally. Review AWS billing separately; successful Terraform destroy alone does not prove zero ongoing charges.

## 12. Next steps

The core AWS EKS platform, GitOps deployment, public networking, DNS, and HTTPS milestones are complete.

The next phase focuses on improving operational maturity and production-readiness practices.

### Priority 1 — CI/CD improvements

- Automate image promotion from GitHub Actions to GitOps manifests.
- Add automated application tests and container image scanning.
- Validate deployment and rollback procedures.

### Priority 2 — Security

- Review IAM permissions and EKS Pod Identity access.
- Implement Kubernetes NetworkPolicies and workload security contexts.
- Add infrastructure security scanning.

### Priority 3 — Reliability and observability

- Test Prometheus alert notifications.
- Configure and test Horizontal Pod Autoscaling.
- Validate readiness/liveness probes and resource limits.
- Perform controlled failure and recovery exercises.

### Priority 4 — Backup and disaster recovery

- Implement PostgreSQL backups to S3.
- Test database restoration.
- Document recovery time and recovery point objectives.

### Priority 5 — Portfolio readiness

- Finalize architecture and deployment documentation.
- Update the project roadmap.
- Record AWS operating costs and cleanup procedures.
- Prepare technical explanations and demonstrations for Platform Engineering and SRE interviews.

See `docs/project-roadmap.md` for the detailed implementation roadmap.
