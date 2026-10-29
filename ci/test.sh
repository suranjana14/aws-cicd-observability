#!/usr/bin/env bash
# Unit tests with a JUnit report CI can publish.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports
python -m pytest -q --junitxml=reports/junit.xml "$@"
