#!/bin/bash
set -e

echo "=== Populating Vault with Sample Secrets ==="

# Vault address
VAULT_ADDR=${VAULT_ADDR:-"http://vault.local"}
export VAULT_ADDR

# Check if logged in
if ! vault token lookup > /dev/null 2>&1; then
  echo "Error: Not logged in to Vault. Please login first:"
  echo "  vault login"
  exit 1
fi

# Enable KV v2 secrets engine if not already enabled
echo "Enabling KV v2 secrets engine..."
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV v2 already enabled"

echo ""
echo "=== Creating CI/CD Secrets ==="

# Harbor registry credentials
echo "Creating Harbor credentials..."
vault kv put secret/ci/harbor \
  username="admin" \
  password="HarborAdmin123" \
  registry="harbor.local"

# GitHub credentials
echo "Creating GitHub credentials..."
vault kv put secret/ci/github \
  username="jenkins-bot" \
  token="ghp_your_github_token_here" \
  email="jenkins@example.com"

# Argo CD credentials
echo "Creating Argo CD credentials..."
vault kv put secret/ci/argocd \
  server="argocd.local" \
  token="your_argocd_token_here"

# Docker build secrets (example)
echo "Creating Docker build secrets..."
vault kv put secret/ci/docker/build-args \
  npm_token="your_npm_token_here" \
  nuget_api_key="your_nuget_key_here"

echo ""
echo "=== Creating Dev Environment Secrets ==="

# Webapp secrets
echo "Creating Webapp Dev secrets..."
vault kv put secret/dev/webapp \
  jwt_secret="dev-jwt-secret-change-in-production" \
  api_key="dev-api-key-12345" \
  encryption_key="dev-encryption-key-32-chars-long" \
  next_public_api_url="http://webapi-service:5000"

# WebAPI secrets
echo "Creating WebAPI Dev secrets..."
vault kv put secret/dev/webapi \
  jwt_secret="dev-jwt-secret-change-in-production" \
  jwt_issuer="https://api.local" \
  jwt_audience="https://webapp.local" \
  database_connection_string="Server=postgres;Database=sampledb;User Id=devuser;Password=devpass123;" \
  redis_connection_string="redis:6379,password=devredis123" \
  smtp_password="dev-smtp-password"

# Shared dev secrets
echo "Creating shared Dev secrets..."
vault kv put secret/dev/shared/database \
  host="postgres.dev.svc.cluster.local" \
  port="5432" \
  username="devuser" \
  password="devpass123" \
  database="sampledb"

vault kv put secret/dev/shared/redis \
  host="redis.dev.svc.cluster.local" \
  port="6379" \
  password="devredis123"

echo ""
echo "=== Secrets populated successfully ==="
echo ""
echo "Verify secrets:"
echo "  vault kv list secret/ci"
echo "  vault kv get secret/ci/harbor"
echo "  vault kv get secret/dev/webapp"
echo "  vault kv get secret/dev/webapi"
echo ""
echo "⚠️  IMPORTANT: Update the placeholder values with real secrets!"
echo "⚠️  NEVER commit real secrets to Git!"
