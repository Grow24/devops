#!/bin/sh
# Zeabur entrypoint for production traffic.
PORT="${PORT:-8080}"
WORKERS="${GUNICORN_WORKERS:-${WEB_CONCURRENCY:-4}}"
THREADS="${GUNICORN_THREADS:-2}"
WORKER_CLASS="${GUNICORN_WORKER_CLASS:-gthread}"
TIMEOUT="${GUNICORN_TIMEOUT:-120}"
KEEPALIVE="${GUNICORN_KEEPALIVE:-5}"
echo "=== GROW24 Docs backend starting on 0.0.0.0:${PORT} (gunicorn workers=${WORKERS}, threads=${THREADS}) ==="
echo "=== DJANGO_CONFIGURATION=${DJANGO_CONFIGURATION:-unset} ==="
exec gunicorn \
  --config /usr/local/etc/gunicorn/impress.py \
  --chdir /app \
  --bind "0.0.0.0:${PORT}" \
  --workers "${WORKERS}" \
  --threads "${THREADS}" \
  --worker-class "${WORKER_CLASS}" \
  --timeout "${TIMEOUT}" \
  --keep-alive "${KEEPALIVE}" \
  impress.wsgi:application
