# Quick Start สำหรับ Local / Local Development Quick Start

## 🚀 ติดตั้งแบบเร็วใน 5 นาที

### ขั้นตอนที่ 1: เตรียม Kubernetes Cluster

เลือกอย่างใดอย่างหนึ่ง:

#### Option A: Minikube (แนะนำ) ⭐
```bash
# ติดตั้ง Minikube (macOS)
brew install minikube

# Start cluster
minikube start --cpus=4 --memory=8192 --disk-size=50g

# เปิด addons
minikube addons enable ingress
minikube addons enable metrics-server
```

#### Option B: Docker Desktop
```bash
# 1. เปิด Docker Desktop
# 2. Settings → Kubernetes → Enable Kubernetes
# 3. ตั้งค่า Resources:
#    - Memory: 8GB
#    - CPUs: 4
```

#### Option C: Kind
```bash
# ติดตั้ง Kind
brew install kind

# Create cluster
kind create cluster --name k8s-platform
```

---

### ขั้นตอนที่ 2: Clone Repository

```bash
git clone <your-repo-url>
cd k8s
```

---

### ขั้นตอนที่ 3: Deploy ทุกอย่างด้วยคำสั่งเดียว

```bash
./scripts/deploy-local.sh
```

รอประมาณ 5-10 นาที...

---

### ขั้นตอนที่ 4: เข้าถึง Services

#### เปิด Terminal ใหม่ 3 หน้าต่าง:

**Terminal 1 - Jenkins:**
```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# เปิด: http://localhost:8080
```

**Terminal 2 - Argo CD:**
```bash
kubectl port-forward -n argocd svc/argocd-server 8443:443
# เปิด: https://localhost:8443
```

**Terminal 3 - Vault:**
```bash
kubectl port-forward -n vault svc/vault 8200:8200
# เปิด: http://localhost:8200
```

---

### ขั้นตอนที่ 5: Get Passwords

#### Jenkins Password:
```bash
kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode; echo
```
- Username: `admin`
- Password: (จากคำสั่งด้านบน)

#### Argo CD Password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```
- Username: `admin`
- Password: (จากคำสั่งด้านบน)

#### Vault Token:
```bash
# Initialize Vault first
kubectl exec -n vault vault-0 -- vault operator init

# จะได้ unseal keys และ root token
# เก็บไว้ให้ดี!
```

---

## 📊 ตารางเปรียบเทียบ Local vs Production

| Component | Production | Local | เหตุผล |
|-----------|-----------|-------|--------|
| **Replicas** | 2-3 | 1 | ประหยัด RAM |
| **CPU Request** | 1-2 cores | 100-500m | ลดการใช้งาน |
| **Memory Request** | 2-4Gi | 256Mi-1Gi | ลดการใช้งาน |
| **Storage** | 50-100Gi | 5-10Gi | ประหยัดพื้นที่ |
| **HA Mode** | ✅ Enabled | ❌ Disabled | ไม่จำเป็น |
| **Ingress** | ✅ ใช้ DNS จริง | ❌ Port-forward | ไม่มี DNS |
| **TLS** | ✅ Enabled | ❌ Disabled | ไม่จำเป็น |
| **Network Policies** | ✅ Enforced | ⚠️ Optional | ทดสอบได้ |
| **Monitoring** | ✅ Full stack | ⚠️ Optional | กิน RAM เยอะ |
| **Harbor Registry** | ✅ Deployed | ❌ Use Docker Hub | กิน RAM เยอะ |

---

## 🎯 การใช้งานพื้นฐาน

### ทดสอบ Deploy Application

#### 1. สร้าง Deployment ง่ายๆ
```bash
kubectl create deployment nginx --image=nginx -n dev
kubectl expose deployment nginx --port=80 --type=NodePort -n dev
```

#### 2. ตรวจสอบ
```bash
kubectl get pods -n dev
kubectl get svc -n dev
```

#### 3. เข้าถึง (ถ้าใช้ Minikube)
```bash
minikube service nginx -n dev
```

### ทดสอบ CI/CD Pipeline

