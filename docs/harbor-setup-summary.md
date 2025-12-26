# Harbor Container Registry - Setup Summary

## ✅ Task 2.4: Setup Container Registry - COMPLETED

**Date:** 2025-12-26
**Status:** Ready for deployment

---

## 📦 What Was Created

### 1. Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| **namespace.yaml** | Harbor namespace definition | `core-components/harbor/` |
| **values-local.yaml** | Helm values for local development | `core-components/harbor/` |
| **values.yaml** | Helm values for production | `core-components/harbor/` |
| **setup-tls.sh** | TLS certificate creation script | `core-components/harbor/` |
| **README.md** | Complete Harbor documentation | `core-components/harbor/` |

### 2. Updated Scripts

- ✅ **deploy-local.sh** - Added Harbor deployment (Phase 6)
- ✅ **Updated /etc/hosts instructions** - Added harbor.local
- ✅ **Updated access instructions** - Added Harbor URLs

---

## 🎯 Harbor Configuration

### Local Development (values-local.yaml)

```yaml
Key Settings:
- External URL: http://harbor.local
- TLS: Disabled (HTTP)
- Admin Password: HarborAdmin123
- Storage: 10Gi registry, 2Gi database
- Resources: Reduced for local (256Mi-512Mi RAM)
- Trivy: Enabled (vulnerability scanning)
- Notary: Disabled
```

### Production (values.yaml)

```yaml
Key Settings:
- External URL: https://harbor.company.local
- TLS: Enabled
- High Availability: 2 replicas
- Storage: 200Gi registry, 20Gi database
- Resources: Production-grade (1Gi-2Gi RAM)
- Trivy: Enabled
- Notary: Enabled (image signing)
```

---

## 📋 Components Included

Harbor deployment includes:

1. **Harbor Core** - Main API and web UI
2. **Harbor Portal** - Web interface
3. **Harbor Registry** - Docker registry
4. **Harbor JobService** - Background jobs
5. **PostgreSQL** - Internal database
6. **Redis** - Cache layer
7. **Trivy** - Vulnerability scanner
8. **Chartmuseum** - Helm chart repository

---

## 🚀 Installation Steps

### Quick Install (Local Development)

```bash
# 1. Add Harbor helm repo
helm repo add harbor https://helm.goharbor.io
helm repo update

# 2. Install Harbor
helm upgrade --install harbor harbor/harbor \
  -f core-components/harbor/values-local.yaml \
  -n harbor \
  --create-namespace \
  --wait \
  --timeout 15m

# 3. Add to /etc/hosts
sudo sh -c 'echo "127.0.0.1 harbor.local" >> /etc/hosts'

# 4. Access Harbor
open http://harbor.local

# 5. Login
# Username: admin
# Password: HarborAdmin123
```

### Install via Deployment Script

```bash
# Harbor is included in deploy-local.sh as Phase 6
./scripts/deploy-local.sh
```

---

## 🔧 Post-Installation Tasks

### 1. Access Harbor Web UI

```bash
# Via Ingress
http://harbor.local

# Via port-forward
kubectl port-forward -n harbor svc/harbor-portal 8888:80
http://localhost:8888
```

### 2. Login to Harbor

```bash
# Web UI credentials
Username: admin
Password: HarborAdmin123

# Docker CLI
docker login harbor.local
```

### 3. Create Your First Project

1. Open http://harbor.local
2. Login with admin credentials
3. Click "NEW PROJECT"
4. Enter project name (e.g., "myapp")
5. Select Public or Private
6. Click "OK"

### 4. Push Your First Image

```bash
# Tag image
docker tag myapp:latest harbor.local/myapp/myapp:latest

# Login
docker login harbor.local

# Push
docker push harbor.local/myapp/myapp:latest
```

---

## 📊 Resource Usage

### Local Development

```
Total Resources (Minimum):
- CPU: ~1.5 cores
- Memory: ~3Gi
- Storage: ~15Gi

Per Component:
- Core: 256Mi RAM, 100m CPU
- Registry: 256Mi RAM, 100m CPU
- Portal: 128Mi RAM, 100m CPU
- Database: 256Mi RAM, 100m CPU
- Redis: 128Mi RAM, 100m CPU
- Trivy: 256Mi RAM, 200m CPU
- JobService: 256Mi RAM, 100m CPU
```

### Production

```
Total Resources (Recommended):
- CPU: ~6 cores
- Memory: ~12Gi
- Storage: ~250Gi

High Availability:
- 2 replicas for core components
- External database recommended
- External Redis recommended
```

---

## 🔐 Security Features

