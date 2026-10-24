# Scripts — AWS EKS Platform

### Bootstrap GitOps — `bootstrap_gitops.sh`

**Purpose:** Register the parent Argo CD Application that starts the GitOps workflow.

**Prerequisites:**
- EKS cluster is running and accessible.
- `kubectl` is configured for the correct cluster.
- Argo CD is installed in the `argocd` namespace.
- External Secrets Operator is installed in the `external-secrets` namespace.
- `gitops/argocd/root-app.yaml` exists.

**Run from the repository root:**

```bash
./scripts/bootstrap_gitops.sh
```

**What the script does:**

1. Changes to the repository root automatically.
2. Verifies Kubernetes connectivity.
3. Displays the current Kubernetes context.
4. Waits up to 300 seconds for the Argo CD server Deployment to become available.
5. Waits up to 300 seconds for the External Secrets Deployment to become available.
6. Applies `gitops/argocd/root-app.yaml` to register the parent Argo CD Application.

**Expected final message:**

```text
GitOps bootstrap completed!
Next: wait for the ExternalSecret and verify PostgreSQL credentials.
```

**Verification:**

```bash
kubectl get applications -n argocd
```

Check whether the parent Application exists and inspect its sync and health status.

**Troubleshooting:**

If Argo CD is unavailable:

```bash
kubectl get pods -n argocd
kubectl describe deployment argocd-server -n argocd
```

If External Secrets Operator is unavailable:

```bash
kubectl get pods -n external-secrets
kubectl describe deployment external-secrets -n external-secrets
```

If the parent Application does not appear:

```bash
kubectl get applications -n argocd
kubectl get events -n argocd --sort-by=.lastTimestamp
```

**Important:** Successful execution confirms that the parent Application was submitted to Kubernetes. It does not guarantee that every child Application has synchronized successfully.



### Verify PostgreSQL credentials — `check_postgres_secret.sh`

**Purpose:** Verify that External Secrets Operator has synchronized PostgreSQL credentials into Kubernetes.

**Prerequisites:**
- EKS is running and `kubectl` is connected to the correct cluster.
- External Secrets Operator is installed and running.
- The `postgres-credentials` ExternalSecret exists in the `default` namespace.
- Its referenced secret provider and credentials are configured.

**Run from the repository root:**

```bash
./scripts/check_postgres_secret.sh
```

**What the script does:**

1. Waits up to 300 seconds for `externalsecret/postgres-credentials` to report `Ready=True`.
2. Checks that the Kubernetes Secret named `postgres-credentials` exists in the `default` namespace.
3. Prints a success message if both checks pass.

**Expected output:**

```text
Waiting for PostgreSQL credentials...
externalsecret.external-secrets.io/postgres-credentials condition met
Checking Kubernetes Secret...
PostgreSQL credentials are available!
```

**Manual verification:**

```bash
kubectl get externalsecret postgres-credentials -n default
kubectl get secret postgres-credentials -n default
```

**Troubleshooting:**

If the ExternalSecret does not become ready:

```bash
kubectl describe externalsecret postgres-credentials -n default
```

Check the External Secrets Operator logs:

```bash
kubectl logs -n external-secrets deployment/external-secrets --tail=100
```

If the ExternalSecret is ready but the Kubernetes Secret is missing, inspect the ExternalSecret's target configuration and operator events.

**Security:** Do not print or commit PostgreSQL passwords. The script checks resource readiness and existence without displaying credential values.

**Note:** This script confirms credential synchronization, not that PostgreSQL can authenticate successfully or that the database is healthy.


### Inspect Terraform plans — `inspect_plan.py`

**Purpose:** Analyze Terraform plan files before applying infrastructure changes.

This Python utility converts a saved Terraform plan into JSON and displays resource changes by category.

**Prerequisites:**
- Python 3
- Terraform CLI
- An initialized Terraform environment
- A saved Terraform plan file

**Step 1 — Generate a Terraform plan**

From the repository root:

```bash
terraform -chdir=env/dev plan -out=tfplan
```

**Step 2 — Inspect the plan**

Run from the repository root using the plan file path:

```bash
python3 scripts/inspect_plan.py summary --plan env/dev/tfplan
```

For this repository, the recommended and verified approach is to run the script from the Terraform environment directory:

```bash
cd env/dev
python3 ../../scripts/inspect_plan.py summary
```

**Available commands:**

