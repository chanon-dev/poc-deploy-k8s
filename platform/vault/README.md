# HashiCorp Vault Deployment / การติดตั้ง Vault

## Overview / ภาพรวม

HashiCorp Vault is used for secrets management in the platform.

HashiCorp Vault ใช้สำหรับจัดการ secrets ในระบบ

## Architecture / สถาปัตยกรรม

- **HA Mode**: 3 Vault pods using Raft integrated storage
- **Storage**: Persistent volumes for data and audit logs
- **Auth**: Kubernetes authentication method
- **Injection**: Vault Agent Injector for automatic secret injection

## Prerequisites / สิ่งที่ต้องเตรียม

1. Kubernetes cluster / Kubernetes cluster พร้อมใช้งาน
2. Helm 3 installed / ติดตั้ง Helm 3
3. kubectl configured / ตั้งค่า kubectl
4. jq installed (for init script) / ติดตั้ง jq

## Installation / วิธีการติดตั้ง

### Step 1: Add Vault Helm Repository
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

### Step 2: Create Namespace
```bash
kubectl create namespace vault
```

### Step 3: Install Vault
```bash
helm install vault hashicorp/vault \
  -f values.yaml \
  -n vault

# Wait for pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s
```

### Step 4: Initialize and Unseal Vault
```bash
# Make scripts executable
chmod +x init-unseal.sh configure-vault.sh

# Initialize and unseal
./init-unseal.sh

# This will create vault-keys.json with unseal keys and root token
# ⚠️ IMPORTANT: Store this file securely!
```

### Step 5: Configure Vault
```bash
# Configure Kubernetes auth and policies
./configure-vault.sh
```

## Accessing Vault / เข้าถึง Vault

### Via CLI
```bash
# Port forward
kubectl port-forward -n vault svc/vault 8200:8200

# Set environment variable
export VAULT_ADDR='http://127.0.0.1:8200'

# Login with root token
vault login <root-token-from-vault-keys.json>

# Or get token programmatically
export VAULT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')
vault login $VAULT_TOKEN
```

### Via UI
```bash
# Port forward
kubectl port-forward -n vault svc/vault-ui 8200:8200

# Open browser: http://localhost:8200
# Login with root token
```

### Via Ingress (Production)
```
https://vault.company.local
```

## Vault Operations / การใช้งาน Vault

### Adding Secrets
```bash
# Add a secret
vault kv put secret/dev/myapp \
  database_password="super-secret" \
  api_key="api-key-12345"

# Add multiple secrets
vault kv put secret/dev/myapp \
  username="admin" \
  password="secret123" \
  database_url="postgresql://db:5432/mydb"

# Read secret
vault kv get secret/dev/myapp

# List secrets
vault kv list secret/dev/

# Delete secret
vault kv delete secret/dev/myapp
```

### Managing Policies
```bash
# List policies
vault policy list

# Read policy
vault policy read dev-policy

# Write policy from file
vault policy write dev-policy dev-policy.hcl

# Write policy inline
vault policy write my-policy - <<EOF
path "secret/data/dev/*" {
  capabilities = ["read"]
}
EOF
```

### Managing Kubernetes Auth
```bash
# List roles
vault list auth/kubernetes/role

# Read role
vault read auth/kubernetes/role/dev

# Create new role
vault write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp-sa \
  bound_service_account_namespaces=dev \
  policies=dev-policy \
  ttl=1h
```

## Vault Agent Injector / การใช้ Vault Injector

### Example: Inject Secrets into Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  namespace: dev
  annotations:
    # Enable injection
    vault.hashicorp.com/agent-inject: "true"

    # Vault role to use
    vault.hashicorp.com/role: "dev"

    # Inject secret from Vault
    vault.hashicorp.com/agent-inject-secret-database: "secret/data/dev/myapp"

    # Template for the secret file
    vault.hashicorp.com/agent-inject-template-database: |
      {{- with secret "secret/data/dev/myapp" -}}
      export DATABASE_URL="{{ .Data.data.database_url }}"
      export DATABASE_PASSWORD="{{ .Data.data.password }}"
      {{- end -}}
spec:
  serviceAccountName: default
  containers:
  - name: app
    image: myapp:latest
    command: ["/bin/sh"]
    args:
      - -c
      - |
        source /vault/secrets/database
        echo "Database URL: $DATABASE_URL"
        # Start your application
        /app/start.sh
