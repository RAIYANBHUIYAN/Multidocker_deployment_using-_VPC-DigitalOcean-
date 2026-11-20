#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
case "$ENV_NAME" in
  staging)
    CONTAINER="backend-staging"
    HOST_PORT="3001"
    ;;
  production)
    CONTAINER="backend-production"
    HOST_PORT="3002"
    ;;
  *)
    echo "usage: deploy.sh <staging|production>" >&2
    exit 1
    ;;
esac

DIGEST="${SSH_ORIGINAL_COMMAND:-}"
if [[ ! "$DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]]; then
  echo "invalid digest" >&2
  exit 1
fi

IMAGE="ghcr.io/raiyanbhuiyan/vpc-backend@${DIGEST}"
STATE_DIR="/opt/app/state"
STATE_FILE="${STATE_DIR}/${ENV_NAME}.digest"
mkdir -p "$STATE_DIR"

PREVIOUS=""
if [[ -f "$STATE_FILE" ]]; then
  PREVIOUS="$(cat "$STATE_FILE")"
fi

deploy_image() {
  local digest="$1"
  local image="ghcr.io/raiyanbhuiyan/vpc-backend@${digest}"

  nerdctl pull "$image"
  nerdctl rm -f "$CONTAINER" >/dev/null 2>&1 || true
  nerdctl run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    --memory 96m \
    --pids-limit 100 \
    --read-only \
    --user 65532:65532 \
    --security-opt no-new-privileges \
    -e PORT=3001 \
    -p "127.0.0.1:${HOST_PORT}:3001" \
    "$image"
}

healthcheck() {
  local i
  for i in $(seq 1 15); do
    if body="$(curl -fsS "http://127.0.0.1:${HOST_PORT}/health" 2>/dev/null)" && [[ "$body" == "ok" ]]; then
      return 0
    fi
    sleep 2
  done
  return 1
}

if deploy_image "$DIGEST" && healthcheck; then
  echo "$DIGEST" > "$STATE_FILE"
  echo "env=${ENV_NAME} digest=${DIGEST} outcome=ok"
  exit 0
fi

echo "env=${ENV_NAME} digest=${DIGEST} outcome=failed" >&2

if [[ -n "$PREVIOUS" ]]; then
  if deploy_image "$PREVIOUS" && healthcheck; then
    echo "$PREVIOUS" > "$STATE_FILE"
    echo "env=${ENV_NAME} digest=${PREVIOUS} outcome=rolled_back" >&2
    exit 1
  fi
fi

nerdctl rm -f "$CONTAINER" >/dev/null 2>&1 || true
exit 1