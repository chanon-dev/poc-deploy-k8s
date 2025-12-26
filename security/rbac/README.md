# RBAC Configuration / การตั้งค่า RBAC

## Overview / ภาพรวม

This directory contains Role-Based Access Control (RBAC) configurations for the Kubernetes platform.

ไดเรกทอรีนี้เก็บการตั้งค่า RBAC สำหรับ Kubernetes platform

## Roles / บทบาท

### 1. ClusterAdmin (Platform Team)
- **File:** `cluster-admin-role.yaml`
- **Access:** Full cluster access
- **Who:** Platform Team only
- **TH:** สิทธิ์เต็มทั้ง cluster สำหรับ Platform Team เท่านั้น

### 2. NamespaceAdmin (Tech Leads)
- **File:** `namespace-admin-role.yaml`
- **Access:** Full access within specific namespace
- **Who:** Tech Leads scoped to their project namespace
- **TH:** สิทธิ์เต็มใน namespace ของตัวเอง สำหรับ Tech Lead

### 3. Developer
- **File:** `developer-role.yaml`
- **Access:** Read-only + port-forward + logs + exec (optional)
- **Who:** Developers
- **TH:** อ่านได้อย่างเดียว + port-forward + ดู log สำหรับ Developer

### 4. ServiceAccount Policy
- **File:** `serviceaccount-policy.yaml`
- **Access:** Minimal privileges, no auto-mount unless required
- **Who:** Application workloads, CI/CD agents
- **TH:** สิทธิ์น้อยที่สุด ไม่ auto-mount token เว้นแต่จำเป็น

## Deployment Instructions / วิธีการติดตั้ง

### Apply all RBAC configurations:
```bash
# Apply to cluster
kubectl apply -f security/rbac/

# Or apply individually
kubectl apply -f security/rbac/cluster-admin-role.yaml
kubectl apply -f security/rbac/namespace-admin-role.yaml
kubectl apply -f security/rbac/developer-role.yaml
kubectl apply -f security/rbac/serviceaccount-policy.yaml
```

### Create user/group mappings:
```bash
# You need to configure your authentication method (OIDC, LDAP, etc.)
# and map users to groups

# Example: Create certificate for a user
openssl genrsa -out developer.key 2048
openssl req -new -key developer.key -out developer.csr -subj "/CN=developer@company.com/O=developers-dev"

# Sign with cluster CA (requires cluster admin access)
# This creates the user certificate
```

## Testing RBAC / ทดสอบ RBAC

### Test as developer:
```bash
# Impersonate as developer user
kubectl auth can-i get pods --namespace=dev --as=developer@company.com
kubectl auth can-i delete pods --namespace=dev --as=developer@company.com  # Should be 'no'

# Try to access as developer
kubectl get pods -n dev --as=developer@company.com
kubectl get pods -n prod --as=developer@company.com  # Should fail
```

### Test as namespace admin:
```bash
kubectl auth can-i '*' '*' --namespace=dev --as=techlead-dev@company.com
kubectl auth can-i get nodes --as=techlead-dev@company.com
```

## Security Best Practices / แนวทางความปลอดภัย

1. **Least Privilege:** Always grant minimum required permissions
   - **TH:** ให้สิทธิ์น้อยที่สุดเท่าที่จำเป็น

2. **ServiceAccount Security:**
   - Disable `automountServiceAccountToken: false` by default
   - Only enable for workloads that need K8s API access
   - **TH:** ปิด auto-mount token โดยdefault, เปิดเฉพาะที่จำเป็น

3. **Namespace Isolation:**
   - Developers should not have cross-namespace access
   - **TH:** Developer ไม่ควรเข้าถึง namespace อื่นได้

4. **Regular Audits:**
   - Review RBAC permissions quarterly
   - Remove unused roles and bindings
   - **TH:** ตรวจสอบสิทธิ์ทุกไตรมาส ลบ role ที่ไม่ใช้แล้ว

5. **Pod Security:**
   - Use Pod Security Standards/Admission
   - Prevent privileged containers
   - **TH:** ใช้ Pod Security Standards ป้องกัน privileged container

## Customization / ปรับแต่ง

To add users or groups, edit the `subjects` section in each RoleBinding:

```yaml
subjects:
- kind: User
  name: username@company.com
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: group-name
  apiGroup: rbac.authorization.k8s.io
```

To replicate roles across namespaces:
```bash
# Example: Create developer role in all environments
for ns in dev sit uat prod; do
  kubectl apply -f developer-role.yaml -n $ns
done
```

## References / อ้างอิง

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [RBAC Best Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
