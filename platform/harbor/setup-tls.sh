#!/bin/bash
# Setup TLS Certificates for Harbor
# สร้าง self-signed certificate สำหรับ Harbor

set -e

NAMESPACE="harbor"
HARBOR_DOMAIN="${HARBOR_DOMAIN:-harbor.local}"
CERT_DIR="/tmp/harbor-certs"

echo "=========================================="
echo "Harbor TLS Certificate Setup"
echo "=========================================="
echo ""

# Create temporary directory
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "1. Generating self-signed certificate for $HARBOR_DOMAIN..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout harbor-tls.key \
  -out harbor-tls.crt \
  -subj "/CN=$HARBOR_DOMAIN/O=Harbor" \
  -addext "subjectAltName = DNS:$HARBOR_DOMAIN,DNS:*.$HARBOR_DOMAIN"

echo ""
echo "2. Creating Kubernetes TLS secret..."

# Check if secret already exists
if kubectl get secret harbor-tls -n "$NAMESPACE" &>/dev/null; then
    echo "Secret 'harbor-tls' already exists. Deleting..."
    kubectl delete secret harbor-tls -n "$NAMESPACE"
fi

# Create namespace if not exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create TLS secret
kubectl create secret tls harbor-tls \
  --cert=harbor-tls.crt \
  --key=harbor-tls.key \
  -n "$NAMESPACE"

echo ""
echo "3. Verifying secret..."
kubectl get secret harbor-tls -n "$NAMESPACE"

echo ""
echo "4. Cleaning up temporary files..."
cd -
rm -rf "$CERT_DIR"

echo ""
echo "=========================================="
echo "✅ TLS certificate setup complete!"
echo "=========================================="
echo ""
echo "Certificate details:"
echo "  Domain: $HARBOR_DOMAIN"
echo "  Namespace: $NAMESPACE"
echo "  Secret name: harbor-tls"
echo "  Valid for: 365 days"
echo ""
echo "You can now install Harbor with TLS enabled:"
echo "  helm upgrade --install harbor harbor/harbor \\"
echo "    -f values-local.yaml \\"
echo "    --set expose.tls.enabled=true \\"
echo "    --set expose.tls.certSource=secret \\"
echo "    --set expose.tls.secret.secretName=harbor-tls \\"
echo "    -n harbor"
echo ""
