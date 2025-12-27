# CI/CD Pipelines

Jenkins pipeline definitions for building and deploying applications.

## Available Pipelines

| Pipeline | Environment | Build Method | Security | Use Case |
|----------|-------------|--------------|----------|----------|
| **[Jenkinsfile](Jenkinsfile)** | Any | Docker (local) | Basic | Development/Testing |
| **[Jenkinsfile.vault](Jenkinsfile.vault)** | VM Jenkins | Docker | Vault integration | Development |
| **[Jenkinsfile.vault.k8s](Jenkinsfile.vault.k8s)** | Jenkins on K8s | Docker-in-Docker | Vault + Privileged | Development |
| **[Jenkinsfile.vault.kaniko](Jenkinsfile.vault.kaniko)** | Jenkins on K8s | **Kaniko** | **Vault + No privileged** | **Production** ⭐ |

## Quick Start

### For Local/VM Jenkins
```bash
# Jenkins job configuration
Pipeline script from SCM
Script Path: pipelines/Jenkinsfile.vault
```

### For Jenkins on Kubernetes
```bash
# Production (recommended)
Script Path: pipelines/Jenkinsfile.vault.kaniko

# Development only
Script Path: pipelines/Jenkinsfile.vault.k8s
```

## Pipeline Stages

All pipelines include:

1. **Vault Login** - Authenticate with HashiCorp Vault using AppRole
2. **Checkout** - Clone source code from Git
3. **Read Secrets** - Retrieve credentials from Vault dynamically
4. **Build Webapp** - Build Next.js Docker image
5. **Build WebAPI** - Build .NET Docker image
6. **Security Scan** - Scan images with Trivy (parallel)
7. **Push to Harbor** - Push images to container registry
8. **Update Manifests** - Update Kubernetes manifests with new image tags
9. **Trigger Argo CD** - Trigger GitOps deployment
10. **Record Build** - Store build metadata in Vault for audit

## Prerequisites

### Vault Credentials (All pipelines)

Required Jenkins credentials:
- `vault-role-id` (Secret text) - Vault AppRole Role ID
- `vault-secret-id` (Secret text) - Vault AppRole Secret ID

**Get credentials:**
```bash
cd ../security/vault-policies
./get-jenkins-credentials.sh
```

See: [Quick Start Guide](../security/vault-policies/QUICK-START.md)

### For Kaniko Pipeline Only

Create Harbor registry secret in Jenkins namespace:
```bash
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.local \
  --docker-username=admin \
  --docker-password=<your-password> \
  --namespace=jenkins
```

## Documentation

- **[Complete Pipeline Explanation](../docs/jenkinsfile-vault-explained.md)** - Deep dive into how pipelines work
  - Container build options comparison (Docker vs Kaniko)
  - Stage-by-stage breakdown
  - Security considerations
  - Production recommendations

- **[Vault Secrets Management](../docs/vault-secrets-management.md)** - How to manage secrets with Vault

- **[Jenkins Setup Guide](../docs/jenkins-setup-guide.md)** - Jenkins installation and configuration

## Choosing the Right Pipeline

### Development/Testing
- Use **Jenkinsfile** for quick local testing
- Use **Jenkinsfile.vault** for Vault integration testing

### Staging
- Use **Jenkinsfile.vault.kaniko** to test production-like setup

### Production
- Use **Jenkinsfile.vault.kaniko** (recommended)
  - ✅ No privileged mode required (secure)
  - ✅ Industry standard (Google, GitLab, Spotify)
  - ✅ Compliant with security standards (SOC 2, PCI-DSS)

## Architecture

```
Developer → Git Push
    ↓
Jenkins Pipeline (this dir)
    ↓
Docker/Kaniko Build
    ↓
Harbor Registry
    ↓
Update K8s Manifests (../manifests)
    ↓
Argo CD (../gitops/argocd-apps)
    ↓
Kubernetes Cluster
```

## Troubleshooting

### Build fails with "docker: not found"
- You're using Jenkinsfile.vault on Kubernetes
- **Solution**: Use Jenkinsfile.vault.kaniko or Jenkinsfile.vault.k8s instead

### Build fails with "Could not find credentials"
- Vault credentials not configured in Jenkins
- **Solution**: Follow [Quick Start Guide](../security/vault-policies/QUICK-START.md)

### Kaniko fails to push images
- Harbor registry secret not created
- **Solution**: Create `harbor-registry-secret` in jenkins namespace (see Prerequisites above)

## Related Directories

- **[../apps](../apps)** - Application source code
- **[../manifests](../manifests)** - Kubernetes manifests
- **[../gitops](../gitops)** - Argo CD applications
- **[../security/vault-policies](../security/vault-policies)** - Vault policies and scripts
