#!/bin/bash
# Deploy Security Components Script

set -e

echo "Deploying RBAC configurations..."
kubectl apply -f security/rbac/

echo ""
echo "Deploying Network Policies..."
kubectl apply -f security/network-policies/

echo ""
echo "✓ Security components deployed"

# Verify
echo ""
echo "Verifying RBAC..."
kubectl get clusterrolebindings | grep -E "platform|tech-lead|developer"
kubectl get rolebindings -A | head -10

echo ""
echo "Verifying Network Policies..."
kubectl get networkpolicies -A
