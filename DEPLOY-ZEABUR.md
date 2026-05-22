# Zeabur par deploy — step by step

> **Pehle ye padho (aapke screenshots + missing services):** [zeabur/ZEABUR-COMPLETE-GUIDE.md](./zeabur/ZEABUR-COMPLETE-GUIDE.md)  
> **Error: "No Dockerfile found"?** → [ZEABUR-QUICKFIX.md](./ZEABUR-QUICKFIX.md)  
> Dockerfile override box **har service par khali** rakho.

Ye stack **6+ services** use karta hai. Zeabur par sab kuch ek saath Docker Compose ki tarah nahi chalta — har service alag add karni hoti hai.

## Pehle GitHub complete karo

[README.md](./README.md) ke **GitHub** steps follow karke code push karo.

---

## Architecture on Zeabur

```
[User Browser]
     │
     ├─► Frontend (Next.js)     ── Zeabur Service #1
     ├─► Backend (Django)      ── Zeabur Service #2  ──► Zeabur PostgreSQL
     ├─► y-provider            ── Zeabur Service #3  ──► Zeabur Redis
     ├─► Keycloak              ── Zeabur Service #4  ──► same PostgreSQL (alag DB)
     └─► MinIO / S3            ── Zeabur MinIO ya Object Storage
```

---

## Step 1 — Zeabur account

1. https://zeabur.com par sign up / login  
2. **New Project** → naam: `grow24-docs`

---

## Step 2 — Managed database & cache

### PostgreSQL

1. Project → **Add Service** → **PostgreSQL**  
2. Deploy hone ke baad **Variables** / **Connect** se connection string copy karo  
   - Example: `postgres://user:pass@host.zeabur.internal:5432/zeabur`  
3. Zeabur dashboard se **extra database** `office_suite_docs_db` aur `keycloak_db` banani padegi (SQL console ya init script)

### Redis

1. **Add Service** → **Redis**  
2. `REDIS_URL` copy karo (password ke saath)

---

## Step 3 — Backend (Django API) deploy

1. **Add Service** → **Git** → apna GitHub repo select karo  
2. **Root Directory:** `office_suite/docs`  
3. **Builder:** Dockerfile  
4. Dockerfile target (Zeabur advanced / build args): `backend-production`  
   - Agar option na ho to `office_suite/docs/Dockerfile` mein production stage verify karo  
5. **Port:** `8000`  
6. **Variables:** `zeabur/zeabur.env.example` se **BACKEND** section copy karke bharo  
   - `DATABASE_URL`, `REDIS_URL` = Zeabur wale values  
   - `IMPRESS_BASE_URL` = frontend ka public URL (Step 4 ke baad update)  
   - `OIDC_*` = Keycloak public HTTPS URLs (Step 5 ke baad)  
7. Deploy ke baad **domain** assign karo → e.g. `https://grow24-api.zeabur.app`

### Post-deploy commands (Zeabur → Service → Command / one-off)

```bash
python manage.py migrate --noinput
python manage.py collectstatic --noinput
```

---

## Step 4 — Frontend deploy

1. **Add Service** → same repo, **Root:** `office_suite/docs`  
2. Dockerfile: `./src/frontend/Dockerfile`, target: `frontend-production`  
3. **Build arguments (zaroori):**

   | Name | Value |
   |------|--------|
   | `API_ORIGIN` | `https://grow24-api.zeabur.app` (apna backend URL) |
   | `DOCKER_USER` | `1000` |
   | `PUBLISH_AS_MIT` | `false` |
   | `SW_DEACTIVATED` | `true` |

4. Port: `3000`  
5. Public domain → `https://grow24-docs.zeabur.app`  
6. Backend env mein `IMPRESS_BASE_URL` aur `LOGIN_REDIRECT_URL` ko is frontend URL se update karke **redeploy** karo

---

## Step 5 — y-provider deploy

1. **Add Service** → repo root `office_suite/docs`  
2. Dockerfile: `./src/frontend/servers/y-provider/Dockerfile`, target: `y-provider`  
3. Port: `4444`  
4. Domain → `https://grow24-yprovider.zeabur.app`  
5. Backend variables update:

   - `COLLABORATION_API_URL=https://grow24-yprovider.zeabur.app/collaboration/api/`
   - `COLLABORATION_WS_URL=wss://grow24-yprovider.zeabur.app/collaboration/ws/`
   - `Y_PROVIDER_API_BASE_URL=https://grow24-yprovider.zeabur.app/api/`

---

## Step 6 — Keycloak

**Option A — Zeabur par Keycloak container**

1. **Add Service** → **Docker Image** → `quay.io/keycloak/keycloak:24.0`  
2. Start command: `start --hostname-strict=false --http-enabled=true`  
3. Env: `keycloak/env.d/.env.example` jaisa, lekin:
   - `KC_DB_URL_HOST` = Zeabur Postgres internal host  
   - `KEYCLOAK_HOSTNAME` = aapka public Keycloak domain (bina port ke)  
4. Realm `grow24`, client `office_docs` — local jaisa `kcadm` se configure karo  
5. Redirect URIs:

   ```
   https://YOUR_BACKEND_DOMAIN/api/v1.0/*
   https://YOUR_FRONTEND_DOMAIN/*
   ```

**Option B — Alag VPS / managed IdP**

Agar Keycloak Zeabur par mushkil lage to existing server `keycloak.intelligentsalesman.com` use karo — `common.example` ke commented production OIDC URLs dekho.

---

## Step 7 — Object storage (MinIO / S3)

**Option A:** Zeabur par MinIO service (image `minio/minio`)  
**Option B:** AWS S3 / compatible storage — backend env:

```
AWS_S3_ENDPOINT_URL=https://...
AWS_S3_ACCESS_KEY_ID=...
AWS_S3_SECRET_ACCESS_KEY=...
AWS_S3_USE_SSL=True
```

---

## Step 8 — Keycloak OIDC client (production)

1. Keycloak Admin → realm **grow24** → client **office_docs**  
2. **Valid redirect URIs:**

   ```
   https://YOUR_BACKEND/api/v1.0/*
   https://YOUR_FRONTEND/*
   ```

3. **Web origins:** frontend + backend URLs  
4. Client secret → backend `OIDC_RP_CLIENT_SECRET`

---

## Step 9 — Final checklist

| Check | Done? |
|-------|--------|
| GitHub push (secrets gitignore mein) | ☐ |
| Postgres migrate on backend | ☐ |
| Frontend `API_ORIGIN` = backend HTTPS URL | ☐ |
| Backend `IMPRESS_BASE_URL` = frontend HTTPS URL | ☐ |
| OIDC sab endpoints **HTTPS** + same Keycloak host | ☐ |
| `SECURE_SSL_REDIRECT=True` on production backend | ☐ |
| Keycloak redirect URIs match backend callback | ☐ |

---

## Common issues

| Problem | Fix |
|---------|-----|
| 500 on `/api/v1.0/callback` | `migrate` run karo; `DATABASE_URL` sahi ho |
| Login redirect loop | `LOGIN_REDIRECT_URL` = frontend URL |
| OIDC invalid redirect | Keycloak client URIs + trailing slash `/callback/` |
| CORS error | Production mein `CORS_ALLOW_ALL_ORIGINS=False` + allowed origins set karo |

---

## Reference files

- Local env template: `office_suite/docs/env.d/grow24/common.example`
- Zeabur variables list: `zeabur/zeabur.env.example`
- Docker Compose (local): `office_suite/docs/docker_compose_production.yml`
