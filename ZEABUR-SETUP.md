# Zeabur — correct deployment settings (read this)

## The problem you hit

Zeabur **build context** must match **Dockerfile paths**. There are two valid setups — **mixing them breaks the build**:

| Root Directory | Dockerfile used | COPY paths in Dockerfile |
|----------------|-----------------|------------------------|
| `office_suite/docs` | `office_suite/docs/Dockerfile` | `src/backend`, `docker/files/...` |
| `/` (repo root) | `/Dockerfile` | `office_suite/docs/src/backend`, ... |

**Broken (paths “don’t exist”):**

- Root Directory = `office_suite/docs` + Dockerfile from **repo root** (`/Dockerfile`)
- Root Directory = `/` + Dockerfile from `office_suite/docs/Dockerfile` (without `office_suite/docs/` prefix)

---

## Recommended (use this)

In Zeabur → service **devops** → **Settings**:

| Setting | Value |
|---------|--------|
| **Root Directory** | `office_suite/docs` |
| **Dockerfile override** | **empty** (delete all text, Save) |
| **Port** | leave default / `$PORT` |

Then **Redeploy**.

Build uses `office_suite/docs/Dockerfile` — same as local `docker compose`.

---

## Alternative (repo root)

Only if you keep Root Directory = `/`:

| Setting | Value |
|---------|--------|
| **Root Directory** | `/` |
| **Dockerfile** | repo root `/Dockerfile` (monorepo paths) |

---

## After deploy — test URLs

- `https://YOUR-DOMAIN.zeabur.app/__heartbeat__/`
- `https://YOUR-DOMAIN.zeabur.app/api/v1.0/config/`

Root `/` has no HTML page (API only).

## Required env vars

```
DJANGO_CONFIGURATION=Production
DJANGO_ALLOWED_HOSTS=YOUR-DOMAIN.zeabur.app
DATABASE_URL=...
REDIS_URL=...
DJANGO_SECRET_KEY=...
```

Post-deploy command:

```bash
python manage.py migrate --noinput
```
