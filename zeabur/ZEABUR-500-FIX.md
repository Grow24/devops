# Zeabur 500 fix — `devopsdev.zeabur.app`

**500 + `server: uvicorn`** = Django is running; something fails on **every request** (including `/__heartbeat__/`).

Most common cause: **Redis not reachable**. This app stores sessions in Redis and creates a session on every request.

---

## Required services (same Zeabur project)

1. **PostgreSQL** — copy internal connection string  
2. **Redis** — copy internal `REDIS_URL` (with password)  
3. **devops** (backend) — variables below  

Do **not** use `localhost` in connection strings on Zeabur.

---

## Variables on service `devops`

```env
PORT=8080
DJANGO_CONFIGURATION=Production
PYTHONUNBUFFERED=1

DJANGO_SECRET_KEY=<50+ random characters>

# Host (either name works after latest settings.py)
ALLOWED_HOSTS=devopsdev.zeabur.app
DJANGO_ALLOWED_HOSTS=devopsdev.zeabur.app

# Zeabur PostgreSQL → Connect tab (internal URL)
DATABASE_URL=postgres://user:pass@host.zeabur.internal:5432/postgres

# Zeabur Redis → Connect tab (required — without this, everything returns 500)
REDIS_URL=redis://:password@host.zeabur.internal:6379/0

# HTTPS behind Zeabur proxy
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
```

**Networking:** port **8080** (must match `PORT`).

---

## After deploy

### 1. Runtime logs

You should see:

```
=== GROW24 Docs backend starting on 0.0.0.0:8080 (workers=1) ===
INFO: Uvicorn running on http://0.0.0.0:8080
```

If logs show Redis/connection errors, fix `REDIS_URL` / `DATABASE_URL`.

### 2. Migrate (one-off command on service `devops`)

```bash
python manage.py migrate --noinput
```

### 3. Test

| URL | Expected |
|-----|----------|
| `/__heartbeat__/` | **200** |
| `/api/v1.0/config/` | **200** JSON |
| `/` | **404** is OK (no homepage on API) |

```bash
curl -I https://devopsdev.zeabur.app/__heartbeat__/
```

---

## Still 500?

1. Open **Logs** (runtime, not build) and copy the traceback.  
2. Confirm **Redis** service is **RUNNING** in the same project.  
3. Confirm `REDIS_URL` matches Redis **Connect** (password, host, port).  
4. Redeploy after changing variables.

Full stack (frontend, Keycloak, MinIO, y-provider) is separate — API can return 200 on heartbeat without them; login/docs UI need those services later.
