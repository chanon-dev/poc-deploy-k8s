#!/bin/bash
# Vault Initialization and Unseal Script
# This script initializes and unseals a new Vault cluster

set -e

echo "=== Vault Initialization and Unseal Script ==="

# Configuration
VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"
KEYS_FILE="vault-keys.json"

# Check if vault is already initialized
echo "Checking if Vault is already initialized..."
if kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault status 2>&1 | grep -q "Initialized.*true"; then
    echo "Vault is already initialized!"
    read -p "Do you want to unseal? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$KEYS_FILE" ]; then
            echo "Unsealing Vault..."
            UNSEAL_KEY_1=$(cat $KEYS_FILE | jq -r '.unseal_keys_b64[0]')
            UNSEAL_KEY_2=$(cat $KEYS_FILE | jq -r '.unseal_keys_b64[1]')
            UNSEAL_KEY_3=$(cat $KEYS_FILE | jq -r '.unseal_keys_b64[2]')

            kubectl exec -n $VAULT_NAMESPACE vault-0 -- vault operator unseal $UNSEAL_KEY_1
            kubectl exec -n $VAULT_NAMESPACE vault-0 -- vault operator unseal $UNSEAL_KEY_2
            kubectl exec -n $VAULT_NAMESPACE vault-0 -- vault operator unseal $UNSEAL_KEY_3

            kubectl exec -n $VAULT_NAMESPACE vault-1 -- vault operator unseal $UNSEAL_KEY_1
            kubectl exec -n $VAULT_NAMESPACE vault-1 -- vault operator unseal $UNSEAL_KEY_2
            kubectl exec -n $VAULT_NAMESPACE vault-1 -- vault operator unseal $UNSEAL_KEY_3

            kubectl exec -n $VAULT_NAMESPACE vault-2 -- vault operator unseal $UNSEAL_KEY_1
            kubectl exec -n $VAULT_NAMESPACE vault-2 -- vault operator unseal $UNSEAL_KEY_2
            kubectl exec -n $VAULT_NAMESPACE vault-2 -- vault operator unseal $UNSEAL_KEY_3

            echo "Vault unsealed successfully!"
        else
            echo "Error: Keys file not found! Cannot unseal."
            exit 1
        fi
    fi
    exit 0
fi

# Initialize Vault
echo "Initializing Vault..."
INIT_OUTPUT=$(kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json)

# Save keys to file
echo "$INIT_OUTPUT" > $KEYS_FILE
chmod 600 $KEYS_FILE

echo "✅ Vault initialized successfully!"
echo "⚠️  IMPORTANT: Keys saved to $KEYS_FILE"
echo "⚠️  CRITICAL: Store these keys securely and never commit to Git!"
echo ""

# Extract keys
ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')
UNSEAL_KEY_1=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[2]')

echo "Root Token: $ROOT_TOKEN"
echo ""
echo "Unseal Keys (need 3 out of 5):"
echo "Key 1: $UNSEAL_KEY_1"
echo "Key 2: $UNSEAL_KEY_2"
echo "Key 3: $UNSEAL_KEY_3"
echo ""

# Unseal all Vault pods
echo "Unsealing Vault pods..."

for pod in vault-0 vault-1 vault-2; do
    echo "Unsealing $pod..."
    kubectl exec -n $VAULT_NAMESPACE $pod -- vault operator unseal $UNSEAL_KEY_1
    kubectl exec -n $VAULT_NAMESPACE $pod -- vault operator unseal $UNSEAL_KEY_2
    kubectl exec -n $VAULT_NAMESPACE $pod -- vault operator unseal $UNSEAL_KEY_3
done

echo ""
echo "✅ All Vault pods unsealed successfully!"
echo ""
echo "Next steps:"
echo "1. Login to Vault: kubectl exec -it -n vault vault-0 -- vault login $ROOT_TOKEN"
echo "2. Enable Kubernetes auth: kubectl exec -it -n vault vault-0 -- vault auth enable kubernetes"
echo "3. Run the configuration script: ./configure-vault.sh"
echo ""
echo "⚠️  Remember to store the keys in a secure location!"
