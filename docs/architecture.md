# AWS Container Platform — Architecture

## 1. Overview

This project demonstrates the evolution of a containerized application platform from Amazon ECS Fargate to Amazon EKS.

The architecture separates infrastructure provisioning, container image delivery, Kubernetes application management, secrets management, and persistent storage.

The AWS infrastructure is provisioned for lab sessions and destroyed afterward to minimize ongoing costs.

## 2. Architecture Diagram

```text
                      GitHub Repository
                             |
              +--------------+---------------+
              |                              |
       Terraform Code                 GitHub Actions
              |                              |
              v                              v
      AWS Infrastructure              Docker Build
              |                              |
       +------+------+                       v
       |             |                   Amazon ECR
       v             v
    Networking      IAM
       |             |
       +------+------+
              |
              v
         Amazon EKS
              |
      +-------+--------+
      |                |
      v                v
  Worker Nodes     EKS Add-ons
      |                |
      |           +----+------+
      |           |           |
      |        EBS CSI    Pod Identity
      |
      v
    Argo CD
      |
      +-- External Secrets Configuration
      |       |
      |       v
      |   AWS Secrets Manager
      |
      +-- StorageClass (gp3)
      |       |
      |       v
      |    Amazon EBS
      |
      +-- PostgreSQL (Helm)
              |
              +-- Kubernetes Secret
              |
              +-- PersistentVolumeClaim
```

GitHub Actions publishes application images to ECR. Argo CD renders their Helm charts and deploys both images to EKS. Services are currently internal ClusterIP services.

## 3. Infrastructure Layer — Terraform

Terraform provisions the AWS infrastructure.

### Networking

The development VPC includes:

- Two public subnets.
- Two private subnets.
- Internet Gateway.
- NAT Gateway.
- Route tables and subnet associations.
- Security groups.

The subnets span two Availability Zones.

### Amazon EKS

Terraform provisions:

- EKS control plane.
- Managed EC2 worker nodes.
- IAM roles and policies.
- EKS access entries.
- Amazon EBS CSI Driver.
- EKS Pod Identity Agent.

The cluster was validated with two Ready worker nodes.

## 4. Container Build and Registry

GitHub Actions authenticates to AWS using OpenID Connect (OIDC), avoiding long-lived AWS access keys in GitHub.

The workflow builds container images and pushes them to Amazon ECR.

Two applications were containerized:

- FastAPI backend.
- Nginx portfolio website.

Both applications were validated during the ECS Fargate POC.

## 5. Kubernetes and GitOps Layer

Argo CD was installed on EKS using Helm.

The GitOps configuration uses an App-of-Apps pattern.

The parent Application, `platform-apps`, monitors:

`gitops/argocd/applications/`

Child Applications manage:

- External Secrets configuration.
- PostgreSQL.
- Kubernetes storage configuration.
- FastAPI platform API.
- Nginx portfolio website.

The parent Application was configured with automatic synchronization, pruning, and self-healing.

All six Applications (the parent and five children) were observed as Synced and Healthy.

## 6. Application Workloads

The FastAPI and portfolio applications each have their own Helm chart and Argo CD child Application.

- `helm/platform-api`: Deployment, ClusterIP Service on port 8000, readiness and liveness checks at `/health`.
- `helm/portfolio`: Deployment, ClusterIP Service on port 80, readiness and liveness checks at `/`.
- ECR images are referenced by explicit Git commit tags in Helm values.
- Verified FastAPI via `kubectl port-forward svc/platform-api 8000:8000` and `curl http://localhost:8000/health`.
- Verified portfolio via `kubectl port-forward svc/portfolio 8081:80` and browser access at `http://localhost:8081`.

There is no public Ingress yet. Updating the Helm image tags automatically after CI builds is also future work.

## 7. Secrets Management

AWS Secrets Manager stores PostgreSQL credentials.

External Secrets Operator retrieves the secret using an AWS IAM role associated with a Kubernetes service account through EKS Pod Identity.

A ClusterSecretStore defines access to AWS Secrets Manager.

An ExternalSecret creates or updates the Kubernetes Secret consumed by PostgreSQL.

This avoids storing PostgreSQL passwords directly in the Git repository.

## 8. Persistent Storage

PostgreSQL requires persistent storage.

The EBS CSI Driver provisions Amazon EBS volumes for Kubernetes PersistentVolumeClaims.

The project uses a `gp3` StorageClass with:

- Encrypted EBS storage.
- `WaitForFirstConsumer` volume binding.
- Volume expansion support.
- `Retain` reclaim policy.

During testing, PostgreSQL successfully obtained a 20 GiB persistent volume.

The `Retain` policy requires careful cleanup because deleting the Kubernetes claim does not automatically delete the underlying EBS volume.

## 9. Deployment Sequence

The platform was deployed in the following general order:

1. Provision AWS networking, IAM, and EKS with Terraform.
2. Configure AWS CLI and Kubernetes access.
3. Install Argo CD using Helm.
4. Install External Secrets Operator.
5. Configure the required AWS secret value.
6. Bootstrap the parent Argo CD Application.
7. Synchronize the child Applications.
8. Validate secrets, storage, and PostgreSQL health.
9. Argo CD deploys FastAPI and portfolio from their Helm charts.
10. Verify both pods, Services, and HTTP endpoints via port-forward.

This sequence was not fully automated end to end. Some installation, secret initialization, and synchronization steps required manual intervention.

## 10. Validation

The platform was validated using Terraform, AWS CLI, Kubernetes, and Argo CD.

Example commands:

```bash
terraform validate
terraform plan

kubectl get nodes
kubectl get pods -A
kubectl get applications -n argocd
kubectl get externalsecrets
kubectl get storageclass
kubectl get pvc,pv -A
```

## 11. Known Limitations

The following capabilities were not completed:

- AWS Load Balancer Controller and Kubernetes Ingress.
- Route 53 custom-domain routing.
- ACM HTTPS integration.
- Prometheus, Grafana, and alerting.
- Fully automated platform bootstrap.

These capabilities are candidates for the next platform engineering project.

## 12. Teardown and Cost Management

The development infrastructure is destroyed after testing to avoid unnecessary costs. Each new session requires rebuilding the lab.

Terraform state was confirmed empty, and follow-up AWS CLI checks returned no remaining EC2 instances or EBS volumes in the project region.

The Terraform backend and any resources created outside the Terraform development state require separate cleanup verification.

## 13. Architecture Lessons

The project demonstrated the importance of separating responsibilities:

- Terraform provisions AWS infrastructure.
- GitHub Actions builds and publishes container images.
- Argo CD manages desired Kubernetes application state.
- Helm packages Kubernetes workloads.
- External Secrets Operator synchronizes credentials.
- EBS CSI provisions persistent storage.

A key improvement for future projects is to automate dependency ordering and platform bootstrapping so the environment can be reproduced consistently.
