# Ingress Setup Guide for Local Development
# คู่มือการติดตั้ง Ingress สำหรับ Local Development

## Overview / ภาพรวม

คู่มือนี้จะอธิบายวิธีการติดตั้งและใช้งาน **NGINX Ingress Controller** สำหรับ Local Kubernetes บน Docker Desktop

### ทำไมต้องใช้ Ingress?

**ข้อดี:**
- ✅ เข้าถึงผ่าน hostname ที่จดจำง่าย (jenkins.local, argocd.local)
- ✅ ไม่ต้องเปิด terminal สำหรับ port-forward
- ✅ เหมือนกับ Production environment
- ✅ รองรับ SSL/TLS
- ✅ Path-based และ Host-based routing

**ข้อเสีย:**
- ❌ Setup ซับซ้อนกว่า port-forward
- ❌ ต้องแก้ไข /etc/hosts file
- ❌ ใช้ resources มากขึ้น

---

## Prerequisites / สิ่งที่ต้องมีก่อน

- Kubernetes cluster (Docker Desktop, Minikube, Kind)
- kubectl installed
- Helm installed (for some services)
- Admin access to edit /etc/hosts

---

## Installation Steps / ขั้นตอนการติดตั้ง

### Step 1: Install NGINX Ingress Controller

#### วิธีที่ 1: ใช้ Script (แนะนำ) ⭐

```bash
bash scripts/setup-ingress.sh
```

#### วิธีที่ 2: Manual Installation

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
```

**ตรวจสอบการติดตั้ง:**

```bash
# ดู pods
kubectl get pods -n ingress-nginx

# ควรเห็น:
# NAME                                       READY   STATUS
# ingress-nginx-controller-xxx               1/1     Running

# ดู service
kubectl get svc -n ingress-nginx

# ควรเห็น:
# NAME                           TYPE           EXTERNAL-IP   PORT(S)
# ingress-nginx-controller       LoadBalancer   localhost     80:xxxxx/TCP,443:xxxxx/TCP
```

---

### Step 2: Update /etc/hosts

เพิ่ม hostnames สำหรับ services:

```bash
# วิธีที่ 1: เพิ่มทีละบรรทัด
sudo sh -c 'echo "127.0.0.1 jenkins.local" >> /etc/hosts'
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'
sudo sh -c 'echo "127.0.0.1 argocd-http.local" >> /etc/hosts'
sudo sh -c 'echo "127.0.0.1 vault.local" >> /etc/hosts'

# วิธีที่ 2: เพิ่มพร้อมกัน
sudo sh -c 'echo "127.0.0.1 jenkins.local argocd.local argocd-http.local vault.local" >> /etc/hosts'

# วิธีที่ 3: แก้ไขด้วย editor
sudo nano /etc/hosts
```

เพิ่มบรรทัดนี้:
```
127.0.0.1 jenkins.local argocd.local argocd-http.local vault.local
```

**ตรวจสอบ:**

```bash
# Test DNS resolution
ping jenkins.local
ping argocd.local
ping vault.local

# ควรได้ response จาก 127.0.0.1
```

---

### Step 3: Deploy Services with Ingress

#### 3.1 Jenkins

```bash
# Install Jenkins with Ingress enabled
helm install jenkins jenkins/jenkins \
  -f core-components/jenkins/values-local.yaml \
  -n jenkins \
  --wait

# Ingress จะถูกสร้างโดย Helm อัตโนมัติ
# ตรวจสอบ:
kubectl get ingress -n jenkins
```

#### 3.2 Argo CD

```bash
# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Configure insecure mode (required for Ingress)
kubectl apply -f core-components/argocd/argocd-cmd-params-cm.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Restart to apply configuration
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd

# Apply Ingress
kubectl apply -f core-components/argocd/ingress.yaml

# ตรวจสอบ:
kubectl get ingress -n argocd
```

**หมายเหตุ สำหรับ Argo CD:**

Argo CD ต้อง disable TLS เพื่อทำงานกับ Ingress โดยเราตั้งค่าผ่าน ConfigMap (`argocd-cmd-params-cm.yaml`) ซึ่งเป็นวิธีที่ดีกว่าการ patch

<details>
<summary>วิธีทางเลือก: Patch แบบเดิม (ถ้าติดตั้งไปแล้ว)</summary>

```bash
# สำหรับกรณีที่ติดตั้ง Argo CD ไปแล้ว และต้องการ patch ทีหลัง
kubectl patch deployment argocd-server -n argocd \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'
```
</details>

#### 3.3 Vault

```bash
# Install Vault with Ingress enabled
helm install vault hashicorp/vault \
  -f core-components/vault/values-local.yaml \
  -n vault \
  --wait

# Ingress จะถูกสร้างโดย Helm อัตโนมัติ
# ตรวจสอบ:
kubectl get ingress -n vault
```

---

### Step 4: Access Services

เปิด browser และเข้าถึง services:

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| **Jenkins** | http://jenkins.local | admin | `kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" \| base64 --decode` |
| **Argo CD** | https://argocd.local | admin | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |
| **Argo CD (HTTP)** | http://argocd-http.local | admin | (same as above) |
| **Vault** | http://vault.local | (root token) | (from init) |

---

## Verification / ตรวจสอบ

### Check All Ingress Resources

