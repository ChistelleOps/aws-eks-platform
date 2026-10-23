# Amazon ECS Fargate — Proof of Concept

## Objective

Deploy two containerized applications to AWS using Terraform, Amazon ECR, and Amazon ECS Fargate.

This POC demonstrates container deployment, networking, IAM, application logging, infrastructure automation, and cost-conscious cleanup.

## Architecture

```text
Local Development
    |
    | Docker build
    v
Docker Images
    |
    | Docker push
    v
Amazon ECR
    |
    | Image pull
    v
Amazon ECS Cluster
    |
    +-- FastAPI Service (Fargate)
    |      Port 8000
    |
    +-- Portfolio Service (Fargate)
           Port 80

Infrastructure:
- VPC: 10.20.0.0/16
- Public Subnet A: 10.20.1.0/24
- Public Subnet B: 10.20.2.0/24
- Internet Gateway
- Public Route Table
- Security Group
- IAM Execution Role
- CloudWatch Logs
```

Each Fargate task receives its own network interface and public IPv4 address.

Inbound application access is restricted to an approved IPv4 address using security group rules.

This configuration is intended for temporary learning and testing, not public production deployment.

## Prerequisites

- AWS account and configured AWS CLI
- Docker
- Terraform
- AWS IAM permissions for the required resources
- An existing S3 bucket for Terraform remote state

## 1. Configure Terraform Backend

Update `backend.tf` with an existing S3 bucket name and a unique state key for this environment.

The backend uses S3 native state locking.

```bash
terraform init
```

Run Terraform commands from the `env/ecs-poc` directory.

## 2. Validate Infrastructure

```bash
terraform fmt -check
terraform validate
terraform plan
```

Review the proposed changes and potential AWS charges before deployment.

## 3. Create ECR Repositories

The ECR repositories must exist before images can be pushed.

For the initial bootstrap:

```bash
terraform apply \
  -target=aws_ecr_repository.platform_api \
  -target=aws_ecr_repository.portfolio
```

Targeted applies are used here only for initial image-registry bootstrapping. Normal Terraform operations should use a complete plan.

## 4. Authenticate Docker to ECR

```bash
AWS_REGION=us-east-1

API_ECR_URL=$(terraform output -raw platform_api_ecr_url)
PORTFOLIO_ECR_URL=$(terraform output -raw portfolio_ecr_url)
ECR_REGISTRY="${API_ECR_URL%%/*}"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
```

## 5. Build and Push Applications

Run these commands from the repository root:

```bash
docker build -t platform-api:v1 ./apps/platform-api
docker build -t portfolio:v1 ./apps/portfolio
```

Then return to `env/ecs-poc` to retrieve the repository URLs, or use the URLs obtained earlier.

```bash
docker tag platform-api:v1 "$API_ECR_URL:v1"
docker push "$API_ECR_URL:v1"

docker tag portfolio:v1 "$PORTFOLIO_ECR_URL:v1"
docker push "$PORTFOLIO_ECR_URL:v1"
```

## 6. Deploy ECS Services

After both images exist in ECR:

```bash
terraform plan
terraform apply
```

For testing, set `desired_count = 1` for each ECS service.

## 7. Validate Applications

In the AWS ECS console:

1. Open the ECS cluster.
2. Verify both services have one running task.
3. Open each running task and locate its public IPv4 address.
4. Test the endpoints.

FastAPI:

```text
http://<API_PUBLIC_IP>:8000/health
```

Portfolio:

```text
http://<PORTFOLIO_PUBLIC_IP>/
```

The security group permits inbound access only from the configured approved IP address.

## 8. Check CloudWatch Logs

Log groups:

```text
/ecs/aws-eks-platform/poc/platform-api
/ecs/aws-eks-platform/poc/portfolio
```

Check application startup messages and HTTP access logs.

## 9. Stop Running Tasks

Change both ECS services to:

```hcl
desired_count = 0
```

Then:

```bash
terraform plan
terraform apply
```

Verify that both services have zero running tasks.

## 10. Destroy the POC

The ECR repositories contain images. Remove their images before destroying the repositories, unless the repository configuration explicitly supports force deletion.

```bash
aws ecr batch-delete-image \
  --repository-name aws-eks-platform/platform-api \
  --image-ids imageTag=v1 \
  --region us-east-1

aws ecr batch-delete-image \
  --repository-name aws-eks-platform/portfolio \
  --image-ids imageTag=v1 \
  --region us-east-1
```

Then review and destroy:

```bash
terraform plan -destroy
terraform destroy
```

The S3 backend bucket is managed separately and is not destroyed by this ECS configuration.

## Lessons Learned

- ECS Fargate runs containers without requiring EC2 host management.
- ECR provides private image storage for ECS deployments.
- ECS task definitions specify container images, CPU, memory, ports, and logging.
- ECS services maintain the desired number of running tasks.
- Security groups control access to application ports.
- CloudWatch provides centralized container logs.
- Terraform enables repeatable deployment and cleanup.
- Remote state and locking help maintain consistent infrastructure management.

## Future Improvements

- Use private subnets and an Application Load Balancer.
- Add HTTPS and custom-domain routing.
- Automate container builds and deployment through CI/CD.
- Improve application health checks and monitoring.
- Introduce more granular IAM permissions and service-level security groups.

These improvements will be explored in the EKS phase.
