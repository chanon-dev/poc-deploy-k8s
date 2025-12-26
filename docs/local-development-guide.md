# Local Development Guide / คู่มือการใช้งานบน Local

## สิ่งที่แตกต่างจาก Production / Differences from Production

เมื่อรันบนเครื่อง local จะมีการปรับแต่งเหล่านี้:

### 1. Resource Requirements / ความต้องการทรัพยากร
- **Production:** HA mode (3 replicas), high resources
- **Local:** Single instance, reduced resources
- **เครื่อง Local ต้องมี:** อย่างน้อย 8GB RAM, 4 CPU cores

### 2. Storage / การจัดเก็บข้อมูล
- **Production:** Distributed storage (NFS/Ceph)
- **Local:** Local path provisioner หรือ hostPath
- **แนะนำ:** ใช้ local-path-provisioner

### 3. High Availability
- **Production:** 3 masters, multiple workers
- **Local:** Single node cluster
- **Replicas:** ลดเหลือ 1 ทั้งหมด

### 4. Networking / เครือข่าย
- **Production:** Load balancer, real DNS
- **Local:** Port-forward, /etc/hosts
- **Ingress:** Optional หรือใช้ NodePort

### 5. TLS/SSL
- **Production:** Real certificates
- **Local:** Self-signed หรือปิด TLS
- **แนะนำ:** ปิด TLS ไปก่อนเพื่อความง่าย

---

## Local Kubernetes Options / ตัวเลือก Kubernetes บน Local

เลือกอย่างใดอย่างหนึ่ง:

### Option 1: Minikube (แนะนำสำหรับผู้เริ่มต้น)
```bash
# Install Minikube
brew install minikube  # macOS
# หรือ https://minikube.sigs.k8s.io/docs/start/

# Start with more resources
minikube start --cpus=4 --memory=8192 --disk-size=50g

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server
```

### Option 2: Docker Desktop (macOS/Windows)
```bash
# Enable Kubernetes in Docker Desktop settings
# Preferences → Kubernetes → Enable Kubernetes

# ตั้งค่า resources:
# - Memory: 8GB
# - CPUs: 4
# - Disk: 50GB
```

### Option 3: Kind (Kubernetes in Docker)
```bash
# Install Kind
brew install kind

# Create cluster
kind create cluster --config=infrastructure/cluster/kind-config.yaml
```

### Option 4: K3s (Lightweight)
```bash
# Install K3s
curl -sfL https://get.k3s.io | sh -

# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config
```

---

## Quick Setup for Local / ติดตั้งแบบเร็วสำหรับ Local

### Step 1: Start Kubernetes
```bash
# ใช้ Minikube (แนะนำ)
minikube start --cpus=4 --memory=8192

# ตรวจสอบ
kubectl get nodes
kubectl cluster-info
```

### Step 2: Install Storage Provisioner
```bash
# ถ้าใช้ Minikube - มี default storage อยู่แล้ว
kubectl get storageclass

# ถ้าไม่มี - ติดตั้ง local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Set as default
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Step 3: Deploy with Local Configuration
```bash
# ใช้ script พิเศษสำหรับ local
./scripts/deploy-local.sh

# หรือทีละขั้นตอน
./scripts/local/01-setup-local-namespaces.sh
./scripts/local/02-deploy-local-core.sh
```

### Step 4: Access Services
```bash
# Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# เปิด: http://localhost:8080

# Argo CD
kubectl port-forward -n argocd svc/argocd-server 8443:443
# เปิด: https://localhost:8443

# Vault
kubectl port-forward -n vault svc/vault 8200:8200
# เปิด: http://localhost:8200

# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# เปิด: http://localhost:3000
```

---

## Resource Quotas สำหรับ Local

ลดค่าให้เหมาะกับเครื่อง local:

```yaml
# ตัวอย่างสำหรับ dev namespace (local)
resources:
  requests:
    cpu: "2"        # ลดจาก 20
    memory: 4Gi     # ลดจาก 40Gi
  limits:
    cpu: "4"        # ลดจาก 40
    memory: 8Gi     # ลดจาก 80Gi
```

---

## Components - Local Configuration

### Jenkins (Local)
```yaml
# ใช้ values-local.yaml แทน values.yaml
controller:
  resources:
    requests:
      cpu: "500m"     # ลดจาก 1000m
      memory: "1Gi"   # ลดจาก 2Gi
    limits:
      cpu: "1"        # ลดจาก 2
      memory: "2Gi"   # ลดจาก 4Gi

  # ไม่ต้องการ HA
  # replicaCount: 1

  # Disable ingress, ใช้ port-forward
  ingress:
    enabled: false
```

### Argo CD (Local)
```yaml
# ปิด HA mode
server:
  replicas: 1       # ลดจาก 2

controller:
  replicas: 1       # default คือ 1

repoServer:
  replicas: 1       # ลดจาก 2

# ลด resources
server:
  resources:
    requests:
      cpu: 100m     # ลดจาก 250m
      memory: 256Mi # ลดจาก 512Mi
```

### Vault (Local)
```yaml
# ใช้ standalone mode แทน HA
server:
  ha:
    enabled: false

  standalone:
    enabled: true
    config: |
      ui = true
      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
      }
      storage "file" {
        path = "/vault/data"
      }

  # ลด resources
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 512Mi
      cpu: 500m
