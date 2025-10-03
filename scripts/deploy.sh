#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-observability}

echo "Creating namespace $NAMESPACE (if not exists)"
kubectl create ns "$NAMESPACE" 2>/dev/null || true

echo "Adding Helm repos"
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null
helm repo update >/dev/null

echo "Installing MinIO (lab)"
helm upgrade --install minio bitnami/minio -n "$NAMESPACE" -f /workspace/helm/minio-values.yaml

echo "Creating Loki S3 secret"
kubectl -n "$NAMESPACE" delete secret loki-s3 2>/dev/null || true
kubectl -n "$NAMESPACE" create secret generic loki-s3 \
  --from-literal=access_key=minio \
  --from-literal=secret_key=minio123

echo "Installing Loki"
helm upgrade --install loki grafana/loki -n "$NAMESPACE" -f /workspace/helm/loki-values.yaml

echo "Installing Promtail"
helm upgrade --install promtail grafana/promtail -n "$NAMESPACE" -f /workspace/helm/promtail-values.yaml

echo "Installing Tempo"
helm upgrade --install tempo grafana/tempo -n "$NAMESPACE" -f /workspace/helm/tempo-values.yaml

echo "Installing Grafana"
helm upgrade --install grafana grafana/grafana -n "$NAMESPACE" -f /workspace/helm/grafana-values.yaml

echo "Done. Get Grafana admin password:"
kubectl -n "$NAMESPACE" get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo

