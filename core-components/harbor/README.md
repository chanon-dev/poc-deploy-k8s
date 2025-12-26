# Harbor - Container Registry

Harbor เป็น open-source container registry ที่มี security, identity management, และ image scanning

## 📋 Features / คุณสมบัติ

- ✅ **Private Docker Registry** - เก็บ container images แบบ private
- ✅ **Vulnerability Scanning** - Scan ช่องโหว่ด้วย Trivy
- ✅ **Image Signing** - Verify image authenticity ด้วย Notary
- ✅ **RBAC** - Role-based access control
- ✅ **Replication** - Multi-registry replication
- ✅ **Web UI** - Manage images ผ่าน web interface

---

## 🚀 Quick Start / เริ่มต้นใช้งานเร็ว

### Prerequisites / สิ่งที่ต้องมีก่อน

- Kubernetes cluster running
- Helm 3.x installed
- kubectl configured
- NGINX Ingress Controller deployed
- 15Gi+ free storage space

---

## 📦 Installation / การติดตั้ง

### Method 1: Local Development (แนะนำ) ⭐

#### Step 1: Create Namespace

```bash
kubectl apply -f namespace.yaml
```

#### Step 2: Add Harbor Helm Repository

```bash
# Add Harbor helm repo
helm repo add harbor https://helm.goharbor.io

# Update repo
helm repo update

# Search for chart
helm search repo harbor/harbor
```

#### Step 3: Install Harbor

**Option A: HTTP (Simple, for local dev)**

```bash
# Install with HTTP
helm upgrade --install harbor harbor/harbor \
  -f values-local.yaml \
  -n harbor \
  --wait \
  --timeout 10m
```

**Option B: HTTPS (More secure)**

```bash
# 1. Create TLS certificate
./setup-tls.sh

# 2. Install Harbor with HTTPS
helm upgrade --install harbor harbor/harbor \
  -f values-local.yaml \
  --set expose.tls.enabled=true \
  --set expose.tls.certSource=secret \
  --set expose.tls.secret.secretName=harbor-tls \
  -n harbor \
  --wait \
  --timeout 10m
```

#### Step 4: Update /etc/hosts

```bash
# Add harbor.local to hosts
sudo sh -c 'echo "127.0.0.1 harbor.local" >> /etc/hosts'
```

#### Step 5: Access Harbor

```bash
# Web UI
open http://harbor.local
# or
open https://harbor.local

# Login credentials:
# Username: admin
# Password: HarborAdmin123
```

---

### Method 2: Production Deployment

#### Step 1: Create TLS Certificate

**Option A: Self-signed (for internal use)**

```bash
./setup-tls.sh
```

**Option B: Let's Encrypt (recommended)**

```bash
# Install cert-manager first
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@company.local
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

#### Step 2: Configure values.yaml

```bash
# Edit values.yaml
# - Change externalURL to your domain
# - Set harborAdminPassword
# - Configure database/redis (external recommended)
# - Enable notary for image signing
# - Configure OIDC/OAuth for SSO

vi values.yaml
```

#### Step 3: Install Harbor

```bash
helm upgrade --install harbor harbor/harbor \
  -f values.yaml \
  --set harborAdminPassword="YourSecurePassword" \
  -n harbor \
  --create-namespace \
  --wait \
  --timeout 15m
```

---

## 🔍 Verification / ตรวจสอบการติดตั้ง

### Check Pods

```bash
# Check all pods are running
kubectl get pods -n harbor

# Expected pods:
# - harbor-core
# - harbor-database
# - harbor-jobservice
# - harbor-portal
# - harbor-redis
# - harbor-registry
# - harbor-trivy
```

### Check Services

```bash
kubectl get svc -n harbor
```

### Check Ingress

```bash
kubectl get ingress -n harbor
```

### Test Harbor API

```bash
# Test Harbor API
curl -I http://harbor.local/api/v2.0/ping

