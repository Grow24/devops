# Zeabur 502 fix checklist

502 = Zeabur proxy **cannot reach** your app (not the same as Django 500).

## Step 1 — Zeabur settings (service `devops`)

| Setting | Value |
|---------|--------|
| Root Directory | `office_suite/docs` |
| Dockerfile box | **empty** → Save |
| Redeploy | latest GitHub `main` |

## Step 2 — Add PostgreSQL + Redis (same project)

Without these, the app may run but API returns errors. For 502, the main fixes are port + memory.

1. Project → **Add Service** → **PostgreSQL**
2. Project → **Add Service** → **Redis**
3. Open **devops** service → **Variable** → add from each service’s **Connect** tab:

```
DATABASE_URL=<paste PostgreSQL connection string>
REDIS_URL=<paste Redis connection string>
DJANGO_CONFIGURATION=Production
DJANGO_SECRET_KEY=<50+ random characters>
DJANGO_ALLOWED_HOSTS=devopsdev.zeabur.app
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
```

## Step 3 — Networking port (critical for STARTING / 502)

Zeabur must forward to the **same port** the app listens on (`$PORT`).

| Zeabur Networking | Variable `PORT` | Result |
|-------------------|-----------------|--------|
| **8080** | `8080` (or unset, defaults 8080) | OK |
| **8000** | set `PORT=8000` in Variables | OK |
| Networking **8000**, app on **8080** | | **STARTING forever / 502** |

1. Service **devops** → **Networking** → use **8080** (recommended)
2. Or keep **8000** and add Variable: `PORT=8000`
3. Logs must show:

```
=== GROW24 Docs backend starting on 0.0.0.0:8080 (workers=1) ===
```

If Networking says `8000` but logs show `8080`, change Networking to **8080** and redeploy.

## Step 4 — Check runtime logs (not build logs)

**Logs** tab must show:

```
INFO: Uvicorn running on http://0.0.0.0:8080
```

If you see **Child process died** in a loop → upgrade plan or keep `workers=1` (already in latest Dockerfile).

If logs are **empty** or container **restarts** → missing `DATABASE_URL` / wrong image / build failed.

## Step 5 — Test URLs

| URL | OK |
|-----|-----|
| `/__heartbeat__/` | 200 |
| `/api/v1.0/config/` | 200 JSON |
| `/` | 404 is fine |

## Step 6 — Migrate (once RUNNING)

```bash
python manage.py migrate --noinput
```
