#!/bin/bash
# Setup NGINX Ingress Controller for Local Kubernetes
# For Docker Desktop, Minikube, or Kind

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=============================================="
echo "  NGINX Ingress Controller Setup"
echo "  สำหรับ Local Kubernetes Development"
echo "=============================================="
echo ""

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

# Check cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Kubernetes cluster is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Detect cluster type
CLUSTER_TYPE="unknown"
if kubectl get nodes -o wide | grep -q "docker-desktop"; then
    CLUSTER_TYPE="docker-desktop"
elif kubectl get nodes -o wide | grep -q "minikube"; then
    CLUSTER_TYPE="minikube"
elif kubectl get nodes -o wide | grep -q "kind"; then
    CLUSTER_TYPE="kind"
fi

echo -e "${BLUE}Detected cluster type: ${CLUSTER_TYPE}${NC}"
echo ""

# Install NGINX Ingress Controller
echo -e "${BLUE}Installing NGINX Ingress Controller...${NC}"

# Use official NGINX Ingress Controller manifest
# Version: controller-v1.8.1
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

echo ""
echo -e "${YELLOW}Waiting for Ingress Controller to be ready...${NC}"
echo "This may take 1-2 minutes..."
echo ""

# Wait for the deployment to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo ""
echo -e "${GREEN}✓ NGINX Ingress Controller installed successfully!${NC}"
echo ""

# Check the service
echo "Ingress Controller Service:"
kubectl get svc -n ingress-nginx ingress-nginx-controller
echo ""

# Get LoadBalancer info
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
EXTERNAL_HOSTNAME=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$EXTERNAL_IP" ] && [ -z "$EXTERNAL_HOSTNAME" ]; then
    echo -e "${YELLOW}⚠️  LoadBalancer IP/Hostname not assigned yet${NC}"
    echo "For Docker Desktop, it should show 'localhost' after a moment"
    echo ""
else
    echo -e "${GREEN}✓ LoadBalancer is ready${NC}"
    [ -n "$EXTERNAL_IP" ] && echo "  IP: $EXTERNAL_IP"
    [ -n "$EXTERNAL_HOSTNAME" ] && echo "  Hostname: $EXTERNAL_HOSTNAME"
    echo ""
fi

# Instructions
echo "=============================================="
echo "  Next Steps"
echo "=============================================="
echo ""
echo "1️⃣  Update your /etc/hosts file:"
echo ""
echo -e "${YELLOW}sudo nano /etc/hosts${NC}"
echo ""
echo "Add these lines:"
echo "127.0.0.1 jenkins.local"
echo "127.0.0.1 argocd.local"
echo "127.0.0.1 argocd-http.local"
echo "127.0.0.1 vault.local"
echo ""
echo "2️⃣  Apply Ingress resources for services:"
echo ""
echo "   # Jenkins"
echo "   kubectl apply -f core-components/jenkins/ingress.yaml"
echo ""
echo "   # Argo CD"
echo "   kubectl apply -f core-components/argocd/ingress.yaml"
echo ""
echo "   # Vault"
echo "   kubectl apply -f core-components/vault/ingress.yaml"
echo ""
echo "3️⃣  Access services:"
echo ""
echo "   Jenkins:  http://jenkins.local"
echo "   Argo CD:  https://argocd.local (or http://argocd-http.local)"
echo "   Vault:    http://vault.local"
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
