# คำอธิบายคำสั่งแต่ละตัว / Command Explanations

## อธิบายทุกคำสั่งที่ใช้ในการติดตั้ง - ทำอะไร ทำไมต้องใช้

---

## 📚 Table of Contents

1. [Kubectl Commands](#kubectl-commands)
2. [Helm Commands](#helm-commands)
3. [Vault Commands](#vault-commands)
4. [Docker Commands](#docker-commands)
5. [Utility Commands](#utility-commands)

---

## Kubectl Commands

### `kubectl version --client`

**ทำอะไร:**
- แสดงเวอร์ชันของ kubectl ที่ติดตั้งในเครื่องเรา
- ไม่ต้องเชื่อมต่อกับ cluster

**ทำไมต้องใช้:**
- ตรวจสอบว่าติดตั้ง kubectl แล้วหรือยัง
- ดูว่าเวอร์ชันใช้งานได้กับ Kubernetes cluster หรือไม่

**ผลลัพธ์ที่ได้:**
```
Client Version: v1.28.2
```

**ตัวอย่าง:**
```bash
kubectl version --client
# Output: Client Version: version.Info{Major:"1", Minor:"28",...}
```

---

### `kubectl cluster-info`

**ทำอะไร:**
- แสดงข้อมูล Kubernetes cluster ที่เรากำลังเชื่อมต่ออยู่
- แสดง URL ของ control plane และ services

**ทำไมต้องใช้:**
- ตรวจสอบว่า cluster running อยู่หรือไม่
- ดูว่าเชื่อมต่อกับ cluster ที่ถูกต้องหรือไม่

**ผลลัพธ์ที่ได้:**
```
Kubernetes control plane is running at https://kubernetes.docker.internal:6443
CoreDNS is running at https://kubernetes.docker.internal:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

**ตัวอย่าง:**
```bash
kubectl cluster-info
# แสดงว่า cluster พร้อมใช้งาน
```

---

### `kubectl create namespace dev`

**ทำอะไร:**
- สร้าง namespace ชื่อ "dev" ใน Kubernetes cluster
- Namespace = กลุ่มแยกสำหรับเก็บ resources (เหมือนโฟลเดอร์)

**ทำไมต้องสร้าง:**
- **แยก environment** - dev, sit, uat, prod อยู่คนละ namespace
- **แยก resources** - แต่ละทีมมี namespace ของตัวเอง
- **จำกัดสิทธิ์** - ใช้ RBAC ควบคุมว่าใครเข้าถึง namespace ไหนได้
- **จัดการง่าย** - ลบ namespace เดียวก็ลบทุกอย่างข้างในทิ้ง

**ผลลัพธ์ที่ได้:**
- namespace "dev" ถูกสร้างขึ้น
- พร้อมให้ deploy applications ลงไปได้

**เปรียบเทียบ:**
```
Kubernetes Cluster
├── default namespace (ที่มีอยู่แล้ว)
├── kube-system namespace (ของ K8s เอง)
├── dev namespace (ที่เราสร้างใหม่) ← สำหรับ development
├── jenkins namespace (ที่เราสร้างใหม่) ← สำหรับ Jenkins
└── argocd namespace (ที่เราสร้างใหม่) ← สำหรับ Argo CD
```

**ตัวอย่าง:**
```bash
# สร้าง namespace
kubectl create namespace dev

# ผลลัพธ์:
# namespace/dev created

# ตรวจสอบ
kubectl get namespaces
# NAME          STATUS   AGE
# dev           Active   10s
# default       Active   2d
```

**ทำไมไม่ใช้ default namespace:**
- default namespace ควรเว้นว่างไว้
- แยก namespace ทำให้จัดการง่าย ไม่สับสน
- ถ้าเกิดปัญหา ลบ namespace ไป ไม่กระทบอย่างอื่น

---

### `kubectl apply -f <file.yaml>`

**ทำอะไร:**
- อ่านไฟล์ YAML
- สร้างหรืออัพเดต resources ตามที่กำหนดในไฟล์
- ถ้ามีอยู่แล้ว = อัพเดต
- ถ้ายังไม่มี = สร้างใหม่

**ทำไมใช้ apply แทน create:**
- `create` ใช้ครั้งแรกเท่านั้น (ถ้ามีแล้วจะ error)
- `apply` ใช้ได้ทั้งสร้างใหม่และอัพเดต (declarative)
- `apply` เป็น best practice สำหรับ GitOps

**ผลลัพธ์ที่ได้:**
- Resources ที่อยู่ในไฟล์ถูกสร้างหรืออัพเดต

**ตัวอย่าง:**
```bash
# Apply namespace config
kubectl apply -f environments/dev/namespace.yaml

# ผลลัพธ์:
# namespace/dev created
# resourcequota/dev-resource-quota created
# limitrange/dev-limit-range created
```

**อธิบาย environments/dev/namespace.yaml:**
```yaml
# 1. สร้าง namespace ชื่อ dev
apiVersion: v1
kind: Namespace
metadata:
  name: dev

# 2. กำหนด resource quota (จำกัดทรัพยากร)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-resource-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"      # รวม CPU ขอใช้ไม่เกิน 4 cores
    requests.memory: 8Gi   # รวม RAM ขอใช้ไม่เกิน 8GB
    limits.cpu: "8"        # รวม CPU limit ไม่เกิน 8 cores
    limits.memory: 16Gi    # รวม RAM limit ไม่เกิน 16GB

# 3. กำหนด limit range (จำกัดแต่ละ pod)
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limit-range
  namespace: dev
spec:
  limits:
  - default:               # ค่า default ถ้าไม่ระบุ
      cpu: 250m            # ให้ 0.25 core
      memory: 256Mi        # ให้ 256MB RAM
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

**ทำไมต้องมี ResourceQuota:**
- **ป้องกันใครคน/pod หนึ่งใช้ทรัพยากรหมด** - จำกัดไม่ให้ใช้เกินกำหนด
- **แบ่ง resources ให้เป็นธรรม** - แต่ละ namespace ได้ส่วนแบ่ง
- **ประหยัด** - ไม่ให้ waste resources

---

### `kubectl get pods -A`

**ทำอะไร:**
- แสดงรายการ pods ทั้งหมดในทุก namespace
- `-A` = `--all-namespaces`

**ทำไมต้องใช้:**
- ดูว่า pods ไหน running อยู่
- ตรวจสอบสถานะของ deployment
- Debug ปัญหา

**ผลลัพธ์ที่ได้:**
```
NAMESPACE   NAME                        READY   STATUS    RESTARTS   AGE
jenkins     jenkins-0                   2/2     Running   0          5m
argocd      argocd-server-xxx           1/1     Running   0          3m
vault       vault-0                     1/1     Running   0          2m
```

**อธิบายคอลัมน์:**
- **NAMESPACE** - pod อยู่ใน namespace ไหน
- **NAME** - ชื่อ pod
- **READY** - container ที่พร้อม/ทั้งหมด (2/2 = พร้อมหมดแล้ว)
- **STATUS** - สถานะ (Running, Pending, Error, etc.)
- **RESTARTS** - จำนวนครั้งที่ restart (ถ้าเยอะ = มีปัญหา)
- **AGE** - อายุ (สร้างมานานแค่ไหน)

**ตัวอย่าง:**
```bash
# ดู pods ทุก namespace
kubectl get pods -A

# ดู pods เฉพาะ namespace dev
kubectl get pods -n dev

# ดู pods พร้อมข้อมูลเพิ่มเติม
kubectl get pods -A -o wide
```

---

### `kubectl get storageclass`

**ทำอะไร:**
- แสดงรายการ storage classes ที่มีอยู่ใน cluster
- Storage class = ประเภทของ storage สำหรับ persistent volumes

**ทำไมต้องดู:**
- ตรวจสอบว่ามี storage class หรือยัง
- ดูว่า storage class ไหนเป็น default
- ถ้าไม่มี = pods ที่ต้องการ storage จะ pending

**ผลลัพธ์ที่ได้:**
```
NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE
hostpath (default)   docker.io/hostpath   Delete          Immediate
```

**อธิบายคอลัมน์:**
- **NAME** - ชื่อ storage class
- **(default)** - เป็น default storage class
- **PROVISIONER** - ใครจัดการ storage (Docker Desktop, Minikube, etc.)
- **RECLAIMPOLICY** - เมื่อลบ PVC จะเกิดอะไร (Delete = ลบข้อมูลทิ้ง)
- **VOLUMEBINDINGMODE** - เมื่อไหร่จะสร้าง volume (Immediate = สร้างทันที)

**ตัวอย่าง:**
```bash
kubectl get storageclass

# ถ้าไม่มี (default) ต้อง patch
kubectl patch storageclass hostpath \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**ทำไมต้องมี default storage class:**
- เมื่อ pod ขอ PVC (Persistent Volume Claim) โดยไม่ระบุ storage class
- จะใช้ default storage class สร้าง volume ให้อัตโนมัติ
- ถ้าไม่มี default = pods จะ pending (รอ storage ไม่รู้จบ)

---

### `kubectl port-forward -n jenkins svc/jenkins 8080:8080`

**ทำอะไร:**
- สร้างอุโมงค์ (tunnel) จากเครื่องเรา (localhost) ไปยัง service ใน cluster
- เชื่อม `localhost:8080` → `jenkins service:8080` ใน cluster

**ทำไมต้องใช้:**
- **บน local ไม่มี Load Balancer** - ไม่สามารถเข้าถึง service จากภายนอกได้
- **ไม่มี Ingress** - ไม่มี domain name หรือ DNS
- **Port-forward แก้ปัญหานี้** - ทำให้เข้าถึง service ผ่าน localhost ได้

**ผลลัพธ์ที่ได้:**
- เปิด browser ที่ `http://localhost:8080` → เข้าถึง Jenkins ได้

**รูปแบบคำสั่ง:**
```bash
kubectl port-forward [options] TYPE/NAME [LOCAL_PORT:]REMOTE_PORT

# TYPE = svc (service), pod, deployment, etc.
# NAME = ชื่อ service/pod
# LOCAL_PORT = port บนเครื่องเรา
# REMOTE_PORT = port ใน cluster
```

**ตัวอย่าง:**
```bash
# Port-forward service
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# localhost:8080 → jenkins service:8080

# Port-forward pod โดยตรง
kubectl port-forward -n jenkins jenkins-0 8080:8080
# localhost:8080 → jenkins-0 pod:8080

# ใช้ port ต่างกัน
kubectl port-forward -n jenkins svc/jenkins 9000:8080
# localhost:9000 → jenkins service:8080
```

**อธิบายที่เกิดขึ้น:**
```
Your Computer                    Kubernetes Cluster
┌─────────────┐                 ┌──────────────────┐
│  Browser    │                 │                  │
│             │                 │  ┌────────────┐  │
│ localhost:  │ port-forward    │  │  Jenkins   │  │
│   8080  ────┼─────────────────┼─>│  Service   │  │
│             │                 │  │  :8080     │  │
└─────────────┘                 │  └────────────┘  │
                                └──────────────────┘
```

**ข้อควรรู้:**
- **ต้องเปิดทิ้งไว้** - ปิด terminal = port-forward หยุดทำงาน
- **ใช้แค่ตัวเราเอง** - คนอื่นเข้าไม่ได้ (ต่างจาก Ingress)
- **สำหรับ development เท่านั้น** - production ต้องใช้ Ingress หรือ LoadBalancer

---

### `kubectl logs -f -n jenkins jenkins-0`

**ทำอะไร:**
- แสดง logs จาก pod ชื่อ `jenkins-0` ใน namespace `jenkins`
- `-f` = follow (ติดตาม real-time เหมือน `tail -f`)

**ทำไมต้องใช้:**
- **Debug ปัญหา** - ดูว่า pod error ตรงไหน
- **Monitor** - ดู logs แบบ real-time
- **ตรวจสอบการทำงาน** - ดูว่า application ทำงานถูกต้องหรือไม่

**ผลลัพธ์ที่ได้:**
```
2024-01-15 10:30:00 INFO  Starting Jenkins...
2024-01-15 10:30:05 INFO  Jenkins is fully up and running
```

**ตัวอย่าง:**
```bash
# ดู logs ปกติ (แสดงทั้งหมดแล้วจบ)
kubectl logs -n jenkins jenkins-0

# Follow logs (ติดตาม real-time)
kubectl logs -f -n jenkins jenkins-0

# ดู logs ย้อนหลัง 100 บรรทัด
kubectl logs --tail=100 -n jenkins jenkins-0

# ดู logs จาก container เฉพาะ (ถ้า pod มีหลาย container)
kubectl logs -n jenkins jenkins-0 -c jenkins

# ดู logs ของ pod ที่ restart ไปแล้ว
kubectl logs -n jenkins jenkins-0 --previous
```

**กรณี Pod มีหลาย Container:**
```bash
# ดู containers ที่มี
kubectl get pod jenkins-0 -n jenkins -o jsonpath='{.spec.containers[*].name}'
# Output: jenkins init-container

# ดู logs ของ jenkins container
kubectl logs -n jenkins jenkins-0 -c jenkins -f
```

---

### `kubectl describe pod <pod-name> -n <namespace>`

**ทำอะไร:**
- แสดงรายละเอียดครบถ้วนของ pod
- ข้อมูลเกี่ยวกับ containers, volumes, events, status

**ทำไมต้องใช้:**
- **Debug ทำไม pod pending** - ดู events ว่าติดตรงไหน
- **ดูข้อมูล pod** - image, resources, volumes
- **ตรวจสอบ error** - ดู error messages ล่าสุด

**ผลลัพธ์ที่ได้:**
```
Name:         jenkins-0
Namespace:    jenkins
Status:       Running
IP:           10.1.0.5
Containers:
  jenkins:
    Image:          jenkins/jenkins:lts
    Port:           8080/TCP
    State:          Running
    Ready:          True
Events:
  Type    Reason     Message
  ----    ------     -------
  Normal  Scheduled  Successfully assigned jenkins/jenkins-0
  Normal  Pulled     Container image pulled
  Normal  Created    Created container jenkins
  Normal  Started    Started container jenkins
```

**ตัวอย่าง:**
```bash
# Describe pod
kubectl describe pod jenkins-0 -n jenkins

# ส่วนสำคัญที่ต้องดู:
# 1. Status - Running/Pending/Error
# 2. Events - อะไรเกิดขึ้นล่าสุด (ดูที่นี่ถ้ามีปัญหา)
# 3. Containers - container ไหน ready หรือไม่
# 4. Conditions - pod พร้อมใช้งานหรือยัง
```

**ใช้ debug ปัญหา:**
```bash
# Pod pending นานไม่ขึ้น?
kubectl describe pod <pod> -n <namespace>
# ดู Events: ถ้าเห็น "FailedScheduling" = ไม่มี resources พอ
# ดู Events: ถ้าเห็น "Pending" = รอ storage

# Pod CrashLoopBackOff?
kubectl describe pod <pod> -n <namespace>
# ดู Events: จะบอกว่า crash เพราะอะไร
# ดู State: Last State จะบอก exit code
```

---

### `kubectl exec -it -n vault vault-0 -- vault status`

**ทำอะไร:**
- เข้าไปรันคำสั่ง `vault status` ใน pod `vault-0`
- `-it` = interactive terminal (เหมือน ssh เข้าไป)
- `--` = แยกระหว่าง kubectl options กับคำสั่งที่จะรัน

**ทำไมต้องใช้:**
- **รันคำสั่งใน pod** - ไม่ต้อง ssh เข้าไป
- **ตรวจสอบ application** - เช่น vault status, database queries
- **Debug** - ตรวจสอบไฟล์, config ใน pod

**ผลลัพธ์ที่ได้:**
```
Sealed: false
Initialized: true
Version: 1.15.2
```

**ตัวอย่าง:**
```bash
# รันคำสั่งเดียว
kubectl exec -n vault vault-0 -- vault status

# เข้าไปใช้ shell (interactive)
kubectl exec -it -n vault vault-0 -- sh
# จากนั้นพิมพ์คำสั่งได้เลย
$ vault status
$ ls /vault/data
$ exit

# รันคำสั่งใน container เฉพาะ (ถ้ามีหลาย container)
kubectl exec -it -n jenkins jenkins-0 -c jenkins -- bash

# รัน vault login
kubectl exec -n vault vault-0 -- vault login <token>

# Read secret from vault
kubectl exec -n vault vault-0 -- vault kv get secret/dev/test
```

**เปรียบเทียบกับ SSH:**
```bash
# แทนที่จะ ssh
ssh user@server
vault status

# ใช้ kubectl exec แทน
kubectl exec -n vault vault-0 -- vault status
```

---

## Helm Commands

### `helm repo add jenkins https://charts.jenkins.io`

**ทำอะไร:**
- เพิ่ม Helm repository ของ Jenkins
- Repository = ที่เก็บ Helm charts (package ของ Kubernetes)

**ทำไมต้องใช้:**
- **ไม่ต้องเขียน YAML เอง** - ใช้ chart สำเร็จรูป
- **ได้ best practices** - chart ถูกออกแบบมาดีแล้ว
- **อัพเดตง่าย** - `helm upgrade` คำสั่งเดียว

**ผลลัพธ์ที่ได้:**
- Helm รู้จัก repository ชื่อ `jenkins`
- สามารถ install charts จาก repo นี้ได้

**ตัวอย่าง:**
```bash
# เพิ่ม repos
helm repo add jenkins https://charts.jenkins.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add hashicorp https://helm.releases.hashicorp.com

# ผลลัพธ์:
# "jenkins" has been added to your repositories
```

**อธิบาย Helm Repository:**
```
Helm Repository = App Store สำหรับ Kubernetes

jenkins repo
├── jenkins chart (version 4.3.0)
├── jenkins chart (version 4.2.0)
└── jenkins chart (version 4.1.0)

argo repo
├── argo-cd chart (version 5.19.0)
└── ...

hashicorp repo
├── vault chart (version 0.25.0)
└── ...
```

---

### `helm repo update`

**ทำอะไร:**
- อัพเดตรายการ charts จาก repositories ทั้งหมด
- เหมือน `apt update` หรือ `brew update`

**ทำไมต้องใช้:**
- **ให้ได้ charts เวอร์ชันล่าสุด**
- หลังเพิ่ม repo ใหม่ ควร update ทุกครั้ง

**ตัวอย่าง:**
```bash
helm repo update
# Output:
# Hang tight while we grab the latest from your chart repositories...
# ...Successfully got an update from the "jenkins" chart repository
# ...Successfully got an update from the "argo" chart repository
# Update Complete.
```

---

### `helm install jenkins jenkins/jenkins -f values.yaml -n jenkins`

**ทำอะไร:**
- ติดตั้ง Jenkins ด้วย Helm chart
- ใช้ค่าจาก `values.yaml` (custom configuration)
- ติดตั้งใน namespace `jenkins`

**ทำไมใช้ Helm:**
- **ติดตั้งง่าย** - คำสั่งเดียวจบ แทนที่จะ apply YAML หลายไฟล์
- **จัดการง่าย** - upgrade, rollback, uninstall ทำได้ง่าย
- **Customize ได้** - ใช้ values.yaml ปรับแต่งตามต้องการ

**รูปแบบคำสั่ง:**
```bash
helm install [RELEASE_NAME] [CHART] [flags]

# RELEASE_NAME = ชื่อที่ตั้งให้ installation นี้
# CHART = chart ที่จะติดตั้ง (repo/chart-name)
```

**ผลลัพธ์ที่ได้:**
- Jenkins ถูกติดตั้งใน namespace jenkins
- สร้าง Deployment, Service, PVC, ConfigMap, etc. อัตโนมัติ

**ตัวอย่าง:**
```bash
# Install Jenkins
helm install jenkins jenkins/jenkins \
  -f core-components/jenkins/values-local.yaml \
  -n jenkins \
  --wait \
  --timeout 10m

# ผลลัพธ์:
# NAME: jenkins
# NAMESPACE: jenkins
# STATUS: deployed
# REVISION: 1
```

**อธิบาย flags:**
- `-f values-local.yaml` - ใช้ค่า config จากไฟล์นี้
- `-n jenkins` - ติดตั้งใน namespace jenkins
- `--wait` - รอจน resources พร้อมก่อนจบคำสั่ง
- `--timeout 10m` - รอสูงสุด 10 นาที

**สิ่งที่ Helm สร้างให้:**
```bash
kubectl get all -n jenkins
# NAME                    READY   STATUS
# pod/jenkins-0           2/2     Running
#
# NAME                    TYPE        PORT(S)
# service/jenkins         ClusterIP   8080/TCP
# service/jenkins-agent   ClusterIP   50000/TCP
#
# NAME                       READY
# statefulset/jenkins        1/1
#
# NAME                                   DATA
# configmap/jenkins                      5
# configmap/jenkins-jenkins-jcasc-config 1
```

---

### `helm upgrade jenkins jenkins/jenkins -f values.yaml -n jenkins`

**ทำอะไร:**
- อัพเดต Jenkins installation ที่มีอยู่
- ใช้ค่าใหม่จาก values.yaml

**ทำไมใช้ upgrade:**
- **แก้ config** - เปลี่ยน values.yaml แล้วใช้ upgrade
- **อัพเกรดเวอร์ชัน** - อัพเดตเป็น chart เวอร์ชันใหม่
- **ปลอดภัย** - ถ้าผิดพลาด rollback ได้

**ตัวอย่าง:**
```bash
# แก้ไข values.yaml เสร็จแล้ว upgrade
helm upgrade jenkins jenkins/jenkins \
  -f core-components/jenkins/values-local.yaml \
  -n jenkins

# หรือใช้ install ที่มี upgrade ในตัว
helm upgrade --install jenkins jenkins/jenkins \
  -f core-components/jenkins/values-local.yaml \
  -n jenkins
# ถ้ายังไม่มี = install, ถ้ามีแล้ว = upgrade
```

---

### `helm uninstall jenkins -n jenkins`

**ทำอะไร:**
- ลบ Jenkins installation ทิ้ง
- ลบทุก resources ที่ Helm สร้างไว้

**ทำไมต้องใช้:**
- **ลบทิ้งเมื่อไม่ใช้แล้ว**
- **ติดตั้งใหม่** - ลบแล้ว install ใหม่

**ผลลัพธ์ที่ได้:**
- Jenkins ถูกลบทิ้งทั้งหมด
- Pods, Services, ConfigMaps ถูกลบ
- **PVC อาจยังอยู่** - ต้องลบแยก

**ตัวอย่าง:**
```bash
# Uninstall
helm uninstall jenkins -n jenkins

# ผลลัพธ์:
# release "jenkins" uninstalled

# ลบ PVC ด้วย (ถ้าต้องการ)
kubectl delete pvc -n jenkins --all

# ลบ namespace
kubectl delete namespace jenkins
```

---

## Vault Commands

### `vault operator init`

**ทำอะไร:**
- เริ่มต้น (initialize) Vault ครั้งแรก
- สร้าง master keys และ root token
- **ทำได้แค่ครั้งเดียว** - ไม่สามารถ init ซ้ำได้

**ทำไมต้อง init:**
- **Vault ใหม่ยังใช้งานไม่ได้** - ต้อง init ก่อน
- **ได้ unseal keys และ root token** - สำหรับ unseal และ login

**ผลลัพธ์ที่ได้:**
```
Unseal Key 1: xxxxx
Unseal Key 2: xxxxx
Unseal Key 3: xxxxx
Unseal Key 4: xxxxx
Unseal Key 5: xxxxx

Initial Root Token: s.xxxxxxxxx
```

**⚠️ สำคัญมาก:**
- **เก็บ keys และ token ให้ดี!**
- **ห้ามหาย!** - หายแล้วเข้า Vault ไม่ได้
- **ห้าม commit เข้า Git!**

**ตัวอย่าง:**
```bash
# Initialize vault (basic)
kubectl exec -n vault vault-0 -- vault operator init

# Initialize vault (save to file)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# -key-shares=5      → สร้าง 5 unseal keys
# -key-threshold=3   → ต้องใช้ 3 keys เพื่อ unseal
# -format=json       → output เป็น JSON
```

**ทำไมใช้ 5 keys threshold 3:**
- **Shamir's Secret Sharing** - แบ่ง master key เป็น 5 parts
- **ต้องใช้ 3 parts ถึงจะ unseal ได้** - ป้องกันคนคนเดียวเข้าถึงได้
- **Best practice** - แบ่ง keys ให้คนละคน
  - Key 1 → Person A
  - Key 2 → Person B
  - Key 3 → Person C
  - Key 4 → Person D
  - Key 5 → Person E
- ต้องมีอย่างน้อย 3 คนมา unseal ด้วยกัน

---

### `vault operator unseal <key>`

**ทำอะไร:**
- Unseal Vault ด้วย unseal key
- ต้องใช้ 3 keys (ตาม threshold ที่ตั้งไว้)
- Unseal แล้วถึงจะใช้งาน Vault ได้

**ทำไม Vault sealed:**
- **ความปลอดภัย** - เมื่อ restart pod, Vault จะ sealed อัตโนมัติ
- **Sealed = ล็อคไว้** - ไม่สามารถอ่าน/เขียน secrets ได้
- **Unsealed = ปลดล็อค** - ใช้งานได้ปกติ

**ผลลัพธ์ที่ได้:**
```
# หลังใส่ key ที่ 1
Sealed: true
Unseal Progress: 1/3

# หลังใส่ key ที่ 2
Sealed: true
Unseal Progress: 2/3

# หลังใส่ key ที่ 3
Sealed: false     ← Unsealed แล้ว!
Unseal Progress: 3/3
```

**ตัวอย่าง:**
```bash
# Unseal ครั้งที่ 1
kubectl exec -n vault vault-0 -- vault operator unseal <key1>

# Unseal ครั้งที่ 2
kubectl exec -n vault vault-0 -- vault operator unseal <key2>

# Unseal ครั้งที่ 3
kubectl exec -n vault vault-0 -- vault operator unseal <key3>

# ตรวจสอบ
kubectl exec -n vault vault-0 -- vault status
# Sealed: false ← เรียบร้อย!
```

**เมื่อไหร่ต้อง unseal:**
- เมื่อ init Vault ครั้งแรก
- เมื่อ pod restart
- เมื่อ seal Vault ด้วยตัวเอง (`vault operator seal`)

---

### `vault login <token>`

**ทำอะไร:**
- Login เข้า Vault ด้วย token
- หลัง login ถึงจะรัน vault commands อื่นๆ ได้

**ทำไมต้อง login:**
- **Vault ต้องการ authentication** - รู้ว่าเป็นใคร
- **Token = รหัสผ่าน** - ใช้ยืนยันตัวตน
- **ได้สิทธิ์ตาม policies** - token แต่ละ token มีสิทธิ์ต่างกัน

**ตัวอย่าง:**
```bash
# Login with root token
kubectl exec -n vault vault-0 -- vault login s.xxxxxx

# Login แบบ interactive
kubectl exec -it -n vault vault-0 -- vault login
# Token (will be hidden): _

# ผลลัพธ์:
# Success! You are now authenticated.
```

---

### `vault kv put secret/dev/test password=hello123`

**ทำอะไร:**
- เขียน secret ลง Vault
- Path: `secret/dev/test`
- Data: `password=hello123`

**ทำไมใช้ kv:**
- **KV = Key-Value** - secrets engine ประเภทหนึ่ง
- **เก็บ secrets แบบ key-value pairs**

**ตัวอย่าง:**
```bash
# เขียน secret เดียว
kubectl exec -n vault vault-0 -- \
  vault kv put secret/dev/test password=hello123

# เขียน secrets หลายตัว
kubectl exec -n vault vault-0 -- \
  vault kv put secret/dev/database \
  username=admin \
  password=secret123 \
  host=db.example.com \
  port=5432

# อ่าน secret
kubectl exec -n vault vault-0 -- \
  vault kv get secret/dev/test

# ลบ secret
kubectl exec -n vault vault-0 -- \
  vault kv delete secret/dev/test
```

**โครงสร้าง Path:**
```
secret/                    ← secrets engine
  ├── dev/                 ← environment
  │   ├── test             ← app/service
  │   ├── database
  │   └── api
  ├── sit/
  ├── uat/
  └── prod/
```

---

## Docker Commands

### `docker --version`

**ทำอะไร:**
- แสดงเวอร์ชันของ Docker

**ทำไมต้องตรวจสอบ:**
- ดูว่าติดตั้ง Docker แล้วหรือยัง
- Docker Desktop ต้องมี Kubernetes ในตัว

---

### `docker ps`

**ทำอะไร:**
- แสดง containers ที่ running อยู่

**ใช้ดูอะไร:**
- ตรวจสอบว่า Kubernetes containers running หรือไม่
- ดู resource usage

---

## Utility Commands

### `jq`

**ทำอะไร:**
- JSON processor - อ่าน/แปลง/query JSON

**ใช้ทำอะไร:**
```bash
# Extract value from JSON
cat vault-keys.json | jq -r '.root_token'

# Format JSON
kubectl get pod -o json | jq '.'
```

---

### `base64 --decode`

**ทำอะไร:**
- แปลง base64 encoded string กลับเป็นข้อความปกติ

**ทำไมต้องใช้:**
- **Kubernetes เก็บ secrets เป็น base64**
- ต้อง decode เพื่ออ่าน

**ตัวอย่าง:**
```bash
# Get password (ยังเป็น base64)
kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}"
# Output: YWRtaW4xMjM=

# Decode
kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
# Output: admin123
```

---

## สรุป Flow การทำงาน

### 1. Setup Cluster
```bash
kubectl cluster-info          # ตรวจสอบ cluster
kubectl get storageclass      # ตรวจสอบ storage
```

### 2. Create Namespaces
```bash
kubectl create namespace dev  # สร้าง namespace
kubectl get namespaces        # ตรวจสอบ
```

### 3. Install with Helm
```bash
helm repo add jenkins ...     # เพิ่ม repo
helm repo update              # อัพเดต
helm install jenkins ...      # ติดตั้ง
```

### 4. Verify
```bash
kubectl get pods -A           # ตรวจสอบ pods
kubectl get svc -A            # ตรวจสอบ services
```

### 5. Access
```bash
kubectl port-forward ...      # เข้าถึง services
```

### 6. Initialize Vault
```bash
vault operator init           # initialize
vault operator unseal         # unseal (3 ครั้ง)
vault login                   # login
```

---

## Quick Reference Table / ตารางอ้างอิงด่วน

| คำสั่ง | ทำอะไร | เมื่อไหร่ใช้ |
|--------|--------|-------------|
| `kubectl get pods -A` | ดู pods ทั้งหมด | ตรวจสอบสถานะ |
| `kubectl describe pod` | ดูรายละเอียด pod | Debug ปัญหา |
| `kubectl logs -f` | ดู logs แบบ real-time | ดู application logs |
| `kubectl exec -it` | รันคำสั่งใน pod | Debug, run commands |
| `kubectl port-forward` | สร้างอุโมงค์เข้า service | เข้าถึง services บน local |
| `helm install` | ติดตั้ง application | ติดตั้งครั้งแรก |
| `helm upgrade` | อัพเดต application | แก้ config, อัพเกรดเวอร์ชัน |
| `helm uninstall` | ลบ application | ลบทิ้ง |
| `vault operator init` | เริ่มต้น Vault | ครั้งแรกเท่านั้น |
| `vault operator unseal` | ปลดล็อค Vault | หลัง restart |

---

**หวังว่าจะเข้าใจแต่ละคำสั่งมากขึ้นนะครับ!** 🎓
