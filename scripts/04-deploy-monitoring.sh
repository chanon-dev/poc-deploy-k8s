#!/bin/bash
# Deploy Monitoring Stack Script

set -e

echo "Deploying Prometheus & Grafana..."

# Add Prometheus helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --wait \
  --timeout 10m

echo ""
echo "✓ Monitoring stack deployed"

# Verify
echo ""
echo "Verifying monitoring components..."
kubectl get pods -n monitoring

echo ""
echo "Access Grafana:"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  Default credentials: admin / prom-operator"
