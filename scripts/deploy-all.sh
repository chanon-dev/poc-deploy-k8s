#!/bin/bash
# Deploy All Components Script
# This script deploys all platform components in the correct order

set -e

echo "========================================="
echo "  On-Premise Kubernetes Platform Deploy"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}helm is required but not installed.${NC}" >&2; exit 1; }
echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Phase 1: Namespaces
echo "========================================="
echo "Phase 1: Creating Namespaces"
echo "========================================="
./scripts/01-deploy-namespaces.sh
echo ""

# Phase 2: Security
echo "========================================="
echo "Phase 2: Deploying Security Components"
echo "========================================="
./scripts/02-deploy-security.sh
echo ""

# Phase 3: Core Components
echo "========================================="
echo "Phase 3: Deploying Core Components"
echo "========================================="
./scripts/03-deploy-core-components.sh
echo ""

# Phase 4: Monitoring
echo "========================================="
echo "Phase 4: Deploying Monitoring Stack"
echo "========================================="
./scripts/04-deploy-monitoring.sh || echo -e "${YELLOW}Warning: Monitoring deployment skipped or failed${NC}"
echo ""

# Summary
echo "========================================="
echo "  Deployment Summary"
echo "========================================="
echo ""
echo "✅ Namespaces created"
echo "✅ RBAC configured"
echo "✅ Network Policies applied"
echo "✅ Core components deployed"
echo ""
echo "Next steps:"
echo "1. Initialize Vault:"
echo "   cd core-components/vault && ./init-unseal.sh"
echo ""
echo "2. Get Jenkins admin password:"
echo "   kubectl get secret -n jenkins jenkins -o jsonpath=\"{.data.jenkins-admin-password}\" | base64 --decode"
echo ""
echo "3. Get Argo CD admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "4. Access services via port-forward:"
echo "   kubectl port-forward -n jenkins svc/jenkins 8080:8080"
echo "   kubectl port-forward -n argocd svc/argocd-server 8443:443"
echo "   kubectl port-forward -n vault svc/vault 8200:8200"
echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