| Command | Description |
|---|---|
| `summary` | Count resource creation, update, and deletion actions |
| `eks` | Display planned EKS clusters, node groups, and add-ons |
| `iam` | Display IAM roles, policies, and EKS access entries |
| `security` | List security groups and their rules |
| `security-details` | Display detailed security group rule configurations |

**Examples from `env/dev`:**

```bash
python3 ../../scripts/inspect_plan.py summary
python3 ../../scripts/inspect_plan.py eks
python3 ../../scripts/inspect_plan.py iam
python3 ../../scripts/inspect_plan.py security
python3 ../../scripts/inspect_plan.py security-details
```

**Inspect a differently named plan:**

```bash
python3 ../../scripts/inspect_plan.py summary --plan custom.tfplan
```

**Example summary output:**

```text
Terraform Plan Summary
----------------------
create: 67
update: 0
delete: 0
```

**Important notes:**

- The script is read-only. It does not apply Terraform changes.
- Terraform must be initialized in the working directory.
- A saved plan is required before running the script.
- The `summary` category counts actions, not necessarily unique resources. For example, a replacement can count as both a deletion and a creation.
- Some security group attributes may be unknown until Terraform applies the configuration.
- Saved Terraform plans may contain sensitive information. Do not commit them to Git.

**Troubleshooting:**

If Terraform cannot find the plan file, check your current directory:

```bash
pwd
ls -lh tfplan
```

If Terraform reports missing providers or initialization errors:

```bash
terraform init
```

If the saved plan is outdated, generate a new plan before reviewing it.



### Install Argo CD — `install_argocd.sh`

**Purpose:** Install or upgrade Argo CD on the EKS cluster using Helm.

Argo CD is the GitOps controller used to synchronize Kubernetes resources with configurations stored in Git.

**Prerequisites:**

- EKS cluster is running.
- `kubectl` is configured for the correct cluster.
- Helm is installed.
- The user has sufficient Kubernetes permissions to install resources and create namespaces.
- `gitops/argocd/install/values.yaml` exists.
- Helm chart version `10.11.1` is available in the Argo Helm repository.

**Run from the repository root:**

```bash
./scripts/install_argocd.sh
```

**What the script does:**

1. Registers the Argo Helm chart repository.
2. Updates Helm repository metadata.
3. Installs or upgrades the `argocd` Helm release.
4. Creates the `argocd` namespace if needed.
5. Uses Helm chart version `10.11.1`.
6. Applies custom settings from `gitops/argocd/install/values.yaml`.
7. Waits up to 10 minutes for Helm's resource readiness checks.

**Verify the installation:**

```bash
helm list -n argocd
kubectl get pods -n argocd
kubectl get deployments -n argocd
```

Inspect the Argo CD server:

```bash
kubectl get deployment argocd-server -n argocd
```

**Troubleshooting:**

If the Helm installation fails:

```bash
helm status argocd -n argocd
kubectl get pods -n argocd
kubectl get events -n argocd --sort-by=.lastTimestamp
```

To inspect a failing pod:

```bash
kubectl describe pod POD_NAME -n argocd
kubectl logs POD_NAME -n argocd
```

Replace `POD_NAME` with the actual pod name.

**Important notes:**

- This script installs Argo CD but does not register our GitOps applications.
- The parent Argo CD Application is registered separately using `bootstrap_gitops.sh`.
- The script uses a relative values file path, so it should be run from the repository root.
- Running the script again invokes a Helm upgrade operation; it does not necessarily recreate the installation.
- Helm installation success does not guarantee that GitOps applications have synchronized.

**Next step:**

Install External Secrets Operator before running the GitOps bootstrap script.


### Install External Secrets Operator — `install_external_secrets.sh`

**Purpose:** Install or upgrade External Secrets Operator (ESO) in EKS using Helm.

ESO synchronizes credentials from external secret providers, such as AWS Secrets Manager, into Kubernetes Secrets.

**Prerequisites:**

- EKS cluster is running and accessible.
- `kubectl` is configured for the correct cluster.
- Helm is installed.
- Sufficient Kubernetes permissions to install Helm charts and create namespaces.
- `gitops/external-secrets/install/values.yaml` exists.
- Helm chart version `2.14.0` is available in the External Secrets chart repository.

**Run:**

```bash
./scripts/install_external_secrets.sh
```

The script automatically changes to the repository root, so it can also be invoked from another directory.

