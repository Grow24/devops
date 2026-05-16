#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

copy_if_missing() {
  local example="$1"
  local target="$2"
  if [[ -f "$target" ]]; then
    echo "OK  $target (already exists)"
  elif [[ -f "$example" ]]; then
    cp "$example" "$target"
    echo "CREATED $target from example"
  else
    echo "SKIP missing example: $example"
  fi
}

copy_if_missing "$ROOT/database/postgres/env.d/.env.example" "$ROOT/database/postgres/env.d/.env"
copy_if_missing "$ROOT/database/redis/env.d/.env.example" "$ROOT/database/redis/env.d/.env"
copy_if_missing "$ROOT/keycloak/env.d/.env.example" "$ROOT/keycloak/env.d/.env"
copy_if_missing "$ROOT/office_suite/docs/env.d/grow24/common.example" "$ROOT/office_suite/docs/env.d/grow24/common"

docker network inspect suite_net >/dev/null 2>&1 || docker network create suite_net

echo ""
echo "Done. Edit env files with your passwords, then run:"
echo "  1) database/run-postgres-redis.sh"
echo "  2) keycloak/run-keycloak.sh"
echo "  3) office_suite/docs: docker compose -f docker_compose_production.yml up -d --build"