```

### Example: Inject as Environment Variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "dev"
        vault.hashicorp.com/agent-inject-secret-config: "secret/data/dev/myapp"
        vault.hashicorp.com/agent-inject-template-config: |
          {{ with secret "secret/data/dev/myapp" -}}
          {
            "database_password": "{{ .Data.data.database_password }}",
            "api_key": "{{ .Data.data.api_key }}"
          }
          {{- end }}
    spec:
      serviceAccountName: default
      containers:
      - name: app
        image: myapp:latest
        volumeMounts:
        - name: secrets
          mountPath: /vault/secrets
          readOnly: true
```

## Unsealing Vault / การ Unseal Vault

Vault needs to be unsealed after pod restarts:

```bash
# Check seal status
kubectl exec -n vault vault-0 -- vault status

# Unseal (need 3 keys)
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-3>

# Or use the script
./init-unseal.sh
```

### Auto-Unseal (Advanced)
For production, consider using auto-unseal with:
- Cloud KMS (AWS KMS, GCP KMS, Azure Key Vault)
- Transit secrets engine (Vault-to-Vault)

## High Availability / HA

### Check Cluster Status
```bash
# Check raft peers
kubectl exec -n vault vault-0 -- vault operator raft list-peers

# Check leader
kubectl exec -n vault vault-0 -- vault status | grep "HA Mode"
```

### Raft Snapshots (Backup)
```bash
# Create snapshot
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/snapshot.snap

# Copy snapshot out
kubectl cp vault/vault-0:/tmp/snapshot.snap ./vault-snapshot.snap

# Restore snapshot (careful!)
kubectl cp ./vault-snapshot.snap vault/vault-0:/tmp/snapshot.snap
kubectl exec -n vault vault-0 -- vault operator raft snapshot restore /tmp/snapshot.snap
```

## Monitoring / การ Monitor

### Check Vault Status
```bash
# Via CLI
kubectl exec -n vault vault-0 -- vault status

# Check all pods
for pod in vault-0 vault-1 vault-2; do
  echo "=== $pod ==="
  kubectl exec -n vault $pod -- vault status
done
```

### Prometheus Metrics
```bash
# Vault exposes Prometheus metrics at /v1/sys/metrics
# Configure Prometheus to scrape:
# http://vault:8200/v1/sys/metrics
```

### Audit Logs
```bash
# View audit logs
kubectl exec -n vault vault-0 -- cat /vault/audit/audit.log

# Tail audit logs
kubectl exec -n vault vault-0 -- tail -f /vault/audit/audit.log
```

## Security Best Practices / ความปลอดภัย

1. **Store Unseal Keys Securely**
   - Never commit vault-keys.json to Git
   - Use a password manager or HSM
   - Consider using auto-unseal

2. **Rotate Root Token**
   ```bash
   vault token revoke <root-token>
   vault operator generate-root
   ```

3. **Use Least Privilege Policies**
   - Grant minimum required permissions
   - Separate policies per environment

4. **Enable Audit Logging**
   - Monitor all Vault operations
   - Forward logs to SIEM

5. **Regular Backups**
   - Take Raft snapshots regularly
   - Test restore procedures

6. **TLS Everywhere**
   - Enable TLS for Vault API
   - Use TLS for storage backend

## Troubleshooting / แก้ปัญหา

### Issue 1: Vault is sealed
```bash
# Unseal using keys
./init-unseal.sh

# Or manually
kubectl exec -n vault vault-0 -- vault operator unseal <key>
```

### Issue 2: Pod can't access secrets
```bash
# Check ServiceAccount has access
kubectl get sa -n dev default

# Check Vault role
vault read auth/kubernetes/role/dev

# Check policy
vault policy read dev-policy

# Test authentication
kubectl exec -it -n dev <pod> -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

### Issue 3: Injector not working
```bash
# Check injector is running
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector

# Check pod annotations
kubectl describe pod -n dev <pod-name>

# Check injector logs
kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector
```

### Issue 4: Raft cluster issues
```bash
# Check raft status
kubectl exec -n vault vault-0 -- vault operator raft list-peers

# Join a node to cluster
kubectl exec -n vault vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
```

## Common Commands / คำสั่งที่ใช้บ่อย

```bash
# Status
vault status

# Login
vault login <token>

# List secrets
vault kv list secret/dev/

# Get secret
vault kv get secret/dev/myapp

# Put secret
vault kv put secret/dev/myapp key=value

# Delete secret
vault kv delete secret/dev/myapp

# List policies
vault policy list

# Read policy
vault policy read dev-policy

# List auth methods
vault auth list

# List roles
vault list auth/kubernetes/role
```

## References / อ้างอิง

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vault on Kubernetes](https://www.vaultproject.io/docs/platform/k8s)
- [Vault Agent Injector](https://www.vaultproject.io/docs/platform/k8s/injector)
- [Vault Helm Chart](https://github.com/hashicorp/vault-helm)