**What the script does:**

1. Moves to the repository root.
2. Adds or refreshes the External Secrets Helm repository.
3. Updates Helm repository metadata.
4. Installs or upgrades the `external-secrets` Helm release.
5. Creates the `external-secrets` namespace if necessary.
6. Uses chart version `2.14.0`.
7. Applies settings from `gitops/external-secrets/install/values.yaml`.
8. Waits up to 10 minutes for Helm readiness checks.

**Expected final message:**

```text
External Secrets Operator installation completed!
```

**Verify installation:**

```bash
helm list -n external-secrets
kubectl get pods -n external-secrets
kubectl get deployments -n external-secrets
```

**Verify the ESO CustomResourceDefinitions (CRDs):**

```bash
kubectl get crd | grep external-secrets
```

**Troubleshooting:**

Check Helm release status:

```bash
helm status external-secrets -n external-secrets
```

Check pods and events:

```bash
kubectl get pods -n external-secrets
kubectl get events -n external-secrets --sort-by=.lastTimestamp
```

Inspect operator logs:

```bash
kubectl logs -n external-secrets deployment/external-secrets --tail=100
```

**Important notes:**

- The script installs ESO but does not create PostgreSQL credentials.
- Successful installation does not confirm AWS Secrets Manager connectivity.
- AWS authentication and secret synchronization must be verified separately.
- Running the script again performs a Helm install-or-upgrade operation.
- Helm chart version `2.14.0` is pinned for repeatable installation.

**Next steps:**

Configure PostgreSQL credentials in AWS Secrets Manager, bootstrap the GitOps applications, and verify synchronization using `check_postgres_secret.sh`.



### Configure PostgreSQL credentials — `set_postgres_secret.sh`

**Purpose:** Securely update the PostgreSQL password stored in AWS Secrets Manager.

**AWS configuration:**

| Setting | Value |
|---|---|
| Secret name | `platform/dev/postgres` |
| AWS Region | `us-east-1` |
| Secret JSON key | `password` |
| AWS service | Secrets Manager |

**Prerequisites:**

- AWS CLI installed and authenticated.
- AWS credentials have `secretsmanager:DescribeSecret` and `secretsmanager:PutSecretValue` permissions for the target secret.
- The Secrets Manager secret already exists.
- The operator knows the intended AWS account ID.

**Run from the repository root:**

```bash
./scripts/set_postgres_secret.sh
```

**Interactive workflow:**

1. Displays the active AWS identity.
2. Prompts for the expected AWS account ID.
3. Cancels if the account IDs do not match.
4. Checks that `platform/dev/postgres` exists in `us-east-1`.
5. Requires typing `YES` before proceeding.
6. Prompts for the PostgreSQL password without displaying the characters.
7. Generates a JSON payload containing the `password` key.
8. Sends the payload to AWS Secrets Manager using standard input.
9. Displays the secret ARN and new version ID.

**Expected final message:**

```text
PostgreSQL secret updated successfully.
```

**Verify the secret metadata without revealing its value:**

```bash
aws secretsmanager describe-secret \
  --secret-id platform/dev/postgres \
  --region us-east-1 \
  --query '{Name:Name,LastChangedDate:LastChangedDate}' \
  --output table
```

**Troubleshooting:**

- **AWS account mismatch:** Verify your active AWS profile and credentials.
- **ResourceNotFoundException:** Confirm Terraform has created the secret in the correct region.
- **AccessDeniedException:** Verify IAM permissions for Secrets Manager.
- **Empty password:** The script rejects empty input.
- **Incorrect password:** Rerun the script with the correct value, after verifying the target account.

**Security considerations:**

- Never commit passwords or secret payloads to Git.
- Never paste the PostgreSQL password into documentation or logs.
- Avoid running the script with Bash tracing (`bash -x`).
- The script uses hidden password input and avoids placing the secret directly in AWS CLI command-line arguments.
- Updating a secret in Secrets Manager does not automatically change an existing PostgreSQL database user's password.

**Next step:** After External Secrets Operator and the PostgreSQL ExternalSecret are configured, run:

```bash
./scripts/check_postgres_secret.sh
```

This verifies that the Kubernetes Secret is available.





### Validate Kubernetes manifests and Helm — `validate_k8s.py`

**Purpose:** Validate Kubernetes YAML files, PostgreSQL resource references, and Helm chart templates before deployment.

This script runs locally and does not require an active Kubernetes cluster.

