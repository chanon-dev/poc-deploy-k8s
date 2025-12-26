#!/bin/bash
# Deploy to Local Kubernetes (Minikube, Docker Desktop, Kind, etc.)
# สำหรับการติดตั้งบนเครื่อง local

set -e

echo "=============================================="
echo "  Local Kubernetes Platform Deployment"
echo "  การติดตั้งแพลตฟอร์ม Kubernetes บน Local"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check prerequisites
echo "Checking prerequisites / ตรวจสอบความพร้อม..."
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}❌ helm is required but not installed.${NC}" >&2; exit 1; }

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Kubernetes cluster is not running!${NC}"
    echo ""
    echo "Please start your local Kubernetes cluster first:"
    echo "  - Minikube: minikube start --cpus=4 --memory=8192"
    echo "  - Docker Desktop: Enable Kubernetes in settings"
    echo "  - Kind: kind create cluster"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Show cluster info
echo "Kubernetes Cluster Info:"
kubectl cluster-info
echo ""

# Check available resources
echo "Checking cluster resources / ตรวจสอบทรัพยากร..."
kubectl top nodes 2>/dev/null || echo -e "${YELLOW}Note: metrics-server not available${NC}"
echo ""

# Warning about resources
echo -e "${YELLOW}⚠️  Local Setup Notes:${NC}"
echo "  - This is a minimal setup for local development"
echo "  - Recommended: 8GB RAM, 4 CPU cores minimum"
echo "  - Some features are disabled to save resources"
echo "  - High Availability (HA) is disabled"
echo ""
read -p "Continue with local deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi
echo ""

# Phase 0: Setup Ingress Controller (Optional)
echo "=============================================="
echo "Phase 0: NGINX Ingress Controller (Optional)"
echo "=============================================="
echo ""
echo "Do you want to install NGINX Ingress Controller?"
echo "This allows you to access services via hostname (jenkins.local, argocd.local, vault.local)"
echo "instead of port-forward."
echo ""
read -p "Install Ingress Controller? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Installing NGINX Ingress Controller...${NC}"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

    echo "Waiting for Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=300s || echo -e "${YELLOW}Warning: Timeout waiting for Ingress Controller${NC}"

    INSTALL_INGRESS=true
    echo -e "${GREEN}✓ Ingress Controller installed${NC}"
else
    INSTALL_INGRESS=false
    echo "Skipping Ingress Controller installation"
    echo -e "${YELLOW}Note: You'll need to use port-forward to access services${NC}"
fi
echo ""

# Add Helm repos
echo -e "${BLUE}Adding Helm repositories...${NC}"
helm repo add jenkins https://charts.jenkins.io
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
echo ""

# Phase 1: Namespaces
echo "=============================================="
echo "Phase 1: Creating Namespaces"
echo "=============================================="
kubectl apply -f environments/local/namespace.yaml
kubectl apply -f core-components/jenkins/namespace.yaml
kubectl apply -f core-components/argocd/namespace.yaml
kubectl apply -f core-components/vault/namespace.yaml
echo -e "${GREEN}✓ Namespaces created${NC}"
echo ""

# Phase 2: RBAC (Basic only)
echo "=============================================="
echo "Phase 2: Deploying RBAC (Basic)"
echo "=============================================="
kubectl apply -f security/rbac/cluster-admin-role.yaml
kubectl apply -f security/rbac/developer-role.yaml
echo -e "${GREEN}✓ Basic RBAC configured${NC}"
echo -e "${YELLOW}Note: Network Policies skipped for local${NC}"
echo ""

# Phase 3: Jenkins
echo "=============================================="
echo "Phase 3: Deploying Jenkins"
echo "=============================================="
helm upgrade --install jenkins jenkins/jenkins \
  -f core-components/jenkins/values-local.yaml \
  -n jenkins \
  --wait \
  --timeout 10m
echo -e "${GREEN}✓ Jenkins deployed${NC}"
echo ""

# Phase 4: Argo CD
echo "=============================================="
echo "Phase 4: Deploying Argo CD (Official Manifest)"
echo "=============================================="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Configure Argo CD for insecure mode (required for Ingress)
echo "Configuring Argo CD server for insecure mode..."
kubectl apply -f core-components/argocd/argocd-cmd-params-cm.yaml

# Wait for Argo CD pods to be ready
echo "Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Restart argocd-server to apply insecure mode setting
echo "Restarting Argo CD server to apply settings..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd --timeout=300s

echo -e "${GREEN}✓ Argo CD deployed and configured${NC}"
echo ""

# Phase 5: Vault
echo "=============================================="
echo "Phase 5: Deploying Vault (Standalone)"
echo "=============================================="
helm upgrade --install vault hashicorp/vault \
  -f core-components/vault/values-local.yaml \
  -n vault \
  --wait \
  --timeout 10m
echo -e "${GREEN}✓ Vault deployed${NC}"
echo ""

