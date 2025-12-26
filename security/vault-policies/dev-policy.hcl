# Policy for Dev Environment
# Applications in dev namespace can read secrets from secret/dev/*

path "secret/data/dev/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/dev/*" {
  capabilities = ["list"]
}

# Allow reading specific finance service secrets
path "secret/data/dev/finance-service/*" {
  capabilities = ["read"]
}

# Deny delete capability
path "secret/data/dev/*" {
  capabilities = ["delete"]
  deny = true
}
