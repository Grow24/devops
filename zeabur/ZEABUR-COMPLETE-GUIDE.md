# Zeabur — poora stack deploy (Grow24/devops)

Repo: [https://github.com/Grow24/devops](https://github.com/Grow24/devops)

Aapke project **devops** par ye services honi chahiye:

| # | Service | Type | Domain (aapke setup) |
|---|---------|------|----------------------|
| 1 | `postgresql` | Zeabur template | internal only |
| 2 | `redis` | Zeabur template | internal only |
| 3 | `keycloak` | Docker image | `keycloak.zeabur.app` |
| 4 | `devops` | Git → backend | `devopsdev.zeabur.app` |
| 5 | `docs-frontend` | Git → frontend | `devopsdocs.zeabur.app` |
| 6 | `y-provider` | Git (add karo) | `devopsyprovider.zeabur.app` (naya) |
| 7 | `minio` | Docker image (add karo) | `minio.zeabur.app` (naya) |

---

## Screenshot audit — kya galat / missing hai

### Sab services par (devops, docs-frontend, redis*)

| Problem | Fix |
|---------|-----|
| Settings → Dockerfile box mein `FROM node:18-alpine` | **Poora box delete** → Save. Ye Node template hai, aapki services par lagana **galat** hai. |
| Startup Command = `gunicorn` (frontend par) | **Khali** rakho. Frontend = nginx, backend = image CMD `start-zeabur.sh`. |
| `redis` service par bhi Node Dockerfile dikhe | Agar **Git** service hai → **delete** karo. Sirf **Add Service → Redis** (managed) rakho. |

\* Zeabur **managed Redis** ka alag UI hota hai — us par Dockerfile nahi hona chahiye.

### `devops` (backend) — missing / galat

| Setting | Abhi (screenshot) | Sahi value |
|---------|-------------------|------------|
| Root Directory | `/` OK **ya** `office_suite/docs` | Dono chal sakte hain; override khali |
| `PORT` | `8000` | **`8080`** |
| `DJANGO_CONFIGURATION` | missing | `Production` |
| `DATABASE_URL` | sirf `POSTGRESQL_HOST` link | PostgreSQL → **Connect** → poora URL paste |
| `REDIS_URL` | sirf `REDIS_HOST` link | Redis → **Connect** → poora URL paste |
| `DJANGO_SECRET_KEY` | missing | 50+ random chars |
| `DJANGO_ALLOWED_HOSTS` | missing | `devopsdev.zeabur.app` |
| OIDC / `IMPRESS_BASE_URL` | missing | Neeche `env/devops-backend.env.example` |
| `OIDC_RP_CLIENT_SECRET` | missing | Keycloak `office_docs` secret |
| Post-deploy | missing | `python manage.py migrate --noinput` |

### `docs-frontend` — galat variable

| Variable | Abhi | Sahi |
|----------|------|------|
| `PUBLISH_AS_NIT` | typo | **`PUBLISH_AS_MIT`** = `false` |
| `PASSWORD` | random — backend ka | **Hatao** (frontend ko nahi chahiye) |
| `POSTGRESQL_HOST`, `REDIS_HOST`, `KEYCLOAK_HOST` | linked | **Hatao** — sirf build args chahiye |
| Networking port | `8080` | **Sahi** (nginx) |
| `API_ORIGIN` | `https://devopsdev.zeabur.app` | **Sahi** |

### `keycloak` — mostly OK, 2 fixes

| Item | Status |
|------|--------|
| Image `quay.io/keycloak/keycloak:24.0` | OK |
| `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` | OK (`admin` / aapka password) |
| `KC_HOSTNAME=keycloak.zeabur.app` | OK |
| `KC_PROXY=edge` | OK |
| CMD `start --hostname-strict=false` | OK; add: `--http-enabled=true` |
| Client `office_docs` redirect | **Missing frontend URI** — add `https://devopsdocs.zeabur.app/*` |
| Realm user for Docs login | **Users** mein `testuser` banao (neeche) |

### Abhi deploy nahi — add karna zaroori

| Service | Kyon |
|---------|------|
| **y-provider** | Real-time document collaboration |
| **MinIO** | Media / file storage (backend `AWS_S3_*`) |

---

## Step 0 — PostgreSQL: 2 databases

Zeabur PostgreSQL → **Console** / one-off command:

```sql
-- File: zeabur/postgres/create-databases.sql
CREATE DATABASE office_suite_docs_db;
CREATE DATABASE keycloak_db;
```

`devops` backend `DATABASE_URL` mein database name: **`office_suite_docs_db`**  
Keycloak `KC_DB_URL_DATABASE`: **`keycloak_db`**

---

## Step 1 — Service `devops` (backend)

**Settings**

| Field | Value |
|-------|--------|
| Source | Git `Grow24/devops` branch `main` |
| Root Directory | `/` **(recommended)** ya `office_suite/docs` |
| Dockerfile override | **empty** |
| Startup Command | **empty** |
| CMD | **empty** |

**Networking**

| Field | Value |
|-------|--------|
| Public domain | `devopsdev.zeabur.app` |
| Container port | **8080** |

**Variables** — copy from [`env/devops-backend.env.example`](./env/devops-backend.env.example), replace `YOUR_*`.

**Post-deploy** (service → Command, ek baar):

```bash
python manage.py migrate --noinput
python manage.py collectstatic --noinput
```

**Test**

```bash
curl -I https://devopsdev.zeabur.app/__heartbeat__/
curl -s https://devopsdev.zeabur.app/api/v1.0/config/ | head
```

Expected: **HTTP 200** (500 = `REDIS_URL` / `DATABASE_URL` galat).

---

## Step 2 — Service `docs-frontend`

**Settings**

| Field | Value |
|-------|--------|
| Root Directory | `office_suite/docs` |
| Dockerfile path | `src/frontend/Dockerfile` (ya var `ZBPACK_DOCKERFILE_PATH`) |
| Build target | `frontend-production` |
| Dockerfile override | **empty** |
| Startup / CMD | **empty** |

**Build arguments** (Variables ya Build tab):

```
API_ORIGIN=https://devopsdev.zeabur.app
DOCKER_USER=1000
PUBLISH_AS_MIT=false
SW_DEACTIVATED=true
```

**Networking:** port **8080**, domain `devopsdocs.zeabur.app`

Detail: [ZEABUR-FRONTEND-DEPLOY.md](./ZEABUR-FRONTEND-DEPLOY.md)

---

## Step 3 — Keycloak client + user

### Admin console login

| | |
|--|--|
| URL | https://keycloak.zeabur.app/admin/ |
| Username | `admin` |
| Password | Zeabur variable `KEYCLOAK_ADMIN_PASSWORD` (aapka: screenshot wala) |

### Client `office_docs` (realm **grow24**)

**Valid redirect URIs** (dono lines):

```
https://devopsdev.zeabur.app/api/v1.0/*
https://devopsdocs.zeabur.app/*
```

**Web origins:**

```
https://devopsdev.zeabur.app
https://devopsdocs.zeabur.app
```

**Client secret** → backend `OIDC_RP_CLIENT_SECRET` (aapka: `1n94fyAtn7apfb6lbB4MRsWNRdSK8h6C` — agar regenerate kiya ho to naya paste karo).

### Docs app user (realm grow24, master admin nahi)

| Username | Password |
|----------|----------|
| `testuser` | `Test@12345` |

**Users** → Create → Credentials → password set → **Temporary = Off**.

---

## Step 4 — Service `y-provider` (naya)

1. **Add Service** → Git → same repo  
2. Name: `y-provider`  
3. Root Directory: `office_suite/docs`  
4. Variable: `ZBPACK_DOCKERFILE_PATH=src/frontend/servers/y-provider/Dockerfile`  
5. Build target: `y-provider`  
6. Port: **4444**, domain e.g. `devopsyprovider.zeabur.app`  
7. Variables: [`env/y-provider.env.example`](./env/y-provider.env.example)  
8. Backend `devops` variables mein collaboration URLs update → Redeploy

---

## Step 5 — MinIO (naya)

1. **Add Service** → **Docker Image** → `minio/minio`  
2. CMD: `server --console-address :9001 /data`  
3. Variables:

```env
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=Admin@12345
```

4. Networking: API **9000**, Console **9001** (alag public domain console ke liye)  
5. Backend par:

```env
AWS_S3_ENDPOINT_URL=https://YOUR_MINIO_DOMAIN
AWS_S3_ACCESS_KEY_ID=admin
AWS_S3_SECRET_ACCESS_KEY=Admin@12345
AWS_STORAGE_BUCKET_NAME=grow24-office-docs-media-storage
AWS_S3_USE_SSL=True
```

Bucket manually console se banao ya one-off `mc` job (local compose jaisa).

---

## Flow-wise URLs + login (production)

| Step | URL | Username | Password |
|------|-----|----------|----------|
| 1 | https://keycloak.zeabur.app/admin/ | `admin` | `KEYCLOAK_ADMIN_PASSWORD` |
| 2 | https://devopsdev.zeabur.app/__heartbeat__/ | — | — (200 expect) |
| 3 | https://devopsdocs.zeabur.app/home/ | — | — |
| 4 | Start Writing → Keycloak | `testuser` | `Test@12345` |
| 5 | MinIO console (agar add kiya) | `admin` | `Admin@12345` |

---

## Final checklist

| # | Task |
|---|------|
| 1 | Sab services par Dockerfile override **khali** |
| 2 | `devops`: `PORT=8080`, full backend env, migrate run |
| 3 | `docs-frontend`: `PUBLISH_AS_MIT`, sirf build args, port 8080 |
| 4 | Keycloak: frontend redirect + web origins |
| 5 | `testuser` in realm grow24 |
| 6 | `OIDC_RP_CLIENT_SECRET` backend = Keycloak client secret |
| 7 | y-provider + MinIO add (full features) |
| 8 | GitHub latest push → har service **Redeploy** |

---

## Quick links

- Backend env template: [`env/devops-backend.env.example`](./env/devops-backend.env.example)
- Frontend build args: [`env/docs-frontend.env.example`](./env/docs-frontend.env.example)
- Keycloak env: [`env/keycloak.env.example`](./env/keycloak.env.example)
- 502/404: [DEVOPS-404-502.md](./DEVOPS-404-502.md)
- 500 Redis: [ZEABUR-500-FIX.md](./ZEABUR-500-FIX.md)
