#!/bin/bash
set -e

echo "=== Getting Vault AppRole Credentials for Jenkins ==="
echo ""

# Vault address
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
export VAULT_ADDR

echo "Using Vault address: $VAULT_ADDR"
echo ""

# Check if Vault is accessible
echo "Checking Vault connectivity..."
if ! curl -s --connect-timeout 5 $VAULT_ADDR/v1/sys/health > /dev/null 2>&1; then
  echo "❌ Error: Cannot connect to Vault at $VAULT_ADDR"
  echo ""
  echo "Please ensure:"
  echo "1. Vault is running:"
  echo "   kubectl get pods -n vault"
  echo ""
  echo "2. Port forward is active:"
  echo "   kubectl port-forward -n vault svc/vault 8200:8200"
  echo ""
  echo "3. Or set VAULT_ADDR to correct address:"
  echo "   export VAULT_ADDR='http://vault-address:8200'"
  exit 1
fi

echo "✅ Vault is accessible"
echo ""

# Check if logged in
echo "Checking Vault authentication..."
if ! vault token lookup > /dev/null 2>&1; then
  echo "❌ Error: Not logged in to Vault"
  echo ""
  echo "Please login first:"
  echo "  vault login"
  echo ""
  echo "Or if you have root token:"
  echo "  vault login <root-token>"
  echo ""
  echo "To get root token from Kubernetes:"
  echo "  kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.vault-root}' | base64 -d"
  exit 1
fi

echo "✅ Authenticated to Vault"
echo ""

# Check if AppRole auth is enabled
echo "Checking AppRole authentication method..."
if ! vault auth list | grep -q "approle"; then
  echo "⚠️  AppRole auth method not enabled"
  echo ""
  echo "Enabling AppRole..."
  vault auth enable approle
  echo "✅ AppRole enabled"
fi

# Check if jenkins-ci role exists
echo ""
echo "Checking jenkins-ci role..."
if ! vault read auth/approle/role/jenkins-ci > /dev/null 2>&1; then
  echo "⚠️  jenkins-ci role does not exist"
  echo ""
  echo "Creating jenkins-ci role..."

  # Check if policy exists
  if ! vault policy list | grep -q "jenkins-ci"; then
    echo "⚠️  jenkins-ci policy not found"
    echo ""
    echo "Please create the policy first:"
    echo "  cd /Users/chanon/Desktop/k8s/security/vault-policies"
    echo "  vault policy write jenkins-ci jenkins-ci-policy.hcl"
    echo ""
    echo "Or run the full setup:"
    echo "  ./setup-vault-k8s-auth.sh"
    exit 1
  fi

  # Create role
  vault write auth/approle/role/jenkins-ci \
    token_policies=jenkins-ci \
    token_ttl=1h \
    token_max_ttl=4h

  echo "✅ jenkins-ci role created"
fi

echo "✅ jenkins-ci role exists"
echo ""

# Get Role ID
echo "=== Getting Role ID ==="
ROLE_ID=$(vault read -field=role_id auth/approle/role/jenkins-ci/role-id)

if [ -z "$ROLE_ID" ]; then
  echo "❌ Error: Could not get Role ID"
  exit 1
fi

echo "Role ID: $ROLE_ID"
echo ""

# Generate new Secret ID
echo "=== Generating Secret ID ==="
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/jenkins-ci/secret-id)

if [ -z "$SECRET_ID" ]; then
  echo "❌ Error: Could not generate Secret ID"
  exit 1
fi

echo "Secret ID: $SECRET_ID"
echo ""

# Display summary
echo "================================================================"
echo "                   JENKINS CREDENTIALS                          "
echo "================================================================"
echo ""
echo "Copy these values to Jenkins:"
echo ""
echo "1. Vault Role ID:"
echo "   ┌────────────────────────────────────────────────────────────┐"
echo "   │ $ROLE_ID"
echo "   └────────────────────────────────────────────────────────────┘"
echo ""
echo "2. Vault Secret ID:"
echo "   ┌────────────────────────────────────────────────────────────┐"
echo "   │ $SECRET_ID"
echo "   └────────────────────────────────────────────────────────────┘"
echo ""
echo "================================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Go to Jenkins: http://jenkins.local"
echo "2. Navigate to: Manage Jenkins → Credentials → System → Global credentials"
echo "3. Click '+ Add Credentials'"
echo ""
echo "4. Add Role ID:"
echo "   - Kind: Secret text"
echo "   - Scope: Global"
echo "   - Secret: (paste Role ID from above)"
echo "   - ID: vault-role-id"
echo "   - Description: Vault AppRole Role ID for Jenkins"
echo "   - Click 'Create'"
echo ""
echo "5. Add Secret ID:"
echo "   - Click '+ Add Credentials' again"
echo "   - Kind: Secret text"
echo "   - Scope: Global"
echo "   - Secret: (paste Secret ID from above)"
echo "   - ID: vault-secret-id"
echo "   - Description: Vault AppRole Secret ID for Jenkins"
echo "   - Click 'Create'"
echo ""
echo "6. Go back to your pipeline and click 'Build Now'"
echo ""
echo "================================================================"
echo ""
echo "⚠️  SECURITY NOTES:"
echo "- Secret ID is shown only once - save it securely"
echo "- Secret ID has TTL of 1 hour for login, max 4 hours"
echo "- You can generate new Secret ID anytime without changing Role ID"
echo "- Never commit these values to Git"
echo ""

# Save to file (optional)
echo "💾 Saving credentials to temporary file..."
cat > /tmp/jenkins-vault-credentials.txt <<EOF
Jenkins Vault Credentials
Generated: $(date)

Role ID: $ROLE_ID
Secret ID: $SECRET_ID

⚠️  DELETE THIS FILE AFTER ADDING TO JENKINS!
EOF

echo "✅ Credentials saved to: /tmp/jenkins-vault-credentials.txt"
echo ""
echo "Remember to delete this file after use:"
echo "  rm /tmp/jenkins-vault-credentials.txt"
echo ""
