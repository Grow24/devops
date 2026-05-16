# Zeabur error: "No Dockerfile found in the repository"

## Problem (aapke screenshot jaisa)

- **Root Directory** = `/` (repo root) — yahan koi `Dockerfile` nahi hai
- Settings mein **galat** `node:18-alpine` Dockerfile likha hai (ye Node app hai, Docs Django/Python hai)

## Fix (5 minute)

### Step 1 — Settings → Root Directory

| Field | Value |
|-------|--------|
| **Root Directory** | `office_suite/docs` |

> Slash `/` mat rakho. Exactly: `office_suite/docs`

### Step 2 — Dockerfile override hatao

1. Settings → Dockerfile wala box **poora khali** kar do (node:18 lines delete)
2. **Save** dabao
3. Phir **Redeploy** (Overview → Redeploy)

Zeabur ab `office_suite/docs/Dockerfile` use karega (Python/Django backend).

### Step 3 — Port

| Field | Value |
|-------|--------|
| **Port** | `8000` |

### Step 4 — Variables (kam se kam)

Zeabur → **Variable** tab → `zeabur/zeabur.env.example` se values bharo:

- `DJANGO_CONFIGURATION=Production`
- `DATABASE_URL` = Zeabur PostgreSQL connection string
- `REDIS_URL` = Zeabur Redis connection string
- `DJANGO_SECRET_KEY` = long random string
- `DJANGO_ALLOWED_HOSTS` = aapka backend domain

### Step 5 — Deploy ke baad

Service → **Command** (one-off):

```bash
python manage.py migrate --noinput
python manage.py collectstatic --noinput
```

---

## Agar service ka naam `devops` hai

Repo mein `office_suite/docs/Dockerfile.devops` add hai — Zeabur is naam se auto-match kar sakta hai. Phir bhi **Root Directory = `office_suite/docs`** zaroori hai.

---

## Alag services (ek hi GitHub repo)

| Service | Root Directory | Dockerfile |
|---------|----------------|------------|
| Backend (`devops`) | `office_suite/docs` | default `Dockerfile` |
| Frontend | `office_suite/docs` | Variable: `ZBPACK_DOCKERFILE_PATH=src/frontend/Dockerfile` + build arg `API_ORIGIN` |
| y-provider | `office_suite/docs` | `ZBPACK_DOCKERFILE_PATH=src/frontend/servers/y-provider/Dockerfile` |

Poori guide: [DEPLOY-ZEABUR.md](./DEPLOY-ZEABUR.md)
