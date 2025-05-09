#!/bin/bash
set -e

CLUSTER_NAME="my-eks-cluster-vjuser"
REGION="us-east-1"

echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# Install Helm if missing
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
fi

# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring || echo "Namespace already exists."

# Deploy Prometheus Stack with LoadBalancer services
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.service.type=LoadBalancer \
  --wait

# Get LoadBalancer endpoints (wait until they're assigned)
echo "Waiting for LoadBalancer IPs..."
PROMETHEUS_LB=""
GRAFANA_LB=""
while [[ -z "$PROMETHEUS_LB" || -z "$GRAFANA_LB" ]]; do
  sleep 10
  PROMETHEUS_LB=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  GRAFANA_LB=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
done

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

# Output endpoints and credentials
echo "========================================================"
echo "Prometheus URL: http://${PROMETHEUS_LB}:9090"
echo "Grafana URL:    http://${GRAFANA_LB}"
echo "Grafana Credentials:"
echo "  Username: admin"
echo "  Password: ${GRAFANA_PASSWORD}"
echo "========================================================"

# Fallback port-forwarding if LoadBalancer takes too long (optional)
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090 &
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 &
