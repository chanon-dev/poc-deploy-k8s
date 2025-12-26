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

### 3. CI/CD Configuration
- **Location:** `Jenkinsfile`
- **Contains:** Multi-stage Jenkins pipeline for building and deploying both applications

## CI/CD Pipeline Flow

```
1. Developer pushes code to Git
   ↓
2. Jenkins detects change (webhook)
   ↓
3. Jenkins builds Docker images
   ↓
4. Jenkins pushes images to Harbor
   ↓
5. Jenkins updates k8s-manifests with new image tags
   ↓
6. Argo CD detects manifest changes
   ↓
7. Argo CD deploys to Kubernetes
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
kubectl apply -f ../environments/dev/namespace.yaml

# Create Harbor registry secret
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.local \
  --docker-username=admin \
  --docker-password=HarborAdmin123 \
  --namespace=dev

# Apply Kubernetes manifests
kubectl apply -f ../environments/dev/webapp-deployment.yaml
kubectl apply -f ../environments/dev/webapp-service.yaml
kubectl apply -f ../environments/dev/webapi-deployment.yaml
kubectl apply -f ../environments/dev/webapi-service.yaml
kubectl apply -f ../environments/dev/ingress.yaml
kubectl apply -f ../environments/dev/configmap.yaml

# Or use Argo CD Applications
kubectl apply -f ../ci-cd/argocd-apps/
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

## Jenkins Pipeline

The `Jenkinsfile` defines a complete CI/CD pipeline:

1. **Checkout:** Clone source code
2. **Build Webapp:** Build Next.js Docker image
3. **Build WebAPI:** Build C# Docker image
4. **Security Scan:** Scan images with Trivy
5. **Push to Harbor:** Push images to Harbor registry
6. **Update Manifests:** Update Kubernetes manifests with new image tags
7. **Trigger Argo CD:** Trigger automatic deployment

## Documentation

- [Webapp README](webapp/README.md) - Next.js development guide
- [WebAPI README](webapi/README.md) - C# API development guide
- [Argo CD Apps README](../ci-cd/argocd-apps/README.md) - Deployment guide
