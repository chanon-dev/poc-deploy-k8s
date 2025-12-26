# Quick Start - Get Vault Credentials for Jenkins

วิธีรับ Vault Role ID และ Secret ID สำหรับใส่ใน Jenkins แบบง่ายที่สุด

## ขั้นตอนที่ 1: เตรียม Vault

### 1.1 ตรวจสอบ Vault ทำงานอยู่

```bash
kubectl get pods -n vault
```

ควรเห็น:
```
NAME      READY   STATUS    RESTARTS   AGE
vault-0   1/1     Running   0          1h
```

### 1.2 Port Forward Vault (เปิด Terminal แยก)

```bash
kubectl port-forward -n vault svc/vault 8200:8200
```

เปิดทิ้งไว้ อย่าปิด Terminal นี้

### 1.3 Login to Vault (Terminal ใหม่)

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
vault login
```

ใส่ token ของคุณ (root token หรือ token ที่มีสิทธิ์)

**หา root token:**
```bash
kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.vault-root}' | base64 -d
```

## ขั้นตอนที่ 2: Get Vault Credentials

### วิธีที่ 1: ใช้ Script (แนะนำ - ง่ายที่สุด)

```bash
cd /Users/chanon/Desktop/k8s/security/vault-policies

./get-jenkins-credentials.sh
```

**Output จะเป็น:**
```
================================================================
                   JENKINS CREDENTIALS
================================================================

Copy these values to Jenkins:

1. Vault Role ID:
   ┌────────────────────────────────────────────────────────────┐
   │ a1b2c3d4-e5f6-7890-abcd-ef1234567890
   └────────────────────────────────────────────────────────────┘

2. Vault Secret ID:
   ┌────────────────────────────────────────────────────────────┐
   │ x1y2z3a4-b5c6-d7e8-f9g0-h1234567890i
   └────────────────────────────────────────────────────────────┘

================================================================
```

**Copy ทั้ง 2 ค่านี้!**

### วิธีที่ 2: Manual (ทำเองทีละขั้นตอน)

#### 2.1 Login to Vault

```bash
# Login with root token
kubectl exec -n vault vault-0 -- vault login <your-root-token>
```

**หา root token:**
- ดูจาก init output เมื่อ setup Vault ครั้งแรก
- หรือถ้าเก็บไว้ใน secret: `kubectl get secret vault-keys -n vault`

**ตัวอย่าง:**
```bash
kubectl exec -n vault vault-0 -- vault login hvs.XXXXXXXXXXXXXXXXXXXXX
```

#### 2.2 Enable AppRole (ถ้ายังไม่เคย enable)

```bash
kubectl exec -n vault vault-0 -- vault auth enable approle
```

#### 2.3 Enable KV Secrets Engine (ถ้ายังไม่เคย enable)

```bash
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2
```

#### 2.4 Create Policy

```bash
# Copy policy file to pod
kubectl cp /Users/chanon/Desktop/k8s/security/vault-policies/jenkins-ci-policy.hcl \
  vault/vault-0:/tmp/jenkins-ci-policy.hcl

# Write policy
kubectl exec -n vault vault-0 -- vault policy write jenkins-ci /tmp/jenkins-ci-policy.hcl
```

#### 2.5 Create AppRole

```bash
kubectl exec -n vault vault-0 -- vault write auth/approle/role/jenkins-ci \
  token_policies=jenkins-ci \
  token_ttl=1h \
  token_max_ttl=4h
```

#### 2.6 Get Role ID

```bash
kubectl exec -n vault vault-0 -- vault read -field=role_id auth/approle/role/jenkins-ci/role-id
```

**Output ตัวอย่าง:**
```
355cd578-c5b9-c57e-c2ba-4f83c96694af
```

**💾 Copy Role ID นี้!**

#### 2.7 Generate Secret ID

```bash
kubectl exec -n vault vault-0 -- vault write -field=secret_id -f auth/approle/role/jenkins-ci/secret-id
```

**Output ตัวอย่าง:**
```
25a55696-d1a7-4493-16ad-4e6c42434232
```

**💾 Copy Secret ID นี้!**

### วิธีที่ 3: One-liner (สำหรับคนที่รู้ root token แล้ว)

```bash
# Set your root token (replace with your actual token)
ROOT_TOKEN="hvs.XXXXXXXXXXXXXXXXXXXXX"

# Get Role ID
kubectl exec -n vault vault-0 -- sh -c "vault login $ROOT_TOKEN > /dev/null 2>&1 && vault read -field=role_id auth/approle/role/jenkins-ci/role-id"

