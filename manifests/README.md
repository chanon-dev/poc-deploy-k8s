# Kubernetes Manifests

Kubernetes deployment manifests for all environments.

## Directory Structure

```
manifests/
├── dev/         # Development environment
├── sit/         # System Integration Testing
├── uat/         # User Acceptance Testing
├── prod/        # Production environment
└── local/       # Local development (optional)
```

## Environments

### Development (dev/)
- **Purpose**: Active development and testing
- **Update Method**: Automatic via CI/CD pipeline
- **Argo CD Sync**: Auto-sync enabled
- **Resources**: Standard limits

### SIT (sit/)
- **Purpose**: Integration testing
- **Update Method**: Manual or promoted from dev
- **Argo CD Sync**: Manual sync
- **Resources**: Production-like

### UAT (uat/)
- **Purpose**: User acceptance testing
- **Update Method**: Manual promotion
- **Argo CD Sync**: Manual sync
- **Resources**: Production-like

### Production (prod/)
- **Purpose**: Live production workloads
- **Update Method**: Manual promotion with approvals
- **Argo CD Sync**: Manual sync only
- **Resources**: Production limits with auto-scaling

## Deployment Flow

```
Code Push → CI/CD Build → manifests/dev/ → Argo CD
                              ↓
                         manifests/sit/ → Argo CD (manual)
                              ↓
                         manifests/uat/ → Argo CD (manual)
                              ↓
                         manifests/prod/ → Argo CD (manual + approval)
```

## File Naming Convention

```
<service>-deployment.yaml       # Standard deployment
<service>-deployment.vault.yaml # Vault-integrated deployment
<service>-service.yaml          # Kubernetes service
<service>-ingress.yaml          # Ingress rules
<service>-configmap.yaml        # Configuration
```

## How Manifests are Updated

### Automatic (Development)

CI/CD pipeline automatically updates `dev/` manifests:

1. Jenkins builds new Docker images
2. Tags images with `BUILD_NUMBER-GIT_COMMIT_SHORT`
3. Updates `dev/*-deployment.yaml` files
4. Commits changes to Git
5. Argo CD detects changes and deploys

### Manual (Staging/Production)

For sit/uat/prod, promote manually:

```bash
# Example: Promote dev to sit
cd manifests/

# Copy image tags from dev
DEV_WEBAPP_IMAGE=$(grep "image:" dev/webapp-deployment.yaml | awk '{print $2}')
DEV_WEBAPI_IMAGE=$(grep "image:" dev/webapi-deployment.yaml | awk '{print $2}')

# Update sit manifests
sed -i "s|image:.*webapp.*|image: $DEV_WEBAPP_IMAGE|" sit/webapp-deployment.yaml
sed -i "s|image:.*webapi.*|image: $DEV_WEBAPI_IMAGE|" sit/webapi-deployment.yaml

# Commit
git add sit/
git commit -m "Promote dev to sit: ${DEV_WEBAPP_IMAGE}"
git push
```

## Vault Integration

Some deployments use Vault Agent Injector for secrets:

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "webapp-dev"
  vault.hashicorp.com/agent-inject-secret-config: "secret/data/dev/webapp"
```

**Files with Vault:**
- `*-deployment.vault.yaml` - Uses Vault Agent Injector
- `*-deployment.yaml` - Uses Kubernetes Secrets

## GitOps with Argo CD

All manifests are deployed via Argo CD (GitOps).

**Argo CD Applications:**
- Defined in: `../gitops/argocd-apps/`
- Each application watches a specific environment directory

**Sync Policy:**
- `dev`: Auto-sync enabled
- `sit/uat/prod`: Manual sync only

## Common Operations

### Deploy New Application

1. Create manifests in `dev/`:
```bash
cd manifests/dev/
cp webapp-deployment.yaml mynewapp-deployment.yaml
cp webapp-service.yaml mynewapp-service.yaml
# Edit files...
```

2. Create Argo CD application in `../gitops/argocd-apps/`

3. Apply to cluster:
```bash
kubectl apply -f ../gitops/argocd-apps/mynewapp-dev.yaml
```

### Update Image Tag Manually

```bash
cd manifests/dev/
sed -i 's|image: harbor.local/sample-app/webapp:.*|image: harbor.local/sample-app/webapp:7-abc1234|' webapp-deployment.yaml
git commit -am "Update webapp to build 7"
git push
```

### Rollback

```bash
# Option 1: Git revert
git revert HEAD
git push

# Option 2: Argo CD UI
# Go to application → History → Rollback to previous version
```

## Manifest Validation

Before committing, validate manifests:

```bash
# Dry-run
kubectl apply --dry-run=client -f dev/webapp-deployment.yaml

# Or use kubeval
kubeval dev/*.yaml
```

## Environment Variables

Each environment can have different configurations:

**ConfigMaps:**
```bash
# dev/configmap.yaml
data:
  API_URL: "http://api.dev.local"
  LOG_LEVEL: "debug"

# prod/configmap.yaml
data:
  API_URL: "https://api.prod.com"
  LOG_LEVEL: "info"
```

## Related Directories

- **[../pipelines](../pipelines)** - CI/CD pipelines that update these manifests
- **[../gitops/argocd-apps](../gitops/argocd-apps)** - Argo CD application definitions
- **[../apps](../apps)** - Application source code
- **[../security/vault-policies](../security/vault-policies)** - Vault policies for secret access

## Best Practices

1. **Never commit secrets** - Use Vault or Kubernetes Secrets
2. **Always use image tags** - Never use `:latest` in production
3. **Set resource limits** - Prevent resource starvation
4. **Use health checks** - Define liveness and readiness probes
5. **Version control everything** - All changes via Git
6. **Test in dev first** - Validate before promoting to higher environments
