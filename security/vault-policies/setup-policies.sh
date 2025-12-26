#!/bin/bash
set -e

echo "=== Setting up Vault Policies ==="

# Vault address
VAULT_ADDR=${VAULT_ADDR:-"http://vault.local"}
export VAULT_ADDR

# Check if logged in
if ! vault token lookup > /dev/null 2>&1; then
  echo "Error: Not logged in to Vault. Please login first:"
  echo "  vault login"
  exit 1
fi

echo "Creating Jenkins CI policy..."
vault policy write jenkins-ci jenkins-ci-policy.hcl

echo "Creating Webapp Dev policy..."
vault policy write webapp-dev webapp-dev-policy.hcl

echo "Creating WebAPI Dev policy..."
vault policy write webapi-dev webapi-dev-policy.hcl

echo ""
echo "=== Policies created successfully ==="
echo ""
echo "List all policies:"
vault policy list

echo ""
echo "Next steps:"
echo "1. Create AppRole for Jenkins:"
echo "   vault auth enable approle"
echo "   vault write auth/approle/role/jenkins-ci policies=jenkins-ci"
echo ""
echo "2. Enable Kubernetes auth for applications:"
echo "   vault auth enable kubernetes"
echo "   vault write auth/kubernetes/config kubernetes_host=https://kubernetes.default.svc"
echo ""
echo "3. Create Kubernetes auth roles:"
echo "   vault write auth/kubernetes/role/webapp-dev bound_service_account_names=webapp bound_service_account_namespaces=dev policies=webapp-dev ttl=24h"
echo "   vault write auth/kubernetes/role/webapi-dev bound_service_account_names=webapi bound_service_account_namespaces=dev policies=webapi-dev ttl=24h"
