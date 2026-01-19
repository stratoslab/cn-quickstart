# Stratos Canton Infrastructure Architecture

## Overview

This is a **stripped-down fork** of [Digital Asset's cn-quickstart](https://github.com/digital-asset/cn-quickstart) that runs only the Canton ledger infrastructure. The application layer (backend, frontend) has been removed because Stratos provides its own applications via Cloudflare Pages.

## What Was Removed

| Component | Original Purpose | Why Removed |
|-----------|------------------|-------------|
| `backend/` | Java Spring Boot REST API | Stratos apps use Cloudflare Functions |
| `frontend/` | React demo application | Stratos apps (vault, rwa, swap) provide UI |
| `docker/backend-service/` | Docker config for backend | Not needed |
| `docker/register-app-user-tenant/` | Tenant registration scripts | Stratos uses direct party creation |
| `config/nginx/` | Nginx proxy config | Cloudflare handles routing |
| `docker/modules/observability/` | Grafana, Prometheus, etc. | Saves ~2GB RAM |
| `docker/modules/keycloak/` | OAuth2 identity provider | Using shared-secret auth |
| `integration-test/` | End-to-end tests | Tests the removed backend |

## What Remains

```
quickstart/
├── compose.yaml                    # Minimal compose (comments only)
├── docker/
│   └── modules/
│       ├── localnet/               # Canton + Splice infrastructure
│       │   ├── compose.yaml        # Main infrastructure services
│       │   ├── conf/canton/        # Canton participant configs
│       │   └── conf/splice/        # Splice validator configs
│       ├── splice-onboarding/      # Onboarding scripts
│       └── pqs/                    # Participant Query Store
├── daml/                           # DAML smart contracts (if needed)
├── .env                            # Default environment
├── .env.local                      # Local overrides (gitignored)
├── Makefile                        # Build/run commands
├── DEPLOYMENT.md                   # Deployment guide
└── ARCHITECTURE.md                 # This file
```

## Running Services

| Container | Image | Ports | Purpose |
|-----------|-------|-------|---------|
| **postgres** | `postgres:17` | 5432 | Database for Canton and PQS |
| **canton** | `canton:0.5.3` | 2901-2902, 2975, 3901-3902, 3975, 4901-4902, 4975 | Canton participant nodes |
| **splice** | `splice-app:0.5.3` | 2903, 3903, 4903 | Splice validator services |
| **pqs-app-provider** | `scribe:0.6.12` | - | Participant Query Store |

### Port Convention

- `2xxx` = App User participant
- `3xxx` = App Provider participant
- `4xxx` = Super Validator (SV)

| Service | App User | App Provider | SV |
|---------|----------|--------------|-----|
| Ledger API | 2901 | 3901 | 4901 |
| Admin API | 2902 | 3902 | 4902 |
| JSON API | 2975 | 3975 | 4975 |
| Validator API | 2903 | 3903 | 4903 |

---

# Stratos Ecosystem Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLOUDFLARE EDGE                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │ stratos-vault│  │ stratos-rwa  │  │ stratos-swap │  │stratos-init │ │
│  │ (Pages+Func) │  │ (Pages+Func) │  │ (Pages+Func) │  │(Pages+Func) │ │
│  │ n1.canton... │  │ rwa.canton...│  │ swap.canton..│  │init.canton..│ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘ │
│         │                 │                 │                 │         │
│         └─────────────────┼─────────────────┼─────────────────┘         │
│                           │                 │                           │
│                    ┌──────┴─────────────────┴──────┐                    │
│                    │    stratos-wallet-sdk         │                    │
│                    │    (iframe postMessage)       │                    │
│                    └──────────────┬────────────────┘                    │
│                                   │                                     │
└───────────────────────────────────┼─────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │     CLOUDFLARE TUNNEL         │
                    │   (canton-tunnel)             │
                    └───────────────┬───────────────┘
                                    │
┌───────────────────────────────────┼─────────────────────────────────────┐
│                     LOCAL CANTON INFRASTRUCTURE                          │
├───────────────────────────────────┼─────────────────────────────────────┤
│                                   │                                      │
│    ┌──────────────────────────────┴──────────────────────────────┐      │
│    │                                                              │      │
│    │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │      │
│    │  │   canton    │  │   splice    │  │    postgres         │ │      │
│    │  │ (JSON API)  │  │ (Validator) │  │    (Database)       │ │      │
│    │  │ :2975/:3975 │  │ :2903/:3903 │  │    :5432            │ │      │
│    │  └─────────────┘  └─────────────┘  └─────────────────────┘ │      │
│    │                                                              │      │
│    └──────────────────────────────────────────────────────────────┘      │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Cloudflare Tunnel Configuration

The Cloudflare tunnel (`canton-tunnel`) exposes the local Canton services to the internet:

```yaml
# /etc/cloudflared/config.yml
tunnel: canton-tunnel
credentials-file: ~/.cloudflared/<tunnel-id>.json

ingress:
  # App-User Validator API
  - hostname: p1.cantondefi.com
    path: /api/validator/*
    service: http://localhost:2903

  # App-User JSON API
  - hostname: p1-json.cantondefi.com
    service: http://localhost:2975

  # App-Provider Validator API
  - hostname: p2.cantondefi.com
    path: /api/validator/*
    service: http://localhost:3903

  # App-Provider JSON API
  - hostname: p2-json.cantondefi.com
    service: http://localhost:3975

  # Catch-all
  - service: http_status:404
```

### Setting Up the Tunnel

1. **Install cloudflared:**
   ```bash
   curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/bin/cloudflared
   chmod +x /usr/bin/cloudflared
   ```

2. **Authenticate:**
   ```bash
   cloudflared tunnel login
   ```

3. **Create tunnel:**
   ```bash
   cloudflared tunnel create canton-tunnel
   ```

4. **Configure DNS (in Cloudflare dashboard):**
   - `p1.cantondefi.com` → CNAME to `<tunnel-id>.cfargotunnel.com`
   - `p1-json.cantondefi.com` → CNAME to `<tunnel-id>.cfargotunnel.com`
   - `p2.cantondefi.com` → CNAME to `<tunnel-id>.cfargotunnel.com`
   - `p2-json.cantondefi.com` → CNAME to `<tunnel-id>.cfargotunnel.com`

5. **Create systemd service:**
   ```bash
   cloudflared service install
   systemctl enable cloudflared
   systemctl start cloudflared
   ```

---

## Stratos Wallet SDK

The `stratos-wallet-sdk` enables iframe applications to communicate with the parent wallet via postMessage.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PARENT WINDOW (stratos-vault)                │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    ParentBridge                             │ │
│  │  - Handles RPC requests from iframes                       │ │
│  │  - Manages wallet state (user, addresses, assets)          │ │
│  │  - Signs transactions (EVM, Solana, Bitcoin, TRON, TON)    │ │
│  │  - Executes Canton operations (query, create, exercise)    │ │
│  └───────────────────────────┬────────────────────────────────┘ │
│                              │ postMessage                      │
│  ┌───────────────────────────┼────────────────────────────────┐ │
│  │                     IFRAME                                  │ │
│  │  ┌─────────────────────────────────────────────────────┐   │ │
│  │  │              StratosSDK (child)                      │   │ │
│  │  │  - sdk.getUser()                                     │   │ │
│  │  │  - sdk.getAddresses()                                │   │ │
│  │  │  - sdk.getAssets()                                   │   │ │
│  │  │  - sdk.transfer()                                    │   │ │
│  │  │  - sdk.cantonQuery()                                 │   │ │
│  │  │  - sdk.cantonCreate()                                │   │ │
│  │  │  - sdk.cantonExercise()                              │   │ │
│  │  │  - sdk.signEVMTransaction()                          │   │ │
│  │  │  - sdk.sendEVMTransaction()                          │   │ │
│  │  └─────────────────────────────────────────────────────┘   │ │
│  │                                                             │ │
│  │  Example: stratos-rwa, stratos-swap                        │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### SDK Usage (in iframe app)

```typescript
import { StratosSDK } from 'stratos-wallet-sdk';

const sdk = new StratosSDK({ debug: true });

// Connect to parent
const state = await sdk.connect();
console.log('User:', state.user);
console.log('Addresses:', state.addresses);

// Get assets
const assets = await sdk.getAssets();

// Query Canton contracts
const contracts = await sdk.cantonQuery({
  templateId: 'RWAOperator:RWAAsset',
  filter: { owner: state.user.partyId }
});

// Create a Canton contract
const result = await sdk.cantonCreate({
  templateId: 'RWAOperator:RWAAsset',
  payload: {
    issuer: state.user.partyId,
    name: 'My Asset',
    value: '1000'
  }
});

// Exercise a choice
await sdk.cantonExercise({
  contractId: result.contractId,
  templateId: 'RWAOperator:RWAAsset',
  choice: 'Transfer',
  argument: { newOwner: 'some-party-id' }
});

// Send EVM transaction
const txResult = await sdk.sendEVMTransaction({
  transaction: {
    to: '0x...',
    value: '0x0',
    data: '0x...',
    chainId: 1
  }
});
```

### Supported Operations

| Category | Methods |
|----------|---------|
| **Connection** | `connect()`, `disconnect()`, `isConnected()` |
| **User** | `getUser()`, `getAddresses()`, `getAddress(chain)` |
| **Assets** | `getAssets()`, `getBalance(symbol, chain)` |
| **Transactions** | `getTransactions()`, `transfer()` |
| **Canton** | `cantonQuery()`, `cantonCreate()`, `cantonExercise()`, `grantUserRights()` |
| **EVM** | `signEVMTransaction()`, `sendEVMTransaction()`, `signTypedData()` |
| **Solana** | `signRawSolanaTransaction()`, `sendRawSolanaTransaction()` |
| **Bitcoin** | `signBTCTransaction()`, `sendBTCTransaction()` |
| **TRON** | `triggerTronSmartContract()`, `broadcastTronTransaction()` |
| **TON** | `signRawTonMessage()`, `sendRawTonMessage()` |

---

## Cloudflare Wallet (Parent Bridge Implementation)

The `cloudflare-wallet` serves as the parent window that implements the `ParentBridge` interface.

### Key Components

```
cloudflare-wallet/
├── src/
│   └── App.tsx                    # Main React app with ParentBridge
├── functions/
│   ├── _lib/
│   │   ├── canton-json-client.ts  # Canton JSON API v2 client
│   │   └── splice-client.ts       # Splice Validator API client
│   └── api/
│       ├── auth/                  # WebAuthn authentication
│       ├── admin/                 # User/party management
│       ├── wallet/                # Wallet operations
│       └── canton/                # Canton contract operations
├── schema.sql                     # D1 database schema
└── wrangler.toml                  # Cloudflare configuration
```

### Canton Integration

The wallet connects to Canton via two clients:

**1. CantonJsonClient** (`canton-json-client.ts`)
- Endpoint: `https://p1-json.cantondefi.com` (or `p2-json`)
- API Version: v2
- Auth: JWT with HS256 (shared secret)

```typescript
const client = new CantonJsonClient({
  host: 'p1-json.cantondefi.com',
  port: 443,
  authSecret: 'unsafe',
  authUser: 'ledger-api-user',
  authAudience: 'https://canton.network.global'
});

// Party operations
await client.allocateParty('myparty', 'My Party');
await client.createUser('user123', partyId, 'User Name');
await client.grantRights('user123', partyId);

// Contract operations
const contracts = await client.queryContracts(partyId, templateId);
await client.createContract(partyId, templateId, payload);
await client.exerciseChoice(partyId, contractId, templateId, choice, args);
```

**2. SpliceClient** (`splice-client.ts`)
- Endpoint: `https://p1.cantondefi.com/api/validator/v0`
- Purpose: Wallet operations (balance, transfers, tap)

```typescript
const client = new SpliceClient({
  validatorHost: 'p1.cantondefi.com',
  validatorPort: 443,
  authSecret: 'unsafe',
  authUser: 'ledger-api-user',
  authAudience: 'https://canton.network.global'
});

await client.register();
const balance = await client.getBalance();
await client.createTransferOffer(receiver, amount);
```

---

## App Embedding Flow

1. **User visits stratos-vault** (parent window)
2. **User authenticates** via WebAuthn passkey
3. **Parent loads iframe** with embedded app (e.g., stratos-rwa)
4. **Iframe initializes SDK** and calls `sdk.connect()`
5. **Parent responds** with user info, addresses, assets
6. **Iframe app** makes SDK calls as needed
7. **Parent handles** Canton operations, transaction signing

### Security Model

- **Origin validation**: Parent validates iframe origin against allowlist
- **No private keys in iframe**: All signing happens in parent
- **WebAuthn PRF**: Keys encrypted with hardware-backed passkeys
- **Non-custodial**: Server never sees private keys

---

## Deployment Checklist

1. **Start Canton infrastructure:**
   ```bash
   cd quickstart
   # Use the provided start script or make start
   ```

2. **Verify services:**
   ```bash
   docker ps  # Should show: postgres, canton, splice, pqs-app-provider
   ```

3. **Start Cloudflare tunnel:**
   ```bash
   systemctl start cloudflared
   ```

4. **Test endpoints:**
   ```bash
   curl https://p1-json.cantondefi.com/v2/parties/participant-id
   curl https://p2.cantondefi.com/api/validator/v0/wallet/user-status
   ```

5. **Deploy Stratos apps:**
   ```bash
   cd ../stratos-vault && npm run deploy
   cd ../stratos-rwa && npm run deploy
   # etc.
   ```