### 1. Vulnerability Scanning

- ✅ **Trivy integrated** - Automatic CVE scanning
- ✅ **Scan on push** - Can be enabled
- ✅ **Block vulnerable images** - Policy enforcement

### 2. Access Control

- ✅ **RBAC** - Project-level permissions
- ✅ **Robot accounts** - Service accounts for automation
- ✅ **OIDC/OAuth** - SSO integration (production)

### 3. Content Trust

- ✅ **Image signing** - Notary integration (production)
- ✅ **Signature verification** - Ensure image authenticity

### 4. Audit Logging

- ✅ **Activity logs** - Track all operations
- ✅ **Webhook notifications** - External integrations

---

## 🔗 Integration Examples

### With Jenkins

```groovy
pipeline {
    environment {
        HARBOR = 'harbor.local'
        HARBOR_CRED = credentials('harbor-credentials')
    }
    stages {
        stage('Build & Push') {
            steps {
                sh '''
                    docker build -t ${HARBOR}/myapp/myapp:${BUILD_NUMBER} .
                    docker login -u $HARBOR_CRED_USR -p $HARBOR_CRED_PSW ${HARBOR}
                    docker push ${HARBOR}/myapp/myapp:${BUILD_NUMBER}
                '''
            }
        }
    }
}
```

### With Kubernetes

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: harbor.local/myapp/myapp:1.0.0
  imagePullSecrets:
  - name: harbor-secret
```

### With Argo CD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    helm:
      values: |
        image:
          repository: harbor.local/myapp/myapp
          tag: "1.0.0"
```

---

## 📚 Documentation References

### Created Documentation

- [Harbor README](../core-components/harbor/README.md) - Complete setup guide
- [TLS Setup Script](../core-components/harbor/setup-tls.sh) - Certificate creation

### Official Documentation

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor Helm Chart](https://github.com/goharbor/harbor-helm)
- [Trivy Scanner](https://github.com/aquasecurity/trivy)

---

## ✅ Verification Checklist

After installation, verify:

- [ ] All pods running: `kubectl get pods -n harbor`
- [ ] Ingress created: `kubectl get ingress -n harbor`
- [ ] Web UI accessible: `http://harbor.local`
- [ ] Can login with admin credentials
- [ ] Can create a project
- [ ] Can push an image
- [ ] Can pull an image
- [ ] Trivy scanning works
- [ ] Can use image in Kubernetes pod

---

## 🎯 Next Steps

### Immediate (Required)

1. ✅ Deploy Harbor via script or manually
2. ✅ Access web UI and change admin password
3. ✅ Create projects for your applications
4. ✅ Configure Jenkins integration

### Short Term (Recommended)

1. Enable vulnerability scanning on push
2. Set up robot accounts for CI/CD
3. Configure image retention policies
4. Set up replication (if multi-cluster)

### Long Term (Production)

1. Enable TLS with valid certificates
2. Configure external PostgreSQL database
3. Configure external Redis
4. Enable Notary for image signing
5. Set up OIDC/OAuth SSO
6. Configure backup and disaster recovery

---

## 🆘 Troubleshooting

### Issue: Pods Not Starting

```bash
# Check events
kubectl get events -n harbor --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs -n harbor <pod-name>

# Common causes:
# - Insufficient resources
# - PVC not bound
# - Image pull errors
```

### Issue: Cannot Access UI

```bash
# Check Ingress
kubectl get ingress -n harbor
kubectl describe ingress -n harbor

# Check /etc/hosts
cat /etc/hosts | grep harbor

# Check service
kubectl get svc -n harbor
```

### Issue: Cannot Push Images

```bash
# Test docker login
docker login harbor.local

# Check project exists
# Via UI or: curl -u admin:HarborAdmin123 \
#   http://harbor.local/api/v2.0/projects

# Check disk space
kubectl exec -n harbor harbor-registry-xxx -- df -h
```

---

## 📝 Summary

**Task 2.4: Setup Container Registry** - ✅ **COMPLETED**

### What Was Accomplished

1. ✅ Created complete Harbor configuration
2. ✅ Configured for both local dev and production
3. ✅ Integrated with deployment scripts
4. ✅ Documented thoroughly
5. ✅ Ready for immediate deployment

### Ready for Deployment

Harbor can be deployed immediately using:

```bash
./scripts/deploy-local.sh
```

Or manually:

```bash
helm upgrade --install harbor harbor/harbor \
  -f core-components/harbor/values-local.yaml \
  -n harbor --create-namespace --wait
```

---

**Harbor Container Registry setup is complete and ready for use!** 🎉
