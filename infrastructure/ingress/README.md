# Ingress Setup for Local Development

## Overview

This directory contains Ingress configurations for local Kubernetes development.

## Components

- **NGINX Ingress Controller**: Main ingress controller for routing traffic
- **Service Ingress Rules**: Individual ingress rules for each service

## Installation

### 1. Install NGINX Ingress Controller

```bash
kubectl apply -f infrastructure/ingress/nginx-ingress-controller.yaml
```

Or use the setup script:

```bash
bash scripts/setup-ingress.sh
```

### 2. Update /etc/hosts

Add these entries to your `/etc/hosts` file:

```bash
sudo nano /etc/hosts
```

Add:
```
127.0.0.1 jenkins.local
127.0.0.1 argocd.local
127.0.0.1 vault.local
```

### 3. Access Services

- **Jenkins**: http://jenkins.local
- **Argo CD**: https://argocd.local
- **Vault**: http://vault.local

## Troubleshooting

### Check Ingress Controller

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Check Ingress Resources

```bash
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>
```

### View Logs

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f
```

## Uninstall

```bash
kubectl delete -f infrastructure/ingress/nginx-ingress-controller.yaml
```
