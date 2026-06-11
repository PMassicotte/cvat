#!/usr/bin/env bash
# Tear down CVAT + the Nuclio function containers that compose doesn't manage.
#
# `docker compose down` only knows about services in COMPOSE_FILE (CVAT + the
# nuclio dashboard). The per-function containers that `nuctl deploy` creates
# (nuclio-nuclio-*, plus nuclio-local-storage-reader) are invisible to compose,
# so they'd be left running and would keep the cvat_cvat network from being
# removed. Remove them first, then bring the compose stack down.
#
# Volumes (Postgres DB, redis, etc.) are preserved by default. To also delete
# them, pass through the usual compose flag:
#   ./down.sh -v        # WARNING: drops the database and all annotations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$SCRIPT_DIR"

echo ">>> Removing Nuclio function containers (not managed by compose)"
# Match nuclio-* containers (the deployed functions + local-storage-reader) but
# not the bare "nuclio" dashboard, which compose owns and tears down itself.
mapfile -t NUCLIO_FUNCS < <(docker ps -aq --filter 'name=nuclio-')
if [ ${#NUCLIO_FUNCS[@]} -gt 0 ]; then
    docker rm -f "${NUCLIO_FUNCS[@]}"
else
    echo ">>> No Nuclio function containers to remove"
fi

echo ">>> Bringing CVAT stack down"
docker compose down "$@"

echo ">>> Done"
