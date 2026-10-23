
#!/usr/bin/env bash
set -euo pipefail

# Always run from the repository root
cd "$(dirname "$0")/.."

echo "=================================="
echo " AWS EKS PLATFORM VALIDATION"
echo "=================================="

# 1. Terraform validation
echo
echo "[1/4] Validating Terraform..."

terraform -chdir=env/dev validate

echo "PASS: Terraform validation"

# 2. Kubernetes and Helm validation
echo
echo "[2/4] Validating Kubernetes and Helm..."

python3 scripts/validate_k8s.py

echo "PASS: Kubernetes and Helm validation"

# 3. Shell script validation
echo
echo "[3/4] Validating shell scripts..."

for script in scripts/*.sh; do
    echo "Checking $script"
    bash -n "$script"
done

echo "PASS: Shell script validation"

# 4. GitOps YAML validation
echo
echo "[4/4] Validating GitOps YAML files..."

python3 - <<'PY'
from pathlib import Path
import yaml

files = sorted(Path("gitops").rglob("*.yaml"))

for file in files:
    with file.open() as stream:
        list(yaml.safe_load_all(stream))
    print(f"PASS: {file}")

print(f"Validated {len(files)} GitOps YAML files.")
PY

echo
echo "=================================="
echo " ALL PLATFORM CHECKS PASSED!"
echo "=================================="
