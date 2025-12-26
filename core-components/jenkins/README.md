# Jenkins Deployment / การติดตั้ง Jenkins

## Overview / ภาพรวม

Jenkins is deployed as the Continuous Integration (CI) server for the platform.

Jenkins ใช้เป็น CI server สำหรับ platform

## Prerequisites / สิ่งที่ต้องเตรียม

1. Kubernetes cluster running / Kubernetes cluster ทำงานอยู่
2. Helm 3 installed / ติดตั้ง Helm 3 แล้ว
3. kubectl configured / ตั้งค่า kubectl แล้ว
4. Storage class available / มี storage class

## Installation / วิธีการติดตั้ง

### Step 1: Add Jenkins Helm Repository
```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

### Step 2: Create Namespace
```bash
kubectl apply -f namespace.yaml
```

### Step 3: Create PVC (if not using dynamic provisioning)
```bash
kubectl apply -f pvc.yaml
```

### Step 4: Install Jenkins using Helm
```bash
# Install with custom values
helm install jenkins jenkins/jenkins \
  -f values.yaml \
  -n jenkins \
  --create-namespace

# Or upgrade if already installed
helm upgrade jenkins jenkins/jenkins \
  -f values.yaml \
  -n jenkins
```

### Step 5: Get Admin Password
```bash
# Get the initial admin password
kubectl exec -it svc/jenkins -n jenkins -- cat /run/secrets/additional/chart-admin-password

