# Product Requirement Document (PRD)

## 1. Overview / ภาพรวมระบบ
**EN:** This document defines the requirements for building an **On-Premise Enterprise Platform System** deployed on **Kubernetes**, using **Argo CD**, **Jenkins**, and **HashiCorp Vault**, fully self-hosted with no dependency on managed cloud services.

**TH:** เอกสารนี้อธิบายความต้องการของระบบแพลตฟอร์มระดับองค์กรที่ติดตั้งและใช้งานแบบ **On-Premise 100%** โดย deploy บน **Kubernetes** และใช้ **Argo CD**, **Jenkins**, และ **HashiCorp Vault** เป็น core components

---

## 2. Goals & Objectives / เป้าหมายของระบบ

### 2.1 Business Goals
**EN:**
- Provide a secure, scalable, and auditable application delivery platform
- Support multiple product teams with standardized CI/CD
- Eliminate dependency on public cloud services

**TH:**
- สร้างแพลตฟอร์มที่ปลอดภัย ขยายได้ และตรวจสอบย้อนหลังได้
- รองรับหลายทีมพัฒนาในองค์กร
- ไม่พึ่งพา Cloud Provider ภายนอก

### 2.2 Technical Goals
**EN:**
- GitOps-first deployment model
- Immutable infrastructure via containers
- Centralized secrets management

**TH:**
- ใช้แนวคิด GitOps เป็นหลัก
- ใช้ container แบบ immutable
- จัดการ secret แบบรวมศูนย์

---

## 3. In-Scope / Out-of-Scope

### In-Scope
- Kubernetes Cluster (On-Prem)
- CI/CD with Jenkins + Argo CD
- Secret management with Vault
- RBAC & Audit
- Application deployment lifecycle

### Out-of-Scope
- SaaS integrations
- Public cloud managed services
- End-user application UX design

---

## 4. Target Users / ผู้ใช้งานระบบ

| Role | Description |
|-----|------------|
| Platform Admin | ดูแล K8S, Vault, CI/CD |
| DevOps Engineer | สร้าง pipeline, infra |
| Developer | Deploy application |
| Security Officer | Audit & compliance |

---

## 5. High-Level Architecture / สถาปัตยกรรมระดับสูง

**EN:**
The system consists of an on-prem Kubernetes cluster acting as the runtime platform, integrated with Jenkins for CI, Argo CD for CD, and Vault for secrets.

**TH:**
ระบบประกอบด้วย Kubernetes Cluster แบบ On-Prem เป็นศูนย์กลาง เชื่อมกับ Jenkins (CI), Argo CD (CD) และ Vault (Secrets)

**Key Components:**
- Kubernetes (Control Plane + Worker Nodes)
- Jenkins (Build & Test)
- Argo CD (GitOps Deployment)
- HashiCorp Vault (Secrets & Credentials)
- Git Repository (Source of Truth)

---

## 6. Functional Requirements / ความสามารถของระบบ

### 6.1 Source Control & GitOps
**EN:**
- All deployments must be driven from Git repositories
- Git is the single source of truth

**TH:**
- ทุก deployment ต้องมาจาก Git
- Git เป็นแหล่งข้อมูลเดียวของระบบ

### 6.2 CI – Jenkins
**EN:**
- Triggered by Git commit or PR
- Build container images
- Run unit/integration tests
- Push images to on-prem container registry

**TH:**
- Trigger จาก Git
- Build container
- Run test
- Push image เข้า registry ภายใน

### 6.3 CD – Argo CD
**EN:**
- Auto-sync or manual approval deployment
- Environment separation (dev / sit / uat / prod)
- Rollback via Git history

**TH:**
- Deploy แบบอัตโนมัติหรืออนุมัติ
- แยก environment
- rollback ได้จาก Git

### 6.4 Secret Management – Vault
**EN:**
- Store secrets, tokens, certificates
- Dynamic secrets for DB and services
- Kubernetes auth integration

**TH:**
- เก็บ secret, token, certificate
- สร้าง secret แบบ dynamic
- เชื่อมกับ Kubernetes ServiceAccount

### 6.5 Access Control & Security
**EN:**
- RBAC for Kubernetes, Jenkins, Argo CD
- Audit logs for all critical actions

**TH:**
- ควบคุมสิทธิ์ด้วย RBAC
- มี audit log

---

## 7. Non-Functional Requirements / NFR

### 7.1 Security
- TLS everywhere
- Secrets never stored in Git
- Network isolation via Kubernetes NetworkPolicy

### 7.2 Availability
- HA control plane
- Jenkins & Vault in HA mode

### 7.3 Performance
- CI pipeline must complete within defined SLA
- Horizontal Pod Autoscaling supported

### 7.4 Compliance
- Full audit trail
- Role separation (Dev / Ops / Security)

---

## 8. Deployment Environment / สภาพแวดล้อม

| Environment | Purpose |
|------------|--------|
| Dev | Development |
| SIT | System Integration Test |
| UAT | User Acceptance Test |
| Prod | Production |

All environments run on the same on-prem Kubernetes cluster with namespace isolation.

---

## 9. Risks & Mitigation / ความเสี่ยง

| Risk | Mitigation |
|----|-----------|
| Hardware failure | HA + backup |
| Human error | GitOps + RBAC |
| Secret leakage | Vault + policy |

---

## 10. Success Metrics / ตัวชี้วัดความสำเร็จ

**EN:**
- Deployment frequency increased
- Mean time to recovery (MTTR) reduced
- Zero secrets stored in plain text

**TH:**
- deploy ได้บ่อยขึ้น
- แก้ปัญหาได้เร็วขึ้น
- ไม่มี secret หลุด

---

## 11. Future Enhancements / แนวทางในอนาคต
- Service Mesh (Istio / Linkerd)
- Policy as Code (OPA / Kyverno)
- Internal Developer Portal (Backstage)

---

**End of PRD**

