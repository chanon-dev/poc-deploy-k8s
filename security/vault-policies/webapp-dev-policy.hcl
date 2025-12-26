# Webapp Dev Environment Policy
# This policy allows webapp pods in dev namespace to read their secrets

# Allow webapp to read its own secrets in dev environment
path "secret/data/dev/webapp" {
  capabilities = ["read"]
}

# Allow webapp to read shared dev secrets (like database connection strings)
path "secret/data/dev/shared/*" {
  capabilities = ["read"]
}

# Deny access to other services' secrets
path "secret/data/dev/webapi" {
  capabilities = ["deny"]
}

# Deny access to other environments
path "secret/data/sit/*" {
  capabilities = ["deny"]
}

path "secret/data/uat/*" {
  capabilities = ["deny"]
}

path "secret/data/prod/*" {
  capabilities = ["deny"]
}
