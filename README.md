# AWS Container Platform — ECS to EKS

A hands-on DevOps and cloud infrastructure project demonstrating how to containerize applications, provision AWS infrastructure using Terraform, deploy workloads to Amazon ECS Fargate, and evolve the platform toward Kubernetes on Amazon EKS.

## Project Overview

This project follows a practical two-phase approach:

**Phase 1: Amazon ECS Fargate — Proof of Concept**

Deploy and validate two containerized applications using AWS-managed container infrastructure.

**Phase 2: Amazon EKS — Kubernetes Platform**

Build a production-style Kubernetes environment with Infrastructure as Code, CI/CD, GitOps, networking, security, and observability.

## Applications

| Application | Technology | Port | Purpose |
|---|---|---|---|
| Platform API | Python, FastAPI | 8000 | API service with a health-check endpoint |
| Portfolio | HTML, Nginx | 80 | Static portfolio website |

## Technologies

- **Cloud:** AWS
- **Containers:** Docker
- **Container orchestration:** Amazon ECS Fargate, Amazon EKS
- **Container registry:** Amazon ECR
- **Infrastructure as Code:** Terraform
- **Networking:** Amazon VPC, public/private subnets, routing, security groups
- **Logging:** Amazon CloudWatch
- **CI/CD:** GitHub Actions
- **Planned Kubernetes tooling:** Helm, Argo CD, Kubernetes Ingress
- **Terraform backend:** Amazon S3 with versioning and state locking

## ECS Proof of Concept

The ECS POC has been successfully deployed and tested.

### Completed

- Built two Docker images locally.
- Provisioned two Amazon ECR repositories using Terraform.
- Pushed Docker images to ECR.
- Provisioned an ECS cluster using AWS Fargate.
- Created a dedicated VPC with two public subnets.
- Configured an internet gateway, routing, and security group rules.
- Configured IAM permissions for ECS task execution.
- Deployed the FastAPI and portfolio applications as ECS services.
- Verified application availability through public IPv4 addresses.
- Verified container logs in Amazon CloudWatch.
- Scaled ECS services to zero after testing.
- Cleaned up the POC infrastructure using Terraform.
- Used Amazon S3 for remote Terraform state management.

See [ECS POC Documentation](env/ecs-poc/README.md) for architecture and deployment instructions.

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
└── README.md
```

## EKS Roadmap

The next phase focuses on:

1. Kubernetes fundamentals and local cluster testing.
2. Amazon EKS infrastructure provisioning.
3. Kubernetes Deployments and Services.
4. Helm application packaging.
5. GitHub Actions CI/CD pipelines.
6. Argo CD and GitOps.
7. Kubernetes Ingress, HTTPS, and custom-domain routing.
8. Secrets management, monitoring, and security.
9. Infrastructure validation and cleanup.

## Cost Management

This project uses short-lived cloud environments to minimize unnecessary AWS charges.

Resources are provisioned for testing and removed when no longer required. Terraform state is stored separately in S3.

## Project Status

- ECS Fargate POC: Completed
- EKS platform: In progress

## Author

[ChistelleOps](https://github.com/ChistelleOps)
