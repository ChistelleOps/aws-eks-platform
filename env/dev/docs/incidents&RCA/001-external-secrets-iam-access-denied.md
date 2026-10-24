# Incident Report: External Secrets Operator Unable to Retrieve PostgreSQL Credentials

**Project:** AWS EKS Platform  
**Environment:** Development  
**Date:** October 24, 2026  
**Affected Components:** AWS Secrets Manager, IAM, EKS Pod Identity, External Secrets Operator, Argo CD  
**Status:** Root cause identified; Terraform correction and recovery verification pending

## 1. Incident Summary

During the deployment of a Kubernetes platform on Amazon EKS, the External Secrets Operator (ESO) failed to synchronize PostgreSQL credentials from AWS Secrets Manager.

The ExternalSecret resource reported `SecretSyncedError`, and Argo CD marked the External Secrets configuration application as `Degraded`.

Investigation revealed a typo in the AWS region portion of an IAM permissions policy ARN.

**Root cause:** The deployed IAM policy referenced `us-east1` instead of `us-east-1`.

Although the IAM policy was attached to the correct role and included the required Secrets Manager actions, the incorrect resource ARN prevented AWS from granting access.

## 2. Expected Behavior

The intended authentication and secret retrieval workflow was:

1. External Secrets Operator runs inside the EKS cluster.
2. EKS Pod Identity provides temporary AWS credentials through `platform-external-secrets-role`.
3. The IAM policy authorizes the role to retrieve `platform/dev/postgres`.
4. External Secrets Operator reads the secret from AWS Secrets Manager.
5. Kubernetes creates or updates the `postgres-credentials` Secret.
6. PostgreSQL consumes the credentials during deployment.

## 3. Initial Symptoms

After deploying Argo CD and External Secrets Operator, the GitOps bootstrap completed successfully.

However, the Argo CD application statuses showed:

| Application | Sync Status | Health Status |
|---|---|---|
| external-secrets-config | Synced | Degraded |
| platform-apps | OutOfSync | Healthy |
| postgres | OutOfSync | Missing |

The PostgreSQL ExternalSecret also reported:

```text
NAME                   STATUS              READY
postgres-credentials   SecretSyncedError   False
```

Argo CD displayed:

```text
could not get secret data from provider
```

This indicated that the secret synchronization process was failing.

## 4. Troubleshooting Timeline

### Investigation 1 — Verify External Secrets Operator

Command:

```bash
kubectl get pods -n external-secrets
```

Result:

All three ESO components were running with no restarts:

- external-secrets
- external-secrets-cert-controller
- external-secrets-webhook

**Conclusion:** The operator installation appeared healthy.

### Investigation 2 — Verify ClusterSecretStore

Command:

```bash
kubectl get clustersecretstores
```

Result:

```text
NAME                  STATUS   READY
aws-secrets-manager   Valid    True
```

**Conclusion:** The ClusterSecretStore configuration was valid. However, this did not guarantee that every requested secret could be retrieved.

### Investigation 3 — Inspect ExternalSecret

Commands:

```bash
kubectl get externalsecrets -A

kubectl describe externalsecret postgres-credentials -n default
```

Result:

```text
Reason: SecretSyncedError
Message: could not get secret data from provider
```

Repeated `UpdateFailed` events confirmed the synchronization problem.

**Conclusion:** More detailed operator logs were required.

### Investigation 4 — Inspect External Secrets Logs

Command:

```bash
kubectl logs -n external-secrets \
  deployment/external-secrets \
  --since=10m \
  --tail=100
```

The logs revealed:

```text
AccessDeniedException:
User: assumed-role/platform-external-secrets-role
is not authorized to perform:
secretsmanager:GetSecretValue

because no identity-based policy allows the action
```

**Conclusion:** ESO successfully assumed the intended IAM role, but AWS denied access to the secret.

This narrowed the investigation to IAM authorization.

### Investigation 5 — Verify the Secret Exists

Command:

```bash
aws secretsmanager describe-secret \
  --secret-id platform/dev/postgres \
  --region us-east-1 \
  --query '{Name:Name,ARN:ARN}' \
  --output table
```

Result:

AWS returned the secret name and ARN.

**Conclusion:** The secret existed in the expected region.

### Investigation 6 — Verify IAM Policy Attachment

Command:

```bash
aws iam list-attached-role-policies \
  --role-name platform-external-secrets-role \
  --query 'AttachedPolicies[*].[PolicyName,PolicyArn]' \
  --output table
```

Result:

The policy `platform-external-secrets-read` was attached.

**Conclusion:** The IAM role had a policy attachment, so the next step was to inspect the actual policy document.

