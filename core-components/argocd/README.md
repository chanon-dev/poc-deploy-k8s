# Argo CD Deployment / การติดตั้ง Argo CD

## Overview / ภาพรวม

Argo CD is a declarative GitOps continuous delivery tool for Kubernetes.

Argo CD เป็น GitOps CD tool สำหรับ Kubernetes

## Prerequisites / สิ่งที่ต้องเตรียม

1. Kubernetes cluster / Kubernetes cluster พร้อมใช้งาน
2. kubectl configured / ตั้งค่า kubectl แล้ว
3. Helm 3 installed (for Helm installation) / ติดตั้ง Helm 3 (ถ้าจะใช้ Helm)

## Installation / วิธีการติดตั้ง

### Method 1: Official Manifest (Quick Start)

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Method 2: Helm Chart (Recommended for Production)

```bash
# Add Argo CD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create namespace
kubectl create namespace argocd

# Install with custom values
helm install argocd argo/argo-cd \
  -f values.yaml \
  -n argocd

# Or upgrade
helm upgrade argocd argo/argo-cd \
  -f values.yaml \
  -n argocd
```

## Access Argo CD / เข้าถึง Argo CD

### Get Initial Admin Password
```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

### Port Forward (for testing)
```bash
# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access UI: https://localhost:8080
# Username: admin
# Password: <from above command>
```

### Via Ingress (production)
```bash
# Access via configured ingress
# https://argocd.company.local

# Make sure ingress is configured in values.yaml
```

### CLI Login
```bash
# Install argocd CLI
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Login via CLI
argocd login argocd.company.local --insecure
# Or with port-forward
argocd login localhost:8080 --insecure

# Change admin password
argocd account update-password
```

## Configuration / การตั้งค่า

### Add Git Repository
```bash
# Via CLI
argocd repo add https://git.company.local/k8s-manifests.git \
  --username <username> \
  --password <password>

# Or via UI: Settings → Repositories → Connect Repo
```

### Add Cluster (if managing multiple clusters)
```bash
# List available contexts
kubectl config get-contexts

# Add cluster
argocd cluster add <context-name>
```

### Configure RBAC
```bash
# Apply RBAC configuration
kubectl apply -f argocd-rbac.yaml

# Or edit ConfigMap directly
kubectl edit configmap argocd-rbac-cm -n argocd
```

## Sync Policies / Sync Policies

### Auto Sync vs Manual Sync

**Auto Sync (Dev/SIT):**
```yaml
syncPolicy:
  automated:
    prune: true      # Remove resources not in Git
    selfHeal: true   # Revert manual changes
  syncOptions:
    - CreateNamespace=true
```

**Manual Sync (UAT/Prod):**
```yaml
syncPolicy:
  # No automated section - requires manual sync
  syncOptions:
    - CreateNamespace=true
```

## Health Checks / Health Checks

Argo CD automatically checks health of standard resources. For custom resources:

```yaml
# In argocd-cm ConfigMap
resource.customizations: |
  MyCustomResource:
    health.lua: |
      hs = {}
      if obj.status ~= nil then
        if obj.status.phase == "Running" then
          hs.status = "Healthy"
          hs.message = "Resource is running"
          return hs
        end
      end
      hs.status = "Progressing"
      hs.message = "Waiting for resource"
      return hs
```

## Notifications / การแจ้งเตือน

### Configure Slack Notifications
```bash
# Create secret with Slack token
kubectl create secret generic argocd-notifications-secret \
  -n argocd \
  --from-literal=slack-token=<your-slack-token>

# Configure in argocd-notifications-cm ConfigMap
# See values.yaml for notification templates
```

### Configure Email Notifications
```bash
# Create secret with email credentials
kubectl create secret generic argocd-notifications-secret \
  -n argocd \
  --from-literal=email-username=<username> \
  --from-literal=email-password=<password>
```

## Application Examples / ตัวอย่าง Application

### Example 1: Simple Application (Dev - Auto Sync)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://git.company.local/k8s-manifests.git
    targetRevision: HEAD
    path: dev/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Example 2: Production Application (Manual Sync)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-prod
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://git.company.local/k8s-manifests.git
    targetRevision: v1.0.0  # Use tags for prod
    path: prod/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: prod
  syncPolicy:
    # Manual sync required
    syncOptions:
      - CreateNamespace=true
```

### Example 3: Helm Chart Application
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-ingress
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://kubernetes.github.io/ingress-nginx
    chart: ingress-nginx
    targetRevision: 4.7.1
    helm:
      values: |
        controller:
          replicaCount: 2
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Projects / Projects

