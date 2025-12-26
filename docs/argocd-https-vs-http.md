# Argo CD: HTTPS vs HTTP Configuration

คู่มือเปรียบเทียบการติดตั้ง Argo CD แบบ HTTPS (Secure) และ HTTP (Insecure)

## 📊 เปรียบเทียบทั้งสองวิธี

| หัวข้อ | HTTP (Insecure Mode) | HTTPS (Secure Mode) |
| ----- | -------------------- | ------------------- |
| **ความปลอดภัย** | ⚠️ ไม่มีการเข้ารหัส | ✅ มีการเข้ารหัส SSL/TLS |
| **การติดตั้ง** | ✅ ง่ายกว่า | ⚠️ ซับซ้อนกว่าเล็กน้อย |
| **เหมาะสำหรับ** | Local Development | Production / Staging |
| **Browser Warning** | ⚠️ ไม่มี HTTPS | ✅ ปลอดภัย (ถ้ามี cert ที่ถูกต้อง) |
| **Performance** | เร็วกว่าเล็กน้อย | ใช้ CPU เพิ่มสำหรับ encryption |

---

## 🔒 วิธีที่ 1: HTTPS Mode (Secure) - แนะนำสำหรับ Production

### ข้อดี:
- ✅ ข้อมูลถูกเข้ารหัส (username, password ปลอดภัย)
- ✅ ป้องกัน Man-in-the-Middle attacks
- ✅ เป็น best practice สำหรับ production
- ✅ Browser ไม่แสดง security warning (ถ้ามี valid certificate)

### ข้อเสีย:
- ⚠️ ต้องจัดการ TLS certificates
- ⚠️ Setup ซับซ้อนกว่าเล็กน้อย
- ⚠️ Browser จะเตือนถ้าใช้ self-signed certificate

### ขั้นตอนการติดตั้ง:

#### Step 1: ลบ ConfigMap ที่ตั้งค่า insecure mode (ถ้ามี)

```bash
# ลบ ConfigMap หรือแก้ไขเป็น false
kubectl delete configmap argocd-cmd-params-cm -n argocd

# หรือ
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  -p '{"data":{"server.insecure":"false"}}'
```

#### Step 2: Restart Argo CD server

```bash
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

#### Step 3: ลบ Ingress แบบ HTTP (ถ้ามี)

```bash
kubectl delete ingress argocd-server-ingress -n argocd
kubectl delete ingress argocd-server-http-ingress -n argocd
```

#### Step 4: Apply Ingress แบบ HTTPS

**แบบที่ 1: SSL Passthrough (ง่ายที่สุด, ไม่ต้องมี certificate)**

```bash
kubectl apply -f core-components/argocd/ingress-https.yaml
```

Ingress จะ forward HTTPS traffic ตรงไปยัง Argo CD ที่มี self-signed certificate อยู่แล้ว

**แบบที่ 2: Terminate SSL at Ingress (ต้องมี certificate)**

```bash
# สร้าง TLS certificate (ตัวอย่างใช้ self-signed)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout argocd-tls.key -out argocd-tls.crt \
  -subj "/CN=argocd.local/O=argocd"

# สร้าง secret จาก certificate
kubectl create secret tls argocd-tls-secret \
  --cert=argocd-tls.crt \
  --key=argocd-tls.key \
  -n argocd

# Apply Ingress with TLS
kubectl apply -f core-components/argocd/ingress-https.yaml
```

#### Step 5: เข้าใช้งาน

```bash
# เข้าผ่าน HTTPS
https://argocd.local

# หมายเหตุ: Browser จะเตือนเรื่อง self-signed certificate
# คลิก "Advanced" → "Proceed to argocd.local (unsafe)"
```

---

## 🌐 วิธีที่ 2: HTTP Mode (Insecure) - สำหรับ Local Development

### ข้อดี:
- ✅ ติดตั้งง่าย ไม่ต้องจัดการ certificates
- ✅ ไม่มี SSL warnings จาก browser
- ✅ เหมาะสำหรับ local testing

### ข้อเสีย:
- ⚠️ ข้อมูลไม่ได้เข้ารหัส (password ส่งแบบ plain text)
- ⚠️ ไม่ควรใช้บน production
- ⚠️ ไม่เป็น best practice

### ขั้นตอนการติดตั้ง:

#### Step 1: Apply ConfigMap สำหรับ insecure mode

```bash
kubectl apply -f core-components/argocd/argocd-cmd-params-cm.yaml
```

#### Step 2: Restart Argo CD server

```bash
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

#### Step 3: Apply Ingress แบบ HTTP

```bash
kubectl apply -f core-components/argocd/ingress.yaml
```

#### Step 4: เข้าใช้งาน

```bash
# เข้าผ่าน HTTP
http://argocd.local
# หรือ
http://argocd-http.local
```

---

## 🔄 สลับระหว่าง HTTPS และ HTTP

### จาก HTTP → HTTPS

```bash
# 1. ลบ insecure mode
kubectl delete configmap argocd-cmd-params-cm -n argocd

# 2. Restart
kubectl rollout restart deployment argocd-server -n argocd

# 3. ลบ Ingress เก่า
kubectl delete ingress argocd-server-ingress argocd-server-http-ingress -n argocd

# 4. Apply Ingress HTTPS
kubectl apply -f core-components/argocd/ingress-https.yaml

# 5. เข้าผ่าน HTTPS
open https://argocd.local
```

### จาก HTTPS → HTTP

```bash
# 1. Apply insecure mode
kubectl apply -f core-components/argocd/argocd-cmd-params-cm.yaml

# 2. Restart
kubectl rollout restart deployment argocd-server -n argocd

# 3. ลบ Ingress เก่า
kubectl delete ingress argocd-server-ingress-https argocd-server-ingress-tls -n argocd

# 4. Apply Ingress HTTP
kubectl apply -f core-components/argocd/ingress.yaml

# 5. เข้าผ่าน HTTP
open http://argocd.local
```

---

## 🎯 คำแนะนำ

### สำหรับ Local Development:
**ใช้ HTTP Mode** (วิธีที่ 2)
- ง่าย รวดเร็ว ไม่ต้องจัดการ certificates
- ไฟล์ที่ใช้: `ingress.yaml` + `argocd-cmd-params-cm.yaml`

### สำหรับ Production:
**ใช้ HTTPS Mode** (วิธีที่ 1)
- ปลอดภัย มี SSL/TLS encryption
- ไฟล์ที่ใช้: `ingress-https.yaml`
- ควรใช้ certificate จาก Certificate Authority (เช่น Let's Encrypt)

### สำหรับ Staging/UAT:
**ใช้ HTTPS Mode** (วิธีที่ 1)
- ใกล้เคียง production
- ใช้ self-signed certificate ก็ได้

---

## 🔍 Troubleshooting

### Browser แสดง "Your connection is not private"

**สาเหตุ:** ใช้ self-signed certificate

**วิธีแก้:**
1. คลิก "Advanced" → "Proceed to argocd.local"
2. หรือติดตั้ง certificate จาก Let's Encrypt (cert-manager)

### 502 Bad Gateway

**สาเหตุ:** Ingress backend protocol ไม่ตรงกับ Argo CD mode

**วิธีแก้:**
- ตรวจสอบว่า Ingress ใช้ `backend-protocol: HTTP` หรือ `HTTPS` ให้ตรงกับ Argo CD
- ดู logs: `kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller`

---

## 📚 อ้างอิง

- [Argo CD Ingress Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/)
- [NGINX Ingress SSL Passthrough](https://kubernetes.github.io/ingress-nginx/user-guide/tls/#ssl-passthrough)
