# Manual Installation Steps / ขั้นตอนการติดตั้งแบบ Manual

## สำหรับผู้ที่ต้องการเข้าใจแต่ละขั้นตอนและทำเองทีละ Step

เอกสารนี้อธิบายการติดตั้งแบบละเอียดทุกขั้นตอน โดยไม่ใช้ script อัตโนมัติ

---

## 📋 Table of Contents

1. [Prerequisites Check](#step-0-prerequisites-check)
2. [Start Kubernetes Cluster](#step-1-start-kubernetes-cluster)
3. [Setup Storage](#step-2-setup-storage)
4. [Create Namespaces](#step-3-create-namespaces)
5. [Deploy RBAC](#step-4-deploy-rbac)
6. [Deploy Network Policies (Optional)](#step-5-deploy-network-policies-optional)
7. **[Setup Ingress Controller (Optional)](#step-6-setup-ingress-controller-optional)**
8. [Install Jenkins](#step-7-install-jenkins)
9. [Install Argo CD](#step-8-install-argo-cd)
10. [Install Vault](#step-9-install-vault)
11. [Access Services](#step-10-access-services)
12. [Initialize Vault](#step-11-initialize-vault)
13. [Verify Installation](#step-12-verify-installation)

---

## Step 0: Prerequisites Check / ตรวจสอบความพร้อม

### 0.1 ตรวจสอบ Tools ที่ต้องมี

```bash
# ตรวจสอบ kubectl
kubectl version --client

# ตรวจสอบ helm
helm version

# ตรวจสอบ docker (ถ้าใช้ Docker Desktop)
docker --version
```

**ถ้ายังไม่มี ให้ติดตั้ง:**

```bash
# macOS - ติดตั้ง kubectl
brew install kubectl

# macOS - ติดตั้ง helm
brew install helm

# Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop
```

### 0.2 ตรวจสอบ System Resources

```bash
# ตรวจสอบ RAM (macOS)
sysctl hw.memsize | awk '{print $2/1024/1024/1024 " GB"}'

# ตรวจสอบ CPU cores
sysctl -n hw.ncpu
```

**ต้องการอย่างน้อย:**

- RAM: 8GB (แนะนำ 16GB)
- CPU: 4 cores

---

## Step 1: Start Kubernetes Cluster / เริ่ม Kubernetes Cluster

เลือกอย่างใดอย่างหนึ่ง:

### Option A: Docker Desktop Kubernetes (แนะนำ) ⭐

#### 1.1 เปิด Docker Desktop

```bash
# เปิด Docker Desktop application
open -a Docker
```

#### 1.2 Enable Kubernetes

1. คลิก Docker icon บน menu bar
2. Preferences / Settings
3. Kubernetes tab
4. ✅ Enable Kubernetes
5. Apply & Restart

#### 1.3 ตั้งค่า Resources

1. Resources tab
2. ตั้งค่า:
   - **CPUs:** 4
   - **Memory:** 8.00 GB (หรือ 12GB ถ้ามี RAM เหลือ)
   - **Swap:** 2 GB
   - **Disk:** 50 GB
3. Apply & Restart

#### 1.4 รอจน Kubernetes พร้อม

```bash
# ตรวจสอบว่า Kubernetes running แล้ว
kubectl cluster-info

# ควรเห็น:
# Kubernetes control plane is running at https://kubernetes.docker.internal:6443
```

### Option B: Minikube

```bash
# ติดตั้ง Minikube
brew install minikube

# Start cluster with resources
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=50g \
  --driver=docker

# Enable addons
minikube addons enable metrics-server
minikube addons enable ingress

# ตรวจสอบ
kubectl cluster-info
```

### Option C: Kind

```bash
# ติดตั้ง Kind
brew install kind

# Create cluster with config
kind create cluster \
  --name k8s-platform \
  --config infrastructure/cluster/kind-config.yaml

# ตรวจสอบ
kubectl cluster-info
```

---

## Step 2: Setup Storage / ตั้งค่า Storage

### 2.1 ตรวจสอบ Storage Class

```bash
# ดู storage class ที่มีอยู่
kubectl get storageclass

# ถ้าใช้ Docker Desktop จะมี 'hostpath' อยู่แล้ว
# ถ้าใช้ Minikube จะมี 'standard' อยู่แล้ว
```

### 2.2 ติดตั้ง Local Path Provisioner (ถ้ายังไม่มี)

```bash
# ติดตั้ง local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# รอให้ pod พร้อม
kubectl wait --for=condition=ready pod \
  -l app=local-path-provisioner \
  -n local-path-storage \
  --timeout=120s

# ตรวจสอบ
kubectl get storageclass
```

### 2.3 Set Default Storage Class

```bash
# ตั้งเป็น default (เลือกชื่อตาม cluster ที่ใช้)

# สำหรับ Docker Desktop
kubectl patch storageclass hostpath \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# สำหรับ Minikube
kubectl patch storageclass standard \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# สำหรับ local-path-provisioner
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**ตรวจสอบ:**

```bash
kubectl get storageclass
# ควรเห็น (default) ข้างชื่อ storage class
```

---

## Step 3: Create Namespaces / สร้าง Namespaces

### 3.1 สร้าง Environment Namespace (dev)

```bash
# สร้าง dev namespace
kubectl apply -f environments/local/namespace.yaml

# หรือสร้างด้วยคำสั่ง
kubectl create namespace dev
```

**คำอธิบาย:** สร้าง namespace สำหรับ dev environment พร้อม resource quotas และ limits

### 3.2 สร้าง Component Namespaces

```bash
# สร้าง namespace สำหรับ Jenkins
kubectl apply -f core-components/jenkins/namespace.yaml
# หรือ
kubectl create namespace jenkins

# สร้าง namespace สำหรับ Argo CD
kubectl apply -f core-components/argocd/namespace.yaml
# หรือ
kubectl create namespace argocd

# สร้าง namespace สำหรับ Vault
kubectl apply -f core-components/vault/namespace.yaml
# หรือ
kubectl create namespace vault
```

**คำอธิบาย:** แยก namespace สำหรับแต่ละ component เพื่อความเป็นระเบียบและ isolation

### 3.3 ตรวจสอบ Namespaces

```bash
# ดู namespaces ทั้งหมด
kubectl get namespaces

# ควรเห็น:
# dev       Active   1m
# jenkins   Active   1m
# argocd    Active   1m
# vault     Active   1m

# ดู resource quotas
kubectl get resourcequota -A
```

---

## Step 4: Deploy RBAC / ติดตั้ง RBAC

### 4.1 Deploy Cluster Admin Role

```bash
# Apply cluster admin RBAC
kubectl apply -f security/rbac/cluster-admin-role.yaml
```

**คำอธิบาย:** สร้าง ClusterAdmin role สำหรับ platform team

### 4.2 Deploy Developer Role

```bash
# Apply developer role
kubectl apply -f security/rbac/developer-role.yaml
```

**คำอธิบาย:** สร้าง Developer role ที่มี read-only access + port-forward

### 4.3 Deploy Namespace Admin Role (Optional)

```bash
# Apply namespace admin role
kubectl apply -f security/rbac/namespace-admin-role.yaml
```

**คำอธิบาย:** สร้าง NamespaceAdmin role สำหรับ tech leads

### 4.4 Deploy ServiceAccount Policy

```bash
# Apply service account policies
kubectl apply -f security/rbac/serviceaccount-policy.yaml
```

**คำอธิบาย:** ตั้งค่า ServiceAccount ให้มี minimal privileges

### 4.5 ตรวจสอบ RBAC

```bash
# ดู cluster role bindings
kubectl get clusterrolebinding | grep -E "platform|developer"

# ดู role bindings in dev namespace
kubectl get rolebinding -n dev

# ทดสอบ permissions
kubectl auth can-i get pods --namespace=dev --as=developer@company.com
```

---

## Step 5: Deploy Network Policies (Optional) / ติดตั้ง Network Policies

**หมายเหตุ:** สำหรับ local development แนะนำให้ **ข้าม step นี้** เพื่อความสะดวก

### 5.1 Deploy Default Deny All

```bash
# Apply default deny policy
kubectl apply -f security/network-policies/default-deny-all.yaml
```

**คำอธิบาย:** บล็อก traffic ทั้งหมดโดย default (Zero Trust)

### 5.2 Allow DNS

```bash
# Allow DNS resolution
kubectl apply -f security/network-policies/allow-dns.yaml
```

**คำอธิบาย:** อนุญาตให้ pods resolve DNS ได้

### 5.3 Allow Other Policies (ตามต้องการ)

```bash
# Allow ingress to frontend
kubectl apply -f security/network-policies/allow-ingress-to-frontend.yaml

# Allow frontend to backend
kubectl apply -f security/network-policies/allow-frontend-to-backend.yaml

# Allow vault access
kubectl apply -f security/network-policies/allow-vault-access.yaml

# Allow external egress
kubectl apply -f security/network-policies/allow-external-egress.yaml
```

### 5.4 ตรวจสอบ Network Policies

```bash
# ดู network policies
kubectl get networkpolicy -A

# Test DNS (ถ้าใส่ policies แล้ว)
kubectl run test-dns --image=busybox -n dev --rm -it -- nslookup google.com
```

---

## Step 6: Setup Ingress Controller (Optional) / ติดตั้ง Ingress Controller (ถ้าต้องการ)

**หมายเหตุ:** Step นี้เป็น **Optional** - ถ้าต้องการใช้ hostname (jenkins.local, argocd.local) แทน port-forward

### เลือกวิธีการเข้าถึง Services

- **Option A: Ingress** (Production-like) - ใช้ hostname, ไม่ต้อง port-forward
- **Option B: Port-Forward** (ง่ายกว่า) - ใช้ localhost:port

**ถ้าเลือก Port-Forward สามารถข้าม Step นี้ไปที่ [Step 7](#step-7-install-jenkins--ติดตั้ง-jenkins)**

---

### 6.1 Install NGINX Ingress Controller

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

**คำอธิบาย:** ติดตั้ง NGINX Ingress Controller สำหรับ routing traffic ไปยัง services

**สิ่งที่เกิดขึ้น:**

1. สร้าง namespace `ingress-nginx`
2. สร้าง Deployment สำหรับ ingress-nginx-controller
3. สร้าง Service (Type: LoadBalancer) สำหรับรับ traffic จากภายนอก
4. สร้าง RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)
5. สร้าง ConfigMap สำหรับ configuration

### 6.2 Wait for Ingress Controller

```bash
# รอให้ Ingress Controller พร้อม (ประมาณ 1-2 นาที)
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
```

**คำอธิบาย:** รอจนกว่า Ingress Controller pod จะ ready

### 6.3 ตรวจสอบ Ingress Controller

```bash
# ดู pods
kubectl get pods -n ingress-nginx

# ควรเห็น:
# NAME                                       READY   STATUS    RESTARTS   AGE
# ingress-nginx-controller-xxx               1/1     Running   0          2m

# ดู service
kubectl get svc -n ingress-nginx

# ควรเห็น:
# NAME                           TYPE           EXTERNAL-IP   PORT(S)
# ingress-nginx-controller       LoadBalancer   localhost     80:xxxxx/TCP,443:xxxxx/TCP
```

**สังเกต:**

- EXTERNAL-IP ควรเป็น `localhost` (สำหรับ Docker Desktop)
- หรืออาจเป็น IP address อื่น (ขึ้นอยู่กับ cluster type)

### 6.4 Update /etc/hosts

เพิ่ม hostnames สำหรับ services:

```bash
# วิธีที่ 1: เพิ่มทีละบรรทัด
sudo sh -c 'echo "127.0.0.1 jenkins.local" >> /etc/hosts'
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'
sudo sh -c 'echo "127.0.0.1 argocd-http.local" >> /etc/hosts'
sudo sh -c 'echo "127.0.0.1 vault.local" >> /etc/hosts'

# วิธีที่ 2: เพิ่มพร้อมกัน (แนะนำ)
sudo sh -c 'echo "127.0.0.1 jenkins.local argocd.local argocd-http.local vault.local" >> /etc/hosts'

# วิธีที่ 3: แก้ไขด้วย text editor
sudo nano /etc/hosts
# แล้วเพิ่มบรรทัดนี้:
# 127.0.0.1 jenkins.local argocd.local argocd-http.local vault.local
```

**คำอธิบาย:**

- เพิ่ม DNS mapping สำหรับ local hostnames
- ทำให้เข้าถึง services ผ่าน <http://jenkins.local> แทน <http://localhost:8080>

**ตรวจสอบ:**

```bash
# Test DNS resolution
ping jenkins.local
# ควรได้ response จาก 127.0.0.1

# Test ว่า Ingress Controller รับ request ได้
curl -I http://localhost
# ควรได้ HTTP response (อาจจะ 404 ถ้ายังไม่มี Ingress rules)
```

### 6.5 Ingress Resources จะถูกสร้างอัตโนมัติ

**หมายเหตุ สำคัญ:**

- **Jenkins**: Ingress จะถูกสร้างอัตโนมัติโดย Helm (เพราะ values-local.yaml มี `ingress.enabled: true`)
- **Vault**: Ingress จะถูกสร้างอัตโนมัติโดย Helm (เพราะ values-local.yaml มี `ingress.enabled: true`)
- **Argo CD**: ต้อง apply Ingress manually (เพราะใช้ official manifest ไม่ใช่ Helm)

เราจะ apply Argo CD Ingress ใน Step 8

---

## Step 7: Install Jenkins / ติดตั้ง Jenkins

### 7.1 Add Helm Repository

```bash
# เพิ่ม Jenkins helm repo
helm repo add jenkins https://charts.jenkins.io

# Update repo
helm repo update

# ค้นหา chart
helm search repo jenkins/jenkins
```

**คำอธิบาย:** เพิ่ม official Jenkins Helm repository

### 7.2 Review Configuration

```bash
# ดูไฟล์ config สำหรับ local
cat core-components/jenkins/values-local.yaml

# สังเกต:
# - resources ลดลง (1-2Gi RAM)
# - replicas = 1
# - ingress enabled (ถ้าติดตั้ง Ingress Controller ใน Step 6)
# - persistence = 10Gi
```

### 7.3 Install Jenkins Chart

```bash
# Install Jenkins
helm install jenkins jenkins/jenkins \
  -f core-components/jenkins/values-local.yaml \
  -n jenkins \
  --wait \
  --timeout 10m
```

**คำอธิบาย:** ติดตั้ง Jenkins ด้วย Helm พร้อม custom values สำหรับ local

**สิ่งที่เกิดขึ้น:**

1. สร้าง StatefulSet สำหรับ Jenkins controller
2. สร้าง PVC สำหรับเก็บ Jenkins data (10Gi)
3. สร้าง Service (ClusterIP) สำหรับเข้าถึง Jenkins
4. สร้าง ServiceAccount และ RBAC สำหรับ Kubernetes integration
5. **สร้าง Ingress (ถ้าติดตั้ง Ingress Controller)** สำหรับเข้าถึงผ่าน jenkins.local
6. รอจนกว่า pods จะ ready (~3-5 นาที)

### 7.4 ตรวจสอบ Jenkins

```bash
# ดู pods
kubectl get pods -n jenkins

# ควรเห็น:
# NAME        READY   STATUS    RESTARTS   AGE
# jenkins-0   2/2     Running   0          3m

# ดู services
kubectl get svc -n jenkins

# ดู logs (ถ้ามีปัญหา)
kubectl logs -n jenkins jenkins-0 -c jenkins

# ดู ingress (ถ้าติดตั้ง Ingress Controller)
kubectl get ingress -n jenkins
```

### 7.5 Get Jenkins Admin Password

```bash
# Get admin password
kubectl get secret -n jenkins jenkins \
  -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode

echo ""  # new line

# เก็บ password นี้ไว้!
```

---

## Step 8: Install Argo CD / ติดตั้ง Argo CD

### 8.1 Install Using Official Manifest (แนะนำ) ⭐

```bash
# Install Argo CD using official manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**คำอธิบาย:** ติดตั้ง Argo CD ด้วย official manifest (มีเสถียรภาพสูงกว่า Helm สำหรับ local development)

**ทำไมใช้ Official Manifest:**

- ✅ มีเสถียรภาพมากกว่า (tested และ recommended จาก Argo CD team)
- ✅ ไม่มีปัญหาเรื่อง Helm values compatibility
- ✅ ติดตั้งง่ายและรวดเร็ว
- ✅ ใช้ได้ดีกับ Docker Desktop Kubernetes

**สิ่งที่เกิดขึ้น:**

1. สร้าง Deployment สำหรับ argocd-server
2. สร้าง Deployment สำหรับ argocd-application-controller
3. สร้าง Deployment สำหรับ argocd-repo-server
4. สร้าง Deployment สำหรับ argocd-dex-server
5. สร้าง StatefulSet สำหรับ argocd-application-controller
6. สร้าง Deployment สำหรับ argocd-redis
7. สร้าง Services สำหรับแต่ละ component
8. รอจนกว่า pods จะ ready (~2-3 นาที)

### 8.2 (Alternative) Install Using Helm

**หมายเหตุ:** สามารถใช้ Helm ได้ แต่อาจพบปัญหา compatibility กับ values file

```bash
# เพิ่ม Argo CD helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Argo CD (ไม่แนะนำสำหรับ local)
helm install argocd argo/argo-cd \
  -n argocd \
  --wait \
  --timeout 10m

# หรือใช้กับ custom values (advanced)
# helm install argocd argo/argo-cd \
#   -f core-components/argocd/values-local.yaml \
#   -n argocd
```

### 8.3 Apply Ingress และ Configure Argo CD (ถ้าติดตั้ง Ingress)

**หมายเหตุ:** ข้าม step นี้ถ้าไม่ได้ติดตั้ง Ingress Controller ใน Step 6

#### 8.3.1 Configure Argo CD Insecure Mode

```bash
# Configure Argo CD server สำหรับ insecure mode (จำเป็นสำหรับ Ingress)
kubectl apply -f core-components/argocd/argocd-cmd-params-cm.yaml

# Restart Argo CD server เพื่อให้อ่าน configuration ใหม่
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

**คำอธิบาย:**

- Apply ConfigMap (`argocd-cmd-params-cm.yaml`) เพื่อตั้งค่า `server.insecure: "true"`
- Restart Argo CD server เพื่อให้อ่านค่า configuration จาก ConfigMap

**ทำไมใช้ ConfigMap แทน Patch?**

- ✅ เป็นวิธีที่ถูกต้องตาม Argo CD best practices
- ✅ Configuration เป็น declarative (Infrastructure as Code)
- ✅ สามารถ version control ได้
- ✅ ง่ายต่อการ rollback หรือเปลี่ยนแปลงในอนาคต

#### 8.3.2 Create TLS Certificate (SSL Termination at Ingress) ⭐

**แนะนำ:** ใช้ SSL Termination at Ingress (Method 2) สำหรับ HTTPS access ที่ปลอดภัย

```bash
# สร้าง self-signed certificate สำหรับ argocd.local
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout argocd-tls.key \
  -out argocd-tls.crt \
  -subj "/CN=argocd.local/O=argocd"

# สร้าง Kubernetes TLS secret
kubectl create secret tls argocd-tls-secret \
  --cert=argocd-tls.crt \
  --key=argocd-tls.key \
  -n argocd

# ลบไฟล์ certificate (เก็บใน secret แล้ว)
rm argocd-tls.key argocd-tls.crt
```

**คำอธิบาย:**

- สร้าง self-signed certificate สำหรับ local development
- สำหรับ production ควรใช้ Let's Encrypt ผ่าน cert-manager
- TLS secret จะถูกใช้โดย Ingress เพื่อ terminate SSL

**หมายเหตุ:**

- Browser จะแสดง certificate warning (เพราะเป็น self-signed)
- คลิก "Advanced" → "Proceed" เพื่อเข้าใช้งาน
- สำหรับ production ควรใช้ valid certificate

#### 8.3.3 Apply Argo CD Ingress

```bash
# Apply Argo CD Ingress with SSL Termination
kubectl apply -f core-components/argocd/ingress.yaml
```

**คำอธิบาย:**

- Apply Ingress resource สำหรับ Argo CD
- ใช้ SSL Termination at Ingress (Method 2) - แนะนำ
- Argo CD จะสามารถเข้าถึงผ่าน <https://argocd.local>

**ตรวจสอบ Ingress:**

```bash
# ดู ingress resources
kubectl get ingress -n argocd

# ควรเห็น:
# NAME                     CLASS   HOSTS          PORTS     AGE
# argocd-server-ingress    nginx   argocd.local   80, 443   1m
```

**ทดสอบ HTTPS access:**

```bash
# Test HTTPS (ควรได้ 200 OK)
curl -k -I https://argocd.local

# Test HTTP redirect (ควรได้ 308 Permanent Redirect)
curl -I http://argocd.local
```

### 8.4 ตรวจสอบ Argo CD

```bash
# ดู pods
kubectl get pods -n argocd

# ควรเห็น:
# argocd-application-controller-xxx   1/1   Running
# argocd-redis-xxx                    1/1   Running
# argocd-repo-server-xxx              1/1   Running
# argocd-server-xxx                   1/1   Running

# ดู services
kubectl get svc -n argocd

# ดู ingress (ถ้าติดตั้ง Ingress Controller)
kubectl get ingress -n argocd
```

### 8.5 Get Argo CD Admin Password

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

echo ""  # new line

# เก็บ password นี้ไว้!
```

---

## Step 9: Install Vault / ติดตั้ง Vault

### 9.1 Add Helm Repository

```bash
# เพิ่ม HashiCorp helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com

# Update repo
helm repo update

# ค้นหา chart
helm search repo hashicorp/vault
```

### 9.2 Review Configuration

```bash
# ดูไฟล์ config สำหรับ local
cat core-components/vault/values-local.yaml

# สังเกต:
# - standalone mode (ไม่ใช่ HA)
# - file storage (ไม่ใช่ Raft)
# - resources ลดลง
# - TLS disabled
# - ingress enabled (ถ้าติดตั้ง Ingress Controller ใน Step 6)
# - PVC = 5Gi
```

### 9.3 Install Vault Chart

```bash
# Install Vault
helm install vault hashicorp/vault \
  -f core-components/vault/values-local.yaml \
  -n vault \
  --wait \
  --timeout 10m
```

**คำอธิบาย:** ติดตั้ง Vault ในโหมด standalone

**สิ่งที่เกิดขึ้น:**

1. สร้าง StatefulSet สำหรับ Vault server (1 pod)
2. สร้าง PVC สำหรับ Vault data และ audit logs (5Gi x 2)
3. สร้าง Service สำหรับเข้าถึง Vault
4. สร้าง Deployment สำหรับ Vault Agent Injector
5. **สร้าง Ingress (ถ้าติดตั้ง Ingress Controller)** สำหรับเข้าถึงผ่าน vault.local
6. Vault pod จะ start แต่ยังไม่ initialized และ sealed

### 9.4 ตรวจสอบ Vault

```bash
# ดู pods
kubectl get pods -n vault

# ควรเห็น:
# vault-0                     0/1   Running   (ยังไม่ ready เพราะ sealed)
# vault-agent-injector-xxx    1/1   Running

# ดู services
kubectl get svc -n vault

# Check vault status (จะเห็นว่า sealed และ not initialized)
kubectl exec -n vault vault-0 -- vault status

# ดู ingress (ถ้าติดตั้ง Ingress Controller)
kubectl get ingress -n vault
```

**Note:** Vault pod จะยังไม่ ready (0/1) เพราะยังไม่ได้ initialize และ unseal

---

## Step 10: Access Services / เข้าถึง Services

เลือกวิธีการเข้าถึง services ตาม option ที่เลือกใน Step 6:

- **Option A: Via Ingress** (ถ้าติดตั้ง Ingress Controller)
- **Option B: Via Port-Forward** (ถ้าไม่ได้ติดตั้ง Ingress)

---

### Option A: Access via Ingress (แนะนำถ้าติดตั้ง Ingress) ⭐

**ข้อดี:**

- ✅ ใช้ hostname ที่จดจำง่าย
- ✅ ไม่ต้องเปิด terminal ไว้
- ✅ เหมือน production environment

```bash
# เปิด browser ที่ URL เหล่านี้:
open http://jenkins.local
open https://argocd.local
# หรือ: open http://argocd-http.local
open http://vault.local
```

**URLs:**

- **Jenkins:**  <http://jenkins.local>
- **Argo CD:** <https://argocd.local> (หรือ <http://argocd-http.local> สำหรับ HTTP)
- **Vault:**   <http://vault.local>

**หมายเหตุ:**

- ต้อง update /etc/hosts ให้เรียบร้อยแล้ว (ดู Step 6.4)
- Browser อาจแจ้ง SSL warning สำหรับ Argo CD (ให้คลิก Advanced → Proceed)

---

### Option B: Access via Port-Forward

**ข้อดี:**

- ✅ ง่ายกว่า ไม่ต้อง setup Ingress
- ✅ เหมาะสำหรับ daily development

เปิด **Terminal ใหม่ 3 หน้าต่าง** แล้วรันคำสั่งเหล่านี้:

#### Terminal 1 - Jenkins

```bash
# Port forward Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# เว้นไว้ (ไม่ต้องกด Ctrl+C)
```

**เข้าถึง:** <http://localhost:8080>

#### Terminal 2 - Argo CD

```bash
# Port forward Argo CD
kubectl port-forward -n argocd svc/argocd-server 8443:443

# เว้นไว้
```

**เข้าถึง:** <https://localhost:8443>

#### Terminal 3 - Vault

```bash
# Port forward Vault
kubectl port-forward -n vault svc/vault 8200:8200

# เว้นไว้
```

**เข้าถึง:** <http://localhost:8200>

---

### 10.3 Login Credentials Summary

#### Jenkins

- **Username:** `admin`
- **Password:** (จาก Step 7.5)

**URLs:**

- Ingress: <http://jenkins.local>
- Port-forward: <http://localhost:8080>

#### Argo CD

- **Username:** `admin`
- **Password:** (จาก Step 8.5)

**URLs:**

- Ingress: <https://argocd.local> (หรือ <http://argocd-http.local>)
- Port-forward: <https://localhost:8443>

**Note:** ใช้ "Advanced" → "Proceed" ถ้า browser แจ้ง SSL warning

#### Vault

- **Token:** (จะได้จาก Step 11 หลัง initialize)

**URLs:**

- Ingress: <http://vault.local>
- Port-forward: <http://localhost:8200>

---

## Step 11: Initialize Vault / เริ่มต้น Vault

### 11.1 Initialize Vault

```bash
# Initialize Vault (ได้ unseal keys และ root token)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# ดูไฟล์
cat vault-keys.json
```

**คำอธิบาย:** Initialize Vault และได้:

- **5 Unseal Keys** (ต้องใช้ 3 keys เพื่อ unseal)
- **1 Root Token** (ใช้ login เป็น admin)

**⚠️ สำคัญมาก:**

- เก็บไฟล์ `vault-keys.json` ไว้ให้ดี
- **อย่า commit เข้า git!**
- ถ้าหาย = เข้า Vault ไม่ได้

### 11.2 Extract Keys and Token

```bash
# Extract unseal keys
UNSEAL_KEY_1=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-keys.json | jq -r '.unseal_keys_b64[2]')

# Extract root token
ROOT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')

# แสดง
echo "Root Token: $ROOT_TOKEN"
echo "Unseal Key 1: $UNSEAL_KEY_1"
echo "Unseal Key 2: $UNSEAL_KEY_2"
echo "Unseal Key 3: $UNSEAL_KEY_3"
```

### 11.3 Unseal Vault

```bash
# Unseal ครั้งที่ 1
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1

# Unseal ครั้งที่ 2
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2

# Unseal ครั้งที่ 3
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3
```

**คำอธิบาย:** ต้อง unseal ด้วย 3 keys จึงจะใช้งาน Vault ได้

### 11.4 ตรวจสอบ Vault Status

```bash
# Check status
kubectl exec -n vault vault-0 -- vault status

# ควรเห็น:
# Sealed: false
# Initialized: true

# ดู pod (ควร ready แล้ว)
kubectl get pods -n vault

# ควรเห็น:
# vault-0   1/1   Running
```

### 11.5 Login to Vault

```bash
# Login with root token
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN

# หรือ login ผ่าน UI
# Via Ingress: http://vault.local
# Via Port-forward: http://localhost:8200
# Method: Token
# Token: <ROOT_TOKEN>
```

### 11.6 Configure Vault

```bash
# Enable Kubernetes auth
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Configure Kubernetes auth
kubectl exec -n vault vault-0 -- sh -c '
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
'

# Enable KV v2 secrets engine
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2

# สร้าง secret ทดสอบ
kubectl exec -n vault vault-0 -- vault kv put secret/dev/test password=hello123
```

**คำอธิบาย:** ตั้งค่า Vault ให้:

1. รองรับ Kubernetes authentication
2. เปิดใช้ KV v2 secrets engine
3. สร้าง test secret

---

## Step 12: Verify Installation / ตรวจสอบการติดตั้ง

### 12.1 Check All Pods

```bash
# ดู pods ทั้งหมด
kubectl get pods -A

# Filter เฉพาะที่เรา deploy
kubectl get pods -n jenkins
kubectl get pods -n argocd
kubectl get pods -n vault
kubectl get pods -n dev
```

**ควรเห็น:**

```
NAMESPACE   NAME                                    READY   STATUS
jenkins     jenkins-0                               2/2     Running
argocd      argocd-server-xxx                       1/1     Running
argocd      argocd-application-controller-xxx       1/1     Running
argocd      argocd-repo-server-xxx                  1/1     Running
argocd      argocd-redis-xxx                        1/1     Running
vault       vault-0                                 1/1     Running
vault       vault-agent-injector-xxx                1/1     Running
```

**หมายเหตุ:** ถ้าติดตั้ง Ingress Controller จะเห็น ingress-nginx pods ด้วย

### 12.2 Check All Services

```bash
# ดู services
kubectl get svc -A | grep -E "jenkins|argocd|vault"

# ดู ingress (ถ้าติดตั้ง Ingress Controller)
kubectl get ingress -A
```

### 12.3 Check Storage

```bash
# ดู PVCs
kubectl get pvc -A

# ควรเห็น:
# jenkins   jenkins-pvc      Bound   10Gi
# vault     data-vault-0     Bound   5Gi
# vault     audit-vault-0    Bound   5Gi
```

### 12.4 Test Jenkins

```bash
# Test Jenkins API (เลือกตาม setup)
# Via Ingress:
curl -s http://jenkins.local/api/json | jq '.mode'

# Via Port-forward:
curl -s http://localhost:8080/api/json | jq '.mode'

# ควรได้: "NORMAL"
```

### 12.5 Test Argo CD

```bash
# Install argocd CLI (optional)
brew install argocd

# Login via CLI (เลือกตาม setup)
# Via Ingress:
argocd login argocd.local:443 \
  --username admin \
  --password <your-password> \
  --insecure

# Via Port-forward:
argocd login localhost:8443 \
  --username admin \
  --password <your-password> \
  --insecure

# List apps
argocd app list
```

### 12.6 Test Vault

```bash
# Read test secret
kubectl exec -n vault vault-0 -- \
  vault kv get secret/dev/test

# ควรเห็น password=hello123
```

### 12.7 Test Deployment in Dev

```bash
# Deploy nginx ทดสอบ
kubectl create deployment nginx --image=nginx -n dev

# ตรวจสอบ
kubectl get pods -n dev

# ลบทิ้ง
kubectl delete deployment nginx -n dev
```

---

## Step 13: Next Steps / ขั้นตอนถัดไป

### 13.1 สร้าง Simple Pipeline ใน Jenkins

1. เปิด Jenkins:
   - Via Ingress: <http://jenkins.local>
   - Via Port-forward: <http://localhost:8080>
2. New Item → Pipeline
3. ใส่ script:

```groovy
pipeline {
    agent any
    stages {
        stage('Hello') {
            steps {
                echo 'Hello from Local Jenkins!'
                sh 'kubectl get nodes'
            }
        }
    }
}
```

1. Save → Build Now

### 13.2 Deploy Application ด้วย Argo CD

```bash
# สร้าง test application
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

# ดู application ใน UI
# Via Ingress: https://argocd.local
# Via Port-forward: https://localhost:8443
```

### 13.3 Test Vault Secret Injection

```bash
# สร้าง pod ที่ inject secret จาก Vault
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-vault
  namespace: dev
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "dev"
    vault.hashicorp.com/agent-inject-secret-database: "secret/data/dev/test"
spec:
  serviceAccountName: default
  containers:
  - name: app
    image: nginx
    command: ["sh", "-c", "sleep 3600"]
EOF

# ตรวจสอบ secret ใน pod
kubectl exec -n dev test-vault -- cat /vault/secrets/database
```

---

## 📚 Additional Resources / เอกสารเพิ่มเติม

### Troubleshooting Guides

- [Main README](../README.md)
- [Ingress Setup Guide](ingress-setup-guide.md) - คู่มือการติดตั้ง Ingress แบบละเอียด
- [Quick Command Reference](quick-command-reference.md) - คำสั่งย่อสำหรับ copy-paste

### Component Documentation

- [Jenkins README](../core-components/jenkins/README.md)
- [Argo CD README](../core-components/argocd/README.md)
- [Vault README](../core-components/vault/README.md)
- [Ingress README](../infrastructure/ingress/README.md)

### Security Documentation

- [RBAC README](../security/rbac/README.md)
- [Network Policies README](../security/network-policies/README.md)

---

## 🎓 คำแนะนำ

### การเรียนรู้

1. **ทำทีละ step** - อย่ารีบ อ่านคำอธิบายให้เข้าใจ
2. **ตรวจสอบทุก step** - ใช้ `kubectl get pods` หลังทุก step
3. **ดู logs ถ้ามีปัญหา** - `kubectl logs -f <pod-name>`
4. **เก็บ passwords** - เขียนลงกระดาษหรือ password manager
5. **Backup vault-keys.json** - อย่าลืม!

### การจัดการ

1. **Stop services:**

   ```bash
   # ถ้าใช้ Port-forward: หยุด port-forwards (Ctrl+C ในแต่ละ terminal)
   # ถ้าใช้ Ingress: ไม่ต้องทำอะไร

   # หยุด cluster
   # Docker Desktop: Quit Docker Desktop
   # Minikube: minikube stop
   # Kind: kind delete cluster --name k8s-platform
   ```

2. **Start again:**

   ```bash
   # Docker Desktop: เปิด Docker Desktop
   # Minikube: minikube start
   # Kind: ต้องสร้าง cluster ใหม่

   # Vault ต้อง unseal ใหม่ทุกครั้ง!
   ```

3. **Clean up:**

   ```bash
   # ลบ namespaces
   kubectl delete ns jenkins argocd vault dev ingress-nginx

   # ลบ cluster
   minikube delete
   # หรือ
   kind delete cluster --name k8s-platform

   # ลบ /etc/hosts entries (ถ้าติดตั้ง Ingress)
   sudo nano /etc/hosts
   # ลบบรรทัดที่มี jenkins.local, argocd.local, vault.local
   ```

---

**เรียบร้อย! คุณได้ติดตั้ง Kubernetes Platform แบบ Manual ครบทุก Step แล้ว** 🎉

หากมีปัญหาหรือคำถาม กลับไปดูที่ [Troubleshooting Section](local-development-guide.md#troubleshooting--แก้ปัญหา)
