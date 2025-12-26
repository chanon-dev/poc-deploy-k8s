#!/bin/bash
set -e

echo "=== Setting up Vault Kubernetes Authentication ==="

# Vault address
VAULT_ADDR=${VAULT_ADDR:-"http://vault.vault.svc.cluster.local:8200"}
export VAULT_ADDR

# Check if logged in
if ! vault token lookup > /dev/null 2>&1; then
  echo "Error: Not logged in to Vault. Please login first:"
  echo "  vault login"
  exit 1
fi

echo ""
echo "Step 1: Enable Kubernetes auth method..."
vault auth enable kubernetes 2>/dev/null || echo "Kubernetes auth already enabled"

echo ""
echo "Step 2: Configure Kubernetes auth method..."

# Get Kubernetes service account token and CA cert
# This assumes you're running this script from within the Kubernetes cluster
# If running from outside, you need to provide these values manually

# For running inside cluster (e.g., from a pod)
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
  echo "Detected running inside Kubernetes cluster"
  TOKEN_REVIEW_JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  KUBE_CA_CERT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
  KUBE_HOST="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"
else
  echo "Running outside Kubernetes cluster"
  # For running outside cluster, get service account token
  echo "Getting service account token..."

  # Create a service account for Vault (if not exists)
  kubectl create serviceaccount vault-auth -n vault 2>/dev/null || echo "ServiceAccount already exists"

  # Create ClusterRoleBinding for token review
  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-tokenreview-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: vault
EOF

  # Get the service account token
  SECRET_NAME=$(kubectl get serviceaccount vault-auth -n vault -o jsonpath='{.secrets[0].name}' 2>/dev/null)

  if [ -z "$SECRET_NAME" ]; then
    echo "Creating token for service account..."
    # For Kubernetes 1.24+, create token manually
    TOKEN_REVIEW_JWT=$(kubectl create token vault-auth -n vault --duration=8760h)
  else
    TOKEN_REVIEW_JWT=$(kubectl get secret $SECRET_NAME -n vault -o jsonpath='{.data.token}' | base64 --decode)
  fi

  KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode)
  KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')
fi

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
  kubernetes_host="$KUBE_HOST" \
  kubernetes_ca_cert="$KUBE_CA_CERT" \
  disable_issuer_verification=true

echo ""
echo "Step 3: Creating Kubernetes auth roles for applications..."

# Webapp Dev role
echo "Creating webapp-dev role..."
vault write auth/kubernetes/role/webapp-dev \
  bound_service_account_names=webapp \
  bound_service_account_namespaces=dev \
  policies=webapp-dev \
  ttl=24h

# WebAPI Dev role
echo "Creating webapi-dev role..."
vault write auth/kubernetes/role/webapi-dev \
  bound_service_account_names=webapi \
  bound_service_account_namespaces=dev \
  policies=webapi-dev \
  ttl=24h

echo ""
echo "Step 4: Creating AppRole for Jenkins..."
vault auth enable approle 2>/dev/null || echo "AppRole auth already enabled"

vault write auth/approle/role/jenkins-ci \
  token_policies=jenkins-ci \
  token_ttl=1h \
  token_max_ttl=4h

# Get RoleID and SecretID
ROLE_ID=$(vault read -field=role_id auth/approle/role/jenkins-ci/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/jenkins-ci/secret-id)

echo ""
echo "=== Vault Kubernetes Auth Setup Complete ==="
echo ""
echo "Jenkins AppRole Credentials (store these in Jenkins):"
echo "  Role ID: $ROLE_ID"
echo "  Secret ID: $SECRET_ID"
echo ""
echo "⚠️  IMPORTANT: Store these credentials securely in Jenkins:"
echo "  1. Go to Jenkins > Credentials > System > Global credentials"
echo "  2. Add credential type 'Secret text'"
echo "     - ID: vault-role-id"
echo "     - Secret: $ROLE_ID"
echo "  3. Add credential type 'Secret text'"
echo "     - ID: vault-secret-id"
echo "     - Secret: $SECRET_ID"
echo ""
echo "Verify setup:"
echo "  vault read auth/kubernetes/role/webapp-dev"
echo "  vault read auth/kubernetes/role/webapi-dev"
echo "  vault read auth/approle/role/jenkins-ci"