# Should return: 200 OK
```

---

## 🐳 Using Harbor / การใช้งาน Harbor

### 1. Login via Docker CLI

```bash
# HTTP (local dev)
docker login harbor.local

# HTTPS (production)
docker login harbor.local

# Enter credentials:
# Username: admin
# Password: HarborAdmin123
```

### 2. Create Project via Web UI

1. เปิด http://harbor.local
2. Login ด้วย admin/HarborAdmin123
3. คลิก "NEW PROJECT"
4. ตั้งชื่อ project (เช่น "myapp")
5. เลือก Access Level:
   - **Public** - ใครก็เข้าถึงได้
   - **Private** - ต้อง login ก่อน

### 3. Tag and Push Image

```bash
# Tag your image
docker tag myapp:latest harbor.local/myapp/myapp:latest

# Push to Harbor
docker push harbor.local/myapp/myapp:latest
```

### 4. Pull Image from Harbor

```bash
# Pull image
docker pull harbor.local/myapp/myapp:latest
```

### 5. Use in Kubernetes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: myapp
    image: harbor.local/myapp/myapp:latest
  imagePullSecrets:
  - name: harbor-registry-secret
```

**Create imagePullSecret:**

```bash
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.local \
  --docker-username=admin \
  --docker-password=HarborAdmin123 \
  -n <your-namespace>
```

---

## 🔐 Security Configuration / การตั้งค่าความปลอดภัย

### 1. Enable Vulnerability Scanning

```bash
# Trivy is enabled by default in values-local.yaml

# Scan image via UI:
# 1. Go to project
# 2. Click on repository
# 3. Click "SCAN" button
```

### 2. Enable Image Signing with Notary

```yaml
# In values.yaml, enable notary
notary:
  enabled: true
```

```bash
# Sign image
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://notary.harbor.local

docker push harbor.local/myapp/myapp:signed
```

### 3. Configure RBAC

**Create User:**
1. Settings → Users → NEW USER
2. Set username/password

**Add User to Project:**
1. Go to project
2. Members → USER
3. Select user and role:
   - **Project Admin** - Full control
   - **Developer** - Push/Pull images
   - **Guest** - Pull only

### 4. Enable Content Trust (CVE Prevention)

Harbor Settings → Configuration:
- Enable **Prevent vulnerable images from running**
- Set severity threshold (e.g., High)

---

## 🔧 Configuration / การตั้งค่า

### Update Harbor Configuration

```bash
# Method 1: helm upgrade with new values
helm upgrade harbor harbor/harbor \
  -f values-local.yaml \
  --set key=value \
  -n harbor

# Method 2: Edit via UI
# Settings → Configuration
```

### Common Settings

| Setting | Description | Recommended |
|---------|-------------|-------------|
| **Token Expiration** | Docker login token validity | 30 days |
| **Scan on Push** | Auto-scan images on push | Enabled |
| **Prevent Vulnerable** | Block vulnerable images | Enabled (Prod) |
| **Robot Account Expiration** | Service account token validity | 90 days |

---

## 📊 Monitoring / การ Monitor

### Harbor Metrics

```bash
# Harbor exports Prometheus metrics on:
# - Core: http://harbor-core:8001/metrics
# - Registry: http://harbor-registry:8001/metrics
# - Exporter: http://harbor-exporter:8001/metrics
```

### Check Harbor Status

```bash
# Via API
curl http://harbor.local/api/v2.0/systeminfo

# Via UI
# Administration → System Settings
```

### View Logs

```bash
# Core logs
kubectl logs -n harbor -l component=core --tail=100

# Registry logs
kubectl logs -n harbor -l component=registry --tail=100

# Database logs
kubectl logs -n harbor -l component=database --tail=100
```

---

## 🚨 Troubleshooting / แก้ปัญหา

### Issue 1: Cannot access Harbor UI

