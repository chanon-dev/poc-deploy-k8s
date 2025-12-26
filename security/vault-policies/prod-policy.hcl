# Policy for Prod Environment
# Applications in prod namespace can read secrets from secret/prod/*

path "secret/data/prod/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/prod/*" {
  capabilities = ["list"]
}

# Deny write and delete capabilities in production
path "secret/data/prod/*" {
  capabilities = ["create", "update", "delete"]
  deny = true
}
