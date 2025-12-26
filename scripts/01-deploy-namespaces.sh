#!/bin/bash
# Deploy Namespaces Script

set -e

echo "Creating namespaces..."

# Deploy environment namespaces
kubectl apply -f environments/dev/namespace.yaml
kubectl apply -f environments/sit/namespace.yaml
kubectl apply -f environments/uat/namespace.yaml
kubectl apply -f environments/prod/namespace.yaml

# Deploy component namespaces
kubectl apply -f core-components/jenkins/namespace.yaml
kubectl apply -f core-components/argocd/namespace.yaml
kubectl apply -f core-components/vault/namespace.yaml

echo "✓ All namespaces created"

# Verify
echo ""
echo "Verifying namespaces..."
kubectl get namespaces | grep -E "dev|sit|uat|prod|jenkins|argocd|vault"

echo ""
echo "Checking resource quotas..."
kubectl get resourcequota -A
