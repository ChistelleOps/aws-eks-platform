# AWS EKS Platform Engineering — Project Roadmap

## Project Goal

Build a production-style, multi-tenant Kubernetes platform on AWS using Terraform, Amazon EKS, Argo CD, Helm, GitHub Actions, monitoring, and security best practices.

Demonstrate practical DevOps, SRE, and Platform Engineering skills.

## Completed Milestones

### Milestone 1 — Application Development and CI/CD
- [x] Build FastAPI application
- [x] Containerize applications with Docker
- [x] Configure GitHub Actions and Amazon ECR workflows

### Milestone 2 — AWS Infrastructure
- [x] Configure Terraform remote state in S3
- [x] Build VPC, public/private subnets, routing, and NAT
- [x] Provision EKS cluster and managed worker nodes
- [x] Configure IAM and EKS access
- [x] Configure EBS CSI driver

### Milestone 3 — GitOps
- [x] Install Argo CD
- [x] Implement App of Apps
- [x] Deploy applications using Helm and GitOps

### Milestone 4 — Storage and Secrets
- [x] Deploy PostgreSQL
- [x] Configure persistent storage
- [x] Integrate AWS Secrets Manager
- [x] Deploy External Secrets Operator

### Milestone 5 — Monitoring and Alerting
- [x] Deploy Prometheus and Grafana
- [x] Configure FastAPI metrics collection
- [x] Create Grafana dashboard
- [x] Configure three FastAPI alert rules
- [x] Verify monitoring and alert rules

## Milestone 6 — Ingress, DNS, and HTTPS (Next)

**Domain:** christelconsult.com  
**Domain registrar:** IONOS  
**AWS region:** us-east-1

### AWS Load Balancer Controller
- [ ] Configure IAM permissions using EKS Pod Identity or IRSA
- [ ] Install AWS Load Balancer Controller
- [ ] Configure Kubernetes Ingress resources
- [ ] Verify ALB and target groups

### Route 53 and Domain
- [ ] Create Route 53 public hosted zone for christelconsult.com
- [ ] Update nameservers at IONOS
- [ ] Verify DNS delegation

### HTTPS
- [ ] Request ACM certificate
- [ ] Validate certificate using DNS
- [ ] Configure HTTPS listener on ALB
- [ ] Redirect HTTP to HTTPS

### Application URLs
- [ ] api.christelconsult.com → FastAPI
- [ ] www.christelconsult.com → Portfolio
- [ ] christelconsult.com → Portfolio (optional)

### Validation
- [ ] Verify public DNS resolution
- [ ] Test HTTPS endpoints
- [ ] Verify ALB health checks and routing
- [ ] Test deployment and rollback through Argo CD

## Milestone 7 — SRE, Reliability, and Security
- [ ] Configure health probes and resource limits
- [ ] Test Horizontal Pod Autoscaling
- [ ] Perform controlled application failure tests
- [ ] Test load and recovery
- [ ] Review Kubernetes RBAC and network security
- [ ] Validate backup and recovery procedures

## Milestone 8 — Documentation and Portfolio
- [ ] Finalize architecture diagram
- [ ] Document deployment and teardown
- [ ] Write Grafana troubleshooting runbook
- [ ] Document common EKS and Argo CD incidents
- [ ] Update GitHub README
- [ ] Prepare project walkthrough for interviews

## Cost Management

This is a learning environment, not a continuously running production system.

- Keep EKS offline between testing sessions.
- Validate Terraform and Helm configurations locally when possible.
- Review retained EBS volumes and load balancers during teardown.
- Check AWS billing after destroying infrastructure.
- Rebuild EKS only when integration testing is required.

## Current Status

**Completed:** Milestones 1–5  
**Next:** Milestone 6 — Ingress, DNS, and HTTPS  
**Immediate priority:** Safely tear down the running EKS environment before continuing offline development.

## Definition of Done

The project is complete when applications can be deployed through GitOps, securely accessed through HTTPS using christelconsult.com, monitored, troubleshot, and rebuilt or destroyed reproducibly using infrastructure as code.