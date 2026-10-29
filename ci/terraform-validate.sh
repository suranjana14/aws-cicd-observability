#!/usr/bin/env bash
# fmt + init (no backend, no credentials) + validate for every Terraform root.
set -euo pipefail
cd "$(dirname "$0")/.."

terraform fmt -check -recursive infra
for dir in infra/envs/*/; do
  echo "==> validating ${dir}"
  terraform -chdir="${dir}" init -backend=false -input=false >/dev/null
  terraform -chdir="${dir}" validate
done

if command -v tflint >/dev/null 2>&1; then
  tflint --init && tflint --recursive
else
  echo "INFO: tflint not installed; skipping" >&2
fi