# Phase 6: Apply Ingress Resources (if installed)
if [ "$INSTALL_INGRESS" = true ]; then
    echo "=============================================="
    echo "Phase 6: Configuring Ingress Resources"
    echo "=============================================="

    # Create TLS certificate for Argo CD (SSL Termination at Ingress)
    echo "Creating TLS certificate for Argo CD..."

    # Check if certificate already exists
    if kubectl get secret argocd-tls-secret -n argocd &>/dev/null; then
        echo "TLS secret already exists, skipping certificate creation"
    else
        echo "Generating self-signed certificate..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
          -keyout /tmp/argocd-tls.key \
          -out /tmp/argocd-tls.crt \
          -subj "/CN=argocd.local/O=argocd" &>/dev/null

        kubectl create secret tls argocd-tls-secret \
          --cert=/tmp/argocd-tls.crt \
          --key=/tmp/argocd-tls.key \
          -n argocd

        # Clean up temporary files
        rm -f /tmp/argocd-tls.key /tmp/argocd-tls.crt
        echo -e "${GREEN}✓ TLS certificate created${NC}"
    fi

    # Apply Argo CD Ingress (since it uses official manifest, not Helm)
    echo "Applying Argo CD Ingress with SSL Termination..."
    kubectl apply -f core-components/argocd/ingress.yaml

    # Jenkins and Vault Ingress are handled by Helm values
    echo -e "${GREEN}✓ Ingress resources configured${NC}"
    echo ""

    echo -e "${YELLOW}⚠️  Important: Update your /etc/hosts file${NC}"
    echo ""
    echo "Run this command:"
    echo ""
    echo -e "${BLUE}sudo sh -c 'echo \"127.0.0.1 jenkins.local argocd.local argocd-http.local vault.local\" >> /etc/hosts'${NC}"
    echo ""
    echo "Or manually edit /etc/hosts and add:"
    echo "127.0.0.1 jenkins.local"
    echo "127.0.0.1 argocd.local"
    echo "127.0.0.1 argocd-http.local"
    echo "127.0.0.1 vault.local"
    echo ""
fi

# Summary
echo "=============================================="
echo "  Deployment Summary / สรุปการติดตั้ง"
echo "=============================================="
echo ""
echo -e "${GREEN}✅ Local Kubernetes Platform deployed successfully!${NC}"
echo ""
echo "Deployed components:"
echo "  ✅ Namespace: dev"
echo "  ✅ RBAC (basic)"
echo "  ✅ Jenkins (single instance)"
echo "  ✅ Argo CD (single instance)"
echo "  ✅ Vault (standalone mode)"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""

# Get Jenkins password
echo "1️⃣  Get Jenkins admin password:"
echo "   kubectl get secret -n jenkins jenkins -o jsonpath=\"{.data.jenkins-admin-password}\" | base64 --decode; echo"
echo ""

# Get Argo CD password
echo "2️⃣  Get Argo CD admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"
echo ""

# Initialize Vault
echo "3️⃣  Initialize Vault:"
echo "   kubectl exec -n vault vault-0 -- vault operator init"
echo "   (Save the unseal keys and root token!)"
echo ""

# Access services
echo "4️⃣  Access services:"
echo ""

if [ "$INSTALL_INGRESS" = true ]; then
    echo "   Via Ingress (recommended):"
    echo "   Jenkins:  http://jenkins.local"
    echo "   Argo CD:  https://argocd.local (or http://argocd-http.local)"
    echo "   Vault:    http://vault.local"
    echo ""
    echo "   Make sure /etc/hosts is updated (see above)"
    echo ""
else
    echo "   Via port-forward:"
    echo ""
    echo "   # Jenkins"
    echo "   kubectl port-forward -n jenkins svc/jenkins 8080:8080"
    echo "   → http://localhost:8080"
    echo ""
    echo "   # Argo CD"
    echo "   kubectl port-forward -n argocd svc/argocd-server 8443:443"
    echo "   → https://localhost:8443"
    echo ""
    echo "   # Vault"
    echo "   kubectl port-forward -n vault svc/vault 8200:8200"
    echo "   → http://localhost:8200"
    echo ""

    # Quick access script
    cat > /tmp/access-services.sh << 'EOF'
#!/bin/bash
echo "Starting port-forwards..."
kubectl port-forward -n jenkins svc/jenkins 8080:8080 &
kubectl port-forward -n argocd svc/argocd-server 8443:443 &
kubectl port-forward -n vault svc/vault 8200:8200 &
echo "Services accessible at:"
echo "  Jenkins:  http://localhost:8080"
echo "  Argo CD:  https://localhost:8443"
echo "  Vault:    http://localhost:8200"
echo ""
echo "Press Ctrl+C to stop all port-forwards"
wait
EOF
    chmod +x /tmp/access-services.sh
    echo "   Quick access script: /tmp/access-services.sh"
    echo ""
fi

# View pods
echo "5️⃣  Check deployment status:"
echo "   kubectl get pods -A"
echo ""

echo -e "${GREEN}🎉 Local deployment completed!${NC}"
echo ""
echo "For more information, see: docs/local-development-guide.md"
