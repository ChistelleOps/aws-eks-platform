# Runbook: EKS Authentication Failure After Cluster Rebuild

## Problem

After rebuilding the EKS cluster using Terraform, `kubectl` could not connect to the Kubernetes API.

**Error:**

```text
error: You must be logged in to the server
(the server has asked for the client to provide credentials)
```

The EKS cluster was created, but Kubernetes authentication failed.

## Root Cause

The AWS CLI was using this IAM user:

```text
arn:aws:iam::452395238296:user/aws-cli-terraform-DO-NOT-DELETE
```

However, the EKS cluster was configured to grant administrator access through a different IAM role:

```text
arn:aws:iam::452395238296:role/eks-platform-admin
```

The IAM user could assume the administrator role, but `kubectl` was not configured to use it.

**Important:** AWS authentication and Kubernetes authorization are related but different. Having permission to create an EKS cluster does not automatically mean an IAM user has Kubernetes administrator access.

## Troubleshooting Steps

### 1. Verify AWS identity

```bash
aws sts get-caller-identity
```

Check which IAM user or role the terminal is using.

### 2. Check EKS Access Entries

```bash
aws eks list-access-entries \
  --cluster-name platform-dev-eks \
  --region us-east-1
```

Verify that the administrator role is registered:

```text
arn:aws:iam::452395238296:role/eks-platform-admin
```

### 3. Verify permission to assume the role

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::452395238296:role/eks-platform-admin \
  --role-session-name eks-admin-test \
  --query 'AssumedRoleUser.Arn' \
  --output text
```

If successful, AWS returns an assumed-role ARN.

**Note:** This command only tests role assumption. It does not permanently switch the terminal to that role.

### 4. Configure kubectl with the administrator role

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name platform-dev-eks \
  --role-arn arn:aws:iam::452395238296:role/eks-platform-admin
```

The `--role-arn` option tells the AWS CLI to assume the specified IAM role when obtaining an EKS authentication token.

### 5. Verify Kubernetes access

```bash
kubectl get nodes
```

Expected result: the cluster's worker nodes are listed with `Ready` status.

## Additional Issue: Outdated AWS CLI

During troubleshooting, the original AWS CLI version was:

```text
aws-cli/2.12.6
```

This version did not recognize:

```bash
aws eks list-access-entries
```

Updating AWS CLI to a newer version resolved the missing-command problem and allowed us to inspect EKS Access Entries.

## Quick Fix for Future Cluster Rebuilds

After `terraform apply` completes, run:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name platform-dev-eks \
  --role-arn arn:aws:iam::452395238296:role/eks-platform-admin

kubectl get nodes
```

This works as long as the current AWS identity can assume the administrator role and that role has the required EKS access permissions.

## Lessons Learned

1. Terraform infrastructure permissions and Kubernetes access are not the same thing.
2. EKS Access Entries determine which IAM identities can authenticate to the cluster.
3. `aws eks update-kubeconfig --role-arn` configures role-based authentication for kubectl.
4. Always check the current AWS identity before troubleshooting Kubernetes permissions.
5. Keep AWS CLI updated to support newer EKS features.
6. Document recurring problems so future deployments are faster and less stressful.

## Status

**Resolved — October 26, 2026**

The EKS administrator role was successfully assumed, kubeconfig was updated, and Kubernetes access was restored.