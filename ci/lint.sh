#!/usr/bin/env bash
# Lint Python (ruff) and Terraform formatting. Mirrors the "lint" job in docs/ci/github-actions.yml.example.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> ruff check"
ruff check .
echo "==> ruff format --check"
ruff format --check .

if command -v terraform >/dev/null 2>&1; then
  echo "==> terraform fmt -check"
  terraform fmt -check -recursive infra
else
  echo "WARN: terraform not installed; skipping fmt check" >&2
fi
