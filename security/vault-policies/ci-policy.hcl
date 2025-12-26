# Policy for CI/CD (Jenkins)
# Jenkins can read/write secrets in ci path and deploy to dev/sit

path "secret/data/ci/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/ci/*" {
  capabilities = ["list", "delete"]
}

# Allow Jenkins to update dev secrets
path "secret/data/dev/*" {
  capabilities = ["create", "read", "update", "list"]
}

# Allow Jenkins to update sit secrets
path "secret/data/sit/*" {
  capabilities = ["create", "read", "update", "list"]
}

# Read-only access to UAT for promotion
path "secret/data/uat/*" {
  capabilities = ["read", "list"]
}

# No access to prod secrets
path "secret/data/prod/*" {
  capabilities = ["deny"]
}
