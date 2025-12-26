# Network Policies / Network Policies สำหรับ Zero Trust

## Overview / ภาพรวม

This directory implements Zero Trust network architecture using Kubernetes Network Policies.

ไดเรกทอรีนี้ทำ Zero Trust network architecture โดยใช้ Kubernetes Network Policies

## Zero Trust Principles / หลักการ Zero Trust

1. **Default Deny:** All traffic is blocked by default
   - **TH:** บล็อก traffic ทั้งหมดโดย default

2. **Explicit Allow:** Only explicitly allowed traffic is permitted
   - **TH:** อนุญาตเฉพาะ traffic ที่กำหนดไว้ชัดเจนเท่านั้น

3. **Least Privilege:** Each service only gets the minimum network access it needs
   - **TH:** แต่ละ service มีสิทธิ์เข้าถึง network เท่าที่จำเป็นเท่านั้น

4. **Microsegmentation:** Network is segmented by namespace and pod labels
   - **TH:** แบ่ง network ตาม namespace และ pod labels

## Policy Files / ไฟล์ Policy

### 1. default-deny-all.yaml
- **Purpose:** Block all ingress and egress traffic by default
- **TH:** บล็อก traffic ทั้งหมดโดย default
- **Applied to:** All namespaces (dev, sit, uat, prod)
- **Critical:** Must be applied first!

### 2. allow-dns.yaml
- **Purpose:** Allow DNS resolution to kube-dns/CoreDNS
- **TH:** อนุญาตให้ resolve DNS ได้
- **Required:** Yes - all pods need DNS

### 3. allow-frontend-to-backend.yaml
- **Purpose:** Example of allowing specific service-to-service communication
- **TH:** ตัวอย่างการอนุญาต traffic ระหว่าง service
- **Pattern:** Frontend → Backend → Database

### 4. allow-ingress-to-frontend.yaml
- **Purpose:** Allow Ingress Controller to reach frontend applications
- **TH:** อนุญาตให้ Ingress Controller เข้าถึง frontend
- **Required:** Yes - for external access

### 5. allow-vault-access.yaml
- **Purpose:** Allow applications to fetch secrets from Vault
- **TH:** อนุญาตให้แอพดึง secret จาก Vault
- **Required:** Yes - for Vault integration

### 6. allow-external-egress.yaml
- **Purpose:** Allow pods to access external APIs (with label)
- **TH:** อนุญาตให้ pod เข้าถึง external API (ที่มี label)
- **Security:** Only pods with `allow-external: "true"` label

## Deployment Instructions / วิธีการติดตั้ง

### Step 1: Apply Default Deny (Critical!)
```bash
# Apply default deny to all namespaces
kubectl apply -f security/network-policies/default-deny-all.yaml

# Verify it's applied
kubectl get networkpolicy -A
```

### Step 2: Apply DNS Allow (Required)
```bash
# Allow DNS resolution
kubectl apply -f security/network-policies/allow-dns.yaml

# Test DNS works
kubectl run -it --rm debug --image=busybox --restart=Never -n dev -- nslookup kubernetes.default
```

### Step 3: Apply Service-Specific Policies
```bash
# Apply based on your application architecture
kubectl apply -f security/network-policies/allow-ingress-to-frontend.yaml
kubectl apply -f security/network-policies/allow-frontend-to-backend.yaml
kubectl apply -f security/network-policies/allow-vault-access.yaml
kubectl apply -f security/network-policies/allow-external-egress.yaml
```

## Testing Network Policies / ทดสอบ Network Policy

### Test 1: Verify Default Deny Works
```bash
# Create a test pod
kubectl run test-pod --image=nginx -n dev

# Try to access another pod (should fail)
kubectl run -it --rm debug --image=busybox -n dev -- wget -O- http://test-pod

# Should timeout or fail if policy is working
```

### Test 2: Verify DNS Works
```bash
kubectl run -it --rm debug --image=busybox -n dev -- nslookup google.com
# Should succeed
```

### Test 3: Verify Allowed Traffic Works
```bash
# If you have frontend and backend pods
kubectl run frontend --image=nginx -n dev --labels="app=frontend,tier=web"
kubectl run backend --image=nginx -n dev --labels="app=backend,tier=api"

# Apply the allow policy
kubectl apply -f allow-frontend-to-backend.yaml

# Test connection from frontend to backend
kubectl exec -it frontend -n dev -- wget -O- http://backend:8080
# Should work if policy is correct
```

### Test 4: Verify External Access (with label)
```bash
# Pod without label (should fail)
kubectl run test1 --image=busybox -n dev -- wget -O- https://google.com
kubectl logs test1 -n dev  # Should show timeout

# Pod with label (should succeed)
kubectl run test2 --image=busybox -n dev --labels="allow-external=true" -- wget -O- https://google.com
kubectl logs test2 -n dev  # Should succeed
```

## Creating Custom Policies / สร้าง Policy ของคุณเอง

### Template for Allow Policy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-{source}-to-{destination}
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: {destination-app}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: {source-app}
    ports:
    - protocol: TCP
      port: {port-number}
```

### Example: Allow API to Cache (Redis)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-redis
  namespace: prod
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 6379
```

## Common Issues / ปัญหาที่พบบ่อย

### Issue 1: Pods can't resolve DNS
**Solution:** Make sure `allow-dns.yaml` is applied to the namespace

### Issue 2: Can't pull container images
**Solution:** Check if `allow-registry-access.yaml` is applied and registry namespace exists

### Issue 3: Ingress not reaching pods
**Solution:** Verify `allow-ingress-to-frontend.yaml` is applied and namespace labels are correct

### Issue 4: Cross-namespace communication not working
**Solution:** Use `namespaceSelector` in your NetworkPolicy:
```yaml
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: other-namespace
```

## Best Practices / แนวปฏิบัติที่ดี

1. **Always apply default-deny first**
   - **TH:** ใส่ default-deny ก่อนเสมอ

2. **Use specific pod selectors**
   - Don't use `podSelector: {}` in allow policies
   - **TH:** ใช้ pod selector ที่ชัดเจน อย่าใช้ `{}`

3. **Document each policy**
   - Explain why the policy exists
   - **TH:** เขียนอธิบายว่าทำไมต้องมี policy นี้

4. **Test policies in dev first**
   - Never test in production
   - **TH:** ทดสอบใน dev ก่อน อย่าทดสอบใน production

5. **Use labels consistently**
   - Define standard labels: app, tier, component
   - **TH:** ใช้ label อย่างสม่ำเสมอ

6. **Regular audits**
   - Review policies quarterly
   - Remove unused policies
   - **TH:** ทบทวน policy ทุกไตรมาส ลบที่ไม่ใช้แล้ว

## Troubleshooting / แก้ปัญหา

### Enable verbose logging
```bash
# Check if CNI plugin supports network policies
kubectl get pods -n kube-system | grep -E 'calico|cilium|weave'

# View network policy events
kubectl get events -n dev --field-selector involvedObject.kind=NetworkPolicy
```

### Test connectivity
```bash
# Install netshoot for debugging
kubectl run netshoot --rm -it --image=nicolaka/netshoot -n dev -- bash

# Inside the pod, test connectivity
nc -zv backend-service 8080
curl -v http://backend-service:8080
```

## References / อ้างอิง

- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Network Policy Recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)
- [Cilium Network Policy Editor](https://editor.cilium.io/)