# Or use this command
printf $(kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

### Step 6: Access Jenkins
```bash
# Port forward for testing
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Open browser: http://localhost:8080
# Or access via ingress: https://jenkins.company.local
```

## Configuration / การตั้งค่า

### Jenkins Configuration as Code (JCasC)

Jenkins is configured using JCasC (Configuration as Code). All configurations are in the `values.yaml` file under `controller.JCasC.configScripts`.

Jenkins ใช้ JCasC (Configuration as Code) การตั้งค่าทั้งหมดอยู่ใน `values.yaml`

### Key Configurations / การตั้งค่าสำคัญ

1. **Kubernetes Cloud**: Jenkins uses Kubernetes to spawn dynamic agents
   - **TH:** ใช้ Kubernetes สร้าง agent แบบ dynamic

2. **Plugins**: Auto-installed via values.yaml
   - **TH:** ติดตั้ง plugin อัตโนมัติตาม values.yaml

3. **Security**: RBAC-based authorization
   - **TH:** ใช้ RBAC ควบคุมสิทธิ์

4. **Vault Integration**: HashiCorp Vault plugin installed
   - **TH:** มี plugin สำหรับเชื่อมกับ Vault

### Vault Integration / เชื่อมกับ Vault

```groovy
// In Jenkinsfile
pipeline {
    agent any
    environment {
        // Read secrets from Vault
        DB_PASSWORD = credentials('vault-db-password')
    }
    stages {
        stage('Build') {
            steps {
                sh 'echo "Using secret from Vault"'
            }
        }
    }
}
```

Configure Vault in Jenkins:
1. Go to: Manage Jenkins → Configure System → Vault Plugin
2. Set Vault URL: `http://vault.vault.svc.cluster.local:8200`
3. Configure authentication (Kubernetes auth recommended)

## Jenkins Agents / Jenkins Agents

### Dynamic Kubernetes Agents

Agents are spawned dynamically on Kubernetes:

```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.8.6-openjdk-11
    command: ['cat']
    tty: true
  - name: docker
    image: docker:latest
    command: ['cat']
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }
    stages {
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn clean package'
                }
            }
        }
        stage('Docker Build') {
            steps {
                container('docker') {
                    sh 'docker build -t myapp:latest .'
                }
            }
        }
    }
}
```

## Sample CI Pipeline / ตัวอย่าง CI Pipeline

```groovy
pipeline {
    agent {
        kubernetes {
            label 'jenkins-agent'
        }
    }

    environment {
        REGISTRY = 'harbor.company.local'
        IMAGE_NAME = 'myapp'
        GIT_COMMIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                sh 'npm install'
                sh 'npm test'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'sonar-scanner'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build -t ${REGISTRY}/${IMAGE_NAME}:${GIT_COMMIT_SHORT} .
                    docker tag ${REGISTRY}/${IMAGE_NAME}:${GIT_COMMIT_SHORT} ${REGISTRY}/${IMAGE_NAME}:latest
                """
            }
        }

        stage('Scan Image') {
            steps {
                sh "trivy image ${REGISTRY}/${IMAGE_NAME}:${GIT_COMMIT_SHORT}"
            }
        }

        stage('Push to Registry') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'harbor-credentials', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh """
                        echo \$PASS | docker login ${REGISTRY} -u \$USER --password-stdin
                        docker push ${REGISTRY}/${IMAGE_NAME}:${GIT_COMMIT_SHORT}
                        docker push ${REGISTRY}/${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Update Manifest') {
            steps {
                sh """
                    git clone https://git.company.local/k8s-manifests.git
                    cd k8s-manifests
                    sed -i 's|image: .*|image: ${REGISTRY}/${IMAGE_NAME}:${GIT_COMMIT_SHORT}|' dev/deployment.yaml
                    git add .
                    git commit -m "Update image to ${GIT_COMMIT_SHORT}"
                    git push
                """
            }
        }
    }

    post {
        success {
            slackSend(color: 'good', message: "Build succeeded: ${env.JOB_NAME} ${env.BUILD_NUMBER}")
        }
        failure {
            slackSend(color: 'danger', message: "Build failed: ${env.JOB_NAME} ${env.BUILD_NUMBER}")
        }
    }
}
```

## Backup & Recovery / การ Backup

### Manual Backup
```bash
# Backup Jenkins home directory
kubectl exec -n jenkins jenkins-0 -- tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home

# Copy backup to local
kubectl cp jenkins/jenkins-0:/tmp/jenkins-backup.tar.gz ./jenkins-backup.tar.gz
```

### Automated Backup
Configure backup using Jenkins plugins:
- ThinBackup Plugin
- Backup Plugin

Or use Velero for cluster-level backups.

## Troubleshooting / แก้ปัญหา

### Issue 1: Pods can't spawn agents
```bash
# Check RBAC permissions
kubectl get rolebinding -n jenkins

# Check service account
kubectl get sa jenkins -n jenkins
```

### Issue 2: Can't access Docker socket
```bash
# Make sure Docker socket is mounted in agent pod
# Add to pod template:
volumeMounts:
- name: docker-sock
  mountPath: /var/run/docker.sock
```

### Issue 3: Plugin installation fails
```bash
# Check internet access
kubectl exec -it -n jenkins jenkins-0 -- curl -I https://updates.jenkins.io

# Manually install plugin
kubectl exec -it -n jenkins jenkins-0 -- java -jar /var/jenkins_home/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ install-plugin <plugin-name>
```

## Monitoring / การ Monitor

### Check Jenkins Health
```bash
# Check pods
kubectl get pods -n jenkins

# Check logs
kubectl logs -f -n jenkins jenkins-0

# Check resources
kubectl top pod -n jenkins
```

### Prometheus Metrics
Jenkins exposes Prometheus metrics at `/prometheus`

## Security / ความปลอดภัย

1. **Change default admin password**
2. **Enable CSRF protection**
3. **Use RBAC for authorization**
4. **Store credentials in Vault, not Jenkins**
5. **Enable audit logging**
6. **Regular updates and security patches**

## References / อ้างอิง

- [Jenkins Helm Chart](https://github.com/jenkinsci/helm-charts)
- [Jenkins Configuration as Code](https://github.com/jenkinsci/configuration-as-code-plugin)
- [Jenkins on Kubernetes](https://www.jenkins.io/doc/book/installing/kubernetes/)
