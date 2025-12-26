# Vault Policies and Setup Scripts

Vault policies and automation scripts for managing secrets in CI/CD and Kubernetes.

## Files

### Vault Policies

- **jenkins-ci-policy.hcl** - Policy for Jenkins CI/CD
  - Read: CI secrets (harbor, github, argocd)
  - Write: Build metadata
  - Deny: Production secrets

- **webapp-dev-policy.hcl** - Policy for Webapp in Dev environment
  - Read: Dev webapp secrets, shared dev secrets
  - Deny: Other services, other environments

- **webapi-dev-policy.hcl** - Policy for WebAPI in Dev environment
  - Read: Dev webapi secrets, shared dev secrets, database
  - Deny: Other services, other environments

### Setup Scripts

- **setup-policies.sh** - Create Vault policies
- **populate-secrets.sh** - Populate Vault with sample secrets
- **setup-vault-k8s-auth.sh** - Configure Kubernetes authentication

## Quick Start

### 1. Login to Vault

```bash
# Port forward Vault service
kubectl port-forward -n vault svc/vault 8200:8200

# Login (in another terminal)
export VAULT_ADDR='http://127.0.0.1:8200'
vault login
```

### 2. Setup Policies

```bash
cd security/vault-policies

# Make scripts executable
chmod +x *.sh

# Create policies
./setup-policies.sh
```

### 3. Populate Secrets

```bash
# Create sample secrets
./populate-secrets.sh

# ⚠️  IMPORTANT: Update with real secrets
vault kv put secret/ci/harbor \
  username="admin" \
  password="your-real-password"
```

### 4. Setup Kubernetes Auth

```bash
# Configure Kubernetes authentication
./setup-vault-k8s-auth.sh

# Save the output (Role ID and Secret ID)
# You'll need these for Jenkins configuration
```

### 5. Configure Jenkins

1. Go to Jenkins → Manage Jenkins → Credentials
2. Add two **Secret text** credentials:
   - ID: `vault-role-id`
   - ID: `vault-secret-id`
3. Use values from step 4 output

## Policy Structure

### Jenkins CI Policy

**Allowed:**
- ✅ Read all CI secrets (`secret/ci/*`)
- ✅ Write build metadata (`secret/ci/builds/*`)
- ✅ Read dev secrets (for dev builds)

**Denied:**
- ❌ Production secrets
- ❌ Other environments' secrets

### Application Policies (Dev)

**Allowed:**
- ✅ Read own secrets (`secret/dev/webapp` or `secret/dev/webapi`)
- ✅ Read shared dev secrets (`secret/dev/shared/*`)

**Denied:**
- ❌ Other services' secrets
- ❌ Other environments (sit, uat, prod)
- ❌ CI secrets

## Secrets Hierarchy

```
secret/
├── ci/                    # CI/CD secrets
│   ├── harbor            # Registry credentials
│   ├── github            # Git access
│   ├── argocd            # Argo CD API
│   └── docker/
│       └── build-args    # Build-time secrets
│
└── dev/                   # Dev environment
    ├── webapp            # Webapp secrets
    ├── webapi            # WebAPI secrets
    └── shared/
        ├── database      # Shared DB
        └── redis         # Shared cache
```

## Verification

### Check Policies

```bash
# List all policies
vault policy list

# Read specific policy
vault policy read jenkins-ci
vault policy read webapp-dev
vault policy read webapi-dev
```

### Check Secrets

```bash
# List secret paths
vault kv list secret/ci
vault kv list secret/dev

# Get specific secret
vault kv get secret/ci/harbor
vault kv get secret/dev/webapp
```

### Check Auth Methods

```bash
# List auth methods
vault auth list

# Check Kubernetes roles
vault list auth/kubernetes/role
vault read auth/kubernetes/role/webapp-dev
vault read auth/kubernetes/role/webapi-dev

# Check AppRole
vault read auth/approle/role/jenkins-ci
```

## Testing

### Test Jenkins Auth

