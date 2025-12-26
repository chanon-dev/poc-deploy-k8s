# Sample Application - Complete Deployment Guide

Step-by-step guide to deploy the sample Next.js + C# application using Jenkins, Harbor, and Argo CD.

## Prerequisites

Before starting, ensure you have:

1. **Kubernetes Cluster** - Kind cluster running with:
   - NGINX Ingress Controller
   - Jenkins
   - Argo CD
   - Harbor Container Registry
   - Vault (optional)

2. **Local DNS Configuration** - Add to `/etc/hosts`:
   ```
   127.0.0.1 jenkins.local argocd.local harbor.local vault.local webapp.local api.local
   ```

3. **Harbor Project Created** - Create `sample-app` project in Harbor

4. **Credentials Configured** - Jenkins credentials for:
   - Harbor registry
   - GitHub repository
   - Argo CD token (optional for manual sync)

## Step-by-Step Deployment

### Step 1: Create Harbor Project

1. Access Harbor UI: http://harbor.local
2. Login with credentials: `admin` / `HarborAdmin123`
3. Click **New Project**
4. Enter project name: `sample-app`
5. Set **Access Level:** Public or Private
6. Click **OK**

### Step 2: Create Kubernetes Namespace and Secrets

```bash
# Create dev namespace
kubectl apply -f environments/dev/namespace.yaml

# Create Harbor registry secret
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.local \
  --docker-username=admin \
  --docker-password=HarborAdmin123 \
  --namespace=dev

# Verify secret
kubectl get secret harbor-registry-secret -n dev
```

### Step 3: Deploy Kubernetes Manifests (Manual Method)

```bash
# Apply all manifests
kubectl apply -f environments/dev/webapp-deployment.yaml
kubectl apply -f environments/dev/webapp-service.yaml
kubectl apply -f environments/dev/webapi-deployment.yaml
kubectl apply -f environments/dev/webapi-service.yaml
kubectl apply -f environments/dev/ingress.yaml
kubectl apply -f environments/dev/configmap.yaml

# Verify deployments
kubectl get all -n dev

# Check pod status
kubectl get pods -n dev

# Check ingress
kubectl get ingress -n dev
```

### Step 4: Deploy Using Argo CD (GitOps Method)

```bash
# Apply Argo CD applications
kubectl apply -f ci-cd/argocd-apps/sample-webapp-app.yaml
kubectl apply -f ci-cd/argocd-apps/sample-webapi-app.yaml
kubectl apply -f ci-cd/argocd-apps/sample-app-ingress.yaml

# Verify applications
kubectl get applications -n argocd

# Watch sync status
kubectl get application sample-webapp -n argocd -w
kubectl get application sample-webapi -n argocd -w
```

Or use Argo CD UI:

1. Access: http://argocd.local
2. Login with admin credentials
3. Click **New App**
4. Or view auto-created applications from manifests

### Step 5: Configure Jenkins Credentials

#### 5.1 Harbor Registry Credentials

1. Access Jenkins: http://jenkins.local
2. Navigate to: **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
3. Click **Add Credentials**
4. Configure:
   - **Kind:** Username with password
   - **Scope:** Global
   - **Username:** admin
   - **Password:** HarborAdmin123
   - **ID:** harbor-credentials
   - **Description:** Harbor Registry Credentials
5. Click **Create**

#### 5.2 GitHub Credentials

1. Click **Add Credentials** again
2. Configure:
   - **Kind:** Username with password
   - **Scope:** Global
   - **Username:** your-github-username
   - **Password:** your-github-token (or password)
   - **ID:** github-credentials
   - **Description:** GitHub Repository Access
3. Click **Create**

#### 5.3 Argo CD Token (Optional)

1. Get Argo CD admin token:
   ```bash
   # Login to Argo CD CLI
   argocd login argocd.local --username admin --password <admin-password>

   # Generate token
   argocd account generate-token --account admin
   ```

2. Add to Jenkins:
   - **Kind:** Secret text
   - **Scope:** Global
   - **Secret:** <token-from-above>
   - **ID:** argocd-token
   - **Description:** Argo CD API Token

### Step 6: Create Jenkins Pipeline

1. Access Jenkins: http://jenkins.local
2. Click **New Item**
3. Enter name: `sample-app-pipeline`
4. Select: **Pipeline**
5. Click **OK**
6. Configure:
   - **Description:** Sample App CI/CD Pipeline
   - **Pipeline Definition:** Pipeline script from SCM
   - **SCM:** Git
   - **Repository URL:** https://github.com/chanon-dev/poc-deploy-k8s.git
   - **Credentials:** github-credentials
   - **Branch:** main
   - **Script Path:** app/Jenkinsfile
7. Click **Save**

### Step 7: Configure GitHub Webhook (Optional)

For automatic builds on code push:

1. Go to GitHub repository settings
2. Click **Webhooks** → **Add webhook**
3. Configure:
   - **Payload URL:** http://jenkins.local/github-webhook/
   - **Content type:** application/json
   - **Events:** Just the push event
4. Click **Add webhook**

### Step 8: Build and Deploy

#### Manual Build

1. Access Jenkins pipeline: http://jenkins.local/job/sample-app-pipeline/
2. Click **Build Now**
3. Watch build progress
4. Check console output for any errors

#### Automatic Build

