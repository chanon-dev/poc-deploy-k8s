# Quick Command Reference / คำสั่งแบบย่อ

## สำหรับ Copy-Paste แบบเร็ว (Docker Desktop Kubernetes)

---

## 🚀 Full Installation

### Option A: With Ingress (Production-like, Hostname-based Access) ⭐

```bash
# ===== STEP 0: Install NGINX Ingress Controller =====
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s

# ===== STEP 0.5: Update /etc/hosts =====
sudo sh -c 'echo "127.0.0.1 jenkins.local argocd.local argocd-http.local vault.local" >> /etc/hosts'

# ===== STEP 1: Check Prerequisites =====
kubectl version --client
helm version

# ===== STEP 2: Add Helm Repos =====
helm repo add jenkins https://charts.jenkins.io
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# ===== STEP 3: Create Namespaces =====
kubectl create namespace dev
kubectl create namespace jenkins
kubectl create namespace argocd
kubectl create namespace vault

# ===== STEP 4: Apply RBAC (Basic) =====
kubectl apply -f security/rbac/cluster-admin-role.yaml
kubectl apply -f security/rbac/developer-role.yaml

# ===== STEP 5: Install Jenkins =====
helm install jenkins jenkins/jenkins \
  -f core-components/jenkins/values-local.yaml \
  -n jenkins \
  --wait --timeout 10m

# ===== STEP 6: Install Argo CD (Official Manifest) =====
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Apply Argo CD Ingress
kubectl apply -f core-components/argocd/ingress.yaml

# Patch Argo CD to run in insecure mode (required for Ingress)
kubectl patch deployment argocd-server -n argocd --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'

# ===== STEP 7: Install Vault =====
helm install vault hashicorp/vault \
  -f core-components/vault/values-local.yaml \
  -n vault \
  --wait --timeout 10m

# ===== STEP 8: Verify =====
kubectl get pods -A

echo "✅ Installation Complete!"
echo ""
echo "Next: Get passwords and access services"
```

---

## 🔑 Get Passwords

```bash
# Jenkins Password
kubectl get secret -n jenkins jenkins \
  -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
echo ""

# Argo CD Password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""

# Save these passwords!
```

---

## 🌐 Access Services

### Option A: Via Ingress (If you installed Ingress Controller) ⭐

```bash
# Simply open in browser:
open http://jenkins.local
open https://argocd.local
# Or: open http://argocd-http.local
open http://vault.local

# No port-forward needed!
```

**URLs:**
- Jenkins:  **http://jenkins.local**
- Argo CD:  **https://argocd.local** (or http://argocd-http.local)
- Vault:    **http://vault.local**

### Option B: Via Port-Forward (Run in 3 Separate Terminals)

#### Terminal 1 - Jenkins
```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# Open: http://localhost:8080
```

#### Terminal 2 - Argo CD
```bash
kubectl port-forward -n argocd svc/argocd-server 8443:443
# Open: https://localhost:8443
```

#### Terminal 3 - Vault
```bash
kubectl port-forward -n vault svc/vault 8200:8200
# Open: http://localhost:8200
```

---

## 🔓 Initialize & Unseal Vault

```bash
# Initialize Vault
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# Extract keys
UNSEAL_KEY_1=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-keys.json | jq -r '.unseal_keys_b64[2]')
ROOT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')

# Unseal Vault (ต้องใช้ 3 keys)
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3

# Verify unsealed
kubectl exec -n vault vault-0 -- vault status

echo "Root Token: $ROOT_TOKEN"
```

---

## 🎯 Configure Vault

```bash
# Login to Vault
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN

# Enable Kubernetes auth
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Configure Kubernetes auth
kubectl exec -n vault vault-0 -- sh -c '
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
'

# Enable KV v2 secrets
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2

# Create test secret
kubectl exec -n vault vault-0 -- \
  vault kv put secret/dev/test password=hello123 username=admin

echo "✅ Vault configured!"
```

---

## 📊 Check Status

```bash
# All pods
kubectl get pods -A

# Specific namespaces
kubectl get pods -n jenkins
kubectl get pods -n argocd
kubectl get pods -n vault
kubectl get pods -n dev

# Services
kubectl get svc -A

# Storage
kubectl get pvc -A

# Nodes
kubectl get nodes
kubectl top nodes
```

---

## 🧪 Test Deployment

```bash
# Deploy test app
kubectl create deployment nginx --image=nginx -n dev
kubectl expose deployment nginx --port=80 --type=NodePort -n dev

# Check
kubectl get pods -n dev
kubectl get svc -n dev

# Clean up
kubectl delete deployment nginx -n dev
kubectl delete svc nginx -n dev
```