```bash
# Get AppRole credentials
ROLE_ID=$(vault read -field=role_id auth/approle/role/jenkins-ci/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/jenkins-ci/secret-id)

# Login with AppRole
VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID")

# Test reading secrets
VAULT_TOKEN=$VAULT_TOKEN vault kv get secret/ci/harbor
```

### Test Kubernetes Auth

```bash
# From inside a pod with ServiceAccount 'webapp' in namespace 'dev'
JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Login to Vault
VAULT_TOKEN=$(vault write -field=token auth/kubernetes/login \
  role=webapp-dev \
  jwt=$JWT)

# Test reading secrets
VAULT_TOKEN=$VAULT_TOKEN vault kv get secret/dev/webapp
```

## Creating Additional Policies

### For new environment (SIT):

1. Create policy file: `webapp-sit-policy.hcl`

```hcl
path "secret/data/sit/webapp" {
  capabilities = ["read"]
}

path "secret/data/sit/shared/*" {
  capabilities = ["read"]
}
```

2. Apply policy:

```bash
vault policy write webapp-sit webapp-sit-policy.hcl
```

3. Create Kubernetes role:

```bash
vault write auth/kubernetes/role/webapp-sit \
  bound_service_account_names=webapp \
  bound_service_account_namespaces=sit \
  policies=webapp-sit \
  ttl=24h
```

## Rotating Secrets

### Rotate Application Secrets

```bash
# 1. Generate new secret
NEW_SECRET=$(openssl rand -base64 32)

# 2. Update in Vault
vault kv patch secret/dev/webapp jwt_secret="$NEW_SECRET"

# 3. Restart pods to pick up new secret
kubectl rollout restart deployment webapp -n dev

# 4. Monitor rollout
kubectl rollout status deployment webapp -n dev
```

### Rotate Jenkins AppRole Secret

```bash
# Generate new secret_id
vault write -f auth/approle/role/jenkins-ci/secret-id

# Update in Jenkins credentials
# Update 'vault-secret-id' credential with new value
```

## Backup and Restore

### Backup Secrets

```bash
# Export all secrets to JSON
vault kv get -format=json secret/ci/harbor > backup-harbor.json
vault kv get -format=json secret/dev/webapp > backup-webapp.json

# ⚠️  Store backups securely (encrypted)
```

### Restore Secrets

```bash
# Restore from JSON
vault kv put secret/ci/harbor @backup-harbor.json
```

## Security Best Practices

1. **Never commit real secrets to Git**
   - `.gitignore` for `*.json`, `*.env`, `*-secrets.sh`
   - Use placeholder values in examples

2. **Rotate secrets regularly**
   - CI secrets: Every 90 days
   - Application secrets: Every 30 days
   - Emergency: Immediately if compromised

3. **Use least privilege**
   - Each service gets only what it needs
   - No wildcard `*` permissions
   - Separate policies per service

4. **Monitor access**
   - Enable audit logging
   - Review logs weekly
   - Alert on suspicious access

5. **Secure Vault itself**
   - Use TLS for Vault API
   - Seal Vault when not in use
   - Secure unseal keys (Shamir's Secret Sharing)

## Troubleshooting

### "Permission denied"

```bash
# Check which policy is attached
vault token lookup

# Check policy capabilities
vault token capabilities secret/dev/webapp
```

### "Secret not found"

```bash
# Check if secret exists
vault kv get secret/dev/webapp

# Check path (v1 vs v2)
# Wrong: secret/dev/webapp
# Correct: secret/data/dev/webapp (for API calls)
```

### "Invalid Vault token"

```bash
# Check token validity
vault token lookup

# Token expired - re-login
vault login
```

## Additional Resources

- [Main Documentation](../../docs/vault-secrets-management.md) - Complete guide with architecture and examples
- [HashiCorp Vault Docs](https://www.vaultproject.io/docs) - Official documentation
- [Vault Best Practices](https://www.vaultproject.io/docs/internals/security) - Security guidelines

---

**Need Help?**
- Check main documentation: `/docs/vault-secrets-management.md`
- Review Vault logs: `kubectl logs -n vault <vault-pod>`
- Test policies in dev environment first
