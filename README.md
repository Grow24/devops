# GROW24 Office Suite — DevOps Setup

La Suite **Docs** (Impress) + PostgreSQL + Redis + Keycloak + MinIO — local Docker stack and Zeabur deployment guide.

## Project structure

```
DEVOPS Setup/
├── database/          # PostgreSQL + Redis
├── keycloak/          # Keycloak (realm: grow24)
├── office_suite/docs/ # Docs app (backend, frontend, y-provider)
├── scripts/           # Helper scripts
└── zeabur/            # Zeabur environment variable templates
```

## Local setup (quick)

```bash
chmod +x scripts/setup-local-env.sh
./scripts/setup-local-env.sh
# Edit env files with your passwords

./database/run-postgres-redis.sh
./keycloak/run-keycloak.sh

cd office_suite/docs
docker compose -f docker_compose_production.yml up -d --build
docker compose -f docker_compose_production.yml exec app-prod python manage.py migrate --noinput
docker compose -f docker_compose_production.yml exec app-prod python manage.py collectstatic --noinput
```

| Service   | URL |
|-----------|-----|
| Docs UI   | http://localhost:20003 |
| API       | http://localhost:20001 |
| Keycloak  | http://localhost:28061 (login), http://localhost:28061/admin/ (admin) |
| MinIO     | http://localhost:20010 |

**Login (grow24 realm):** `testuser` / `Test@12345` or `grow24_admin` / `grow24_admin123`  
**Keycloak master admin (console only):** `grow24_admin` / `grow24_admin123`

## GitHub — step by step

> **Important:** Do not use `/home/bappu` as the git root. This folder has its own repo.

### Step 1 — GitHub par naya repository

1. https://github.com/new par jao  
2. Repository name: e.g. `grow24-office-suite`  
3. **Private** recommend (secrets templates only; real passwords Zeabur par)  
4. README / .gitignore mat add karo — khali repo banao  
5. **Create repository**

### Step 2 — Local repo initialize (pehli baar)

```bash
cd "/home/bappu/bpmn_check/DEVOPS Setup"

git init
git branch -M main
chmod +x scripts/*.sh database/*.sh keycloak/*.sh office_suite/docs/run-docs.sh 2>/dev/null || true

git add .
git status
```

`git status` mein **ye files nahi dikhni chahiye** (`.gitignore` se hide):

- `**/env.d/.env`, `office_suite/docs/env.d/grow24/common`
- `database/postgres/data/`, `keycloak/keycloak_data/`, `office_suite/docs/data/`

### Step 3 — Pehla commit

```bash
git commit -m "Add GROW24 office suite DevOps stack (Docs, Keycloak, Postgres, Redis)"
```

### Step 4 — GitHub se connect + push

`YOUR_GITHUB_USER` aur `YOUR_REPO` apne account se replace karo:

```bash
git remote add origin https://github.com/YOUR_GITHUB_USER/YOUR_REPO.git
git push -u origin main
```

SSH use karte ho to:

```bash
git remote add origin git@github.com:YOUR_GITHUB_USER/YOUR_REPO.git
git push -u origin main
```

### Step 5 — Baad mein changes push

```bash
git add .
git commit -m "Describe your change"
git push
```

---

Zeabur deploy:

- **[zeabur/ZEABUR-COMPLETE-GUIDE.md](./zeabur/ZEABUR-COMPLETE-GUIDE.md)** — screenshot audit + saari services (start here)
- **[DEPLOY-ZEABUR.md](./DEPLOY-ZEABUR.md)** — architecture overview
- Env templates: `zeabur/env/*.env.example`
