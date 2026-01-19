# Unused Components in This Deployment

This deployment runs **infrastructure only** to minimize resource usage (~4GB).

## Not Started (by design)

| Service | Defined In | Reason Not Used |
|---------|------------|-----------------|
| `backend-service` | compose.yaml | Stratos apps provide their own backend via Cloudflare Functions |
| `nginx` | compose.yaml | Stratos apps serve their own frontend via Cloudflare Pages |

## Exited After One-Time Run

| Service | Purpose | Status |
|---------|---------|--------|
| `register-app-user-tenant` | Register tenant with backend | Skipped (backend not running) |
| `splice-onboarding` | Initial ledger setup | Completed |

## Stopped UI Services

These Splice UIs are not needed when using Stratos apps:

- `scan-web-ui`
- `sv-web-ui`
- `wallet-web-ui-app-user`
- `wallet-web-ui-app-provider`
- `wallet-web-ui-sv`
- `ans-web-ui-app-user`
- `ans-web-ui-app-provider`
- `swagger-ui`

## To Start Full Stack

If you need the cn-quickstart demo app:

```bash
# Build first (required)
make build

# Start everything
docker compose up -d
```

## Current Running Services

Only these 4 containers are running:

```
canton          - Canton participant nodes
splice          - Splice validator services
postgres        - Database
pqs-app-provider - Participant Query Store
```