```

---

## Network Policies (Local)

สำหรับ local อาจ**ปิด Network Policies** ไปก่อนเพื่อความสะดวก:

```bash
# ข้าม network policies ในการ deploy local
# หรือลบไฟล์ default-deny-all.yaml ออกชั่วคราว

# ถ้าต้องการทดสอบ network policies
# ให้แน่ใจว่า CNI plugin รองรับ (Calico, Cilium)
```

---

## Monitoring (Optional for Local)

Prometheus & Grafana กิน resources เยอะ - ถ้าเครื่องไม่แรงพอ สามารถข้ามได้:

```bash
# ข้าม monitoring stack
# หรือติดตั้งแบบ minimal

helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
  --set grafana.resources.requests.memory=256Mi
```

---

## Tips for Local Development

### 1. ลด Resource Usage
```bash
# ดู resource usage
kubectl top nodes
kubectl top pods -A

# ถ้า resource ไม่พอ - ปิด component ที่ไม่จำเป็น
kubectl scale deployment -n monitoring --replicas=0 --all
```

### 2. ใช้ Docker Hub แทน Harbor
```bash
# แทนที่จะติดตั้ง Harbor (กิน resources เยอะ)
# ใช้ Docker Hub หรือ Docker Desktop local registry

# Push to Docker Hub
docker tag myapp:latest username/myapp:latest
docker push username/myapp:latest
```

### 3. ใช้ NodePort แทน Ingress
```yaml
# แก้ service type เป็น NodePort
kind: Service
spec:
  type: NodePort
  ports:
  - port: 8080
    nodePort: 30080  # เข้าถึงผ่าน minikube-ip:30080
```

### 4. ดู Logs ง่ายๆ
```bash
# ดู logs แบบง่าย
kubectl logs -f -n jenkins deployment/jenkins

# หรือใช้ stern (ถ้าติดตั้งแล้ว)
stern -n jenkins jenkins
```

### 5. Clean Up
```bash
# ลบ namespace ที่ไม่ใช้
kubectl delete ns sit uat prod

# เก็บแค่ dev
kubectl get ns
```

---

## Common Issues on Local / ปัญหาที่พบบ่อยบน Local

### Issue 1: Out of Memory
```bash
# ดู memory usage
kubectl top nodes

# Solution: ปิด component ที่ไม่จำเป็น
kubectl delete ns monitoring  # ถ้าไม่ต้องการ monitoring

# หรือเพิ่ม memory ให้ minikube
minikube stop
minikube start --memory=12288
```

### Issue 2: Disk Space Full
```bash
# ลบ unused images
docker system prune -a

# ดู disk usage ใน minikube
minikube ssh
df -h
```

### Issue 3: Pods Pending (No Storage)
```bash
# ตรวจสอบ storage class
kubectl get sc

# ติดตั้ง local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### Issue 4: Can't Access Services
```bash
# ใช้ port-forward แทน ingress
kubectl port-forward -n <namespace> svc/<service> <local-port>:<service-port>

# ถ้าใช้ minikube
minikube service <service-name> -n <namespace>
```

### Issue 5: DNS Not Working in Pods
```bash
# ตรวจสอบ CoreDNS
kubectl get pods -n kube-system | grep coredns

# Restart CoreDNS
kubectl rollout restart deployment -n kube-system coredns
```

---

## Recommended Local Setup / การติดตั้งที่แนะนำสำหรับ Local

### Minimal Setup (4GB RAM พอใช้งาน)
```bash
# ติดตั้งเฉพาะ:
✅ Namespaces (dev only)
✅ RBAC (basic)
❌ Network Policies (skip)
✅ Jenkins (1 replica, low resources)
✅ Argo CD (1 replica, low resources)
❌ Vault (ใช้ ConfigMap/Secret ธรรมดาแทน)
❌ Harbor (ใช้ Docker Hub)
❌ Monitoring (skip)
```

### Standard Setup (8GB RAM แนะนำ)
```bash
# ติดตั้ง:
✅ Namespaces (dev, sit)
✅ RBAC
✅ Network Policies (basic)
✅ Jenkins
✅ Argo CD
✅ Vault (standalone mode)
❌ Harbor (ใช้ Docker Hub)
❌ Monitoring (skip)
```

### Full Setup (16GB RAM ขึ้นไป)
```bash
# ติดตั้งครบ:
✅ Namespaces (all)
✅ RBAC
✅ Network Policies
✅ Jenkins
✅ Argo CD
✅ Vault
✅ Harbor (optional)
✅ Monitoring (minimal)
```

---

## Next Steps / ขั้นตอนถัดไป

1. เลือก Local K8s platform (แนะนำ Minikube)
2. รัน `./scripts/deploy-local.sh`
3. ทดสอบ deploy application ง่ายๆ
4. ทดสอบ CI/CD pipeline
5. เรียนรู้การใช้งานแต่ละ component

---

## Cleanup / การลบทิ้ง

```bash
# ลบทุกอย่าง
kubectl delete ns jenkins argocd vault dev sit uat prod monitoring

# หรือลบ cluster ทั้งหมด
minikube delete

# สำหรับ Docker Desktop
# Reset Kubernetes cluster ใน Settings
```

---

**สำคัญ:** Local environment ใช้สำหรับเรียนรู้และทดสอบเท่านั้น ไม่ใช่สำหรับ production!
