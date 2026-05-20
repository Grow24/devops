# Zeabur service name "devops" auto-selects this file (Dockerfile.devops).
# Same as /Dockerfile — keep in sync. Cache-bust: 2026-05-18-v2

FROM python:3.13.13-alpine AS base
RUN apk update && apk upgrade --no-cache && python -m pip install --upgrade pip

FROM base AS back-builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=0
COPY --from=ghcr.io/astral-sh/uv:0.11.10 /uv /uvx /bin/
WORKDIR /app
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=office_suite/docs/src/backend/uv.lock,target=uv.lock \
    --mount=type=bind,source=office_suite/docs/src/backend/pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev
COPY office_suite/docs/src/backend /app
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-dev

FROM node:24 AS mail-builder
COPY office_suite/docs/src/mail /mail/app
WORKDIR /mail/app
RUN yarn install --frozen-lockfile && yarn build

FROM base AS link-collector
ARG IMPRESS_STATIC_ROOT=/data/static
RUN apk add --no-cache pango rdfind
COPY --from=back-builder /app /app
WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"
RUN DJANGO_CONFIGURATION=Build python manage.py collectstatic --noinput
RUN rdfind -makesymlinks true -followsymlinks true -makeresultsfile false ${IMPRESS_STATIC_ROOT}

FROM base AS core
ENV PYTHONUNBUFFERED=1
RUN apk add --no-cache cairo file font-noto font-noto-emoji gettext gdk-pixbuf libffi-dev pango shared-mime-info wget
RUN wget -q https://raw.githubusercontent.com/suitenumerique/django-lasuite/refs/heads/main/assets/conf/mime.types -O /etc/mime.types
COPY office_suite/docs/docker/files/usr/local/bin/entrypoint /usr/local/bin/entrypoint
RUN chmod g=u /etc/passwd
COPY --from=back-builder /app /app
WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"
RUN mkdir /cert && path=`python -c 'import certifi;print (certifi.where())'` && mv $path /cert/ && ln -s /cert/cacert.pem $path
RUN DJANGO_CONFIGURATION=Build python manage.py compilemessages --ignore=".venv/**/*"

FROM core AS backend-production
RUN rm -rf /var/cache/apk/*
ARG IMPRESS_STATIC_ROOT=/data/static
ARG DOCKER_USER=1000
RUN mkdir -p /usr/local/etc/gunicorn
COPY office_suite/docs/docker/files/usr/local/bin/entrypoint /usr/local/bin/entrypoint
COPY office_suite/docs/docker/files/usr/local/etc/gunicorn/impress.py /usr/local/etc/gunicorn/impress.py
COPY office_suite/docs/docker/files/usr/local/bin/start-zeabur.sh /usr/local/bin/start-zeabur.sh
RUN chmod +x /usr/local/bin/entrypoint /usr/local/bin/start-zeabur.sh
COPY --from=link-collector ${IMPRESS_STATIC_ROOT} ${IMPRESS_STATIC_ROOT}
COPY --from=mail-builder /mail/backend/core/templates/mail /app/core/templates/mail
RUN chown -R ${DOCKER_USER}:${DOCKER_USER} ${IMPRESS_STATIC_ROOT} /app
USER ${DOCKER_USER}
ENV PYTHONUNBUFFERED=1
ENV WEB_CONCURRENCY=4
ENV GUNICORN_WORKERS=4
ENV GUNICORN_THREADS=2
ENV GUNICORN_WORKER_CLASS=gthread
ENV GUNICORN_TIMEOUT=120
ENV GUNICORN_KEEPALIVE=5
EXPOSE 8080
ENTRYPOINT []
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD python -c "import requests; requests.get('http://127.0.0.1:8080/__heartbeat__/', timeout=5)" || exit 1
CMD ["sh", "/usr/local/bin/start-zeabur.sh"]