#### 1. สร้าง Simple Pipeline ใน Jenkins
- ไป Jenkins UI: http://localhost:8080
- New Item → Pipeline
- ใส่ Script ง่ายๆ:
```groovy
pipeline {
    agent any
    stages {
        stage('Hello') {
            steps {
                echo 'Hello from Local Jenkins!'
            }
        }
    }
}
```

#### 2. สร้าง Argo CD Application
```bash
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-app
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
```

---

## 🔧 Useful Commands / คำสั่งที่มีประโยชน์

### ดู Resource Usage
```bash
# ดู Node resources
kubectl top nodes

# ดู Pod resources
kubectl top pods -A

# ดู Pod ทั้งหมด
kubectl get pods -A
```

### ดู Logs
```bash
# Jenkins
kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller -f

# Argo CD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f

# Vault
kubectl logs -n vault vault-0 -f
```

### Restart Components
```bash
# Restart Jenkins
kubectl rollout restart deployment -n jenkins jenkins

# Restart Argo CD
kubectl rollout restart deployment -n argocd argocd-server

# Restart Vault
kubectl delete pod -n vault vault-0
```

### Clean Up
```bash
# ลบทุกอย่าง
kubectl delete ns jenkins argocd vault dev

# หรือลบ cluster ทั้งหมด
minikube delete
# หรือ
kind delete cluster --name k8s-platform
```

---

## ⚠️ Troubleshooting / แก้ปัญหา

### ปัญหา: Pod Pending
```bash
# ตรวจสอบ
kubectl describe pod <pod-name> -n <namespace>

# มักเกิดจาก: ไม่มี storage class
kubectl get sc

# แก้: ติดตั้ง local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### ปัญหา: Out of Memory
```bash
# ดู memory usage
kubectl top nodes

# แก้: เพิ่ม memory หรือลด components
minikube stop
minikube delete
minikube start --memory=12288  # 12GB
```

### ปัญหา: Can't Access Service
```bash
# ใช้ port-forward
kubectl port-forward -n <namespace> svc/<service-name> <local-port>:<service-port>

# หรือถ้าใช้ Minikube
minikube service <service-name> -n <namespace>
```

### ปัญหา: Vault Sealed
```bash
# Check status
kubectl exec -n vault vault-0 -- vault status

# Unseal (ต้องมี unseal keys)
kubectl exec -n vault vault-0 -- vault operator unseal <key>
```

---

## 📚 เอกสารเพิ่มเติม

- [Local Development Guide](docs/local-development-guide.md) - คู่มือฉบับเต็ม
- [Main README](README.md) - เอกสารหลัก
- [Implementation Tasks](docs/implementation_tasks.md) - รายการงาน

---

## 💡 Tips

1. **ใช้ alias เพื่อความสะดวก:**
   ```bash
   alias k='kubectl'
   alias kgp='kubectl get pods'
   alias kgpa='kubectl get pods -A'
   ```

2. **Install kubectx/kubens:**
   ```bash
   brew install kubectx
   kubens dev  # Switch to dev namespace
   ```

3. **ใช้ k9s สำหรับ UI:**
   ```bash
   brew install k9s
   k9s
   ```

4. **Save port-forward commands:**
   ```bash
   # สร้างไฟล์ start-services.sh
   cat > start-services.sh << 'EOF'
   #!/bin/bash
   kubectl port-forward -n jenkins svc/jenkins 8080:8080 &
   kubectl port-forward -n argocd svc/argocd-server 8443:443 &
   kubectl port-forward -n vault svc/vault 8200:8200 &
   wait
   EOF
   chmod +x start-services.sh
   ```

---

## 🎓 Learning Path / เส้นทางการเรียนรู้

1. ✅ Deploy ทุกอย่างด้วย `deploy-local.sh`
2. ✅ เข้าถึง Jenkins, Argo CD, Vault UI
3. ✅ สร้าง simple deployment ใน dev namespace
4. ✅ ทดสอบ Jenkins pipeline
5. ✅ ทดสอบ Argo CD sync
6. ✅ ทดสอบ Vault secret injection
7. ✅ ทดสอบ RBAC (สร้าง user ใหม่)
8. ✅ ทดสอบ Network Policies (ถ้าเปิดใช้)
9. ✅ ทำความเข้าใจ GitOps workflow
10. ✅ Deploy real application

---

**Happy Learning! / สนุกกับการเรียนรู้!** 🚀
