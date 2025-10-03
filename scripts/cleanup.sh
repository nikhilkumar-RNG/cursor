#!/bin/bash
# Cleanup script for Loki + Tempo stack

set -e

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}   Loki + Tempo Stack - Cleanup Script                    ${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}This will delete all components in namespace: $NAMESPACE${NC}"
echo -e "${YELLOW}Including: Loki, Tempo, Grafana, MinIO, Promtail${NC}"
echo ""
read -p "Are you sure you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Deleting test applications...${NC}"
kubectl delete -f "$PROJECT_ROOT/testing/log-generator/log-generator.yaml" 2>/dev/null || true
kubectl delete -f "$PROJECT_ROOT/testing/integration/trace-log-correlation-test.yaml" 2>/dev/null || true
echo -e "${GREEN}✓ Test applications deleted${NC}"

echo ""
echo -e "${YELLOW}Deleting Grafana...${NC}"
kubectl delete -k "$PROJECT_ROOT/deployment/grafana/" 2>/dev/null || true
echo -e "${GREEN}✓ Grafana deleted${NC}"

echo ""
echo -e "${YELLOW}Deleting Tempo...${NC}"
kubectl delete -k "$PROJECT_ROOT/deployment/tempo/" 2>/dev/null || true
echo -e "${GREEN}✓ Tempo deleted${NC}"

echo ""
echo -e "${YELLOW}Deleting Promtail...${NC}"
kubectl delete -k "$PROJECT_ROOT/deployment/promtail/" 2>/dev/null || true
echo -e "${GREEN}✓ Promtail deleted${NC}"

echo ""
echo -e "${YELLOW}Deleting Loki...${NC}"
kubectl delete -k "$PROJECT_ROOT/deployment/loki/" 2>/dev/null || true
echo -e "${GREEN}✓ Loki deleted${NC}"

echo ""
echo -e "${YELLOW}Deleting MinIO...${NC}"
kubectl delete -k "$PROJECT_ROOT/deployment/minio/" 2>/dev/null || true
echo -e "${GREEN}✓ MinIO deleted${NC}"

echo ""
read -p "Delete PersistentVolumeClaims (will delete all data)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deleting PVCs...${NC}"
    kubectl delete pvc -n "$NAMESPACE" --all
    echo -e "${GREEN}✓ PVCs deleted${NC}"
fi

echo ""
read -p "Delete namespace '$NAMESPACE'? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deleting namespace...${NC}"
    kubectl delete namespace "$NAMESPACE"
    echo -e "${GREEN}✓ Namespace deleted${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              Cleanup Complete!                            ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
