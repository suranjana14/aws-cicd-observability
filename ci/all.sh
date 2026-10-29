#!/usr/bin/env bash
# Run the whole pipeline locally, in the same order as CI.
set -euo pipefail
cd "$(dirname "$0")"
./lint.sh
./test.sh
./terraform-validate.sh
./docker-build.sh
echo "All CI stages passed."
