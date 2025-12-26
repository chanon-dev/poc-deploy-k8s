# Jenkins CI Policy
# This policy allows Jenkins to read secrets for CI/CD pipeline

# Allow Jenkins to read application secrets for all environments during build
path "secret/data/ci/docker/*" {
  capabilities = ["read", "list"]
}

# Allow Jenkins to read Harbor registry credentials
path "secret/data/ci/harbor" {
  capabilities = ["read"]
}

# Allow Jenkins to read GitHub credentials
path "secret/data/ci/github" {
  capabilities = ["read"]
}

# Allow Jenkins to read Argo CD credentials
path "secret/data/ci/argocd" {
  capabilities = ["read"]
}

# Allow Jenkins to write build-time secrets (like build artifacts info)
path "secret/data/ci/builds/*" {
  capabilities = ["create", "update", "read"]
}

# Allow Jenkins to read dev environment secrets (for dev builds only)
path "secret/data/dev/*" {
  capabilities = ["read", "list"]
}

# Deny access to production secrets from Jenkins
# Production deployments should use separate approval process
path "secret/data/prod/*" {
  capabilities = ["deny"]
}
