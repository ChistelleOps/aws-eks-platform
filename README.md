# AWS Container Platform — From ECS Fargate to EKS

A hands-on DevOps and Platform Engineering project demonstrating how to containerize applications, provision AWS infrastructure using Terraform, deploy workloads to Amazon ECS Fargate, and build a Kubernetes platform on Amazon EKS using Helm, Argo CD, GitOps, and AWS-native security services.

The project was designed as a practical learning environment to explore cloud infrastructure automation, container orchestration, CI/CD, persistent storage, secrets management, and troubleshooting.

## Project Overview

The project consists of two phases:

### Phase 1 — Amazon ECS Fargate POC

Containerize two applications and deploy them to Amazon ECS Fargate using Terraform.

**Status: Completed and tested.**

### Phase 2 — Amazon EKS Platform

Provision a Kubernetes cluster, configure AWS integrations, and deploy supporting platform services using Helm and Argo CD.

**Status: Core platform, application deployments, PostgreSQL, secrets, and observability implemented and tested. Public ingress, DNS, and HTTPS are next.**

Both environments were designed to be temporary to minimize AWS costs.

## Applications
| Application | Technology | Port | Purpose |
|---|---|---|---|
| Platform API | Python, FastAPI | 8000 | Backend API with a health-check endpoint |
| Portfolio | HTML, Nginx | 80 | Static portfolio website |
| PostgreSQL | PostgreSQL | 5432 | Database workload for testing Kubernetes persistent storage and secrets |

The FastAPI and portfolio applications were deployed and validated during both the ECS and EKS phases. GitHub Actions published their container images to Amazon ECR, and Argo CD deployed the existing images to EKS through Helm charts. Both were tested using local port forwarding.

PostgreSQL was deployed and validated on EKS using Helm and Argo CD.

## Technology Stack
| Category | Technologies |
|---|---|
| Cloud | Amazon Web Services |
| Infrastructure as Code | Terraform |
| Containerization | Docker |
| Container Orchestration | Amazon ECS Fargate, Amazon EKS |
| Container Registry | Amazon ECR |
| CI/CD | GitHub Actions, AWS OIDC |
| GitOps | Argo CD |
| Kubernetes Packaging | Helm |
| Networking | VPC, public/private subnets, NAT Gateway, Internet Gateway, route tables, security groups |
| Identity and Security | AWS IAM, EKS Access Entries, EKS Pod Identity |
| Secrets Management | AWS Secrets Manager, External Secrets Operator |
| Persistent Storage | Amazon EBS, EBS CSI Driver, gp3 StorageClass |
| Logging | Amazon CloudWatch |
| Observability | Prometheus, Grafana, kube-prometheus-stack, ServiceMonitor, PrometheusRule |
| Terraform State | Amazon S3 with versioning and encryption |

## Phase 1 — ECS Fargate POC

### Completed

- Built Docker images for the FastAPI and portfolio applications.

- Created Amazon ECR repositories using Terraform.

- Pushed container images to Amazon ECR.

- Provisioned an ECS cluster using AWS Fargate.

- Configured a dedicated VPC, public subnets, routing, and security groups.

- Configured IAM permissions for ECS task execution.

- Deployed both applications as ECS services.

- Verified application accessibility through public IPv4 addresses.

- Reviewed container logs using Amazon CloudWatch.

- Scaled services down after testing.

- Destroyed the ECS infrastructure using Terraform.

See [ECS POC Documentation](env/ecs-poc/README.md).

## Phase 2 — Amazon EKS Platform

### 1. Infrastructure Provisioning

Provisioned an EKS development environment using Terraform.

Implemented:

- VPC with public and private subnets across two Availability Zones.

- Internet Gateway and NAT Gateway.

- Route tables and subnet associations.

- Amazon EKS cluster.

- Managed EC2 worker nodes.

- IAM roles and policies.

- EKS access entries and administrator access.

- Amazon EBS CSI Driver.

- EKS Pod Identity Agent.

Validated cluster connectivity using `kubectl` and confirmed that two worker nodes were Ready.

### 2. CI/CD and Container Registry

Configured GitHub Actions workflows to authenticate to AWS using OpenID Connect (OIDC).

The workflows built and published container images to Amazon ECR without storing long-lived AWS access keys in GitHub.

### 3. Helm and Argo CD

Installed Argo CD using Helm.

Configured an App-of-Apps GitOps structure with a parent Application named `platform-apps`.

The parent Application discovers child Application definitions stored in:

`gitops/argocd/applications/`

Implemented child Applications for:

- External Secrets configuration.

- PostgreSQL.

