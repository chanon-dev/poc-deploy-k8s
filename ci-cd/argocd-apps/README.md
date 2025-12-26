# Argo CD Applications

This directory contains Argo CD Application manifests for deploying the sample application to Kubernetes.

## Applications

### 1. sample-webapp-app.yaml
Frontend Next.js application deployment.

**Includes:**
- Webapp Deployment
- Webapp Service
- ConfigMap

**Access:** http://webapp.local

### 2. sample-webapi-app.yaml
Backend C# ASP.NET Core API deployment.

**Includes:**
- WebAPI Deployment
- WebAPI Service
- ConfigMap

**Access:** http://api.local

### 3. sample-app-ingress.yaml
Ingress configuration for routing external traffic.

**Includes:**
- Ingress resource for both webapp and webapi

## Deployment

### Apply Applications

```bash
# Apply all applications
kubectl apply -f ci-cd/argocd-apps/

# Or apply individually
kubectl apply -f ci-cd/argocd-apps/sample-webapp-app.yaml
kubectl apply -f ci-cd/argocd-apps/sample-webapi-app.yaml
kubectl apply -f ci-cd/argocd-apps/sample-app-ingress.yaml
```

### Verify Applications

```bash
# List all applications
kubectl get applications -n argocd

# Check specific application status
kubectl get application sample-webapp -n argocd -o yaml

# Or use Argo CD CLI
argocd app list
argocd app get sample-webapp
argocd app get sample-webapi
```

### Access Argo CD UI

```bash
# Port forward Argo CD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

Access at: https://localhost:8080
- Username: `admin`
- Password: (from above command)

## Sync Policies

All applications use automated sync with:
- **Prune:** Automatically delete resources removed from Git
- **Self-heal:** Automatically sync if cluster state differs from Git
- **Retry:** Retry failed syncs with exponential backoff

## Manual Sync

If needed, you can manually sync applications:

```bash
# Sync webapp
argocd app sync sample-webapp

# Sync webapi
argocd app sync sample-webapi

# Sync ingress
argocd app sync sample-app-ingress

# Force full sync (delete and recreate)
argocd app sync sample-webapp --force
```

## Rollback

```bash
# List history
argocd app history sample-webapp

# Rollback to specific revision
argocd app rollback sample-webapp <revision-number>
```

## Health Status

```bash
# Check health
argocd app get sample-webapp --refresh

# Watch sync progress
argocd app wait sample-webapp --health
```

## Troubleshooting

### Application not syncing

```bash
# Check application status
kubectl describe application sample-webapp -n argocd

# Check sync status
argocd app get sample-webapp

# Force refresh
argocd app get sample-webapp --refresh --hard
```

### Image pull errors

Ensure Harbor registry secret is created in dev namespace:

```bash
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.local \
  --docker-username=admin \
  --docker-password=HarborAdmin123 \
  --namespace=dev
```

### DNS resolution issues

Add to `/etc/hosts`:
```
127.0.0.1 webapp.local api.local harbor.local
```

## CI/CD Integration

The Jenkins pipeline automatically:
1. Builds Docker images
2. Pushes to Harbor registry
3. Updates Kubernetes manifests in Git
4. Triggers Argo CD sync via API

Argo CD will detect manifest changes and automatically deploy new versions.