### Investigation 7 — Inspect the Deployed IAM Policy

Commands:

```bash
aws iam get-policy \
  --policy-arn arn:aws:iam::452395238296:policy/platform-external-secrets-read \
  --query 'Policy.DefaultVersionId' \
  --output text
```

The default version was `v1`.

```bash
aws iam get-policy-version \
  --policy-arn arn:aws:iam::452395238296:policy/platform-external-secrets-read \
  --version-id v1 \
  --query 'PolicyVersion.Document' \
  --output json
```

The deployed policy contained:

```json
{
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Effect": "Allow",
  "Resource": "arn:aws:secretsmanager:us-east1:452395238296:secret:platform/dev/postgres-*"
}
```

**Root cause identified:** The resource ARN contained an invalid region string.

## 5. Root Cause Analysis

The IAM policy contained the required actions and was attached to the correct role.

However, its resource ARN was incorrect.

**Incorrect:**

```text
arn:aws:secretsmanager:us-east1:452395238296:secret:platform/dev/postgres-*
```

**Correct:**

```text
arn:aws:secretsmanager:us-east-1:452395238296:secret:platform/dev/postgres-*
```

The difference was a single missing hyphen.

Because IAM evaluates permissions against the requested resource, the policy statement did not match the actual Secrets Manager resource ARN.

Consequently, AWS denied `secretsmanager:GetSecretValue`.

The Terraform configuration generated the ARN using:

```hcl
resources = [
  "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:platform/dev/postgres-*"
]
```

The deployed policy confirms the incorrect region value. The exact source of that value in Terraform inputs still needs to be verified.

## 6. Corrective Actions

The planned correction is to update the incorrect AWS region value or ARN construction in Terraform.

Expected resource ARN:

```hcl
resources = [
  "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:platform/dev/postgres-*"
]
```

Preferably, retain the variable-based ARN construction and correct the variable at its source.

Before applying:

```bash
terraform fmt
terraform validate
terraform plan -out=tfplan
```

Review the plan to ensure the correction updates the intended IAM policy without unexpectedly replacing infrastructure.

After applying, verify synchronization:

```bash
kubectl get externalsecrets -A
kubectl get secret postgres-credentials -n default
kubectl get applications -n argocd
```

**Recovery verification is still pending.** The incident should not be marked resolved until the ExternalSecret reports `Ready=True` and dependent workloads are checked.

## 7. Lessons Learned

### IAM permissions require more than the correct action

Even when an IAM policy includes `secretsmanager:GetSecretValue`, access can fail if the resource ARN is incorrect.

### Always inspect deployed configuration

Terraform source code may look correct while a variable produces an incorrect value. Inspecting the actual IAM policy in AWS revealed the problem.

### Follow the dependency chain

The troubleshooting process moved through:

Kubernetes pods → ClusterSecretStore → ExternalSecret → Operator logs → AWS Secrets Manager → IAM role → IAM policy.

This avoided unnecessary changes to working components.

### Terraform validation is not a guarantee of cloud authorization

`terraform validate` checks configuration validity, but it does not prove that a constructed ARN matches a real AWS resource.

### Improve automated validation

Future improvements should include:

- Validate AWS region inputs against known AWS region names.
- Prefer resource ARN outputs instead of manually constructing ARNs when possible.
- Add IAM policy checks to CI/CD.
- Verify ExternalSecret readiness after deployment.
- Fail deployment verification when required secrets are unavailable.

## 8.  Explanation

**Production-style issue I troubleshothed involving Kubernetes and AWS IAM.**

During an AWS EKS platform deployment, our PostgreSQL ExternalSecret failed to retrieve credentials from AWS Secrets Manager.

I started by checking the External Secrets Operator pods and the ClusterSecretStore. Both appeared healthy, but the ExternalSecret reported a synchronization error.

I reviewed the operator logs and found an AWS `AccessDeniedException` for `secretsmanager:GetSecretValue`.

I verified that the secret existed, confirmed the IAM role was being assumed successfully, and checked that the required policy was attached.

Then I inspected the deployed IAM policy and discovered that the resource ARN contained a typo in the AWS region: `us-east1` instead of `us-east-1`.

The policy actions were correct, but the resource ARN didn't match the actual secret.

This reinforced the importance of checking the deployed IAM policy and validating resource ARNs rather than assuming that a successful Terraform deployment means permissions are correct.

## 9. Key Takeaway

**A healthy Kubernetes operator and a correctly attached IAM policy do not guarantee successful authorization.**

Always verify the action, resource ARN, principal, and effective permissions when troubleshooting AWS access errors.
