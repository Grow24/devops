# Zeabur — Frontend (Docs UI) deploy — step by step

Use this after **devops** (API) and **keycloak** are running.

| Role | Your URL (replace if different) |
|------|----------------------------------|
| Backend API | `https://devopsdev.zeabur.app` |
| Keycloak | `https://keycloak.zeabur.app` |
| **Frontend (new)** | `https://devopsdocs.zeabur.app` ← pick in Zeabur Networking |

**Login on frontend:** same Keycloak **grow24** user as `/api/v1.0/authenticate/` (Step 4 in main flow).

---

## Part 1 — Add Frontend service on Zeabur

### Step 1 — New service

1. Open [Zeabur](https://zeabur.com) → project **devops**
2. Click **Add Service**
3. Choose **Git** → same GitHub repo as **devops**
4. Service name: `docs-frontend` (any name)

### Step 2 — Build settings

Open **docs-frontend** → **Settings**:

| Setting | Value |
|---------|--------|
| **Root Directory** | `office_suite/docs` |
| **Dockerfile path** | `src/frontend/Dockerfile` |
| **Dockerfile target / build target** | `frontend-production` |

If there is a **Dockerfile override** box with old text → **delete all** → Save.

### Step 3 — Build arguments (required)

**Settings** → **Build** / **Build arguments** → add:

| Name | Value |
|------|--------|
| `API_ORIGIN` | `https://devopsdev.zeabur.app` |
| `DOCKER_USER` | `1000` |
| `PUBLISH_AS_MIT` | `false` |
| `SW_DEACTIVATED` | `true` |

No trailing slash on `API_ORIGIN`.

### Step 4 — Port & domain

1. Tab **Networking**
2. **Container port:** `8080` (nginx listens on 8080 in this image)
3. **Add domain** → e.g. `devopsdocs.zeabur.app` (Zeabur suggests a free subdomain)
4. Wait until status **PROVISIONED** / **Running**
5. First deploy may take **10–20 minutes** (yarn build)

### Step 5 — Settings cleanup (same as other services)

**Settings** tab:

- **Startup Command (ENTRYPOINT):** empty
- **Arguments (CMD):** empty
- **Dockerfile** override box (if it shows `FROM python` or `gunicorn`): **delete all** → Save

### CRITICAL — `gunicorn: executable file not found` on docs-frontend

This service is **nginx + static Next.js**, not Django. Do **not** install gunicorn or use the backend Dockerfile here.

| Wrong (causes crash loop) | Correct |
|---------------------------|---------|
| Startup Command = `gunicorn` | Startup Command = **empty** |
| Dockerfile override with `FROM python` + `CMD gunicorn` | Dockerfile override = **empty** |
| Variable `DJANGO_CONFIGURATION` on frontend | **Remove** (unlink backend env if Zeabur copied it) |
| Zeabur AI “add gunicorn to Dockerfile” | **Ignore** for docs-frontend |

After save, logs should show **nginx**, not `exec: gunicorn`.

**Variable** tab — keep only frontend vars, delete backend-only keys if present:

- Remove: `DJANGO_CONFIGURATION`, `DJANGO_SECRET_KEY`, `DATABASE_URL`, `DB_*`, `OIDC_*` (backend only)
- Keep: `ZBPACK_DOCKERFILE_PATH`, `API_ORIGIN`, `DOCKER_USER`, `PUBLISH_AS_MIT`, `SW_DEACTIVATED`
- **Typo fix:** `PUBLISH_AS_NIT` → delete; use **`PUBLISH_AS_MIT`** = `false`

---

## Part 2 — Update **devops** (backend) variables

**devops** → **Variable** → edit / add:

```env
IMPRESS_BASE_URL=https://devopsdocs.zeabur.app
LOGIN_REDIRECT_URL=https://devopsdocs.zeabur.app
LOGOUT_REDIRECT_URL=https://devopsdocs.zeabur.app
LOGIN_REDIRECT_URL_FAILURE=https://devopsdocs.zeabur.app/login-error
MEDIA_BASE_URL=https://devopsdev.zeabur.app/media
```

Replace `devopsdocs.zeabur.app` with **your** frontend domain from Part 1 Step 4.

Optional (if browser shows CORS errors):

```env
CORS_ALLOWED_ORIGINS=["https://devopsdocs.zeabur.app"]
CSRF_TRUSTED_ORIGINS=["https://devopsdocs.zeabur.app"]
```

**Save** → **Redeploy** service **devops**.

---

## Part 3 — Update Keycloak client `office_docs`

1. `https://keycloak.zeabur.app/admin` → login (`admin` + `KEYCLOAK_ADMIN_PASSWORD`)
2. Realm **grow24** → **Clients** → **office_docs**
3. **Valid redirect URIs** — add (keep backend URI too):

```text
https://devopsdev.zeabur.app/api/v1.0/*
https://devopsdocs.zeabur.app/*
```

4. **Web origins** — add:

```text
https://devopsdev.zeabur.app
https://devopsdocs.zeabur.app
```

5. **Save**

---

## Part 4 — Test URLs (after deploy)

| # | URL | Login |
|---|-----|--------|
| 1 | `https://devopsdocs.zeabur.app/` | grow24 user (Keycloak) |
| 2 | `https://devopsdocs.zeabur.app/home/` | same |
| 3 | `https://devopsdev.zeabur.app/api/v1.0/config/` | none (JSON) |
| 4 | `https://devopsdev.zeabur.app/` | still **404** (API only — normal) |

**Username / password:** Keycloak → realm **grow24** → **Users** → user you created (not `admin` unless you added admin to grow24).

---

## Part 5 — If build fails

| Error | Fix |
|-------|-----|
| Dockerfile not found | Root Directory = `office_suite/docs`, path = `src/frontend/Dockerfile` |
| Build timeout | Retry deploy; frontend build is heavy |
| Blank page after deploy | Check `API_ORIGIN` = `https://devopsdev.zeabur.app` and rebuild |
| Login loop | Keycloak redirect URIs + devops `LOGIN_REDIRECT_URL` = frontend URL |
| 502 on frontend | Networking port = **8080**, not 3000 |

---

## Quick copy — domains map

```
Browser UI     →  https://devopsdocs.zeabur.app
Django API     →  https://devopsdev.zeabur.app
Keycloak       →  https://keycloak.zeabur.app
```

Collaboration (y-provider) and MinIO are **not** included here — add later for full editor features.
