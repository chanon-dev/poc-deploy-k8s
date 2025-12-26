#!/bin/bash
# Deploy Core Components Script

set -e

echo "Adding Helm repositories..."
helm repo add jenkins https://charts.jenkins.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

echo ""
echo "Deploying Jenkins..."
helm upgrade --install jenkins jenkins/jenkins \
  -f core-components/jenkins/values.yaml \
  -n jenkins \
  --create-namespace \
  --wait \
  --timeout 10m

echo ""
echo "Deploying Argo CD..."
helm upgrade --install argocd argo/argo-cd \
  -f core-components/argocd/values.yaml \
  -n argocd \
  --create-namespace \
  --wait \
  --timeout 10m

echo ""
echo "Deploying Vault..."
helm upgrade --install vault hashicorp/vault \
  -f core-components/vault/values.yaml \
  -n vault \
  --create-namespace \
  --wait \
  --timeout 10m

echo ""
echo "✓ Core components deployed"

# Verify
echo ""
echo "Verifying deployments..."
kubectl get pods -n jenkins
kubectl get pods -n argocd
kubectl get pods -n vault

echo ""
echo "IMPORTANT: Remember to initialize Vault!"
echo "Run: cd core-components/vault && ./init-unseal.sh"
