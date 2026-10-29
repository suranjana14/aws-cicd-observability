#!/usr/bin/env bash
# Build (and optionally push) the container image.
#   IMAGE_REPO   e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/orders-api (default: orders-api)
#   PUSH=1       push after build (requires `aws ecr get-login-password | docker login ...` first)
# The tag is the short git SHA so every deploy is traceable to a commit.
# If no Docker daemon is available (e.g. a sandboxed runner), the script
# exits 0 with a warning so the rest of the pipeline can still run locally.
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE_REPO="${IMAGE_REPO:-orders-api}"
TAG="$(git rev-parse --short HEAD 2>/dev/null || echo dev)"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "WARN: no Docker daemon available; skipping image build for ${IMAGE_REPO}:${TAG}" >&2
  exit 0
fi

docker build -f app/Dockerfile \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --label "org.opencontainers.image.revision=${TAG}" \
  -t "${IMAGE_REPO}:${TAG}" .

# Smoke test the image before it can be pushed anywhere.
cid="$(docker run -d -p 18080:8080 "${IMAGE_REPO}:${TAG}")"
trap 'docker rm -f "$cid" >/dev/null' EXIT
for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:18080/healthz >/dev/null; then echo "smoke test passed"; break; fi
  sleep 1
done
curl -fsS http://127.0.0.1:18080/readyz

if [[ "${PUSH:-0}" == "1" ]]; then
  docker push "${IMAGE_REPO}:${TAG}"
fi
