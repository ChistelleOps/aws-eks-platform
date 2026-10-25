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

**Status: Core platform implemented and tested. Advanced features deferred.**

Both environments were designed to be temporary to minimize AWS costs.

## Applications

| Application | Technology | Port | Purpose |
|---|---|---|---|
| Platform API | Python, FastAPI | 8000 | Backend API with a health-check endpoint |
| Portfolio | HTML, Nginx | 80 | Static portfolio website |
| PostgreSQL | PostgreSQL | 5432 | Database workload for testing Kubernetes persistent storage and secrets |

The FastAPI and portfolio applications were deployed and validated during the ECS phase. Their container images were also published to Amazon ECR through GitHub Actions.

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

The child Applications were successfully synchronized and reported Healthy.

The parent Application remained OutOfSync at the final observed checkpoint. Its root cause was not investigated before teardown.

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

### 6. Troubleshooting

Investigated and resolved multiple deployment issues.

**Incident 001 — External Secrets synchronization failure**

Identified an incorrect AWS region in an IAM policy resource ARN and a Secrets Manager secret without a stored value.

Updated the IAM policy and populated the secret, allowing External Secrets Operator to synchronize PostgreSQL credentials successfully.

**Incident 002 — PostgreSQL PVC stuck Pending**

Investigated PVC events and discovered that the required `gp3` StorageClass did not exist in the cluster.

Added an Argo CD Application to deploy the existing StorageClass manifest through GitOps.

After synchronization, the PVC became Bound and PostgreSQL became Healthy.

These incidents demonstrated Kubernetes troubleshooting, AWS IAM debugging, persistent storage configuration, and GitOps-based remediation.

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
│   └── postgres/
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
  |
  +-- Terraform
  |     |
  |     +-- VPC / Networking
  |     +-- IAM
  |     +-- Amazon EKS
  |     +-- EBS CSI / Pod Identity
  |
  +-- GitHub Actions
  |     |
  |     +-- Build Docker Images
  |     +-- AWS OIDC Authentication
  |     +-- Push Images to Amazon ECR
  |
  +-- GitOps Configuration
        |
        +-- Argo CD
              |
              +-- External Secrets
              |     |
              |     +-- AWS Secrets Manager
              |
              +-- StorageClass
              |     |
              |     +-- Amazon EBS
              |
              +-- PostgreSQL
                    |
                    +-- PersistentVolumeClaim
```

## Deferred Features

The following features were part of the broader roadmap but were not completed in this POC:

- Deploying the FastAPI and portfolio applications to EKS.
- Kubernetes Ingress and AWS Load Balancer Controller.
- HTTPS certificates using AWS Certificate Manager.
- Custom-domain routing using Amazon Route 53.
- Prometheus and Grafana monitoring.
- Alerting and reliability testing.
- Fully automated platform bootstrap and application delivery.
- Multi-environment platform validation.

These areas are candidates for a future production-style platform engineering project.

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

AWS infrastructure was provisioned temporarily for development and testing.

After validating the platform:

- The PostgreSQL test EBS volume was detached and deleted.
- Terraform-managed infrastructure was destroyed.
- Terraform state was checked and contained no managed resources.
- EC2 instance and EBS volume checks returned no remaining resources in the project region.

These checks do not establish that every possible AWS resource or ongoing charge has been eliminated.

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
| Ingress and HTTPS | Deferred |
| Monitoring and alerting | Deferred |
| Fully automated bootstrap | Deferred |
| AWS infrastructure teardown | Completed, with additional resource checks recommended |

The project is preserved in GitHub for reference and future improvements. The running development infrastructure has been destroyed to control AWS costs.

## Author

[ChistelleOps](https://github.com/ChistelleOps)