```bash
# Check Ingress
kubectl get ingress -n harbor
kubectl describe ingress harbor-ingress -n harbor

# Check /etc/hosts
cat /etc/hosts | grep harbor

# Test connectivity
curl -I http://harbor.local
```

### Issue 2: Cannot push images

```bash
# Check docker login
docker login harbor.local

# Check credentials
kubectl get secret -n harbor

# Check registry pod
kubectl logs -n harbor -l component=registry

# Verify project exists
curl -u admin:HarborAdmin123 \
  http://harbor.local/api/v2.0/projects
```

### Issue 3: Vulnerability scanning not working

```bash
# Check Trivy pod
kubectl get pods -n harbor | grep trivy
kubectl logs -n harbor -l component=trivy

# Manually trigger scan via UI or API
curl -X POST -u admin:HarborAdmin123 \
  "http://harbor.local/api/v2.0/projects/myapp/repositories/myapp/artifacts/latest/scan"
```

### Issue 4: Storage full

```bash
# Check PVC usage
kubectl get pvc -n harbor
kubectl describe pvc -n harbor

# Enable garbage collection via UI
# Administration → Clean Up → Garbage Collection
# Schedule: Daily or Weekly

# Or run manually:
# Administration → Clean Up → GC Now
```

---

## 🔄 Backup & Restore / สำรองและกู้คืน

### Backup Harbor

```bash
# Backup database
kubectl exec -n harbor harbor-database-0 -- \
  pg_dump -U postgres registry > harbor-backup.sql

# Backup configuration
helm get values harbor -n harbor > harbor-values-backup.yaml

# Backup PVC data (if needed)
kubectl exec -n harbor harbor-registry-xxx -- \
  tar czf - /storage > harbor-storage-backup.tar.gz
```

### Restore Harbor

```bash
# Restore database
kubectl exec -i -n harbor harbor-database-0 -- \
  psql -U postgres registry < harbor-backup.sql

# Restore with same values
helm upgrade --install harbor harbor/harbor \
  -f harbor-values-backup.yaml \
  -n harbor
```

---

## 🔗 Integration / การเชื่อมต่อ

### With Jenkins

```groovy
// Jenkinsfile
pipeline {
    agent any
    environment {
        HARBOR_REGISTRY = 'harbor.local'
        HARBOR_CREDENTIAL = credentials('harbor-credentials')
    }
    stages {
        stage('Build & Push') {
            steps {
                sh '''
                    docker build -t ${HARBOR_REGISTRY}/myapp/myapp:${BUILD_NUMBER} .
                    docker login -u $HARBOR_CREDENTIAL_USR -p $HARBOR_CREDENTIAL_PSW ${HARBOR_REGISTRY}
                    docker push ${HARBOR_REGISTRY}/myapp/myapp:${BUILD_NUMBER}
                '''
            }
        }
    }
}
```

### With Argo CD

Harbor images can be deployed via Argo CD:

```yaml
# argocd-application.yaml
spec:
  source:
    helm:
      values: |
        image:
          repository: harbor.local/myapp/myapp
          tag: "1.0.0"
```

---

## 📚 References / อ้างอิง

- [Harbor Official Documentation](https://goharbor.io/docs/)
- [Harbor Helm Chart](https://github.com/goharbor/harbor-helm)
- [Harbor API Reference](https://goharbor.io/docs/latest/working-with-projects/working-with-images/pulling-pushing-images/)
- [Trivy Scanner](https://github.com/aquasecurity/trivy)

---

## 📝 Notes / หมายเหตุ

- **Default Admin Password:** HarborAdmin123 (change in production!)
- **Storage:** Requires 10Gi+ for local dev, 200Gi+ for production
- **Resources:** Minimum 2Gi RAM, 2 CPU cores
- **Scanning:** Trivy updates vulnerability database automatically
- **Backup:** Schedule regular database backups
- **HA:** Use 2+ replicas for production
- **External DB/Redis:** Recommended for production

---

**Status:** ✅ Ready for local development
**Last Updated:** 2025-12-26
