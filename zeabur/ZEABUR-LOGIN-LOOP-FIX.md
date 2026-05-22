# Zeabur — login ke baad wapas /home/ (fix)

## Problem

Keycloak login success → phir bhi `https://devopsdocs.zeabur.app/home/` (landing page), dashboard nahi.

**Reason:** Frontend `devopsdocs` API `devopsdev` par `users/me/` call karta hai. Agar **CORS** ya **session cookie** sahi nahi → user "logged out" dikhta hai → `/home/` par hi rehte ho.

---

## Fix — service `devops` → Variable (ek-ek add karo)

Zeabur → project **devops** → service **`devops`** → tab **Variable** → **Edit Raw** → ye lines **zaroor** hon:

| Variable | Value |
|----------|--------|
| `CORS_ALLOW_ALL_ORIGINS` | `False` |
| `CORS_ALLOWED_ORIGINS` | `["https://devopsdocs.zeabur.app"]` |
| `CSRF_TRUSTED_ORIGINS` | `["https://devopsdocs.zeabur.app","https://devopsdev.zeabur.app"]` |
| `SESSION_COOKIE_SAMESITE` | `None` |
| `CSRF_COOKIE_SAMESITE` | `None` |
| `SESSION_COOKIE_SECURE` | `True` |
| `CSRF_COOKIE_SECURE` | `True` |
| `LOGIN_REDIRECT_URL` | `https://devopsdocs.zeabur.app/home/` |
| `LOGIN_REDIRECT_URL_FAILURE` | `https://devopsdocs.zeabur.app/login-error` |
| `LOGOUT_REDIRECT_URL` | `https://devopsdocs.zeabur.app` |
| `IMPRESS_BASE_URL` | `https://devopsdocs.zeabur.app` |
| `OIDC_RP_CLIENT_SECRET` | Keycloak `office_docs` secret (same as Credentials tab) |

→ **Save** → **Redeploy** `devops`

---

## Fix — Keycloak (browser)

1. https://keycloak.zeabur.app/admin/ → realm **grow24** → **Clients** → **office_docs**
2. **Valid redirect URIs** — dono lines:

```
https://devopsdev.zeabur.app/api/v1.0/*
https://devopsdocs.zeabur.app/*
```

3. **Web origins** — dono:

```
https://devopsdev.zeabur.app
https://devopsdocs.zeabur.app
```

4. **Save**

---

## Fix — `docs-frontend` rebuild (API_ORIGIN)

Agar login ke baad bhi fail ho:

1. **docs-frontend** → Variable → `API_ORIGIN` = `https://devopsdev.zeabur.app` (no trailing slash)
2. **Redeploy** (naya build — purana build galat API par ho sakta hai)

---

## Test (browser DevTools)

1. Login karo → **F12** → **Network**
2. Filter: `users/me`
3. Request URL honi chahiye: `https://devopsdev.zeabur.app/api/v1.0/users/me/`
4. **Expected:** Status **200** + JSON user data  
5. **Galat:** 401 ya CORS error → `devops` variables dubara check karo

---

## Expected after fix

Login → `https://devopsdocs.zeabur.app/home/` → short loading → redirect **`https://devopsdocs.zeabur.app/`** → **All docs** grid + onboarding modal (jaise localhost screenshot).
