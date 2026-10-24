
from pathlib import Path

import yaml
import subprocess


ROOT = Path(__file__).resolve().parent.parent
KUBERNETES_DIR = ROOT / "kubernetes"


def load_yaml(path):
    with path.open() as file:
        return yaml.safe_load(file)


def validate_syntax():
    files = sorted(KUBERNETES_DIR.rglob("*.yaml"))

    for file in files:
        load_yaml(file)
        print(f"PASS: YAML syntax - {file.relative_to(ROOT)}")

    print(f"\nValidated {len(files)} YAML files.")


def validate_references():
    deployment = load_yaml(
        KUBERNETES_DIR / "apps/postgres/deployment.yaml"
    )
    service = load_yaml(
        KUBERNETES_DIR / "apps/postgres/service.yaml"
    )
    pvc = load_yaml(
        KUBERNETES_DIR / "storage/postgres-pvc.yaml"
    )
    storage_class = load_yaml(
        KUBERNETES_DIR / "storage/storageclass.yaml"
    )

    pod_template = deployment["spec"]["template"]
    pod_spec = pod_template["spec"]

    claim_name = pod_spec["volumes"][0]["persistentVolumeClaim"]["claimName"]

    assert claim_name == pvc["metadata"]["name"], (
        "Deployment references an incorrect PVC"
    )
    print("PASS: Deployment references the correct PVC")

    assert pvc["spec"]["storageClassName"] == storage_class["metadata"]["name"], (
        "PVC references an incorrect StorageClass"
    )
    print("PASS: PVC references the correct StorageClass")

    pod_labels = pod_template["metadata"]["labels"]
    service_selector = service["spec"]["selector"]

    assert all(
        pod_labels.get(key) == value
        for key, value in service_selector.items()
    ), "Service selector does not match pod labels"

    print("PASS: Service selector matches pod labels")

def validate_schema():
    print("\nChecking Kubernetes API schemas...")

    files = sorted(KUBERNETES_DIR.rglob("*.yaml"))

    command = [
        "kubeconform",
        "-strict",
        "-summary",
        "-kubernetes-version",
        "1.33.0",
    ]
    command.extend(str(file) for file in files)

    subprocess.run(command, check=True)


def validate_helm():
    print("\nChecking PostgreSQL Helm chart...")

    chart = str(ROOT / "helm/postgres")

    # Check the Helm chart for errors
    subprocess.run(
        ["helm", "lint", chart],
        check=True
    )

    # Render the Helm templates locally
    result = subprocess.run(
        ["helm", "template", "dev", chart],
        capture_output=True,
        text=True,
        check=True
    )

    # Validate the generated Kubernetes resources
    subprocess.run(
        [
            "kubeconform",
            "-strict",
            "-summary",
            "-kubernetes-version",
            "1.33.0",
        ],
        input=result.stdout,
        text=True,
        check=True
    )

    print("Helm validation passed!")

def main():
    print("Checking YAML syntax...")
    validate_syntax()

    print("\nChecking Kubernetes resource references...")
    validate_references()

    validate_schema()
    validate_helm()

    print("\nAll checks passed!")


if __name__ == "__main__":
    main()
