# Vault Secrets Management - Complete Guide

Complete guide for managing secrets with HashiCorp Vault in CI/CD pipeline and Kubernetes.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Secrets Structure](#secrets-structure)
4. [Setup Guide](#setup-guide)
5. [CI/CD Integration](#cicd-integration)
6. [Kubernetes Integration](#kubernetes-integration)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## Overview

### Why Vault?

**Problems with traditional secrets management:**
- ❌ Secrets hardcoded in code or config files
- ❌ Secrets stored in Jenkins credentials (single point of failure)
- ❌ No audit trail for secret access
- ❌ Difficult to rotate secrets
- ❌ Secrets scattered across multiple systems

**Benefits of using Vault:**
- ✅ **Centralized secrets management** - Single source of truth
- ✅ **Dynamic secrets** - Generate short-lived credentials
- ✅ **Encryption as a service** - Encrypt/decrypt data
- ✅ **Audit logging** - Track who accessed what and when
- ✅ **Access control** - Fine-grained policies
- ✅ **Secret rotation** - Automatic credential rotation
- ✅ **Revocation** - Instantly revoke compromised secrets

## Architecture

### Secrets Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         HashiCorp Vault                          │
│                    (Secrets Management)                          │
└─────────────┬───────────────────────────────────┬───────────────┘
              │                                   │
              │ AppRole Auth                      │ Kubernetes Auth
              │ (for Jenkins)                     │ (for Pods)
              │                                   │
┌─────────────▼─────────────┐     ┌───────────────▼──────────────┐
│         Jenkins            │     │       Kubernetes Pods        │
│                            │     │                              │
│  1. Login with AppRole     │     │  1. ServiceAccount token     │
│  2. Get Vault token        │     │  2. Vault Agent Injector     │
│  3. Read CI secrets        │     │  3. Auto-inject secrets      │
│  4. Build & push images    │     │  4. App reads from files     │
└────────────────────────────┘     └──────────────────────────────┘
```

### Authentication Methods

#### 1. AppRole (for Jenkins)
- Role ID + Secret ID → Vault Token
- Used by CI/CD systems
- Short-lived tokens (1-4 hours)

#### 2. Kubernetes Auth (for Pods)
- ServiceAccount token → Vault Token
- Vault Agent Injector sidecar
- Secrets injected as files in `/vault/secrets/`

## Secrets Structure

### Vault Secret Paths

```
secret/
├── ci/                          # CI/CD secrets
│   ├── harbor                   # Harbor registry credentials
│   ├── github                   # GitHub access token
│   ├── argocd                   # Argo CD API token
│   ├── docker/
│   │   └── build-args          # Docker build secrets
│   └── builds/
│       └── {build_number}      # Build metadata (audit trail)
│
├── dev/                         # Development environment
│   ├── webapp                   # Webapp-specific secrets
│   ├── webapi                   # WebAPI-specific secrets
│   └── shared/
│       ├── database            # Shared database credentials
│       └── redis               # Shared Redis credentials
│
├── sit/                         # SIT environment
│   └── ...
│
├── uat/                         # UAT environment
│   └── ...
│
└── prod/                        # Production environment
    └── ...
```

### Example Secret Values

#### CI Secrets (`secret/ci/harbor`)
```json
{
  "username": "admin",
  "password": "HarborAdmin123",
  "registry": "harbor.local"
}
```

#### Application Secrets (`secret/dev/webapp`)
```json
{
  "jwt_secret": "dev-jwt-secret-32-characters-long",
  "api_key": "dev-api-key-12345",
  "encryption_key": "dev-encryption-key-32-chars",
  "next_public_api_url": "http://webapi-service:5000"
}
```

#### Application Secrets (`secret/dev/webapi`)
```json
{
  "jwt_secret": "dev-jwt-secret-32-characters-long",
  "jwt_issuer": "https://api.local",
  "jwt_audience": "https://webapp.local",
  "database_connection_string": "Server=postgres;Database=sampledb;...",
  "redis_connection_string": "redis:6379,password=devredis123",
  "smtp_password": "dev-smtp-password"
}
```

## Setup Guide

### Prerequisites

- Vault installed and initialized
- Vault unsealed and accessible
- kubectl access to Kubernetes cluster
- Vault CLI installed locally

### Step 1: Enable KV v2 Secrets Engine

```bash
vault secrets enable -path=secret kv-v2
```

### Step 2: Create Vault Policies

```bash
cd security/vault-policies

# Create policies
vault policy write jenkins-ci jenkins-ci-policy.hcl
vault policy write webapp-dev webapp-dev-policy.hcl
vault policy write webapi-dev webapi-dev-policy.hcl

# Verify
vault policy list
vault policy read jenkins-ci
```

### Step 3: Populate Secrets

```bash
# Run the populate script
./populate-secrets.sh

# Or manually create secrets
vault kv put secret/ci/harbor \
  username="admin" \
  password="HarborAdmin123" \
  registry="harbor.local"

vault kv put secret/dev/webapp \
  jwt_secret="your-secret-here" \
  api_key="your-api-key" \
  encryption_key="32-character-encryption-key"
```

### Step 4: Setup Kubernetes Authentication

```bash
# Run the setup script
./setup-vault-k8s-auth.sh

# This will:
# 1. Enable Kubernetes auth method
# 2. Configure Kubernetes auth backend
# 3. Create roles for webapp-dev and webapi-dev
# 4. Create AppRole for Jenkins
# 5. Display Jenkins credentials
```

### Step 5: Configure Jenkins Credentials

1. Copy Role ID and Secret ID from setup script output
2. Go to Jenkins: **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
3. Add two **Secret text** credentials:
   - ID: `vault-role-id`, Secret: `<role-id>`
   - ID: `vault-secret-id`, Secret: `<secret-id>`

### Step 6: Install Vault Agent Injector

```bash
# Add Vault Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault with Agent Injector
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "injector.enabled=true" \
  --set "server.dev.enabled=true"

# For production, use external Vault:
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "injector.enabled=true" \
  --set "injector.externalVaultAddr=http://vault.vault.svc.cluster.local:8200"
```

## CI/CD Integration

### Jenkins Pipeline with Vault

Use the updated Jenkinsfile: `app/Jenkinsfile.vault`

**Key changes from traditional approach:**

#### Before (Jenkins Credentials):
```groovy
withCredentials([usernamePassword(
  credentialsId: 'harbor-credentials',
  usernameVariable: 'HARBOR_USER',
  passwordVariable: 'HARBOR_PASS'
)]) {
  sh "docker login ${HARBOR_REGISTRY} -u ${HARBOR_USER} -p ${HARBOR_PASS}"
}
```

#### After (Vault):
```groovy
stage('Vault Login') {
  withCredentials([
    string(credentialsId: 'vault-role-id', variable: 'VAULT_ROLE_ID'),
    string(credentialsId: 'vault-secret-id', variable: 'VAULT_SECRET_ID')
  ]) {
    sh '''
      VAULT_TOKEN=$(curl -s --request POST \
        --data "{\\"role_id\\": \\"${VAULT_ROLE_ID}\\", \\"secret_id\\": \\"${VAULT_SECRET_ID}\\"}" \
        ${VAULT_ADDR}/v1/auth/approle/login | jq -r '.auth.client_token')
      echo $VAULT_TOKEN > .vault-token
    '''
  }
}

stage('Read Secrets') {
  sh '''
    export VAULT_TOKEN=$(cat .vault-token)
    HARBOR_USERNAME=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
      ${VAULT_ADDR}/v1/secret/data/ci/harbor | jq -r '.data.data.username')
    HARBOR_PASSWORD=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
      ${VAULT_ADDR}/v1/secret/data/ci/harbor | jq -r '.data.data.password')
    echo "${HARBOR_PASSWORD}" | docker login ${HARBOR_REGISTRY} -u "${HARBOR_USERNAME}" --password-stdin
  '''
}
```

### Pipeline Flow with Vault

```
1. Jenkins Pipeline Start
   ↓
2. Login to Vault with AppRole
   - Provide: Role ID + Secret ID (from Jenkins credentials)
   - Receive: Vault Token (short-lived, 1h)
   ↓
3. Read Secrets from Vault
   - Harbor credentials
   - GitHub token
   - Argo CD token
   - Build secrets
   ↓
4. Use Secrets in Pipeline
   - Docker login
   - Git operations
   - API calls
   ↓
5. Build & Push Images
   ↓
6. Update Manifests
   ↓
7. Record Build in Vault
   - Store build metadata for audit
   ↓
8. Cleanup
   - Remove .vault-token file
   - Revoke Vault token (optional)
```

## Kubernetes Integration

### Vault Agent Injector

**How it works:**

1. Pod starts with ServiceAccount
2. Vault Agent Injector (mutating webhook) injects init container
3. Init container authenticates to Vault using ServiceAccount token
4. Vault validates token and returns secrets based on policy
5. Secrets written to `/vault/secrets/` as files
6. Application container reads secrets from files

### Deployment with Vault Annotations

See: `environments/dev/webapp-deployment.vault.yaml`

**Key annotations:**

```yaml
annotations:
  # Enable injection
  vault.hashicorp.com/agent-inject: "true"

  # Specify Vault role
  vault.hashicorp.com/role: "webapp-dev"

  # Define secret to inject
  vault.hashicorp.com/agent-inject-secret-config: "secret/data/dev/webapp"

  # Template for secret format
  vault.hashicorp.com/agent-inject-template-config: |
    {{- with secret "secret/data/dev/webapp" -}}
    export JWT_SECRET="{{ .Data.data.jwt_secret }}"
    export API_KEY="{{ .Data.data.api_key }}"
    {{- end }}
```

### Reading Secrets in Application

#### Option 1: Source environment file (Shell)

```bash
# In container command
command: ["/bin/sh", "-c"]
args:
  - |
    # Source secrets
    source /vault/secrets/config

    # Start application with secrets as env vars
    node server.js
```

#### Option 2: Read JSON file (Application code)

```javascript
// In Node.js application
const fs = require('fs');
const secrets = JSON.parse(fs.readFileSync('/vault/secrets/config', 'utf8'));

const jwtSecret = secrets.jwt_secret;
```

```csharp
// In C# application
var secretsPath = "/vault/secrets/config";
var secretsJson = File.ReadAllText(secretsPath);
var secrets = JsonSerializer.Deserialize<Dictionary<string, string>>(secretsJson);

var jwtSecret = secrets["jwt_secret"];
```

## Best Practices

### 1. Secret Organization

✅ **Do:**
- Separate secrets by environment (dev, sit, uat, prod)
- Use descriptive path names
- Group related secrets together
- Document secret purposes

❌ **Don't:**
- Mix environments in same path
- Use generic names like `secret1`, `secret2`
- Store non-secret configuration in Vault

### 2. Access Control

✅ **Do:**
- Follow principle of least privilege
- Use separate policies per service
- Limit Jenkins access to CI secrets only
- Deny production access from dev environments

❌ **Don't:**
- Give broad `*` permissions
- Share policies across services
- Allow CI to access production secrets

### 3. Secret Rotation

✅ **Do:**
- Rotate secrets regularly (every 90 days minimum)
- Use dynamic secrets when possible
- Track secret age with metadata
- Test rotation in dev first

❌ **Don't:**
- Use the same secrets for years
- Rotate all secrets at once (causes outages)
- Forget to update applications after rotation

### 4. Audit and Monitoring

✅ **Do:**
- Enable Vault audit logging
- Monitor for unauthorized access attempts
- Alert on policy violations
- Review audit logs regularly

❌ **Don't:**
- Disable audit logging
- Ignore failed authentication attempts
- Share audit logs publicly

### 5. Emergency Access

✅ **Do:**
- Document break-glass procedures
- Keep root token sealed and offline
- Require multi-person authorization
- Log all emergency access

❌ **Don't:**
- Use root token for daily operations
- Share emergency credentials via email/Slack
- Skip documentation of emergency access

## Troubleshooting

### Issue: Pod fails to start with "permission denied"

**Cause:** ServiceAccount doesn't have permission to authenticate with Vault

**Solution:**
```bash
# Check if ServiceAccount exists
kubectl get sa webapp -n dev

# Check if ClusterRoleBinding exists
kubectl get clusterrolebinding webapp-dev-vault-tokenreview

# Verify Vault role
vault read auth/kubernetes/role/webapp-dev
```

### Issue: "Invalid Vault token"

**Cause:** Token expired or revoked

**Solution:**
```bash
# Check token validity
vault token lookup

# Re-login to Vault
vault login

# For Jenkins, regenerate AppRole secret
vault write -f auth/approle/role/jenkins-ci/secret-id
```

### Issue: Secrets not injected into pod

**Cause:** Vault Agent Injector not installed or annotations incorrect

**Solution:**
```bash
# Check if Vault Agent Injector is running
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector

# Check pod annotations
kubectl get pod <pod-name> -n dev -o yaml | grep vault.hashicorp.com

# Check Vault Agent logs
kubectl logs <pod-name> -n dev -c vault-agent-init
```

### Issue: "Secret not found"

**Cause:** Secret path doesn't exist or policy doesn't allow access

**Solution:**
```bash
# Verify secret exists
vault kv get secret/dev/webapp

# Check policy
vault policy read webapp-dev

# Test with token
VAULT_TOKEN=<token> vault kv get secret/dev/webapp
```

## Security Considerations

### 1. Never commit secrets to Git
- Use `.gitignore` for local secret files
- Scan commits for leaked secrets
- Use pre-commit hooks

### 2. Encrypt secrets at rest
- Enable Vault encryption
- Use encrypted storage backend
- Secure Vault unseal keys

### 3. Use HTTPS/TLS
- Enable TLS for Vault API
- Use valid certificates
- Enforce TLS 1.2+

### 4. Regular security audits
- Review Vault policies quarterly
- Audit secret access logs
- Conduct penetration testing

## Migration from Jenkins Credentials to Vault

### Step-by-step migration:

1. **Setup Vault** (Steps 1-6 above)

2. **Migrate secrets to Vault**
   ```bash
   # For each Jenkins credential, create in Vault
   vault kv put secret/ci/harbor username=admin password=xxx
   ```

3. **Update Jenkinsfile**
   - Replace `withCredentials` blocks
   - Add Vault login stage
   - Read secrets from Vault

4. **Test in dev environment**
   - Run pipeline in dev
   - Verify secrets are read correctly
   - Check no credentials errors

5. **Update Kubernetes manifests**
   - Add Vault annotations
   - Create ServiceAccounts
   - Test pod startup

6. **Rollout to other environments**
   - SIT → UAT → Prod
   - Monitor for issues
   - Keep Jenkins credentials as backup initially

7. **Cleanup old credentials**
   - After successful migration
   - Remove Jenkins credentials
   - Document new process

## Additional Resources

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Agent Injector](https://www.vaultproject.io/docs/platform/k8s/injector)
- [Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)
- [Vault AppRole Auth](https://www.vaultproject.io/docs/auth/approle)

---

**Document Version:** 1.0.0
**Last Updated:** 2025-12-26
