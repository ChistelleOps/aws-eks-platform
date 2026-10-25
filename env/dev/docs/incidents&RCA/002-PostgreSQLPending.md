# Incident Report 002: PostgreSQL Pending Due to Missing Kubernetes StorageClass

**Project:** AWS EKS Platform Engineering Lab  
**Environment:** Development — Amazon EKS (`platform-dev-eks`)  
**Technologies:** Kubernetes, AWS EBS CSI Driver, PostgreSQL, Helm, Argo CD, Amazon EBS  
**Severity:** Development deployment blocker  
**Status:** Resolved

## 1. Incident Summary

During the deployment of PostgreSQL to an Amazon EKS cluster using Helm and Argo CD, the PostgreSQL pod could not start because its PersistentVolumeClaim (PVC) remained in `Pending` status.

Investigation revealed that the PVC requested a `gp3` StorageClass, but the EKS cluster only had the default `gp2` StorageClass available.

The required `gp3` StorageClass manifest already existed in the GitHub repository but had not been deployed to the Kubernetes cluster.

## 2. Symptoms

The PostgreSQL application initially appeared as unhealthy or missing in Argo CD.

The PostgreSQL pod and PVC remained in `Pending` status.

The following error was found in the PVC events:

```text
ProvisioningFailed:
storageclass.storage.k8s.io "gp3" not found
```

Running:

```bash
kubectl get storageclass
```

showed that only `gp2` was available.

## 3. Root Cause

The PostgreSQL Helm chart requested persistent storage using the `gp3` StorageClass.

Although the project contained the manifest at:

```text
kubernetes/storage/storageclass.yaml
```

the manifest was not included in an active Argo CD Application.

As a result, Kubernetes could not find the requested StorageClass and could not provision the EBS volume needed by PostgreSQL.

## 4. Troubleshooting Steps

**Step 1 — Investigated PostgreSQL deployment status**

Checked the application in Argo CD and inspected the Kubernetes pod and PVC.

**Step 2 — Examined PVC events**

The events showed that the requested StorageClass did not exist.

**Step 3 — Checked available StorageClasses**

```bash
kubectl get storageclass
```

Only `gp2` was present.

**Step 4 — Reviewed the GitHub repository**

Found an existing `gp3` StorageClass manifest with the EBS CSI provisioner:

```yaml
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
```

The issue was not missing configuration code. It was missing deployment automation.

## 5. Resolution

Instead of manually creating the StorageClass using `kubectl apply`, we integrated the existing manifest into the GitOps workflow.

Created:

```text
gitops/argocd/applications/storage.yaml
```

The new Argo CD Application referenced the existing Kubernetes storage directory and selected only the StorageClass manifest:

```yaml
source:
  repoURL: https://github.com/ChistelleOps/aws-eks-platform.git
  targetRevision: main
  path: kubernetes/storage
  directory:
    include: storageclass.yaml
```

The `include` configuration prevented the Application from also deploying the separate PostgreSQL PVC manifest, which could have conflicted with the PVC managed by the Helm chart.

After committing and pushing the change, the parent Argo CD Application discovered the new storage Application.

Argo CD then deployed the `gp3` StorageClass.

## 6. Validation

The following Argo CD Applications were confirmed healthy:

```text
NAME                      SYNC STATUS   HEALTH STATUS
external-secrets-config   Synced        Healthy
postgres                  Synced        Healthy
storage                   Synced        Healthy
```

The PostgreSQL PVC was successfully provisioned:

```text
NAME                STATUS   CAPACITY   STORAGECLASS
dev-postgres-data   Bound    20Gi       gp3
```

The corresponding PersistentVolume was also `Bound`, confirming that Kubernetes had successfully provisioned storage.

## 7. Lessons Learned

- A valid Kubernetes manifest in GitHub does not mean the resource exists in the cluster.
- Kubernetes PVC events are useful for identifying storage provisioning failures.
- StorageClasses must exist before PVCs requesting them can be provisioned.
- Argo CD can manage cluster-level Kubernetes resources such as StorageClasses.
- GitOps reduces configuration drift by keeping Kubernetes resources defined in version control.
- Argo CD Applications should avoid managing resources already owned by another Helm release or Application.

## 8. Preventive Improvements

- Include StorageClass configuration in the GitOps bootstrap process.
- Add validation to confirm required StorageClasses exist before deploying stateful workloads.
- Add storage readiness checks to platform validation scripts.
- Review persistent volume reclaim policies during environment teardown to prevent orphaned EBS volumes.

## 9. Interview Summary

During my AWS EKS platform project, I deployed PostgreSQL using Helm and Argo CD. The database couldn't start because its PVC was stuck in Pending.

I checked the PVC events and found that Kubernetes couldn't find the `gp3` StorageClass. The YAML already existed in GitHub, but Argo CD wasn't deploying it.

Instead of creating it manually, I added a new Argo CD Application to manage the StorageClass through GitOps. After pushing the change, Argo CD deployed the StorageClass, the PVC became Bound, and PostgreSQL became healthy.

This reinforced the importance of checking Kubernetes events and making sure infrastructure dependencies are included in the deployment workflow.