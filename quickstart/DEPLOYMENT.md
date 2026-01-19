# Canton Infrastructure Deployment Guide

This is a **stripped-down** cn-quickstart that runs Canton infrastructure only.
For full architecture details, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Quick Start

```bash
# Start infrastructure
cd quickstart
source .env && source .env.local

# Using the localnet module directly
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

## Running Services

| Container | Image | Memory | Purpose |
|-----------|-------|--------|---------|
| postgres | postgres:17 | 1 GB | Database |
| canton | canton:0.5.3 | 1.7 GB | Canton participants |
| splice | splice-app:0.5.3 | 833 MB | Splice validators |
| pqs-app-provider | scribe:0.6.12 | 646 MB | Query Store |

**Total: ~4.2 GB RAM**

## Configuration

### .env.local (create this file)

```bash
OBSERVABILITY_ENABLED=false
AUTH_MODE=shared-secret
PARTY_HINT=local-validator-1
PQS_APP_USER_PROFILE=off
PQS_SV_PROFILE=off
RESOURCE_CONSTRAINTS_ENABLED=true
```

## API Endpoints

| Service | Port | URL via Tunnel |
|---------|------|----------------|
| App-User JSON API | 2975 | p1-json.cantondefi.com |
| App-User Validator | 2903 | p1.cantondefi.com |
| App-Provider JSON API | 3975 | p2-json.cantondefi.com |
| App-Provider Validator | 3903 | p2.cantondefi.com |

## Authentication

Using shared-secret mode with JWT tokens:

```python
import jwt, time

token = jwt.encode({
    'aud': 'https://canton.network.global',
    'sub': 'ledger-api-user',
    'exp': int(time.time()) + 3600
}, 'unsafe', algorithm='HS256')
```

## Operations

**Check status:**
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**View logs:**
```bash
docker logs -f canton
docker logs -f splice
```

**Stop:**
```bash
docker compose down
```

## Cloudflare Tunnel

See [ARCHITECTURE.md](ARCHITECTURE.md#cloudflare-tunnel-configuration) for tunnel setup instructions.
