# Stratos Canton Infrastructure

> **Stripped-down fork of [Digital Asset's cn-quickstart](https://github.com/digital-asset/cn-quickstart)**

This repository contains only the **Canton ledger infrastructure** - the application layer (backend, frontend) has been removed. Stratos apps provide their own UI and backend via Cloudflare Pages/Functions.

## What's Included

| Component | Description |
|-----------|-------------|
| Canton participant nodes | Ledger API, Admin API, JSON API |
| Splice validator services | Wallet operations, transfers |
| PostgreSQL | Database for Canton and PQS |
| Participant Query Store | Contract indexing (Scribe) |

## What's Removed

- `backend/` - Java Spring Boot REST API
- `frontend/` - React demo application
- `docker/modules/observability/` - Grafana, Prometheus, Loki, Tempo
- `docker/modules/keycloak/` - OAuth2 identity provider
- `integration-test/` - End-to-end tests

## Documentation

| Document | Description |
|----------|-------------|
| [quickstart/ARCHITECTURE.md](quickstart/ARCHITECTURE.md) | Full system architecture, Cloudflare tunnel setup, Wallet SDK docs |
| [quickstart/DEPLOYMENT.md](quickstart/DEPLOYMENT.md) | Quick start deployment guide |

## Quick Start

```bash
cd quickstart

# Create local config
cat > .env.local << 'EOF'
OBSERVABILITY_ENABLED=false
AUTH_MODE=shared-secret
PARTY_HINT=local-validator-1
PQS_APP_USER_PROFILE=off
PQS_SV_PROFILE=off
RESOURCE_CONSTRAINTS_ENABLED=true
EOF

# Start infrastructure
MODULES_DIR=$(pwd)/docker/modules \
LOCALNET_DIR=$MODULES_DIR/localnet \
docker compose \
  -f $LOCALNET_DIR/compose.yaml \
  -f $MODULES_DIR/splice-onboarding/compose.yaml \
  -f $MODULES_DIR/pqs/compose.yaml \
  --env-file .env --env-file .env.local \
  --env-file $LOCALNET_DIR/compose.env \
  --env-file $LOCALNET_DIR/env/common.env \
  --env-file $MODULES_DIR/pqs/compose.env \
  -f $LOCALNET_DIR/resource-constraints.yaml \
  --profile app-provider --profile pqs-app-provider \
  up -d postgres canton splice pqs-app-provider
```

## API Endpoints

| Service | Port | Tunnel URL |
|---------|------|------------|
| App-User JSON API | 2975 | p1-json.cantondefi.com |
| App-User Validator | 2903 | p1.cantondefi.com |
| App-Provider JSON API | 3975 | p2-json.cantondefi.com |
| App-Provider Validator | 3903 | p2.cantondefi.com |

## Stratos Ecosystem

This Canton infrastructure serves:

- **[stratos-vault](https://github.com/stratoslab/vault)** - Multi-chain yield farming
- **[stratos-rwa](https://github.com/stratoslab/rwa)** - Real World Asset marketplace
- **[stratos-swap](https://github.com/stratoslab/swap)** - Token swap/DEX
- **[stratos-wallet-sdk](https://github.com/stratoslab/stratos-wallet-sdk)** - Wallet integration SDK

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  CLOUDFLARE EDGE                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        │
│  │stratos-vault│ │ stratos-rwa │ │stratos-swap │        │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘        │
│         └───────────────┼───────────────┘               │
│                         │ stratos-wallet-sdk            │
└─────────────────────────┼───────────────────────────────┘
                          │ Cloudflare Tunnel
┌─────────────────────────┼───────────────────────────────┐
│              CANTON INFRASTRUCTURE                       │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐                 │
│  │ canton  │  │ splice  │  │ postgres │                 │
│  │JSON API │  │Validator│  │    DB    │                 │
│  └─────────┘  └─────────┘  └──────────┘                 │
└──────────────────────────────────────────────────────────┘
```

## Original Project

This is a fork of [digital-asset/cn-quickstart](https://github.com/digital-asset/cn-quickstart). See their documentation for the full application:

- [Quickstart Installation](https://docs.digitalasset.com/build/3.3/quickstart/download/cnqs-installation.html)
- [Project Structure](https://docs.digitalasset.com/build/3.3/quickstart/configure/project-structure-overview.html)

## License

Licensed under the BSD Zero Clause License. [Binaries terms and conditions](terms.md).
