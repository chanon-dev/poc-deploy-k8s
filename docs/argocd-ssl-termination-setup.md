# Argo CD - SSL Termination at Ingress Setup Guide

คู่มือติดตั้ง Argo CD แบบ SSL Termination at Ingress (Method 2)

## 🎯 ภาพรวม

**วิธีที่ 2: SSL Termination at Ingress** เป็นวิธีที่แนะนำสำหรับ Production

```
User Browser              NGINX Ingress              Argo CD
    |                          |                         |
    |---[HTTPS encrypted]----->|                         |
    |                          | (decrypt ที่นี่)        |
    |                          |                         |
    |                          |---[HTTP plain]--------->|
    |                          |                         |
    |                          |<-----[Response]---------|
    |<---[HTTPS encrypted]-----|                         |
```

### ข้อดี:
- ✅ **ไม่ซ้ำซ้อน** - Encrypt/decrypt เพียง 1 ครั้ง
- ✅ NGINX ดู traffic ได้ (สามารถทำ rate limiting, caching)
- ✅ Browser ไม่แสดง certificate warning (ถ้าใช้ valid cert)
- ✅ ปลอดภัยเพียงพอสำหรับ cluster เดียวกัน

---

## 📋 ขั้นตอนการติดตั้ง

### Step 1: Configure Argo CD Insecure Mode

```bash
# Apply ConfigMap
kubectl apply -f core-components/argocd/argocd-cmd-params-cm.yaml

# Restart Argo CD server
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

**อธิบาย:** ตั้งค่า `server.insecure: "true"` เพื่อให้ Argo CD รับ HTTP traffic จาก NGINX

---

### Step 2: Create TLS Certificate

```bash
# สร้าง self-signed certificate (สำหรับ local/dev)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout argocd-tls.key \
  -out argocd-tls.crt \
  -subj "/CN=argocd.local/O=argocd"

# สร้าง Kubernetes secret จาก certificate
kubectl create secret tls argocd-tls-secret \
  --cert=argocd-tls.crt \
  --key=argocd-tls.key \
  -n argocd

# ลบไฟล์ certificate (เก็บใน secret แล้ว)
rm argocd-tls.key argocd-tls.crt
```

**หมายเหตุ:**
- สำหรับ Production ควรใช้ Let's Encrypt ผ่าน cert-manager
- Self-signed cert จะมี warning บน browser แต่ใช้งานได้ปกติ

---

### Step 3: Deploy Ingress with SSL Termination

```bash
# Apply SSL Termination Ingress
kubectl apply -f core-components/argocd/ingress.yaml
```

**Ingress Configuration:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - argocd.local
    secretName: argocd-tls-secret
  rules:
  - host: argocd.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80  # HTTP port
```

---

### Step 4: Verify Setup

```bash
# 1. ตรวจสอบ Ingress
kubectl get ingress -n argocd
# ต้องเห็น PORTS: 80, 443

# 2. ตรวจสอบ TLS secret
kubectl get secret argocd-tls-secret -n argocd
# ต้องเห็น TYPE: kubernetes.io/tls

# 3. ทดสอบ HTTPS access
curl -k -I https://argocd.local
# ต้องได้ HTTP/2 200

# 4. ทดสอบ HTTP redirect
curl -I http://argocd.local
# ต้องได้ 308 Permanent Redirect → https://argocd.local
```

---

### Step 5: Access Argo CD

```bash
# เปิด browser
open https://argocd.local

# หรือ
https://argocd.local/applications
```

**หมายเหตุ:**
- Browser จะเตือนเรื่อง self-signed certificate
- คลิก "Advanced" → "Proceed to argocd.local (unsafe)"
- หรือติดตั้ง cert-manager สำหรับ Let's Encrypt

---

## 🔍 Troubleshooting

### ❌ 502 Bad Gateway

**สาเหตุ:** Backend protocol ไม่ตรงกับ Argo CD mode

**วิธีแก้:**
```bash
# 1. ตรวจสอบ Argo CD insecure mode
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml | grep insecure

# 2. ตรวจสอบ Ingress backend protocol
kubectl get ingress argocd-server-ingress -n argocd -o yaml | grep backend-protocol

# 3. ต้องตรงกัน:
# - ConfigMap: server.insecure: "true"
# - Ingress: backend-protocol: "HTTP"
```

---

### ❌ Certificate Warning

**สาเหตุ:** ใช้ self-signed certificate

**วิธีแก้:**

**Option 1: ยอมรับ certificate (สำหรับ local dev)**
- คลิก "Advanced" → "Proceed"

**Option 2: ใช้ Let's Encrypt (สำหรับ production)**
```bash
# ติดตั้ง cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# สร้าง ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Update Ingress annotations
kubectl annotate ingress argocd-server-ingress -n argocd \
  cert-manager.io/cluster-issuer=letsencrypt-prod
```

---

## 📊 เปรียบเทียบกับวิธีอื่น

| คุณสมบัติ | SSL Termination | SSL Passthrough | HTTP Only |
|----------|-----------------|-----------------|-----------|
| **Encryption** | 1 ชั้น (NGINX) | 1 ชั้น (Argo CD) | ไม่มี |
| **ซ้ำซ้อน?** | ❌ ไม่ซ้ำซ้อน | ❌ ไม่ซ้ำซ้อน | N/A |
| **Certificate จัดการที่** | NGINX | Argo CD | ไม่ต้องการ |
| **Browser warning** | ❌ (ถ้าใช้ valid cert) | ⚠️ (self-signed) | ⚠️ ไม่ปลอดภัย |
| **NGINX inspect traffic** | ✅ ได้ | ❌ ไม่ได้ | ✅ ได้ |
| **Production ready** | ⭐ แนะนำ | ✅ ใช้ได้ | ❌ ไม่แนะนำ |

---

## 📚 สรุป

**ทำไมเลือก SSL Termination at Ingress?**

1. ✅ **ไม่ซ้ำซ้อน** - Encrypt แค่ 1 ครั้งระหว่าง Browser → NGINX
2. ✅ **จัดการ certificate ง่าย** - ทำที่เดียวที่ NGINX
3. ✅ **ใช้ Let's Encrypt ได้** - Certificate ที่ valid, ไม่มี warning
4. ✅ **NGINX ทำงานเต็มที่** - Inspect, cache, rate limit ได้
5. ✅ **Best practice** - วิธีมาตรฐานสำหรับ production

**เมื่อไหร่ควรใช้วิธีอื่น?**

- **SSL Passthrough**: เมื่อต้องการ end-to-end encryption แบบเข้มงวด
- **HTTP Only**: เฉพาะ local development ที่ไม่ต้องการความปลอดภัย

---

## 🔗 อ้างอิง

- [docs/ssl-termination-explained.md](ssl-termination-explained.md) - อธิบายทั้ง 3 วิธีโดยละเอียด
- [docs/argocd-https-vs-http.md](argocd-https-vs-http.md) - เปรียบเทียบ HTTPS vs HTTP
- [docs/ingress-setup-guide.md](ingress-setup-guide.md) - คู่มือติดตั้ง Ingress ทั้งหมด
- [core-components/argocd/ingress.yaml](../core-components/argocd/ingress.yaml) - Ingress configuration file