- Kubernetes storage configuration.

- FastAPI (`platform-api`).

- Portfolio (`portfolio`).
- Monitoring stack (`monitoring`).
- Grafana dashboard configuration (`monitoring-dashboards`).

Eight Applications, including the parent `platform-apps`, were confirmed Synced and Healthy during monitoring validation.

### 4. Secrets Management

Installed External Secrets Operator using Helm.

Integrated Kubernetes workloads with AWS Secrets Manager using EKS Pod Identity and IAM permissions.

Configured:

- AWS Secrets Manager secret for PostgreSQL credentials.

- ClusterSecretStore.

- ExternalSecret.

- Kubernetes Secret synchronization.

Validated that the ExternalSecret reached Ready status.

### 5. PostgreSQL and Persistent Storage

Deployed PostgreSQL using a Helm chart managed by Argo CD.

Configured persistent storage using:

- Amazon EBS CSI Driver.

- `gp3` StorageClass.

- PersistentVolumeClaim.

- Dynamically provisioned Amazon EBS volume.

Verified that the PostgreSQL PVC successfully bound to a 20 GiB PersistentVolume and that the PostgreSQL Argo CD Application became Synced and Healthy.

### 6. FastAPI and Portfolio on EKS

Created separate Helm charts in `helm/platform-api/` and `helm/portfolio/`, each with a Deployment, ClusterIP Service, and configurable image reference. Both use the existing Amazon ECR images and are deployed by child Argo CD Applications.

- FastAPI: container and Service port `8000`; tested `/` and `/health` with `kubectl port-forward svc/platform-api 8000:8000`.

- Portfolio: Nginx container and Service port `80`; tested in a browser with `kubectl port-forward svc/portfolio 8081:80`. Port `8081` was chosen locally to avoid a conflict with the Argo CD UI on `8080`.

- Both applications were observed Synced/Healthy in Argo CD and tested successfully.

- These are internal ClusterIP Services; public ALB ingress and HTTPS are not configured yet.

### 7. Monitoring and Alerting

Deployed the `kube-prometheus-stack` through an Argo CD Application, including Prometheus, Grafana, Alertmanager, and the Prometheus Operator.

- Instrumented FastAPI with Prometheus HTTP metrics exposed at `/metrics`.
- Configured a `ServiceMonitor` to scrape the FastAPI service.
- Verified `up{namespace="default",service="platform-api"}` returned `1`.
- Generated HTTP requests and verified the `http_requests_total` counter increased.
- Added a Grafana FastAPI dashboard with request rate, error rate, and latency panels.
- Confirmed the dashboard was visible and all three alert rules were loaded: `FastAPIDown`, `FastAPIHighErrorRate`, and `FastAPIHighLatency`.

Monitoring was tested using local port forwarding. Public monitoring access is not part of the current implementation.

### 8. Troubleshooting

Investigated and resolved multiple deployment issues.

****Incident 001 — External Secrets synchronization failure****

Identified an incorrect AWS region in an IAM policy resource ARN and a Secrets Manager secret without a stored value.

Updated the IAM policy and populated the secret, allowing External Secrets Operator to synchronize PostgreSQL credentials successfully.

****Incident 002 — PostgreSQL PVC stuck Pending****

Investigated PVC events and discovered that the required `gp3` StorageClass did not exist in the cluster.

Added an Argo CD Application to deploy the existing StorageClass manifest through GitOps.

After synchronization, the PVC became Bound and PostgreSQL became Healthy.

These incidents demonstrated Kubernetes troubleshooting, AWS IAM debugging, persistent storage configuration, and GitOps-based remediation.

Additional troubleshooting during observability rollout included Grafana login/session failures caused by container OOM restarts, followed by a memory configuration correction and Argo CD synchronization. See the planned `docs/grafana-troubleshooting.md` write-up.

## Repository Structure

```text

aws-eks-platform/

├── apps/

│   ├── platform-api/

│   └── portfolio/

├── env/

│   ├── ecs-poc/

│   └── dev/

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

└── README.md

```

## Architecture Overview

The platform combines Terraform-managed AWS infrastructure with Kubernetes resources managed through Helm and Argo CD.

