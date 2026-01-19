#!/bin/bash
# Start cn-quickstart with additional participant2 node

set -e

cd /root/cantonlocal/cn-quickstart/quickstart

echo "================================================"
echo "Starting Canton with participant2"
echo "================================================"

# Load env files
source .env
source .env.local 2>/dev/null || true

export MODULES_DIR="$(pwd)/docker/modules"
export LOCALNET_DIR="${MODULES_DIR}/localnet"
export LOCALNET_ENV_DIR="${LOCALNET_DIR}/env"

# Stop existing containers
echo "[1/3] Stopping existing containers..."
docker compose -f compose.yaml \
  -f docker/modules/localnet/compose.yaml \
  -f docker/modules/splice-onboarding/compose.yaml \
  -f docker/modules/pqs/compose.yaml \
  -f docker/modules/localnet/compose-participant2.yaml \
  --env-file .env --env-file .env.local \
  --env-file docker/modules/localnet/compose.env \
  --env-file docker/modules/localnet/env/common.env \
  --env-file docker/modules/pqs/compose.env \
  --profile app-provider --profile app-user --profile sv --profile swagger-ui --profile pqs-app-provider \
  down 2>/dev/null || true

# Start with participant2
echo "[2/3] Starting containers with participant2..."
docker compose -f compose.yaml \
  -f docker/modules/localnet/compose.yaml \
  -f docker/modules/splice-onboarding/compose.yaml \
  -f docker/modules/pqs/compose.yaml \
  -f docker/modules/localnet/compose-participant2.yaml \
  --env-file .env --env-file .env.local \
  --env-file docker/modules/localnet/compose.env \
  --env-file docker/modules/localnet/env/common.env \
  --env-file docker/modules/pqs/compose.env \
  --profile app-provider --profile app-user --profile sv --profile swagger-ui --profile pqs-app-provider \
  up -d

echo "[3/3] Waiting for services to be healthy..."
sleep 10

echo ""
echo "================================================"
echo "Container Status"
echo "================================================"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "canton|splice|postgres"

echo ""
echo "================================================"
echo "Participant2 Ports"
echo "================================================"
echo "  Canton Ledger API:    localhost:5901"
echo "  Canton Admin API:     localhost:5902"
echo "  Canton JSON API:      localhost:5975"
echo "  Splice Validator API: localhost:5903"
echo ""
echo "Test participant2 JSON API:"
echo "  curl http://localhost:5975/v2/version"
echo ""
echo "Test participant2 Splice API:"
echo "  TOKEN=\$(node -e \"console.log(require('jsonwebtoken').sign({sub:'participant2-admin',aud:'https://canton.network.global'},'unsafe',{algorithm:'HS256'}))\")"
echo "  curl -H \"Authorization: Bearer \$TOKEN\" http://localhost:5903/api/validator/v0/wallet/balance"
echo ""
