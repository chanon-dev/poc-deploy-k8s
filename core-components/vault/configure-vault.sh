#!/bin/bash
# Vault Configuration Script
# Configures Vault after initialization

set -e

echo "=== Vault Configuration Script ==="

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"
KEYS_FILE="vault-keys.json"

# Check if keys file exists
if [ ! -f "$KEYS_FILE" ]; then
    echo "Error: $KEYS_FILE not found. Please run init-unseal.sh first."
    exit 1
fi

# Get root token
ROOT_TOKEN=$(cat $KEYS_FILE | jq -r '.root_token')

# Login to Vault
echo "Logging in to Vault..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault login $ROOT_TOKEN

# Enable Kubernetes auth method
echo "Enabling Kubernetes auth method..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault auth enable kubernetes || echo "Kubernetes auth already enabled"

# Configure Kubernetes auth
echo "Configuring Kubernetes auth..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- sh -c '
    vault write auth/kubernetes/config \
        kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
        token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
'

# Enable KV v2 secrets engine
echo "Enabling KV v2 secrets engine..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault secrets enable -path=secret kv-v2 || echo "KV v2 already enabled"

# Create secret paths for each environment
echo "Creating secret paths..."
for env in dev sit uat prod ci; do
    echo "Creating path for $env..."
    kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv put secret/$env/placeholder key=value || true
done

# Create policies
echo "Creating policies..."

# Dev environment policy
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault policy write dev-policy - <<EOF
path "secret/data/dev/*" {
  capabilities = ["read", "list"]
}
EOF

# SIT environment policy
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault policy write sit-policy - <<EOF
path "secret/data/sit/*" {
  capabilities = ["read", "list"]
}
EOF

# UAT environment policy
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault policy write uat-policy - <<EOF
path "secret/data/uat/*" {
  capabilities = ["read", "list"]
}
EOF

# Prod environment policy
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault policy write prod-policy - <<EOF
path "secret/data/prod/*" {
  capabilities = ["read", "list"]
}
EOF

# Jenkins/CI policy
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault policy write ci-policy - <<EOF
path "secret/data/ci/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/data/dev/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/data/sit/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

# Create Kubernetes auth roles for each environment
echo "Creating Kubernetes auth roles..."

# Dev role
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/role/dev \
    bound_service_account_names=default \
    bound_service_account_namespaces=dev \
    policies=dev-policy \
    ttl=24h

# SIT role
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/role/sit \
    bound_service_account_names=default \
    bound_service_account_namespaces=sit \
    policies=sit-policy \
    ttl=24h

# UAT role
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/role/uat \
    bound_service_account_names=default \
    bound_service_account_namespaces=uat \
    policies=uat-policy \
    ttl=24h

# Prod role
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/role/prod \
    bound_service_account_names=default \
    bound_service_account_namespaces=prod \
    policies=prod-policy \
    ttl=24h

# Jenkins role
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/role/jenkins \
    bound_service_account_names=jenkins \
    bound_service_account_namespaces=jenkins \
    policies=ci-policy \
    ttl=1h

# Enable audit logging
echo "Enabling audit logging..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault audit enable file file_path=/vault/audit/audit.log || echo "Audit already enabled"

echo ""
echo "✅ Vault configuration completed successfully!"
echo ""
echo "Vault is now configured with:"
echo "- Kubernetes auth method"
echo "- KV v2 secrets engine at 'secret/'"
echo "- Policies for dev, sit, uat, prod, and ci"
echo "- Kubernetes auth roles for each environment"
echo "- Audit logging enabled"
echo ""
echo "Next steps:"
echo "1. Add secrets: kubectl exec -it -n vault vault-0 -- vault kv put secret/dev/myapp password=secret123"
echo "2. Test injection: See examples in README.md"
echo ""
