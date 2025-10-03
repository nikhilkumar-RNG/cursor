#!/bin/bash
# Deploy complete Loki + Tempo observability stack

set -e

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Loki + Tempo Observability Stack - Deployment Script   ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"
echo ""

# Create namespace
echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace '$NAMESPACE' ready${NC}"
echo ""

# Deploy MinIO
echo -e "${BLUE}Step 2: Deploying MinIO (Object Storage)...${NC}"
kubectl apply -k "$PROJECT_ROOT/deployment/minio/"
echo -e "${YELLOW}Waiting for MinIO to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=minio -n "$NAMESPACE" --timeout=300s || {
    echo -e "${RED}✗ MinIO deployment failed${NC}"
    kubectl get pods -n "$NAMESPACE" -l app=minio
    exit 1
}
echo -e "${GREEN}✓ MinIO deployed successfully${NC}"

# Wait for MinIO setup job
echo -e "${YELLOW}Waiting for MinIO setup job to complete...${NC}"
kubectl wait --for=condition=complete job/minio-setup -n "$NAMESPACE" --timeout=300s || {
    echo -e "${YELLOW}⚠ MinIO setup job did not complete in time, checking logs...${NC}"
    kubectl logs -n "$NAMESPACE" job/minio-setup --tail=20
}
echo -e "${GREEN}✓ MinIO configured${NC}"
echo ""

# Deploy Loki
echo -e "${BLUE}Step 3: Deploying Loki...${NC}"
kubectl apply -k "$PROJECT_ROOT/deployment/loki/"
echo -e "${YELLOW}Waiting for Loki to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=loki -n "$NAMESPACE" --timeout=300s || {
    echo -e "${RED}✗ Loki deployment failed${NC}"
    kubectl get pods -n "$NAMESPACE" -l app=loki
    kubectl logs -n "$NAMESPACE" -l app=loki --tail=20
    exit 1
}
echo -e "${GREEN}✓ Loki deployed successfully${NC}"
echo ""

# Deploy Promtail
echo -e "${BLUE}Step 4: Deploying Promtail (Log Collector)...${NC}"
kubectl apply -k "$PROJECT_ROOT/deployment/promtail/"
echo -e "${YELLOW}Waiting for Promtail DaemonSet...${NC}"
sleep 10
PROMTAIL_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=promtail --no-headers 2>/dev/null | wc -l)
if [ "$PROMTAIL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ Promtail deployed ($PROMTAIL_PODS pods)${NC}"
else
    echo -e "${YELLOW}⚠ No Promtail pods found. Check DaemonSet status.${NC}"
fi
echo ""

# Deploy Tempo
echo -e "${BLUE}Step 5: Deploying Tempo (Distributed Tracing)...${NC}"
kubectl apply -k "$PROJECT_ROOT/deployment/tempo/"
echo -e "${YELLOW}Waiting for Tempo to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=tempo -n "$NAMESPACE" --timeout=300s || {
    echo -e "${RED}✗ Tempo deployment failed${NC}"
    kubectl get pods -n "$NAMESPACE" -l app=tempo
    exit 1
}
echo -e "${GREEN}✓ Tempo deployed successfully${NC}"
echo ""

# Deploy Grafana
echo -e "${BLUE}Step 6: Deploying Grafana...${NC}"
kubectl apply -k "$PROJECT_ROOT/deployment/grafana/"
echo -e "${YELLOW}Waiting for Grafana to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=grafana -n "$NAMESPACE" --timeout=300s || {
    echo -e "${RED}✗ Grafana deployment failed${NC}"
    kubectl get pods -n "$NAMESPACE" -l app=grafana
    exit 1
}
echo -e "${GREEN}✓ Grafana deployed successfully${NC}"
echo ""

# Optional: Deploy test applications
read -p "Deploy test applications (log generator, trace test)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Step 7: Deploying test applications...${NC}"
    
    kubectl apply -f "$PROJECT_ROOT/testing/log-generator/log-generator.yaml"
    echo -e "${GREEN}✓ Log generator deployed${NC}"
    
    kubectl apply -f "$PROJECT_ROOT/testing/integration/trace-log-correlation-test.yaml"
    echo -e "${GREEN}✓ Trace correlation test app deployed${NC}"
    echo ""
fi

# Show deployment status
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              Deployment Summary                           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

kubectl get pods -n "$NAMESPACE"
echo ""

# Show service endpoints
echo -e "${BLUE}Service Endpoints:${NC}"
kubectl get svc -n "$NAMESPACE" -o wide
echo ""

# Access instructions
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              Deployment Successful! 🎉                    ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Access Grafana:${NC}"
echo "  kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
echo "  Then open: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo -e "${YELLOW}Access MinIO Console:${NC}"
echo "  kubectl port-forward -n $NAMESPACE svc/minio 9001:9001"
echo "  Then open: http://localhost:9001"
echo "  Username: minioadmin"
echo "  Password: minioadmin"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Access Grafana and explore the datasources"
echo "  2. Go to Explore → Select Loki datasource"
echo "  3. Run query: {namespace=\"$NAMESPACE\"}"
echo "  4. Check traces in Tempo datasource"
echo "  5. Review documentation: docs/deployment-guide.md"
echo ""
echo -e "${YELLOW}Run Tests:${NC}"
echo "  cd testing/benchmarks"
echo "  ./search-benchmark.sh"
echo "  ./storage-analysis.sh"
echo "  cd ../integration"
echo "  ./integration-test-suite.sh"
echo ""