---

## 🎨 Test Argo CD

```bash
# Create sample app
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    path: guestbook
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Check in UI: https://localhost:8443

# Delete
kubectl delete application guestbook -n argocd
```

---

## 🔍 Troubleshooting

### View Logs
```bash
# Jenkins
kubectl logs -n jenkins jenkins-0 -c jenkins -f

# Argo CD Server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f

# Vault
kubectl logs -n vault vault-0 -f
```

### Restart Components
```bash
# Restart Jenkins
kubectl rollout restart statefulset jenkins -n jenkins

# Restart Argo CD
kubectl rollout restart deployment argocd-server -n argocd

# Restart Vault (will need to unseal again!)
kubectl delete pod vault-0 -n vault
```

### Check Resources
```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -A

# Describe pod
kubectl describe pod <pod-name> -n <namespace>
```

### Common Fixes
```bash
# Pod pending - check storage class
kubectl get sc
kubectl patch storageclass hostpath \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Vault sealed after restart
# Re-run unseal commands from above

# Can't access service
# Check port-forward is running
# Check firewall/antivirus
```

---

## 🧹 Cleanup

### Delete Everything
```bash
# Delete namespaces (will delete all resources inside)
kubectl delete ns jenkins argocd vault dev

# Or uninstall via Helm
helm uninstall jenkins -n jenkins
helm uninstall argocd -n argocd
helm uninstall vault -n vault

# Then delete namespaces
kubectl delete ns jenkins argocd vault dev
```

### Stop Cluster
```bash
# Docker Desktop: Quit application
# Or disable Kubernetes in Settings

# Minikube
minikube stop

# Kind
kind delete cluster --name k8s-platform
```

---

## 🔄 Daily Workflow

### Start Working
```bash
# 1. Make sure cluster is running
kubectl cluster-info

# 2. Unseal Vault (if restarted)
# (use commands from "Initialize & Unseal Vault" section)

# 3. Start port-forwards (in separate terminals)
kubectl port-forward -n jenkins svc/jenkins 8080:8080 &
kubectl port-forward -n argocd svc/argocd-server 8443:443 &
kubectl port-forward -n vault svc/vault 8200:8200 &

# 4. Check all pods running
kubectl get pods -A
```

### Stop Working
```bash
# 1. Kill port-forwards
pkill -f "port-forward"

# 2. (Optional) Stop cluster
# Docker Desktop: Just quit app
# Minikube: minikube stop
```

---

## 📝 Useful Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc

alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgn='kubectl get nodes'
alias kgs='kubectl get svc'
alias kdp='kubectl describe pod'
alias klog='kubectl logs -f'
alias kex='kubectl exec -it'

# Namespace shortcuts
alias kd='kubectl -n dev'
alias kj='kubectl -n jenkins'
alias ka='kubectl -n argocd'
alias kv='kubectl -n vault'

# Port forwards
alias pf-jenkins='kubectl port-forward -n jenkins svc/jenkins 8080:8080'
alias pf-argocd='kubectl port-forward -n argocd svc/argocd-server 8443:443'
alias pf-vault='kubectl port-forward -n vault svc/vault 8200:8200'
```

---

## 🎯 One-Liner Scripts

### Start All Port Forwards
```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080 &
kubectl port-forward -n argocd svc/argocd-server 8443:443 &
kubectl port-forward -n vault svc/vault 8200:8200 &
echo "Services available at:"
echo "  Jenkins:  http://localhost:8080"
echo "  Argo CD:  https://localhost:8443"
echo "  Vault:    http://localhost:8200"
```

### Get All Passwords
```bash
echo "=== Jenkins ==="
echo -n "Password: "
kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
echo ""
echo ""
echo "=== Argo CD ==="
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "=== Vault ==="
echo -n "Root Token: "
cat vault-keys.json 2>/dev/null | jq -r '.root_token' || echo "Run vault init first"
echo ""
```

### Check All Health
```bash
echo "=== Nodes ==="
kubectl get nodes
echo ""
echo "=== Pods ==="
kubectl get pods -n jenkins
kubectl get pods -n argocd
kubectl get pods -n vault
kubectl get pods -n dev
echo ""
echo "=== Services ==="
kubectl get svc -A | grep -E "jenkins|argocd|vault"
```

---

**📚 For detailed explanations, see:** [manual-installation-steps.md](manual-installation-steps.md)
