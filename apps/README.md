# Sample Application - Next.js + C# Web API

Example application demonstrating full CI/CD pipeline with Jenkins, Harbor, and Argo CD.

## Architecture

```
┌─────────────┐         ┌─────────────┐
│   Next.js   │  HTTP   │  C# Web API │
│   Webapp    │ ──────> │   Backend   │
│  (Port 3000)│         │  (Port 5000)│
└─────────────┘         └─────────────┘
```

## Components

### 1. Webapp (Next.js)
- **Location:** `webapp/`
- **Tech:** Next.js 14, React 18, TypeScript
- **Port:** 3000

### 2. WebAPI (C# ASP.NET Core)
- **Location:** `webapi/`
- **Tech:** .NET 8, ASP.NET Core Web API
- **Port:** 5000

### 3. CI/CD Pipelines

Each application has its own **independent Jenkinsfile** for isolated deployments:

| Application | Pipeline                                 | Build Method | Description                      |
|-------------|------------------------------------------|--------------|----------------------------------|
| **Webapp**  | [webapp/Jenkinsfile](webapp/Jenkinsfile) | **Kaniko**   | Next.js production pipeline ⭐   |
| **WebAPI**  | [webapi/Jenkinsfile](webapi/Jenkinsfile) | **Kaniko**   | .NET API production pipeline ⭐  |

**Benefits:**

- ✅ Deploy each app independently
- ✅ Faster builds (only changed app rebuilds)
- ✅ Clear ownership and isolation
- ✅ Production-ready with Kaniko (no privileged mode)

**📚 See:** [Complete Documentation](../docs/jenkinsfile-vault-explained.md) | [Archived Pipelines](../pipelines-archive/README.md)

## CI/CD Pipeline Flow

Each application deploys independently:

```
1. Developer pushes code to Git (webapp/ or webapi/)
   ↓
2. Jenkins detects change (webhook triggers specific app pipeline)
   ↓
3. Application-specific Jenkinsfile executes:
   - Vault Login (retrieve secrets securely)
   - Checkout (clone source code)
   - Build with Kaniko (no privileged mode needed)
   - Security Scan with Trivy
   - Push to Harbor Registry
   ↓
4. Jenkins updates Kubernetes manifests (only changed app)
   ↓
5. Argo CD detects manifest changes
   ↓
6. Argo CD deploys to Kubernetes (only changed app)
```

## Quick Start

### Prerequisites
- Docker installed
- Kubernetes cluster running
- Jenkins configured
- Harbor registry accessible
- Argo CD installed

### Local Development

#### Run Webapp
```bash
cd webapp
npm install
npm run dev
# Access: http://localhost:3000
```

#### Run WebAPI
```bash
cd webapi
dotnet restore
dotnet run
# Access: http://localhost:5000
```

### Build Docker Images

```bash
# Build webapp
docker build -t harbor.local/sample-app/webapp:latest ./webapp

# Build webapi
docker build -t harbor.local/sample-app/webapi:latest ./webapi
```

### Deploy to Kubernetes

```bash
# Create dev namespace
kubectl apply -f ../manifests/dev/namespace.yaml

# Create Harbor registry secret
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.local \
  --docker-username=admin \
  --docker-password=HarborAdmin123 \
  --namespace=dev

# Apply Kubernetes manifests
kubectl apply -f ../manifests/dev/webapp-deployment.yaml
kubectl apply -f ../manifests/dev/webapp-service.yaml
kubectl apply -f ../manifests/dev/webapi-deployment.yaml
kubectl apply -f ../manifests/dev/webapi-service.yaml
kubectl apply -f ../manifests/dev/ingress.yaml
kubectl apply -f ../manifests/dev/configmap.yaml

# Or use Argo CD Applications
kubectl apply -f ../gitops/argocd-apps/
```

## Environment Variables

### Webapp
- `NEXT_PUBLIC_API_URL`: Backend API URL (default: http://localhost:5000)
- `NODE_ENV`: Node environment (development/production)
- `PORT`: Server port (default: 3000)

### WebAPI
- `ASPNETCORE_ENVIRONMENT`: Environment (Development/Production)
- `ASPNETCORE_URLS`: Listening URLs (default: http://+:5000)

## Access Applications

After deployment, add to `/etc/hosts`:
```
127.0.0.1 webapp.local api.local
```

Then access:
- **Webapp:** http://webapp.local
- **WebAPI:** http://api.local
- **API Swagger:** http://api.local/swagger

## Jenkins Pipelines

Each application has its own complete CI/CD pipeline:

**Pipeline Stages:**

1. **Vault Login:** Authenticate with HashiCorp Vault using AppRole
2. **Checkout:** Clone source code from Git
3. **Read Secrets:** Retrieve GitHub credentials from Vault
4. **Build with Kaniko:** Build Docker image (no privileged mode)
5. **Security Scan:** Scan image with Trivy for vulnerabilities
6. **Update Manifests:** Update Kubernetes manifests with new image tags
7. **Trigger Argo CD:** Trigger GitOps deployment
8. **Record Build:** Store build metadata in Vault for audit

## Documentation

- [Webapp README](webapp/README.md) - Next.js development guide
- [WebAPI README](webapi/README.md) - C# API development guide
- [Webapp Jenkinsfile](webapp/Jenkinsfile) - Webapp CI/CD pipeline
- [WebAPI Jenkinsfile](webapi/Jenkinsfile) - WebAPI CI/CD pipeline
- [Manifests README](../manifests/README.md) - Kubernetes deployments
- [Argo CD Apps README](../gitops/argocd-apps/README.md) - GitOps applications
- [Vault Secrets Guide](../docs/vault-secrets-management.md) - Secrets management
- [Jenkinsfile Explained](../docs/jenkinsfile-vault-explained.md) - Pipeline documentation
- [Archived Pipelines](../pipelines-archive/README.md) - Legacy monolithic pipelines (reference only)
