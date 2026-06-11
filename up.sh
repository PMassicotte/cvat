#!/usr/bin/env bash
# Bring up CVAT + reconcile Nuclio function IPs cached in the dashboard.
#
# The Nuclio dashboard caches each function container's IP at deploy time. When
# `docker compose up` recreates the network or function containers, those IPs
# drift and CVAT calls to /api/function_invocations return 500. Redeploying
# each function with `nuctl deploy` refreshes the cache.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$SCRIPT_DIR"

echo ">>> Ensuring gcr.io/iguazio/alpine:3.17 is available locally"
# Iguazio removed this tag from gcr.io, but Nuclio still requests it when
# preparing function volume mounts. Pull upstream alpine:3.17 and retag.
if ! docker image inspect gcr.io/iguazio/alpine:3.17 >/dev/null 2>&1; then
    docker pull alpine:3.17
    docker tag alpine:3.17 gcr.io/iguazio/alpine:3.17
fi

echo ">>> Starting CVAT stack"
docker compose up -d "$@"

echo ">>> Waiting for nuclio dashboard"
for _ in {1..60}; do
    if docker exec nuclio curl -sf http://localhost:8070/api/functions >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

mapfile -t FUNCTIONS < <(
    docker exec nuclio curl -s http://localhost:8070/api/functions |
        python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin).keys()))'
)

if [ ${#FUNCTIONS[@]} -eq 0 ]; then
    echo ">>> No Nuclio functions deployed; skipping redeploy"
    exit 0
fi

declare -A FUNC_DIR=(
    [pth-facebookresearch-sam-vit-h]=serverless/pytorch/facebookresearch/sam/nuclio
)

for func in "${FUNCTIONS[@]}"; do
    dir="${FUNC_DIR[$func]:-}"
    if [ -z "$dir" ]; then
        echo ">>> WARNING: no known path for function '$func'; skipping. Add it to FUNC_DIR in up.sh"
        continue
    fi
    echo ">>> Redeploying $func"
    nuctl deploy --project-name cvat \
        --path "$dir" \
        --file "$dir/function.yaml" \
        --platform local \
        --env CVAT_FUNCTIONS_REDIS_HOST=cvat_redis_ondisk \
        --env CVAT_FUNCTIONS_REDIS_PORT=6666 \
        --platform-config '{"attributes": {"network": "cvat_cvat"}}'
done

echo ">>> Done"
echo ">>> CVAT: http://localhost:8080"
