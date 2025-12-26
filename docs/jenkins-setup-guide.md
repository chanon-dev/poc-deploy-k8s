# Jenkins Setup Guide - Complete Step-by-Step

Complete guide for setting up Jenkins UI for the sample application CI/CD pipeline.

## 📋 Table of Contents

1. [Initial Access](#1-initial-access)
2. [Install Required Plugins](#2-install-required-plugins)
3. [Configure Credentials](#3-configure-credentials)
4. [Create Pipeline Job](#4-create-pipeline-job)
5. [Configure GitHub Webhook](#5-configure-github-webhook)
6. [Run First Build](#6-run-first-build)
7. [Monitor and Troubleshoot](#7-monitor-and-troubleshoot)

---

## 1. Initial Access

### 1.1 Access Jenkins UI

**Method 1: Port Forward (Local Development)**

```bash
# Terminal 1: Port forward Jenkins service
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Access Jenkins at: http://localhost:8080
# Or: http://jenkins.local (if configured in /etc/hosts)
```

**Method 2: Ingress (Production)**

```
http://jenkins.local
```

### 1.2 Get Admin Password

```bash
# Get initial admin password
kubectl exec -n jenkins <jenkins-pod-name> -- cat /run/secrets/additional/chart-admin-password

# Or from secret
kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
echo
```

Example output:
```
Djo3yuw6Kk9oT8Gjrb69IY
```

### 1.3 First Login

1. Open browser: `http://jenkins.local`
2. Username: `admin`
3. Password: (from step 1.2)
4. Click **Sign in**

---

## 2. Install Required Plugins

### 2.1 Navigate to Plugin Manager

1. Click **Manage Jenkins** (left sidebar)
2. Click **Plugins** (or **Manage Plugins** in older versions)
3. Click **Available plugins** tab

### 2.2 Install Essential Plugins

Search and install these plugins:

#### Git & GitHub Integration
- [ ] **Git plugin** (usually pre-installed)
- [ ] **GitHub plugin**
- [ ] **GitHub Branch Source plugin**
- [ ] **Pipeline: GitHub**

#### Docker Support
- [ ] **Docker plugin**
- [ ] **Docker Pipeline**
- [ ] **Docker Commons Plugin**

#### Kubernetes Integration
- [ ] **Kubernetes plugin**
- [ ] **Kubernetes CLI plugin**

#### Pipeline & Build Tools
- [ ] **Pipeline**
- [ ] **Pipeline: Stage View**
- [ ] **Blue Ocean** (modern UI, optional but recommended)

#### Credentials
- [ ] **Credentials Binding Plugin** (usually pre-installed)

### 2.3 Install Plugins

1. Select all required plugins (check boxes)
2. Click **Install**
3. Choose **Restart Jenkins when installation is complete**
4. Wait for Jenkins to restart (~2-3 minutes)
5. Login again with admin credentials

---

## 3. Configure Credentials

### 3.1 Navigate to Credentials

1. Click **Manage Jenkins** (left sidebar)
2. Click **Credentials**
3. Click **System** under "Stores scoped to Jenkins"
4. Click **Global credentials (unrestricted)**
5. Click **+ Add Credentials** (left sidebar)

### 3.2 Add Harbor Registry Credentials

**For traditional Jenkinsfile (without Vault):**

1. **Kind:** `Username with password`
2. **Scope:** `Global (Jenkins, nodes, items, all child items, etc)`
3. **Username:** `admin`
4. **Password:** `HarborAdmin123`
5. **ID:** `harbor-credentials`
6. **Description:** `Harbor Container Registry Credentials`
7. Click **Create**

### 3.3 Add GitHub Credentials

#### Option A: Username + Personal Access Token (Recommended)

1. **Kind:** `Username with password`
2. **Scope:** `Global`
3. **Username:** `your-github-username`
4. **Password:** `ghp_your_github_personal_access_token`
5. **ID:** `github-credentials`
6. **Description:** `GitHub Repository Access Token`
7. Click **Create**

**How to create GitHub Personal Access Token:**
1. Go to GitHub.com
2. Click your profile → **Settings**
3. Scroll down → Click **Developer settings**
4. Click **Personal access tokens** → **Tokens (classic)**
5. Click **Generate new token** → **Generate new token (classic)**
6. Name: `Jenkins CI/CD`
7. Expiration: `90 days` or `No expiration`
8. Select scopes:
   - [x] `repo` (Full control of private repositories)
   - [x] `admin:repo_hook` (for webhooks)
9. Click **Generate token**
10. Copy token immediately (you won't see it again!)

#### Option B: SSH Key (Alternative)

1. **Kind:** `SSH Username with private key`
2. **Scope:** `Global`
3. **ID:** `github-ssh-key`
4. **Username:** `git`
5. **Private Key:** Enter directly or from file
6. Click **Create**

### 3.4 Add Vault Credentials (For Vault Integration)

#### Add Vault Role ID

1. **Kind:** `Secret text`
2. **Scope:** `Global`
3. **Secret:** `<vault-role-id from setup-vault-k8s-auth.sh output>`
4. **ID:** `vault-role-id`
5. **Description:** `Vault AppRole Role ID for Jenkins`
6. Click **Create**

#### Add Vault Secret ID

1. **Kind:** `Secret text`
2. **Scope:** `Global`
3. **Secret:** `<vault-secret-id from setup-vault-k8s-auth.sh output>`
4. **ID:** `vault-secret-id`
5. **Description:** `Vault AppRole Secret ID for Jenkins`
6. Click **Create**

**How to get Vault AppRole credentials:**

```bash
# Run the Vault setup script
cd /Users/chanon/Desktop/k8s/security/vault-policies
./setup-vault-k8s-auth.sh

# Output will show:
# Role ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# Secret ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy

# Copy these values and paste into Jenkins credentials
```

### 3.5 Add Argo CD Token (Optional - for manual sync trigger)

1. **Kind:** `Secret text`
2. **Scope:** `Global`
3. **Secret:** `<argocd-token>`
4. **ID:** `argocd-token`
5. **Description:** `Argo CD API Token`
6. Click **Create**

**How to get Argo CD token:**

```bash
# Login to Argo CD
argocd login argocd.local

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Generate token
argocd account generate-token --account admin
```

### 3.6 Verify All Credentials Created

Go back to **Credentials** → **System** → **Global credentials**

You should see:
- ✅ `harbor-credentials` (Username with password)
- ✅ `github-credentials` (Username with password)
- ✅ `vault-role-id` (Secret text)
- ✅ `vault-secret-id` (Secret text)
- ✅ `argocd-token` (Secret text) - Optional

---

## 4. Create Pipeline Job

### 4.1 Create New Item

1. Click **New Item** (left sidebar) or **+ New Item**
2. **Enter an item name:** `sample-app-pipeline`
3. Select **Pipeline**
4. Click **OK**

### 4.2 Configure General Settings

**Description (optional):**
```
CI/CD Pipeline for Sample Application (Next.js + C# WebAPI)
Builds Docker images, pushes to Harbor, and deploys via Argo CD
```

**Options to enable:**

- [x] **Discard old builds**
  - Strategy: `Log Rotation`
  - Days to keep builds: `30`
  - Max # of builds to keep: `10`

- [x] **Do not allow concurrent builds** (recommended to avoid conflicts)

- [ ] **GitHub project** (optional)
  - Project url: `https://github.com/chanon-dev/poc-deploy-k8s/`

### 4.3 Configure Build Triggers

Choose one or more:

#### Option A: Poll SCM (Simple, but less efficient)

- [x] **Poll SCM**
- Schedule: `H/5 * * * *` (check every 5 minutes)

#### Option B: GitHub hook trigger (Recommended)

- [x] **GitHub hook trigger for GITScm polling**
  - This requires webhook configuration (see Section 5)

#### Option C: Trigger builds remotely

- [x] **Trigger builds remotely**
- Authentication Token: `sample-app-build-token`
  - Used for API calls: `curl http://jenkins.local/job/sample-app-pipeline/build?token=sample-app-build-token`

### 4.4 Configure Pipeline Definition

**Pipeline Definition:** `Pipeline script from SCM`

**SCM:** `Git`

**Repository Configuration:**

1. **Repository URL:** `https://github.com/chanon-dev/poc-deploy-k8s.git`
   - Or SSH: `git@github.com:chanon-dev/poc-deploy-k8s.git` (if using SSH key)

2. **Credentials:** Select `github-credentials`

3. **Branches to build:**
   - Branch Specifier: `*/main` (or `*/master` if using master branch)

**Script Path:**

- **For Vault integration:** `app/Jenkinsfile.vault`
- **For traditional approach:** `app/Jenkinsfile`

**Additional Behaviours (optional but recommended):**

Click **Add** → **Advanced clone behaviours**
- [x] Shallow clone
- Shallow clone depth: `1`
- [x] Honor refspec on initial clone

Click **Add** → **Clean before checkout**
- [x] Delete untracked nested repositories

### 4.5 Configure Pipeline Environment

Scroll down to **Pipeline** section

**Advanced Options:**

Click **Advanced...**

**Display Name:** `Sample App CI/CD`

**Lightweight checkout:** [x] (enabled for better performance)

### 4.6 Save Configuration

Click **Save** button at the bottom

---

## 5. Configure GitHub Webhook

### 5.1 Prerequisites

Jenkins must be accessible from internet OR use GitHub Enterprise/ngrok for local dev

**For Local Development (using ngrok):**

```bash
# Install ngrok
brew install ngrok

# Start ngrok tunnel to Jenkins
ngrok http 8080

# Output example:
# Forwarding: https://abc123.ngrok.io -> http://localhost:8080
```

### 5.2 Configure Webhook in GitHub

1. Go to your GitHub repository: `https://github.com/chanon-dev/poc-deploy-k8s`
2. Click **Settings** (repository settings, not profile)
3. Click **Webhooks** (left sidebar)
4. Click **Add webhook**

**Webhook Configuration:**

1. **Payload URL:**
   - Production: `http://jenkins.local/github-webhook/`
   - With ngrok: `https://abc123.ngrok.io/github-webhook/`

2. **Content type:** `application/json`

3. **Secret:** (leave empty for now, or generate random string)

4. **Which events would you like to trigger this webhook?**
   - Select: **Just the push event**
   - Or: **Let me select individual events**
     - [x] Pushes
     - [x] Pull requests

5. **Active:** [x] (checked)

6. Click **Add webhook**

### 5.3 Verify Webhook

1. GitHub will send a test payload
2. Check **Recent Deliveries** tab
3. Look for green checkmark ✅
4. If red X ❌, click to see error details

**Common issues:**
- ❌ `Connection refused` → Jenkins not accessible
- ❌ `404 Not Found` → Wrong URL (check `/github-webhook/` at end)
- ❌ `403 Forbidden` → Jenkins security settings

---

## 6. Run First Build

### 6.1 Manual Build Trigger

1. Go to Jenkins dashboard: `http://jenkins.local`
2. Click on **sample-app-pipeline** job
3. Click **Build Now** (left sidebar)
4. Watch build appear in **Build History**
5. Click on **#1** (build number)
6. Click **Console Output** to see logs

### 6.2 Monitor Build Progress

**Using Classic UI:**

1. Click on build number (e.g., **#1**)
2. Click **Console Output**
3. Watch real-time logs
4. Look for **SUCCESS** or **FAILURE** at the end

**Using Blue Ocean UI (recommended):**

1. Click **Open Blue Ocean** (left sidebar)
2. Click on **sample-app-pipeline**
3. See visual pipeline with stages
4. Click on any stage to see logs

### 6.3 Understand Build Stages

**For Jenkinsfile.vault (with Vault):**

```
1. ⚙️  Vault Login                    (~5 seconds)
2. 📥 Checkout                        (~10 seconds)
3. 🔐 Read Secrets from Vault         (~5 seconds)
4. 🏗️  Build Webapp                   (~2-3 minutes)
5. 🏗️  Build WebAPI                   (~1-2 minutes)
6. 🔍 Security Scan (parallel)        (~1-2 minutes)
7. 📤 Push to Harbor                  (~1-2 minutes)
8. 📝 Update Kubernetes Manifests     (~10 seconds)
9. 🚀 Trigger ArgoCD Sync             (~5 seconds)
10. 💾 Record Build in Vault          (~5 seconds)
```

**Total time:** ~8-12 minutes for first build (Docker image caching helps subsequent builds)

### 6.4 Verify Build Success

**Check Console Output:**

```
[Pipeline] End of Pipeline
Finished: SUCCESS
```

**Check Build Artifacts:**

1. **Harbor Registry:**
   ```bash
   # Check images in Harbor
   curl -u admin:HarborAdmin123 http://harbor.local/api/v2.0/projects/sample-app/repositories
   ```

2. **Kubernetes Manifests:**
   ```bash
   # Check updated manifests in Git
   git log --oneline environments/dev/
   # Should see: "Update images to version <build-tag>"
   ```

3. **Argo CD:**
   ```bash
   # Check Argo CD sync status
   argocd app get sample-webapp
   argocd app get sample-webapi
   ```

### 6.5 Test Automatic Trigger

**Make a code change:**

```bash
cd /Users/chanon/Desktop/k8s
cd app/webapp/src/app

# Edit page.tsx - change title
# Before:
#   <h1>Sample Application</h1>
# After:
#   <h1>Sample Application v2</h1>

git add .
git commit -m "Update webapp title to v2"
git push origin main
```

**Watch Jenkins:**

1. Within 1-2 minutes, Jenkins should auto-trigger build
2. Check **Build History** for new build (#2)
3. Monitor build progress

---

## 7. Monitor and Troubleshoot

### 7.1 View Build History

**Dashboard:**

1. Click on **sample-app-pipeline**
2. See **Build History** (left sidebar)
   - 🟢 Blue ball = Success
   - 🔴 Red ball = Failure
   - ⚪ Gray ball = Aborted
   - 🟡 Yellow ball = Unstable

**Timeline:**

Click **Timeline** to see build duration over time

### 7.2 View Pipeline Logs

**Console Output:**
- Click build number → **Console Output**
- Full text logs of entire pipeline

**Stage Logs:**
- Click build number → **Pipeline Steps**
- Expand each stage to see specific logs

**Blue Ocean:**
- Better visualization
- Click stages to see logs
- Easier to identify failures

### 7.3 Common Issues and Solutions

#### Issue 1: "Failed to connect to repository"

**Error:**
```
Failed to connect to repository : Command "git ls-remote -h -- https://github.com/..."
```

**Solutions:**

1. Check GitHub credentials:
   ```
   Manage Jenkins → Credentials → Verify github-credentials
   ```

2. Test GitHub access:
   ```bash
   git ls-remote https://github.com/chanon-dev/poc-deploy-k8s.git
   ```

3. Check if token has `repo` scope

4. Try SSH instead of HTTPS

#### Issue 2: "Permission denied" for Docker

**Error:**
```
docker: Got permission denied while trying to connect to Docker daemon
```

**Solutions:**

1. Check Jenkins pod has access to Docker:
   ```bash
   kubectl exec -n jenkins <jenkins-pod> -- docker ps
   ```

2. Ensure Jenkins runs in privileged mode or Docker-in-Docker is configured

3. Check values.yaml for Jenkins Helm chart:
   ```yaml
   agent:
     workspaceVolume:
       type: DynamicPVC
     volumes:
     - type: HostPath
       hostPath: /var/run/docker.sock
       mountPath: /var/run/docker.sock
   ```

#### Issue 3: "Vault login failed"

**Error:**
```
curl: (7) Failed to connect to vault.vault.svc.cluster.local port 8200
```

**Solutions:**

1. Check Vault is running:
   ```bash
   kubectl get pods -n vault
   ```

2. Check Vault service:
   ```bash
   kubectl get svc -n vault
   ```

3. Verify credentials in Jenkins:
   ```
   Manage Jenkins → Credentials → vault-role-id, vault-secret-id
   ```

4. Test Vault access from Jenkins pod:
   ```bash
   kubectl exec -n jenkins <jenkins-pod> -- curl http://vault.vault.svc.cluster.local:8200/v1/sys/health
   ```

#### Issue 4: "Image push failed"

**Error:**
```
denied: requested access to the resource is denied
```

**Solutions:**

1. Check Harbor credentials
2. Verify project exists in Harbor: `sample-app`
3. Check project is public or credentials are correct
4. Test Docker login manually:
   ```bash
   docker login harbor.local -u admin -p HarborAdmin123
   ```

#### Issue 5: Build takes too long

**Solutions:**

1. Enable Docker layer caching
2. Use smaller base images
3. Increase Jenkins agent resources:
   ```yaml
   agent:
     resources:
       requests:
         cpu: "2"
         memory: "4Gi"
       limits:
         cpu: "4"
         memory: "8Gi"
   ```

4. Run security scans in parallel (already configured)
5. Use BuildKit for faster builds

### 7.4 View Jenkins System Logs

**System Log:**
1. **Manage Jenkins** → **System Log**
2. See all Jenkins system logs
3. Filter by log level (SEVERE, WARNING, INFO)

**Pod Logs:**
```bash
# View Jenkins pod logs
kubectl logs -n jenkins <jenkins-pod> --tail=100 -f

# View Jenkins agent logs (if using K8s plugin)
kubectl logs -n jenkins <agent-pod> -c jnlp
```

### 7.5 Performance Monitoring

**Build Trends:**
1. Dashboard → **Trend**
2. See build duration over time
3. Identify performance degradation

**Resource Usage:**
```bash
# Check Jenkins pod resources
kubectl top pod -n jenkins

# Check node resources
kubectl top nodes
```

### 7.6 Backup and Restore

**Backup Jenkins Configuration:**

```bash
# Backup Jenkins home
kubectl exec -n jenkins <jenkins-pod> -- tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home

# Copy backup locally
kubectl cp jenkins/<jenkins-pod>:/tmp/jenkins-backup.tar.gz ./jenkins-backup.tar.gz
```

**Restore:**

```bash
# Copy backup to pod
kubectl cp ./jenkins-backup.tar.gz jenkins/<jenkins-pod>:/tmp/

# Restore
kubectl exec -n jenkins <jenkins-pod> -- tar xzf /tmp/jenkins-backup.tar.gz -C /
```

---

## 8. Advanced Configuration

### 8.1 Configure Build Parameters

Make pipeline accept parameters:

1. Edit pipeline job
2. Check **This project is parameterized**
3. Click **Add Parameter** → **Choice Parameter**

**Example: Environment Parameter**

- Name: `ENVIRONMENT`
- Choices:
  ```
  dev
  sit
  uat
  prod
  ```
- Description: `Target environment for deployment`

**Use in Jenkinsfile:**

```groovy
pipeline {
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'sit', 'uat', 'prod'],
            description: 'Target environment'
        )
    }
    stages {
        stage('Deploy') {
            steps {
                echo "Deploying to ${params.ENVIRONMENT}"
            }
        }
    }
}
```

### 8.2 Configure Email Notifications

1. **Manage Jenkins** → **Configure System**
2. Scroll to **Extended E-mail Notification**
3. Configure SMTP server:
   - SMTP server: `smtp.gmail.com`
   - Use SMTP Authentication: [x]
   - Username: `your-email@gmail.com`
   - Password: `app-password` (not regular password)
   - Use SSL: [x]
   - SMTP port: `465`

4. Add to Jenkinsfile:

```groovy
post {
    failure {
        emailext (
            subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            body: "Check console output at ${env.BUILD_URL}",
            to: "team@example.com"
        )
    }
}
```

### 8.3 Configure Slack Notifications

1. Install **Slack Notification Plugin**
2. Get Slack webhook URL from Slack workspace
3. **Manage Jenkins** → **Configure System** → **Slack**
4. Configure:
   - Workspace: `your-workspace`
   - Credential: Add webhook URL as secret text
   - Default channel: `#ci-cd`

5. Add to Jenkinsfile:

```groovy
post {
    success {
        slackSend (
            color: 'good',
            message: "Build Success: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
}
```

---

## 9. Security Best Practices

### 9.1 Configure Role-Based Access Control

1. Install **Role-based Authorization Strategy** plugin
2. **Manage Jenkins** → **Security** → **Authorization**
3. Select **Role-Based Strategy**
4. **Manage and Assign Roles:**
   - **Admin** - Full access
   - **Developer** - Build, read, view
   - **Viewer** - Read only

### 9.2 Enable CSRF Protection

1. **Manage Jenkins** → **Security**
2. Check **Prevent Cross Site Request Forgery exploits**
3. Default crumb issuer: Standard

### 9.3 Configure Agent to Controller Security

1. **Manage Jenkins** → **Security**
2. **Agents** → **Agent to Controller Access Control**
3. Enable file access rules

### 9.4 Audit Logging

1. Install **Audit Trail Plugin**
2. **Manage Jenkins** → **System** → **Audit Trail**
3. Configure log location: `/var/jenkins_home/logs/audit.log`
4. Pattern: `%d{yyyy-MM-dd HH:mm:ss} %m%n`

---

## Summary Checklist

### Initial Setup
- [ ] Access Jenkins UI
- [ ] Get admin password
- [ ] Login successfully

### Plugin Installation
- [ ] Install Git plugins
- [ ] Install Docker plugins
- [ ] Install Kubernetes plugins
- [ ] Install Pipeline plugins
- [ ] Restart Jenkins

### Credentials Configuration
- [ ] Add Harbor credentials (`harbor-credentials`)
- [ ] Add GitHub token (`github-credentials`)
- [ ] Add Vault Role ID (`vault-role-id`)
- [ ] Add Vault Secret ID (`vault-secret-id`)
- [ ] Add Argo CD token (`argocd-token`) - Optional

### Pipeline Setup
- [ ] Create pipeline job (`sample-app-pipeline`)
- [ ] Configure Git repository
- [ ] Set script path (`app/Jenkinsfile.vault`)
- [ ] Configure build triggers
- [ ] Save configuration

### GitHub Integration
- [ ] Generate GitHub Personal Access Token
- [ ] Configure webhook in GitHub
- [ ] Verify webhook delivery

### First Build
- [ ] Trigger manual build
- [ ] Monitor build progress
- [ ] Verify build success
- [ ] Check Harbor images
- [ ] Test automatic trigger

### Verification
- [ ] Build completes successfully
- [ ] Images pushed to Harbor
- [ ] Manifests updated in Git
- [ ] Argo CD syncs applications
- [ ] Applications accessible

---

## Quick Reference

### Important URLs

- Jenkins UI: `http://jenkins.local`
- Blue Ocean: `http://jenkins.local/blue`
- Harbor: `http://harbor.local`
- Argo CD: `http://argocd.local`
- Vault: `http://vault.local`

### Common Commands

```bash
# Get Jenkins admin password
kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d

# Port forward Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# View Jenkins logs
kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins -f

# Restart Jenkins pod
kubectl rollout restart statefulset jenkins -n jenkins

# Check build images in Harbor
curl -u admin:HarborAdmin123 http://harbor.local/api/v2.0/projects/sample-app/repositories
```

---

**Need Help?**
- Jenkins Documentation: https://www.jenkins.io/doc/
- Plugin Index: https://plugins.jenkins.io/
- Community Forums: https://community.jenkins.io/

**Document Version:** 1.0.0
**Last Updated:** 2025-12-26
