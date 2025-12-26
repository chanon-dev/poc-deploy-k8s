# SSL/TLS Termination แบบต่างๆ กับ NGINX Ingress

เอกสารอธิบายวิธีจัดการ SSL/TLS เมื่อใช้ NGINX Ingress กับ Argo CD

---

## 📊 ภาพรวม: 3 วิธีจัดการ SSL

```
1. SSL Passthrough (ไม่ซ้ำซ้อน - NGINX แค่ส่งผ่าน)
   Client → [HTTPS] → NGINX → [HTTPS] → Argo CD
                      (ไม่ decrypt)    (decrypt ที่นี่)

2. SSL Termination at Ingress (ไม่ซ้ำซ้อน - decrypt ที่ NGINX)
   Client → [HTTPS] → NGINX → [HTTP] → Argo CD
                      (decrypt ที่นี่)  (รับ HTTP)

3. End-to-End Encryption (ซ้ำซ้อน - decrypt 2 รอบ)
   Client → [HTTPS] → NGINX → [HTTPS] → Argo CD
                      (decrypt)  (re-encrypt) (decrypt อีกรอบ)
```

---

## 🔹 วิธีที่ 1: SSL Passthrough (แนะนำ ✅)

### ทำงานอย่างไร?

```
User Browser                 NGINX Ingress              Argo CD
    |                             |                         |
    |---[HTTPS encrypted]-------->|                         |
    |                             |                         |
    |                             |--[HTTPS encrypted]----->|
    |                             |   (ส่งต่อ ไม่แตะ)       |
    |                             |                         |
    |                             |                         | (decrypt ที่นี่)
    |                             |<-----[Response]---------|
    |<---[HTTPS encrypted]--------|                         |
```

### คุณสมบัติ:
- ✅ **ไม่ซ้ำซ้อน** - NGINX ไม่ decrypt, แค่ forward encrypted traffic ผ่านไป
- ✅ End-to-end encryption (ข้อมูลเข้ารหัสตลอดทาง)
- ✅ Argo CD จัดการ SSL certificate เอง (ใช้ self-signed ที่มาใน Argo CD)
- ⚠️ NGINX ไม่เห็นข้อมูล (ทำ HTTP routing/rewrite ไม่ได้)

### Configuration:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
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
              name: https  # port 443
```

### เมื่อใช้วิธีนี้:
- Argo CD ต้องรันแบบ **ปกติ** (ไม่ต้อง insecure mode)
- ลบ `argocd-cmd-params-cm.yaml` หรือตั้งเป็น `server.insecure: "false"`

---

## 🔹 วิธีที่ 2: SSL Termination at Ingress (แนะนำสำหรับ Production ⭐)

### ทำงานอย่างไร?

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

### คุณสมบัติ:
- ✅ **ไม่ซ้ำซ้อน** - NGINX decrypt แล้วส่ง HTTP ไปหา Argo CD
- ✅ NGINX สามารถ inspect/modify traffic ได้
- ✅ ใช้ valid certificate (Let's Encrypt) ได้
- ✅ Browser ไม่เตือน (ถ้าใช้ cert ที่ valid)
- ⚠️ Traffic ระหว่าง NGINX → Argo CD เป็น HTTP (ปลอดภัยถ้าอยู่ใน cluster เดียวกัน)

### Configuration:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - argocd.local
    secretName: argocd-tls-secret  # Certificate ที่คุณจัดหามา
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

### เมื่อใช้วิธีนี้:
- Argo CD ต้องรันแบบ **insecure mode**
- Apply `argocd-cmd-params-cm.yaml` (`server.insecure: "true"`)
- ต้องมี TLS certificate (self-signed หรือ Let's Encrypt)

---

## 🔹 วิธีที่ 3: End-to-End Encryption (ซ้ำซ้อน ⚠️ ไม่แนะนำ)

### ทำงานอย่างไร?

```
User Browser              NGINX Ingress              Argo CD
    |                          |                         |
    |---[HTTPS encrypted]----->|                         |
    |                          | (decrypt)               |
    |                          |                         |
    |                          |---[HTTPS encrypted]---->|
    |                          |   (re-encrypt!)         | (decrypt อีกรอบ)
    |                          |                         |
    |                          |<-----[Response]---------|
    |<---[HTTPS encrypted]-----|                         |