```text

GitHub

&#x20; |

&#x20; +-- Terraform

&#x20; |     |

&#x20; |     +-- VPC / Networking

&#x20; |     +-- IAM

&#x20; |     +-- Amazon EKS

&#x20; |     +-- EBS CSI / Pod Identity

&#x20; |

&#x20; +-- GitHub Actions

&#x20; |     |

&#x20; |     +-- Build Docker Images

&#x20; |     +-- AWS OIDC Authentication

&#x20; |     +-- Push Images to Amazon ECR

&#x20; |

&#x20; +-- GitOps Configuration

&#x20;       |

&#x20;       +-- Argo CD

&#x20;             |

&#x20;             +-- External Secrets

&#x20;             |     |

&#x20;             |     +-- AWS Secrets Manager

&#x20;             |

&#x20;             +-- StorageClass

&#x20;             |     |

&#x20;             |     +-- Amazon EBS

&#x20;             |

&#x20;             +-- PostgreSQL

&#x20;                   |

&#x20;                   +-- PersistentVolumeClaim

              +-- Monitoring (Prometheus / Grafana)
                    |
                    +-- FastAPI ServiceMonitor
                    +-- Grafana dashboard
                    +-- FastAPI alert rules

```

## Deferred Features

The following features were part of the broader roadmap but were not completed in this POC:

- Kubernetes Ingress and AWS Load Balancer Controller.

- HTTPS certificates using AWS Certificate Manager.

- Custom-domain routing using Amazon Route 53.

- Prometheus and Grafana monitoring.

- Alerting and reliability testing.

- Fully automated platform bootstrap and application delivery.

- Multi-environment platform validation.

Next networking milestone: integrate the existing `christelconsult.com` domain (registered at IONOS) with Route 53 DNS, AWS Certificate Manager (ACM), an AWS Application Load Balancer, and Kubernetes Ingress. Proposed application URLs: `api.christelconsult.com` and `www.christelconsult.com`. These endpoints are **not deployed yet**.

## Infrastructure Validation

Validation and troubleshooting used commands including:

```bash

terraform fmt -check

terraform validate

terraform plan

kubectl get nodes

kubectl get pods -A

kubectl get applications -n argocd

kubectl get storageclass

kubectl get pvc,pv -A

```

Additional repository scripts support Terraform, Kubernetes, Helm, and GitOps validation.

## Cost Management and Cleanup

AWS infrastructure is provisioned temporarily for development and testing. The previous deployment was successfully torn down; **a newer EKS lab deployment is currently running and still requires cleanup**.

During an earlier teardown, the following checks were performed:

- The PostgreSQL test EBS volume was detached and deleted.

- Terraform-managed infrastructure was destroyed.

- Terraform state was checked and contained no managed resources.

- EC2 instance and EBS volume checks returned no remaining resources in the project region.

These earlier checks do not establish that every possible AWS resource or ongoing charge has been eliminated, and they do not apply to the currently running lab deployment. Before the next teardown, inspect PVC/PV reclaim policies, retained EBS volumes, and other chargeable resources.

Terraform backend resources, including the S3 state bucket, should be reviewed separately because they may be managed outside the development environment's Terraform state.

## Key Lessons Learned

1. Infrastructure as Code improves repeatability but does not automatically configure every Kubernetes dependency.

2. GitOps requires all intended Kubernetes resources to be included in an Application's source configuration.

3. Kubernetes events provide useful evidence when troubleshooting Pending workloads and PVCs.

4. IAM policy resource ARNs must match the correct AWS region, account, and resource.

5. Creating a Secrets Manager secret does not necessarily mean it contains a usable secret version.

6. PersistentVolume reclaim policies affect storage cleanup and cloud costs.

7. Infrastructure teardown is an important part of operating cost-controlled development environments.

## Project Status
| Component | Status |
|---|---|
| ECS Fargate POC | Completed |
| Terraform EKS infrastructure | Implemented and tested |
| GitHub Actions and ECR | Implemented and tested |
| Argo CD and Helm | Implemented and tested |
| External Secrets integration | Implemented and tested |
| PostgreSQL persistent storage | Implemented and tested |
| FastAPI on EKS | Deployed and tested via port-forward |
| Portfolio on EKS | Deployed and tested via port-forward |
| Ingress and HTTPS | Deferred |
| Monitoring and alerting | Implemented and tested |
| Fully automated bootstrap | Deferred |
| AWS infrastructure teardown | Earlier deployment completed; current running deployment pending teardown |

The project is preserved in GitHub for repeatable lab rebuilds. Infrastructure is temporary and should be destroyed after lab sessions to control AWS costs. The latest session validated application deployments and the observability stack.

**Next:** ALB Ingress, Route 53 DNS, and ACM HTTPS for `christelconsult.com`.

**Documentation to add:** `docs/project-roadmap.md`, `docs/architecture.md`, `docs/monitoring.md`, `docs/grafana-troubleshooting.md`. Existing incident reports remain in `docs/incidents&RCA/`.

## Author

[ChistelleOps](https\://github.com/ChistelleOps)