# Get Secret ID
kubectl exec -n vault vault-0 -- sh -c "vault login $ROOT_TOKEN > /dev/null 2>&1 && vault write -field=secret_id -f auth/approle/role/jenkins-ci/secret-id"
```

## ขั้นตอนที่ 3: เพิ่ม Credentials ใน Jenkins

### 3.1 เปิด Jenkins

```
http://jenkins.local
```

Login ด้วย admin credentials

### 3.2 ไปที่หน้า Credentials

1. คลิก **Manage Jenkins** (sidebar ซ้าย)
2. คลิก **Credentials**
3. คลิก **System**
4. คลิก **Global credentials (unrestricted)**

### 3.3 เพิ่ม Vault Role ID

1. คลิก **+ Add Credentials** (sidebar ซ้าย)
2. กรอกข้อมูล:
   ```
   Kind: Secret text
   Scope: Global (Jenkins, nodes, items, all child items, etc)
   Secret: <paste Role ID>
   ID: vault-role-id
   Description: Vault AppRole Role ID for Jenkins
   ```
3. คลิก **Create**

### 3.4 เพิ่ม Vault Secret ID

1. คลิก **+ Add Credentials** อีกครั้ง
2. กรอกข้อมูล:
   ```
   Kind: Secret text
   Scope: Global
   Secret: <paste Secret ID>
   ID: vault-secret-id
   Description: Vault AppRole Secret ID for Jenkins
   ```
3. คลิก **Create**

### 3.5 Verify

กลับไปที่ **Global credentials** ควรเห็น:
- ✅ `vault-role-id`
- ✅ `vault-secret-id`

## ขั้นตอนที่ 4: Test Pipeline

1. ไปที่ **Dashboard**
2. คลิก **sample-app-pipeline**
3. คลิก **Build Now**
4. คลิก build number (เช่น #3)
5. คลิก **Console Output**

ควรเห็น:
```
[Pipeline] stage (Vault Login)
[Pipeline] { (Vault Login)
[Pipeline] script
[Pipeline] {
[Pipeline] echo
Authenticating with Vault using AppRole...
[Pipeline] sh
+ curl -s --request POST --data ...
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
```

✅ ถ้าผ่าน Vault Login stage แสดงว่าสำเร็จ!

---

## Troubleshooting

### ปัญหา: "Cannot connect to Vault"

**ตรวจสอบ:**
```bash
# 1. Vault pod running?
kubectl get pods -n vault

# 2. Port forward active?
# ดูว่า Terminal ที่รัน port-forward ยังเปิดอย่างไหม

# 3. Test connection
curl http://127.0.0.1:8200/v1/sys/health
```

### ปัญหา: "Not logged in to Vault"

```bash
# Login again
vault login

# Or with root token
kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.vault-root}' | base64 -d
vault login <root-token>
```

### ปัญหา: "jenkins-ci role does not exist"

```bash
# Run full setup script
cd /Users/chanon/Desktop/k8s/security/vault-policies
./setup-vault-k8s-auth.sh
```

### ปัญหา: Jenkins ยัง error "Could not find credentials"

**ตรวจสอบ ID ตรงกันไหม:**

ใน Jenkins credentials:
- ID ต้องเป็น `vault-role-id` (ตัวพิมพ์เล็กทั้งหมด, มี dash)
- ID ต้องเป็น `vault-secret-id` (ตัวพิมพ์เล็กทั้งหมด, มี dash)

ใน Jenkinsfile.vault:
```groovy
withCredentials([
    string(credentialsId: 'vault-role-id', variable: 'VAULT_ROLE_ID'),
    string(credentialsId: 'vault-secret-id', variable: 'VAULT_SECRET_ID')
])
```

ID ต้องตรงกันทุกตัวอักษร!

---

## Alternative: ใช้ Jenkinsfile ธรรมดา (ไม่ใช้ Vault)

ถ้าไม่ต้องการใช้ Vault ตอนนี้:

1. ไปที่ **sample-app-pipeline** → **Configure**
2. เปลี่ยน **Script Path** จาก:
   ```
   app/Jenkinsfile.vault
   ```
   เป็น:
   ```
   app/Jenkinsfile
   ```
3. **Save**

ต้องมี credentials เหล่านี้แทน:
- `harbor-credentials` (Username with password)
- `github-credentials` (Username with password)

---

## Summary Commands

```bash
# 1. Port forward Vault
kubectl port-forward -n vault svc/vault 8200:8200

# 2. Login to Vault (terminal ใหม่)
export VAULT_ADDR='http://127.0.0.1:8200'
vault login

# 3. Get credentials
cd /Users/chanon/Desktop/k8s/security/vault-policies
./get-jenkins-credentials.sh

# 4. Copy Role ID and Secret ID จาก output
# 5. Add to Jenkins UI
# 6. Build pipeline
```

---

**เสร็จแล้ว! 🎉**

ถ้ามีปัญหาอะไร ดูที่:
- [Vault Secrets Management Guide](../../docs/vault-secrets-management.md)
- [Jenkins Setup Guide](../../docs/jenkins-setup-guide.md)