```

### คุณสมบัติ:
- ⚠️ **ซ้ำซ้อน!** - Encrypt → Decrypt → Re-encrypt → Decrypt (4 ครั้ง!)
- ⚠️ ใช้ CPU เยอะ
- ⚠️ Latency สูงขึ้น
- ❌ ไม่มีข้อดีเพิ่มเติม (ถ้าอยู่ใน cluster เดียวกัน)
- ❓ ใช้เฉพาะเมื่อ NGINX และ Argo CD อยู่คนละ network ที่ไม่ปลอดภัย

### Configuration:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"  # HTTPS backend
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - argocd.local
    secretName: argocd-tls-secret  # NGINX cert
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
              name: https  # HTTPS port (Argo CD cert)
```

### เมื่อใช้วิธีนี้:
- Argo CD รันแบบ **ปกติ** (ไม่ insecure)
- ต้องมี certificate 2 ชุด (NGINX และ Argo CD)
- **ไม่แนะนำ** สำหรับ local development

---

## 📊 ตารางเปรียบเทียบ

| คุณสมบัติ | SSL Passthrough | SSL Termination | End-to-End |
|----------|-----------------|-----------------|------------|
| **NGINX decrypt?** | ❌ ไม่ decrypt | ✅ Decrypt | ✅ Decrypt |
| **Backend protocol** | HTTPS | HTTP | HTTPS |
| **Argo CD mode** | Secure | Insecure | Secure |
| **จำนวน encryption** | 1 ชั้น | 1 ชั้น | 2 ชั้น |
| **ซ้ำซ้อน?** | ❌ ไม่ซ้ำซ้อน | ❌ ไม่ซ้ำซ้อน | ⚠️ ซ้ำซ้อน |
| **Certificate ที่ต้องมี** | Argo CD (มาให้แล้ว) | NGINX | NGINX + Argo CD |
| **NGINX ดู traffic ได้?** | ❌ ไม่ได้ | ✅ ได้ | ❌ ไม่ได้ |
| **Performance** | ดี | ดีมาก | แย่ |
| **ความซับซ้อน** | ง่าย | ปานกลาง | ซับซ้อน |

---

## 🎯 คำแนะนำ

### สำหรับ Local Development:
**แนะนำ: SSL Passthrough (วิธีที่ 1)**
```bash
# ลบ insecure mode
kubectl delete configmap argocd-cmd-params-cm -n argocd
kubectl rollout restart deployment argocd-server -n argocd

# Apply Ingress
kubectl apply -f core-components/argocd/ingress-https.yaml
```
**ทำไม?**
- ง่ายที่สุด
- ใช้ self-signed cert ของ Argo CD เลย
- ไม่ต้องจัดการ certificate

### สำหรับ Production:
**แนะนำ: SSL Termination (วิธีที่ 2) + Let's Encrypt**
```bash
# ติดตั้ง cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# สร้าง ClusterIssuer สำหรับ Let's Encrypt
# Apply Ingress with cert-manager annotation
```
**ทำไม?**
- Browser ไม่เตือน
- Valid certificate
- NGINX สามารถทำ rate limiting, caching ได้

### ⚠️ ไม่แนะนำ:
**End-to-End Encryption (วิธีที่ 3)**
- ซ้ำซ้อน ใช้ CPU เปล่าๆ
- ไม่มีประโยชน์เพิ่มใน single cluster

---

## 🔍 ตรวจสอบว่าใช้วิธีไหนอยู่

```bash
# ดู Ingress annotations
kubectl get ingress argocd-server-ingress -n argocd -o yaml | grep annotations -A 5

# ถ้าเห็น:
# ssl-passthrough: "true"              → วิธีที่ 1 (SSL Passthrough)
# backend-protocol: "HTTP"             → วิธีที่ 2 (SSL Termination)
# backend-protocol: "HTTPS" + tls:    → วิธีที่ 3 (End-to-End)

# ดู Argo CD mode
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml | grep insecure

# ถ้าเห็น:
# server.insecure: "true"              → Argo CD ใช้ HTTP
# (ไม่มี หรือ "false")                 → Argo CD ใช้ HTTPS
```

---

## 💡 สรุปคำตอบ

**คำถาม:** SSL มันจะไม่ซ้ำซ้อนกันไหมระหว่าง NGINX กับ Argo CD?

**คำตอบ:**
- **SSL Passthrough (วิธีที่ 1):** ❌ **ไม่ซ้ำซ้อน** - NGINX แค่ส่งผ่าน ไม่แตะ
- **SSL Termination (วิธีที่ 2):** ❌ **ไม่ซ้ำซ้อน** - NGINX decrypt แล้วส่ง HTTP
- **End-to-End (วิธีที่ 3):** ⚠️ **ซ้ำซ้อน** - Decrypt 2 รอบ (ไม่แนะนำ)

**เลือกวิธีที่ 1 หรือ 2 จะไม่ซ้ำซ้อนครับ!** ✅
