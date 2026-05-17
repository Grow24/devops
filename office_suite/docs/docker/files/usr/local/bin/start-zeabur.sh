#!/bin/sh
# Log immediately so Zeabur runtime logs show output even if uvicorn fails later
PORT="${PORT:-8080}"
echo "=== GROW24 Docs backend starting on 0.0.0.0:${PORT} (workers=1) ==="
echo "=== DJANGO_CONFIGURATION=${DJANGO_CONFIGURATION:-unset} ==="
exec uvicorn \
  --app-dir=/app \
  --host=0.0.0.0 \
  --port="${PORT}" \
  --workers=1 \
  --timeout-graceful-shutdown=300 \
  --limit-max-requests=20000 \
  --lifespan=off \
  impress.asgi:application