**Prerequisites:**

- Python 3
- Python package `PyYAML`
- Helm CLI
- kubeconform CLI
- Kubernetes manifests under `kubernetes/`
- PostgreSQL Helm chart under `helm/postgres/`

Install the Python dependency if necessary:

```bash
python3 -m pip install PyYAML
```

Helm and kubeconform must also be installed and available in your `PATH`.

**Run from the repository root:**

```bash
python3 scripts/validate_k8s.py
```

The script uses its own file location to find the repository root, so it can also be invoked from another directory.

**Validation stages:**

**1. YAML syntax**

Parses every `.yaml` file under `kubernetes/` using PyYAML.

**2. PostgreSQL resource references**

Checks that:

- The Deployment's first volume references the expected PVC.
- The PVC references the correct StorageClass.
- The Service selector matches the Pod template labels.

**3. Kubernetes schema validation**

Uses kubeconform with strict validation against Kubernetes version `1.33.0`.

**4. Helm validation**

Runs:

```bash
helm lint helm/postgres
```

Renders the chart locally:

```bash
helm template dev helm/postgres
```

Validates the rendered resources using kubeconform.

**Expected final output:**

```text
Helm validation passed!

All checks passed!
```

**Troubleshooting:**

If Python cannot import `yaml`, install PyYAML in the active Python environment.

If Helm or kubeconform cannot be found, verify that the tools are installed and accessible in `PATH`.

If a PostgreSQL reference check fails, compare the relevant Deployment, Service, PVC, and StorageClass manifests.

If kubeconform fails, inspect the reported resource and field. Some custom resources require additional schemas or configuration.

**Important limitations:**

- This script does not deploy Kubernetes resources.
- It does not check cluster connectivity or runtime health.
- It validates `.yaml` files under `kubernetes/`, not `.yml` files.
- It checks specific PostgreSQL relationships, not every reference in every manifest.
- YAML parsing confirms syntax, not that Kubernetes accepts the resource.
- Helm rendering uses the chart's default values unless configured otherwise.

**Recommended usage:** Run before opening a pull request, before deploying Kubernetes changes, and after modifying PostgreSQL manifests or Helm templates.


### Validate the platform configuration — `validate_platform.sh`

**Purpose:** Run the repository's Terraform, Kubernetes, Helm, shell, and GitOps YAML validation checks from one command.

This script validates source configuration locally. It does not deploy infrastructure or verify live EKS workloads.

**Prerequisites:**

- Terraform CLI, with `env/dev` initialized
- Python 3 with PyYAML installed
- Helm CLI
- kubeconform CLI
- Bash

**Run:**

```bash
./scripts/validate_platform.sh
```

The script automatically changes to the repository root.

**Validation stages:**

| Stage | Command or operation | Checks |
|---|---|---|
| 1. Terraform | `terraform -chdir=env/dev validate` | Terraform configuration validity |
| 2. Kubernetes and Helm | `python3 scripts/validate_k8s.py` | YAML, PostgreSQL references, Kubernetes schemas, Helm chart |
| 3. Shell scripts | `bash -n` for each `scripts/*.sh` | Bash syntax |
| 4. GitOps | Python `yaml.safe_load_all()` | YAML syntax in `gitops/` |

**Expected final output:**

```text
==================================
 ALL PLATFORM CHECKS PASSED!
==================================
```

**When to run:**

- Before committing changes to GitHub
- Before creating a pull request
- After modifying Terraform modules
- After changing Kubernetes or Helm configuration
- After modifying GitOps YAML or shell scripts

**Troubleshooting:**

If Terraform validation fails, review the Terraform error and confirm that `env/dev` is initialized.

If Kubernetes validation fails, run:

```bash
python3 scripts/validate_k8s.py
```

If a shell script fails syntax validation, inspect it individually:

```bash
bash -n scripts/SCRIPT_NAME.sh
```

If GitOps YAML validation fails, inspect the reported file for YAML syntax errors.

**Limitations:**

- Does not run `terraform plan`.
- Does not deploy or modify AWS infrastructure.
- Does not connect to the EKS cluster.
- Does not check live Pods, Services, storage, or Argo CD synchronization.
- `bash -n` checks shell syntax, not runtime behavior.
- GitOps YAML files are parsed for syntax, but are not schema-validated by this script.

**Recommended usage:** Use this as the primary local validation command before committing changes.
