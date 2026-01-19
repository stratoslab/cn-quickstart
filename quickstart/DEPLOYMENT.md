# Local Canton Deployment Documentation

## Overview

This is a minimal cn-quickstart deployment configured for low memory usage (~4GB). It runs the core Canton infrastructure without the application layer (backend/frontend).

## Current Configuration

**Auth Mode:** `shared-secret` (no Keycloak)
**Observability:** Disabled
**Resource Constraints:** Enabled (minimal)

### Environment (.env.local)

```bash
OBSERVABILITY_ENABLED=false
AUTH_MODE=shared-secret
PARTY_HINT=local-validator-1
PQS_APP_USER_PROFILE=off
PQS_SV_PROFILE=off
RESOURCE_CONSTRAINTS_ENABLED=true
```

---

## Running Components

| Container | Image | Port(s) | Memory | Purpose |
|-----------|-------|---------|--------|---------|
| **canton** | `canton:0.4.17` | 2901-2902, 2975, 3901-3902, 3975, 4901-4902, 4975 | 1.7 GB | Canton participant nodes |
| **splice** | `splice-app:0.4.17` | 2903, 3903, 4903 | 833 MB | Splice validator/wallet services |
| **postgres** | `postgres:17` | 5432 | 1.0 GB | Database for Canton and PQS |
| **pqs-app-provider** | `scribe:0.6.11` | — | 646 MB | Participant Query Store |

**Total Memory:** ~4.2 GB

---

## Unused Components (Deliberately Stopped)

These components are defined in compose.yaml but not started to reduce resource usage:

| Container | Status | Purpose | Why Unused |
|-----------|--------|---------|------------|
| **backend-service** | Created (never started) | Java Spring Boot app for quickstart demo | Stratos apps provide their own backend |
| **nginx** | Created (never started) | Frontend proxy for quickstart React app | Stratos apps have their own UI |
| **register-app-user-tenant** | Exited | One-time tenant registration task | Requires backend-service |
| **splice-onboarding** | Exited | One-time onboarding scripts | Completed or not needed |
| **scan-web-ui** | Exited | Splice scan UI | Not needed for API-only usage |
| **sv-web-ui** | Exited | Super Validator UI | Not needed |
| **wallet-web-ui-*** | Exited | Splice wallet UIs | Stratos provides its own wallet |
| **ans-web-ui-*** | Exited | Address Name Service UIs | Not needed |
| **swagger-ui** | Exited | API documentation UI | Can be started if needed |

---

## Port Reference

### Canton Participant Ports (by role)

| Role | Ledger API | Admin API | JSON API |
|------|------------|-----------|----------|
| App User (2xxx) | 2901 | 2902 | 2975 |
| App Provider (3xxx) | 3901 | 3902 | 3975 |
| SV (4xxx) | 4901 | 4902 | 4975 |

### Splice Validator Ports

| Role | Admin API |
|------|-----------|
| App User | 2903 |
| App Provider | 3903 |
| SV | 4903 |

---

## API Authentication

This deployment uses **shared-secret** authentication with HS256 JWT tokens.

### Token Generation

```python
import jwt
import time

token = jwt.encode(
    {
        'aud': 'https://canton.network.global',
        'sub': 'ledger-api-user',  # or specific user
        'exp': int(time.time()) + 3600
    },
    'unsafe',  # shared secret
    algorithm='HS256'
)
```

### Example API Calls

**List Parties (App Provider):**
```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:3975/v2/parties
```

**Get Participant ID:**
```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:3975/v2/parties/participant-id
```

**Create Party:**
```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  http://localhost:3975/v2/parties \
  -d '{"partyIdHint": "myparty", "displayName": "My Party"}'
```

---

## Architecture: Canton vs Tenant Model

### Canton Ledger Primitives

The Canton ledger has NO concept of "tenant". Its core primitives are:

- **Party** - Identity on the ledger (can sign contracts)
- **User** - Authenticated identity that acts as parties
- **Participant** - Node that hosts parties
- **Contract** - Data + logic stored on ledger

### cn-quickstart Tenant Model

The "tenant" is an APPLICATION-level abstraction in the Java backend-service:

```
┌─────────────────────────────────────┐
│  backend-service (Java)             │  ← "tenant" registry here
│  POST /admin/tenant-registrations   │
│  Maps: tenantId → partyId + OAuth   │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│  Canton Ledger                      │  ← no tenant concept
│  Parties, Users, Contracts          │
└─────────────────────────────────────┘
```

### Stratos Multi-Tenant Model (Alternative)

Stratos apps achieve multi-tenancy at the infrastructure layer:

```
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Cloudflare Pages │  │ Cloudflare Pages │  │ Cloudflare Pages │
│ App 1 (own D1)   │  │ App 2 (own D1)   │  │ App 3 (own D1)   │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         └─────────────────────┼─────────────────────┘
                               ▼
                    ┌─────────────────────┐
                    │  Canton APIs        │
                    │  (shared ledger)    │
                    └─────────────────────┘
```

**Advantages:**
- No tenant registry to maintain
- Each app has isolated user database
- Horizontal scaling via Cloudflare edge
- Deploy new "tenants" by deploying new Pages instance

---

## Operations

### Start Only Infrastructure (current state)

```bash
docker compose up -d canton splice postgres pqs-app-provider
```

### Start Full Stack (includes backend/frontend)

```bash
docker compose up -d
```

### View Logs

```bash
docker compose logs -f canton
docker compose logs -f splice
```

### Check Health

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

## Related Projects

This Canton deployment serves as the backend for:

- **stratos-vault** - Multi-chain yield farming platform
- **stratos-rwa** - Real World Asset marketplace
- **stratos-swap** - Token swap/DEX
- **cloudflare-wallet** - WebAuthn wallet with Canton integration

These apps connect directly to Canton APIs (ports 3975, 3903) without using the cn-quickstart backend-service tenant model.