Push code to GitHub repository:

```bash
cd /Users/chanon/Desktop/k8s
git add .
git commit -m "Update application code"
git push origin main
```

Jenkins will automatically:
1. Detect code change
2. Build Docker images
3. Push to Harbor
4. Update Kubernetes manifests
5. Trigger Argo CD sync

### Step 9: Verify Deployment

#### Check Pods

```bash
# Check pod status
kubectl get pods -n dev

# Expected output:
# NAME                      READY   STATUS    RESTARTS   AGE
# webapp-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# webapp-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# webapi-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# webapi-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

#### Check Services

```bash
kubectl get svc -n dev

# Expected output:
# NAME             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
# webapp-service   ClusterIP   10.96.xxx.xxx    <none>        3000/TCP   2m
# webapi-service   ClusterIP   10.96.xxx.xxx    <none>        5000/TCP   2m
```

#### Check Ingress

```bash
kubectl get ingress -n dev

# Expected output:
# NAME                 CLASS   HOSTS                    ADDRESS     PORTS   AGE
# sample-app-ingress   nginx   webapp.local,api.local   localhost   80      2m
```

#### Check Logs

```bash
# Webapp logs
kubectl logs -n dev -l app=webapp --tail=50

# WebAPI logs
kubectl logs -n dev -l app=webapi --tail=50
```

### Step 10: Access Applications

#### Webapp (Frontend)

Open browser: http://webapp.local

You should see:
- Application title and description
- Frontend information (Next.js 14, TypeScript)
- Backend API status (connection status, timestamp, environment)
- Refresh button to re-check backend

#### WebAPI (Backend)

Open browser: http://api.local

You should see:
- Service information
- Available endpoints
- API version

#### Swagger Documentation

Open browser: http://api.local/swagger

Interactive API documentation with:
- All available endpoints
- Request/response schemas
- Try-it-out functionality

### Step 11: Test End-to-End Flow

1. **Make Code Change**
   ```bash
   cd app/webapp/src/app
   # Edit page.tsx - change title
   git add .
   git commit -m "Update webapp title"
   git push origin main
   ```

2. **Watch Jenkins Build**
   - Access http://jenkins.local
   - Watch pipeline execution
   - Check each stage completes successfully

3. **Verify Harbor Image**
   - Access http://harbor.local
   - Navigate to `sample-app` project
   - Verify new image tag appears

4. **Watch Argo CD Sync**
   - Access http://argocd.local
   - Watch application sync automatically
   - Check deployment status

5. **Verify Application Update**
   - Refresh http://webapp.local
   - Verify changes are live

## Troubleshooting

### Pods Not Starting

```bash
# Describe pod for events
kubectl describe pod <pod-name> -n dev

# Common issues:
# - ImagePullBackOff: Check harbor-registry-secret
# - CrashLoopBackOff: Check application logs
```

### Image Pull Errors

```bash
# Verify secret exists
kubectl get secret harbor-registry-secret -n dev

# Recreate if needed
kubectl delete secret harbor-registry-secret -n dev
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.local \
  --docker-username=admin \
  --docker-password=HarborAdmin123 \
  --namespace=dev
```

### DNS Resolution Issues

```bash
# Verify /etc/hosts
cat /etc/hosts | grep local

# Should see:
# 127.0.0.1 jenkins.local argocd.local harbor.local webapp.local api.local
```

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress sample-app-ingress -n dev

# Restart ingress controller if needed
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
```

### Harbor Connection Issues

```bash
# Test Docker login
docker login harbor.local
# Username: admin
# Password: HarborAdmin123

# If SSL errors with self-signed cert:
# Add to /etc/docker/daemon.json:
{
  "insecure-registries": ["harbor.local"]
}

# Restart Docker
sudo systemctl restart docker
```

### Argo CD Sync Issues

```bash
# Force refresh application
kubectl patch application sample-webapp -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check application details
kubectl get application sample-webapp -n argocd -o yaml
```

## Cleanup

### Delete Applications

```bash
# Delete Argo CD applications
kubectl delete -f ci-cd/argocd-apps/

# Delete Kubernetes resources
kubectl delete -f environments/dev/

# Delete namespace
kubectl delete namespace dev
```

### Delete Harbor Project

1. Access Harbor UI
2. Select `sample-app` project
3. Click **Delete**
4. Confirm deletion

## Next Steps

1. **Add Monitoring** - Integrate Prometheus and Grafana
2. **Add Logging** - Set up ELK/EFK stack
3. **Add Vault Integration** - Store secrets in Vault
4. **Add Network Policies** - Restrict pod-to-pod communication
5. **Add Resource Limits** - Fine-tune resource requests/limits
6. **Add HPA** - Configure Horizontal Pod Autoscaler
7. **Add Tests** - Add unit/integration tests to pipeline
8. **Add Security Scanning** - Configure Trivy scanning in Harbor

## Additional Resources

- [Next.js Documentation](https://nextjs.org/docs)
- [ASP.NET Core Documentation](https://docs.microsoft.com/aspnet/core)
- [Kubernetes Documentation](https://kubernetes.io/docs)
- [Argo CD Documentation](https://argo-cd.readthedocs.io)
- [Harbor Documentation](https://goharbor.io/docs)
- [Jenkins Documentation](https://www.jenkins.io/doc)