```bash
# ดู ingress ทั้งหมด
kubectl get ingress -A

# ควรเห็น:
# NAMESPACE   NAME                        HOSTS                 PORTS
# jenkins     jenkins-ingress             jenkins.local         80
# argocd      argocd-server-ingress       argocd.local          80, 443
# argocd      argocd-server-http-ingress  argocd-http.local     80
# vault       vault-ingress               vault.local           80
```

### Test Access

```bash
# Test Jenkins
curl -I http://jenkins.local
# ควรได้ HTTP 200 หรือ 403 (redirect to login)

# Test Vault
curl -I http://vault.local
# ควรได้ HTTP 200

# Test Argo CD
curl -Ik https://argocd.local
# ควรได้ HTTP 200
```

### View Ingress Controller Logs

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

---

## Troubleshooting / แก้ปัญหา

### 1. Cannot access services via hostname

**ปัญหา:** เข้า http://jenkins.local ไม่ได้

**แก้ไข:**

```bash
# 1. ตรวจสอบ /etc/hosts
cat /etc/hosts | grep jenkins.local

# 2. ตรวจสอบ Ingress Controller
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# 3. ตรวจสอบ Ingress resource
kubectl get ingress -n jenkins
kubectl describe ingress jenkins-ingress -n jenkins

# 4. Test DNS
ping jenkins.local
# ควรได้ 127.0.0.1

# 5. Test port 80
curl -I http://localhost
# ควรได้ response จาก Ingress Controller
```

### 2. Argo CD shows blank page or 404

**ปัญหา:** Argo CD ไม่แสดงหน้า UI

**แก้ไข:**

```bash
# Argo CD ต้องรัน insecure mode
kubectl patch deployment argocd-server -n argocd \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'

# รอให้ pod restart
kubectl rollout status deployment argocd-server -n argocd

# หรือใช้ HTTP endpoint
open http://argocd-http.local
```

### 3. SSL/TLS errors

**ปัญหา:** Browser แสดง SSL warning

**แก้ไข:**

```bash
# สำหรับ local development ให้ click "Advanced" → "Proceed to site"

# หรือใช้ HTTP endpoint แทน:
# - Argo CD: http://argocd-http.local
# - Jenkins: http://jenkins.local (ใช้ HTTP อยู่แล้ว)
# - Vault: http://vault.local (ใช้ HTTP อยู่แล้ว)
```

### 4. Ingress Controller not getting LoadBalancer IP

**ปัญหา:** Service อยู่ใน Pending state

**แก้ไข:**

```bash
# Docker Desktop ควรจะ assign localhost อัตโนมัติ
# ถ้ายัง Pending ลองรอสัก 1-2 นาที

# หรือใช้ NodePort แทน (fallback)
kubectl patch svc ingress-nginx-controller -n ingress-nginx \
  -p '{"spec":{"type":"NodePort"}}'

# ดู NodePort
kubectl get svc -n ingress-nginx ingress-nginx-controller

# แก้ /etc/hosts เป็น:
# 127.0.0.1 jenkins.local  # ต้องใช้ localhost:<NodePort> แทน
```

### 5. Port 80 or 443 already in use

**ปัญหา:** Port 80/443 ถูกใช้งานโดย process อื่น

**แก้ไข:**

```bash
# หา process ที่ใช้ port 80
sudo lsof -i :80

# ปิด process หรือเปลี่ยน port ของ Ingress Controller
kubectl edit svc ingress-nginx-controller -n ingress-nginx

# เปลี่ยน port 80 → 8080 และ 443 → 8443
# แล้วเข้าผ่าน http://jenkins.local:8080
```

---

## Cleanup / ลบการติดตั้ง

### Uninstall Ingress Controller

```bash
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

### Remove Ingress Resources

```bash
kubectl delete ingress jenkins-ingress -n jenkins
kubectl delete ingress argocd-server-ingress argocd-server-http-ingress -n argocd
kubectl delete ingress vault-ingress -n vault
```

### Clean up /etc/hosts

```bash
sudo nano /etc/hosts
# ลบบรรทัดที่มี jenkins.local, argocd.local, vault.local
```

---

## Alternative: Use Port-Forward Instead

ถ้าไม่ต้องการใช้ Ingress สามารถใช้ Port-Forward แทน:

```bash
# Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080 &

# Argo CD
kubectl port-forward -n argocd svc/argocd-server 8443:443 &

# Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

# Access:
# Jenkins:  http://localhost:8080
# Argo CD:  https://localhost:8443
# Vault:    http://localhost:8200
```

---

## Summary / สรุป

### Ingress vs Port-Forward

| Feature | Ingress | Port-Forward |
|---------|---------|--------------|
| **Setup** | ซับซ้อน | ง่าย |
| **Hostname** | ✅ jenkins.local | ❌ localhost:8080 |
| **Terminal** | ไม่ต้องเปิดไว้ | ต้องเปิดไว้ |
| **Production-like** | ✅ เหมือน | ❌ ต่างกัน |
| **Resources** | ใช้มากกว่า | ใช้น้อยกว่า |
| **แนะนำสำหรับ** | Learning, Demo | Daily Development |

### คำแนะนำ

- **Daily Development:** ใช้ Port-Forward (ง่าย รวดเร็ว)
- **Learning Production Setup:** ใช้ Ingress (เรียนรู้ real-world)
- **Demo/Presentation:** ใช้ Ingress (ดูเป็นมืออาชีพ)

---

**🎉 ติดตั้ง Ingress สำเร็จแล้ว!**

หากมีปัญหา ดูที่ [Troubleshooting Section](#troubleshooting--แก้ปัญหา) หรือกลับไปใช้ Port-Forward แทน
