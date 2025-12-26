# WebAPI Dev Environment Policy
# This policy allows webapi pods in dev namespace to read their secrets

# Allow webapi to read its own secrets in dev environment
path "secret/data/dev/webapi" {
  capabilities = ["read"]
}

# Allow webapi to read shared dev secrets
path "secret/data/dev/shared/*" {
  capabilities = ["read"]
}

# Allow webapi to read database credentials
path "secret/data/dev/database" {
  capabilities = ["read"]
}

# Deny access to other services' secrets
path "secret/data/dev/webapp" {
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
