#!/usr/bin/env bash
# Post-deploy gate: poll /readyz on the new (green) target and fail the
# pipeline if it never reports the expected version. CodeDeploy / the
# rolling update then rolls back automatically on a failed hook or alarm.
#   BASE_URL          e.g. https://green.orders.example.internal
#   EXPECTED_VERSION  version string the new task should report
set -euo pipefail
: "${BASE_URL:?set BASE_URL}"
: "${EXPECTED_VERSION:?set EXPECTED_VERSION}"

for attempt in $(seq 1 30); do
  body="$(curl -fsS "${BASE_URL}/readyz" || true)"
  if [[ "$body" == *"\"version\":\"${EXPECTED_VERSION}\""* ]]; then
    echo "ready on attempt ${attempt}: ${body}"
    exit 0
  fi
  sleep 5
done
echo "ERROR: ${BASE_URL} never reported version ${EXPECTED_VERSION}" >&2
exit 1