Projects provide logical grouping and access control:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications

  # Source repositories
  sourceRepos:
    - https://git.company.local/k8s-manifests.git

  # Allowed destinations
  destinations:
    - namespace: prod
      server: https://kubernetes.default.svc

  # Allowed resource kinds
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace

  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: ''
      kind: Service
    - group: ''
      kind: ConfigMap

  # RBAC roles
  roles:
    - name: prod-deployer
      policies:
        - p, proj:production:prod-deployer, applications, sync, production/*, allow
      groups:
        - prod-deployers
```

## CLI Commands / คำสั่ง CLI ที่ใช้บ่อย

```bash
# List applications
argocd app list

# Get application details
argocd app get myapp-dev

# Sync application
argocd app sync myapp-dev

# Watch sync progress
argocd app sync myapp-dev --watch

# Rollback
argocd app rollback myapp-dev

# Delete application
argocd app delete myapp-dev

# Get application logs
argocd app logs myapp-dev

# Diff between Git and cluster
argocd app diff myapp-dev

# List projects
argocd proj list

# Create project
argocd proj create myproject

# Add repo to project
argocd proj add-source myproject https://git.company.local/repo.git
```

## Monitoring / การ Monitor

### Prometheus Metrics
```bash
# Argo CD exposes Prometheus metrics
# Metrics endpoints:
# - application-controller: :8082/metrics
# - api-server: :8083/metrics
# - repo-server: :8084/metrics
```

### Check Application Health
```bash
# Via CLI
argocd app get myapp-dev

# Check sync status
argocd app wait myapp-dev --health
```

## Troubleshooting / แก้ปัญหา

### Issue 1: Application stuck in sync
```bash
# Check application events
argocd app get myapp-dev

# Check resource status
kubectl get all -n dev -l app.kubernetes.io/instance=myapp-dev

# Force sync
argocd app sync myapp-dev --force
```

### Issue 2: Can't connect to Git repository
```bash
# Test repository connection
argocd repo get https://git.company.local/k8s-manifests.git

# Update repository credentials
argocd repo add https://git.company.local/k8s-manifests.git \
  --username <new-username> \
  --password <new-password> \
  --upsert
```

### Issue 3: RBAC permission denied
```bash
# Check user permissions
argocd account can-i sync applications 'myproject/myapp'

# View RBAC config
kubectl get configmap argocd-rbac-cm -n argocd -o yaml
```

### Issue 4: Resource hook failed
```bash
# View hook logs
argocd app get myapp-dev

# Skip failing hooks
argocd app sync myapp-dev --force
```

## Best Practices / แนวปฏิบัติที่ดี

1. **Use Git Tags for Production**
   - Dev/SIT: Use branch (e.g., `main`, `develop`)
   - Prod: Use tags (e.g., `v1.0.0`)

2. **Separate Repositories**
   - Application code in one repo
   - K8s manifests in separate repo

3. **Use App of Apps Pattern**
   ```yaml
   # Root application that manages other applications
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: apps
     namespace: argocd
   spec:
     source:
       repoURL: https://git.company.local/k8s-manifests.git
       path: apps
     destination:
       server: https://kubernetes.default.svc
       namespace: argocd
     syncPolicy:
       automated:
         prune: true
   ```

4. **Enable Pruning Carefully**
   - Auto-prune in dev is okay
   - Be careful with prod

5. **Use Projects for Isolation**
   - Separate projects per team/environment
   - Enforce source repos and destinations

6. **Monitor Sync Failures**
   - Set up alerts for sync failures
   - Regular review of out-of-sync apps

## Security / ความปลอดภัย

1. **Change default admin password** immediately
2. **Use RBAC** to limit user permissions
3. **Use private Git repositories**
4. **Store credentials in Kubernetes secrets**, not in Git
5. **Enable TLS** for UI access
6. **Regular updates** to latest stable version

## Backup / การ Backup

```bash
# Backup all Argo CD applications
argocd app list -o yaml > argocd-apps-backup.yaml

# Backup all projects
argocd proj list -o yaml > argocd-projects-backup.yaml

# Backup Argo CD settings
kubectl get configmap -n argocd -o yaml > argocd-config-backup.yaml
kubectl get secret -n argocd -o yaml > argocd-secrets-backup.yaml
```

## References / อ้างอิง

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Argo CD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://opengitops.dev/)
