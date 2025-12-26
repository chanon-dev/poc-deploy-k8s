# Jenkinsfile.vault - Complete Explanation

Jenkinsfile สำหรับ CI/CD Pipeline ที่ใช้ Vault จัดการ secrets แทน Jenkins Credentials

## 📋 Table of Contents

1. [Overview](#overview)
2. [Pipeline Flow](#pipeline-flow)
3. [Environment Variables](#environment-variables)
4. [Stage-by-Stage Explanation](#stage-by-stage-explanation)
5. [Key Features](#key-features)
6. [Dependencies](#dependencies)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### ความแตกต่างจาก Jenkinsfile ธรรมดา

| Aspect | Jenkinsfile (ธรรมดา) | Jenkinsfile.vault (Best Practice) |
|--------|----------------------|-----------------------------------|
| Secrets Storage | Jenkins Credentials | HashiCorp Vault |
| Security | Jenkins RBAC | Vault Policies + Jenkins RBAC |
| Audit Trail | Jenkins logs | Vault audit logs + Jenkins logs |
| Secret Rotation | Manual | Automated via Vault |
| Access Control | Jenkins only | Vault policies (fine-grained) |
| Build Metadata | None | Stored in Vault for audit |

### Required Jenkins Credentials

**เพียง 2 credentials:**
1. `vault-role-id` (Secret text) - Vault AppRole Role ID
2. `vault-secret-id` (Secret text) - Vault AppRole Secret ID

**ไม่ต้องเก็บ:**
- ❌ Harbor password
- ❌ GitHub token
- ❌ Argo CD token
- ❌ Build secrets

ทุกอย่างดึงจาก Vault แบบ dynamic!

---

## Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Vault Login (AppRole)                                       │
│     Jenkins credentials → Vault token (1h TTL)                  │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. Checkout Code                                               │
│     Git clone from repository                                   │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. Read Secrets from Vault                                     │
│     - Harbor credentials                                        │
│     - GitHub token                                              │
│     - Build secrets (if any)                                    │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. Build Webapp (Next.js)                                      │
│     docker build webapp:${BUILD_TAG}                            │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│  5. Build WebAPI (C#)                                           │
│     docker build webapi:${BUILD_TAG}                            │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│  6. Security Scan (Parallel)                                    │
│     ├─ Trivy scan webapp                                        │
│     └─ Trivy scan webapi                                        │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│  7. Push to Harbor                                              │
│     Using credentials from Vault                                │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│  8. Update Kubernetes Manifests                                 │
│     Commit new image tags to Git                                │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│  9. Trigger Argo CD Sync                                        │
│     API call to Argo CD                                         │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 10. Record Build in Vault                                       │
│     Store build metadata for audit trail                        │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 11. Cleanup                                                     │
│     - Remove sensitive files (.vault-token, .harbor-creds)      │
│     - Remove Docker images (if Docker available)                │
│     - Clean workspace                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Environment Variables

### Vault Configuration

```groovy
VAULT_ADDR = 'http://vault.vault.svc.cluster.local:8200'
VAULT_ROLE = 'jenkins-ci'
```

- **VAULT_ADDR**: Vault service URL (Kubernetes internal)
- **VAULT_ROLE**: AppRole role name (not used directly, for reference)

### Harbor Registry

```groovy
HARBOR_REGISTRY = 'harbor.local'
HARBOR_PROJECT = 'sample-app'
```

- **HARBOR_REGISTRY**: Harbor registry hostname
- **HARBOR_PROJECT**: Project name in Harbor

### Image Names

```groovy
WEBAPP_IMAGE = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/webapp"
WEBAPI_IMAGE = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/webapi"
```

- **WEBAPP_IMAGE**: `harbor.local/sample-app/webapp`
- **WEBAPI_IMAGE**: `harbor.local/sample-app/webapi`

### Build Information

```groovy
GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
BUILD_TAG = "${env.BUILD_NUMBER}-${GIT_COMMIT_SHORT}"
```

- **GIT_COMMIT_SHORT**: Short Git commit hash (7 characters)
- **BUILD_TAG**: `<build-number>-<commit-hash>` (e.g., `5-30496a2`)

### Repository Configuration

```groovy
K8S_REPO = 'https://github.com/chanon-dev/poc-deploy-k8s.git'
K8S_BRANCH = 'main'
```

- **K8S_REPO**: Kubernetes manifests repository
- **K8S_BRANCH**: Target branch for manifest updates

### Docker Options

```groovy
DOCKER_BUILDKIT = '1'
```

- Enables Docker BuildKit for faster builds and better caching

---

## Stage-by-Stage Explanation

### Stage 1: Vault Login

**Purpose:** Authenticate to Vault and get a short-lived token

```groovy
stage('Vault Login') {
    steps {
        script {
            withCredentials([
                string(credentialsId: 'vault-role-id', variable: 'VAULT_ROLE_ID'),
                string(credentialsId: 'vault-secret-id', variable: 'VAULT_SECRET_ID')
            ]) {
                sh '''
                    # Login to Vault using AppRole
                    RESPONSE=$(curl -s --request POST \
                        --data "{\\"role_id\\": \\"${VAULT_ROLE_ID}\\", \\"secret_id\\": \\"${VAULT_SECRET_ID}\\"}" \
                        ${VAULT_ADDR}/v1/auth/approle/login)

                    # Extract token using grep and cut (no jq dependency)
                    VAULT_TOKEN=$(echo "$RESPONSE" | grep -o '"client_token":"[^"]*' | cut -d'"' -f4)

                    # Validate token
                    if [ -z "$VAULT_TOKEN" ] || [ "$VAULT_TOKEN" = "null" ]; then
                        echo "❌ Error: Failed to get Vault token"
                        exit 1
                    fi

                    # Save token for subsequent stages
                    echo "$VAULT_TOKEN" > .vault-token
                '''
            }
        }
    }
}
```

**Key Points:**

1. **AppRole Authentication:**
   - Uses Role ID + Secret ID (stored in Jenkins)
   - Returns a Vault token with 1h TTL

2. **No jq Dependency:**
   - Uses `grep -o '"client_token":"[^"]*'` to find pattern
   - Uses `cut -d'"' -f4` to extract value
   - Works on any Linux system without additional tools

3. **Error Handling:**
   - Validates token is not empty or null
   - Exits with error code 1 if login fails

4. **Token Storage:**
   - Saves token to `.vault-token` file
   - Used by all subsequent stages
   - Deleted in cleanup phase

**Vault API Call:**

```bash
POST http://vault.vault.svc.cluster.local:8200/v1/auth/approle/login
Body: {"role_id": "...", "secret_id": "..."}

Response:
{
  "auth": {
    "client_token": "hvs.xxxxxxxxxxxx",
    "accessor": "...",
    "policies": ["jenkins-ci"],
    "token_type": "service",
    "lease_duration": 3600
  }
}
```

---

### Stage 2: Checkout

**Purpose:** Clone source code from Git repository

```groovy
stage('Checkout') {
    steps {
        echo 'Checking out source code...'
        checkout scm
    }
}
```

**Key Points:**

- Uses Jenkins SCM configuration (from pipeline job settings)
- Checks out the branch specified in job configuration
- Sets `GIT_COMMIT_SHORT` environment variable

---

### Stage 3: Read Secrets from Vault

**Purpose:** Retrieve all necessary secrets from Vault

```groovy
stage('Read Secrets from Vault') {
    steps {
        script {
            sh '''
                export VAULT_TOKEN=$(cat .vault-token)

                # Read Harbor credentials (without jq)
                RESPONSE=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/secret/data/ci/harbor)
                HARBOR_USERNAME=$(echo "$RESPONSE" | grep -o '"username":"[^"]*' | cut -d'"' -f4)
                HARBOR_PASSWORD=$(echo "$RESPONSE" | grep -o '"password":"[^"]*' | cut -d'"' -f4)

                # Save to environment file
                echo "HARBOR_USERNAME=${HARBOR_USERNAME}" > .harbor-creds
                echo "HARBOR_PASSWORD=${HARBOR_PASSWORD}" >> .harbor-creds

                # Read GitHub credentials
                RESPONSE=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/secret/data/ci/github)
                GIT_USERNAME=$(echo "$RESPONSE" | grep -o '"username":"[^"]*' | cut -d'"' -f4)
                GIT_TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

                echo "GIT_USERNAME=${GIT_USERNAME}" > .git-creds
                echo "GIT_TOKEN=${GIT_TOKEN}" >> .git-creds

                # Read build secrets (optional)
                RESPONSE=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/secret/data/ci/docker/build-args 2>/dev/null || echo "")
                NPM_TOKEN=$(echo "$RESPONSE" | grep -o '"npm_token":"[^"]*' | cut -d'"' -f4)

                if [ ! -z "$NPM_TOKEN" ] && [ "$NPM_TOKEN" != "null" ]; then
                    echo "NPM_TOKEN=${NPM_TOKEN}" > .build-secrets
                fi
            '''
        }
    }
}
```

**Secrets Retrieved:**

1. **Harbor Credentials** (`secret/ci/harbor`):
   - `username` → Docker registry login
   - `password` → Docker registry password

2. **GitHub Credentials** (`secret/ci/github`):
   - `username` → Git committer name
   - `token` → GitHub Personal Access Token

3. **Build Secrets** (`secret/ci/docker/build-args` - optional):
   - `npm_token` → NPM registry token (if needed)
   - Other build-time secrets

**Why Save to Files:**

- Credentials saved to temporary files (`.harbor-creds`, `.git-creds`)
- Files are sourced in later stages when needed
- All files deleted in cleanup phase
- Prevents secrets from appearing in build logs

---

### Stage 4: Build Webapp

**Purpose:** Build Next.js Docker image

```groovy
stage('Build Webapp') {
    steps {
        dir('app/webapp') {
            script {
                sh """
                    # Source build secrets if available
                    [ -f ../../.build-secrets ] && source ../../.build-secrets || true

                    docker build \
                        -t ${WEBAPP_IMAGE}:${BUILD_TAG} \
                        -t ${WEBAPP_IMAGE}:latest \
                        --build-arg NEXT_PUBLIC_API_URL=http://webapi-service:5000 \
                        .
                """
            }
        }
    }
}
```

**Key Points:**

1. **Multi-tag:**
   - Tags with both `BUILD_TAG` (specific version) and `latest`
   - Example: `harbor.local/sample-app/webapp:5-30496a2` and `harbor.local/sample-app/webapp:latest`

2. **Build Args:**
   - `NEXT_PUBLIC_API_URL`: Backend API URL for Next.js

3. **Build Secrets:**
   - Sources `.build-secrets` if exists (contains NPM_TOKEN, etc.)
   - Secrets available as environment variables during build

4. **Docker BuildKit:**
   - Enabled via `DOCKER_BUILDKIT=1` environment variable
   - Faster builds with better caching

---

### Stage 5: Build WebAPI

**Purpose:** Build C# ASP.NET Core Docker image

```groovy
stage('Build WebAPI') {
    steps {
        dir('app/webapi') {
            script {
                sh """
                    docker build \
                        -t ${WEBAPI_IMAGE}:${BUILD_TAG} \
                        -t ${WEBAPI_IMAGE}:latest \
                        .
                """
            }
        }
    }
}
```

**Key Points:**

- Simpler than webapp (no build args needed)
- Multi-stage Docker build (.NET SDK → Runtime)
- Tags with both specific version and `latest`

---

### Stage 6: Security Scan

**Purpose:** Scan Docker images for vulnerabilities

```groovy
stage('Security Scan') {
    parallel {
        stage('Scan Webapp') {
            steps {
                sh """
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        ${WEBAPP_IMAGE}:${BUILD_TAG} || true
                """
            }
        }
        stage('Scan WebAPI') {
            steps {
                sh """
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        ${WEBAPI_IMAGE}:${BUILD_TAG} || true
                """
            }
        }
    }
}
```

**Key Points:**

1. **Parallel Execution:**
   - Scans both images simultaneously
   - Reduces total pipeline time

2. **Trivy Scanner:**
   - Industry-standard vulnerability scanner
   - Checks for CVEs in base images and dependencies

3. **Severity Levels:**
   - Only reports HIGH and CRITICAL vulnerabilities
   - Can be adjusted based on security requirements

4. **Non-Blocking:**
   - `--exit-code 0` prevents pipeline failure on findings
   - `|| true` ensures stage always succeeds
   - Change to blocking for stricter enforcement

**Production Recommendation:**

```groovy
--exit-code 1  // Fail pipeline if HIGH/CRITICAL found
```

---

### Stage 7: Push to Harbor

**Purpose:** Push Docker images to Harbor registry

```groovy
stage('Push to Harbor') {
    steps {
        script {
            sh '''
                # Source Harbor credentials
                source .harbor-creds

                # Docker login
                echo "${HARBOR_PASSWORD}" | docker login ${HARBOR_REGISTRY} -u "${HARBOR_USERNAME}" --password-stdin

                # Push images
                docker push ${WEBAPP_IMAGE}:${BUILD_TAG}
                docker push ${WEBAPP_IMAGE}:latest
                docker push ${WEBAPI_IMAGE}:${BUILD_TAG}
                docker push ${WEBAPI_IMAGE}:latest

                # Logout
                docker logout ${HARBOR_REGISTRY}
            '''
        }
    }
}
```

**Key Points:**

1. **Credential Sourcing:**
   - Sources `.harbor-creds` file (created in Stage 3)
   - Credentials not visible in logs

2. **Secure Login:**
   - Uses `--password-stdin` to avoid password in process list
   - More secure than `-p password`

3. **Push Both Tags:**
   - Pushes specific version (`5-30496a2`)
   - Pushes `latest` for convenience

4. **Cleanup:**
   - Logs out from registry
   - Prevents credential leakage

---

### Stage 8: Update Kubernetes Manifests

**Purpose:** Update deployment manifests with new image tags

```groovy
stage('Update Kubernetes Manifests') {
    steps {
        script {
            sh """
                # Source Git credentials
                source .git-creds

                # Clone manifest repository
                rm -rf k8s-manifests
                git clone ${K8S_REPO} k8s-manifests
                cd k8s-manifests

                # Configure git
                git config user.name "Jenkins CI"
                git config user.email "jenkins@example.com"

                # Update image tags
                sed -i 's|image: ${WEBAPP_IMAGE}:.*|image: ${WEBAPP_IMAGE}:${BUILD_TAG}|' \
                    environments/dev/webapp-deployment.yaml

                sed -i 's|image: ${WEBAPI_IMAGE}:.*|image: ${WEBAPI_IMAGE}:${BUILD_TAG}|' \
                    environments/dev/webapi-deployment.yaml

                # Commit and push
                git add .
                git commit -m "Update images to version ${BUILD_TAG}" || true
                git push https://\${GIT_USERNAME}:\${GIT_TOKEN}@github.com/chanon-dev/poc-deploy-k8s.git ${K8S_BRANCH}
            """
        }
    }
}
```

**Key Points:**

1. **GitOps Pattern:**
   - All deployments defined in Git
   - No `kubectl apply` from Jenkins
   - Argo CD watches Git for changes

2. **Image Tag Update:**
   - Uses `sed` to replace image tags
   - Updates specific deployment files

3. **Git Commit:**
   - Creates commit with new image tags
   - Commit message includes build tag for traceability

4. **Authentication:**
   - Uses GitHub token from Vault
   - Embedded in Git URL (HTTPS)

---

### Stage 9: Trigger Argo CD Sync

**Purpose:** Trigger immediate deployment via Argo CD API

```groovy
stage('Trigger ArgoCD Sync') {
    steps {
        script {
            sh '''
                export VAULT_TOKEN=$(cat .vault-token)

                # Read Argo CD token from Vault
                ARGOCD_TOKEN=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
                    ${VAULT_ADDR}/v1/secret/data/ci/argocd | grep -o '"token":"[^"]*' | cut -d'"' -f4)

                # Sync applications
                curl -k -X POST \
                    -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
                    -H "Content-Type: application/json" \
                    https://argocd.local/api/v1/applications/sample-webapp/sync

                curl -k -X POST \
                    -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
                    -H "Content-Type: application/json" \
                    https://argocd.local/api/v1/applications/sample-webapi/sync
            '''
        }
    }
}
```

**Key Points:**

1. **Optional Stage:**
   - Argo CD auto-syncs by default
   - This forces immediate sync instead of waiting

2. **API Authentication:**
   - Reads Argo CD token from Vault
   - No Argo CD credentials in Jenkins

3. **Separate Syncs:**
   - Syncs webapp and webapi applications separately
   - Better control and visibility

---

### Stage 10: Record Build in Vault

**Purpose:** Store build metadata in Vault for audit trail

```groovy
stage('Record Build in Vault') {
    steps {
        script {
            sh '''
                export VAULT_TOKEN=$(cat .vault-token)

                # Store build metadata
                curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
                    -H "Content-Type: application/json" \
                    -X POST \
                    -d "{\\"data\\": {\\"build_number\\": \\"${BUILD_NUMBER}\\", \\"git_commit\\": \\"${GIT_COMMIT_SHORT}\\", \\"webapp_image\\": \\"${WEBAPP_IMAGE}:${BUILD_TAG}\\", \\"webapi_image\\": \\"${WEBAPI_IMAGE}:${BUILD_TAG}\\", \\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\\"}}" \
                    ${VAULT_ADDR}/v1/secret/data/ci/builds/${BUILD_NUMBER}
            '''
        }
    }
}
```

**Stored Data:**

```json
{
  "build_number": "5",
  "git_commit": "30496a2",
  "webapp_image": "harbor.local/sample-app/webapp:5-30496a2",
  "webapi_image": "harbor.local/sample-app/webapi:5-30496a2",
  "timestamp": "2025-12-26T23:15:30Z"
}
```

**Vault Path:** `secret/ci/builds/<build-number>`

**Benefits:**

- Complete audit trail of all builds
- Can trace which commit produced which images
- Immutable record (Vault audit logs)
- Useful for incident investigation

---

### Post Actions

**Purpose:** Cleanup and notifications

```groovy
post {
    success {
        echo "Pipeline completed successfully!"
        echo "Webapp image: ${WEBAPP_IMAGE}:${BUILD_TAG}"
        echo "WebAPI image: ${WEBAPI_IMAGE}:${BUILD_TAG}"
    }

    failure {
        echo "Pipeline failed!"
    }

    always {
        script {
            // Clean up sensitive files
            sh """
                rm -f .vault-token .harbor-creds .git-creds .build-secrets || true
            """

            // Clean up Docker images (only if docker exists)
            sh """
                if command -v docker &> /dev/null; then
                    docker rmi ${WEBAPP_IMAGE}:${BUILD_TAG} 2>/dev/null || true
                    docker rmi ${WEBAPP_IMAGE}:latest 2>/dev/null || true
                    docker rmi ${WEBAPI_IMAGE}:${BUILD_TAG} 2>/dev/null || true
                    docker rmi ${WEBAPI_IMAGE}:latest 2>/dev/null || true
                    echo "✅ Docker images cleaned up"
                else
                    echo "⚠️  Docker not available, skipping image cleanup"
                fi
            """
        }

        // Clean workspace (no plugin required)
        deleteDir()
    }
}
```

**Key Points:**

1. **Success Block:**
   - Displays final image names
   - Can add Slack/email notifications here

2. **Failure Block:**
   - Simple message
   - Can add alerting here

3. **Always Block:**
   - Runs regardless of build status
   - Cleanup is critical for security

4. **Sensitive Files Cleanup:**
   - Removes all credential files
   - Prevents secrets from persisting on Jenkins node

5. **Docker Image Cleanup:**
   - Checks if Docker is available first
   - Removes images to save disk space
   - Non-fatal if fails

6. **Workspace Cleanup:**
   - Uses `deleteDir()` (built-in, no plugin needed)
   - Alternative to `cleanWs()` which requires plugin

---

## Key Features

### 1. ✅ No jq Dependency

**Traditional Approach:**
```bash
VAULT_TOKEN=$(... | jq -r '.auth.client_token')
```

**Our Approach:**
```bash
VAULT_TOKEN=$(echo "$RESPONSE" | grep -o '"client_token":"[^"]*' | cut -d'"' -f4)
```

**Benefits:**
- Works on minimal Jenkins agents
- No additional tool installation required
- Standard Unix tools (grep, cut) only

### 2. ✅ Optional Docker

**Smart Docker Detection:**
```bash
if command -v docker &> /dev/null; then
    docker rmi ${IMAGE} || true
else
    echo "Docker not available, skipping..."
fi
```

**Benefits:**
- Pipeline doesn't fail if Docker unavailable
- Graceful degradation
- Clear messaging in logs

### 3. ✅ No Plugins Required

**Uses built-in functions:**
- `deleteDir()` instead of `cleanWs()`
- `checkout scm` instead of custom Git plugins
- `withCredentials` (core plugin)

**Benefits:**
- Minimal Jenkins installation
- Fewer dependency issues
- Faster Jenkins startup

### 4. ✅ Comprehensive Error Handling

**Token Validation:**
```bash
if [ -z "$VAULT_TOKEN" ] || [ "$VAULT_TOKEN" = "null" ]; then
    echo "❌ Error: Failed to get Vault token"
    echo "Response: $RESPONSE"
    exit 1
fi
```

**Benefits:**
- Clear error messages
- Pipeline fails fast
- Debug information included

### 5. ✅ Security Best Practices

**Credentials Management:**
- All secrets from Vault (not Jenkins)
- Short-lived Vault tokens (1h TTL)
- Credentials deleted after use
- No secrets in logs

**Audit Trail:**
- Build metadata stored in Vault
- Vault audit logs all secret access
- Git commits track all changes

---

## Dependencies

### Required Tools on Jenkins Agent

| Tool | Purpose | Installed by Default |
|------|---------|---------------------|
| `bash` | Shell scripting | ✅ Yes |
| `curl` | HTTP requests | ✅ Yes |
| `grep` | Pattern matching | ✅ Yes |
| `cut` | Text extraction | ✅ Yes |
| `sed` | Text replacement | ✅ Yes |
| `git` | Version control | ✅ Usually |
| `docker` | Container builds | ❌ No |

### Optional Tools

| Tool | Purpose | Required |
|------|---------|----------|
| `jq` | JSON parsing | ❌ No (we use grep/cut) |
| `Workspace Cleanup Plugin` | Clean workspace | ❌ No (we use deleteDir) |

### Jenkins Plugins Required

1. **Pipeline** (workflow-aggregator)
2. **Git** (git)
3. **Credentials Binding** (credentials-binding)

All standard plugins, usually pre-installed.

---

## Troubleshooting

### Issue 1: "jq: not found"

**Error:**
```
/script.sh: 3: jq: not found
```

**Solution:**
✅ Already fixed! We use grep/cut instead of jq

### Issue 2: "docker: not found"

**Error:**
```
/script.sh: 5: docker: not found
```

**Solutions:**

**Option A: Install Docker in Jenkins agent**
```yaml
# Add to Jenkins values.yaml
agent:
  volumes:
    - type: HostPath
      hostPath: /var/run/docker.sock
      mountPath: /var/run/docker.sock
```

**Option B: Use Docker-in-Docker**
```groovy
agent {
    docker {
        image 'docker:latest'
        args '-v /var/run/docker.sock:/var/run/docker.sock'
    }
}
```

**Option C: Use Kaniko (no Docker daemon needed)**
```bash
# Replace docker build with kaniko
/kaniko/executor --dockerfile Dockerfile --destination ${IMAGE}:${TAG}
```

### Issue 3: "cleanWs: No such DSL method"

**Error:**
```
No such DSL method 'cleanWs' found
```

**Solution:**
✅ Already fixed! We use deleteDir() instead

### Issue 4: Vault Login Failed

**Error:**
```
❌ Error: Failed to get Vault token
```

**Check:**

1. **Vault is accessible:**
   ```bash
   curl http://vault.vault.svc.cluster.local:8200/v1/sys/health
   ```

2. **Credentials are correct:**
   ```
   Jenkins → Credentials → vault-role-id, vault-secret-id
   ```

3. **AppRole exists:**
   ```bash
   kubectl exec -n vault vault-0 -- vault read auth/approle/role/jenkins-ci
   ```

### Issue 5: Harbor Push Failed

**Error:**
```
denied: requested access to the resource is denied
```

**Check:**

1. **Project exists in Harbor:**
   - Login to Harbor UI
   - Verify `sample-app` project exists

2. **Credentials in Vault:**
   ```bash
   kubectl exec -n vault vault-0 -- vault kv get secret/ci/harbor
   ```

3. **Network connectivity:**
   ```bash
   curl -I http://harbor.local
   ```

---

## Comparison with Standard Jenkinsfile

| Feature | Jenkinsfile | Jenkinsfile.vault |
|---------|-------------|-------------------|
| **Secrets Source** | Jenkins Credentials | HashiCorp Vault |
| **Number of Jenkins Credentials** | 4+ (Harbor, GitHub, Argo CD, etc.) | 2 (Vault Role/Secret ID) |
| **Secret Rotation** | Manual in Jenkins UI | Automatic via Vault |
| **Audit Trail** | Jenkins build logs only | Vault audit logs + Build metadata in Vault |
| **Security** | Credentials visible to Jenkins admins | Vault policies control access |
| **jq Dependency** | N/A | ❌ Removed (uses grep/cut) |
| **Plugin Dependencies** | Workspace Cleanup Plugin | ❌ Not required (uses deleteDir) |
| **Build Metadata** | Not stored | ✅ Stored in Vault |
| **Error Handling** | Basic | ✅ Comprehensive with validation |

---

## Best Practices

### 1. Vault Token Lifecycle

**Current: 1h TTL** (for Jenkins CI role)

```hcl
token_ttl=1h
token_max_ttl=4h
```

**Recommendations:**

- ✅ 1h TTL is good for most builds
- For long builds (>1h): Increase `token_ttl` to 2h or 4h
- For security: Keep `token_max_ttl` ≤ 4h

### 2. Secret Rotation

**Rotate regularly:**

```bash
# Rotate Vault AppRole Secret ID every 90 days
kubectl exec -n vault vault-0 -- vault write -f auth/approle/role/jenkins-ci/secret-id

# Update Jenkins credential with new Secret ID
```

**Automate with:**
- CronJob to rotate Secret ID
- Jenkins Job to update credentials

### 3. Build Metadata

**Current implementation:**
```json
{
  "build_number": "5",
  "git_commit": "30496a2",
  "webapp_image": "...",
  "webapi_image": "...",
  "timestamp": "..."
}
```

**Consider adding:**
- `triggered_by`: Who triggered the build
- `branch`: Git branch name
- `tests_passed`: Test results
- `scan_results`: Trivy scan summary

### 4. Notifications

**Add to post blocks:**

```groovy
post {
    success {
        slackSend(
            color: 'good',
            message: "Build ${BUILD_NUMBER} succeeded\nImages: ${BUILD_TAG}"
        )
    }
    failure {
        slackSend(
            color: 'danger',
            message: "Build ${BUILD_NUMBER} failed\nCheck: ${BUILD_URL}"
        )
    }
}
```

---

## Summary

### ✅ Advantages of Jenkinsfile.vault

1. **Security**: Centralized secrets management with Vault
2. **Auditability**: Complete audit trail in Vault
3. **Simplicity**: Only 2 Jenkins credentials needed
4. **Portability**: No jq or special plugins required
5. **Flexibility**: Easy secret rotation without touching Jenkins
6. **Metadata**: Build information stored for compliance

### ⚠️ Considerations

1. **Vault Dependency**: Pipeline fails if Vault unavailable
2. **Network**: Requires network access to Vault service
3. **Setup Complexity**: Initial Vault setup more complex
4. **Learning Curve**: Team needs to understand Vault

### 🎯 When to Use

**Use Jenkinsfile.vault when:**
- ✅ You have HashiCorp Vault deployed
- ✅ Security and compliance are important
- ✅ You need audit trails
- ✅ You have multiple pipelines sharing secrets
- ✅ You want automated secret rotation

**Use standard Jenkinsfile when:**
- ❌ No Vault infrastructure
- ❌ Simple, single pipeline
- ❌ Quick proof of concept
- ❌ Team not familiar with Vault

---

## Additional Resources

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault AppRole Auth Method](https://www.vaultproject.io/docs/auth/approle)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Vault Secrets Management Guide](vault-secrets-management.md)
- [Jenkins Setup Guide](jenkins-setup-guide.md)

---

**Document Version:** 1.0.0
**Last Updated:** 2025-12-27
**Author:** Platform Engineering Team
