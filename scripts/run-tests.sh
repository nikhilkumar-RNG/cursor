#!/bin/bash
# Run all tests and benchmarks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test-results"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     Loki + Tempo PoC - Test Suite Runner                 ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if stack is deployed
echo -e "${YELLOW}Checking if stack is deployed...${NC}"
if ! kubectl get pods -n monitoring -l app=loki &>/dev/null; then
    echo -e "${RED}✗ Loki not found. Please deploy the stack first:${NC}"
    echo "  ./scripts/deploy-all.sh"
    exit 1
fi
echo -e "${GREEN}✓ Stack is deployed${NC}"
echo ""

# 1. Integration Tests
echo -e "${BLUE}Test 1: Integration Tests${NC}"
echo -e "${YELLOW}Running integration test suite...${NC}"
cd "$PROJECT_ROOT/testing/integration"
bash integration-test-suite.sh | tee "$RESULTS_DIR/integration-tests.log"
echo -e "${GREEN}✓ Integration tests complete${NC}"
echo ""

# 2. Search Benchmark
echo -e "${BLUE}Test 2: Search Performance Benchmark${NC}"
echo -e "${YELLOW}Running search benchmarks...${NC}"
cd "$PROJECT_ROOT/testing/benchmarks"
bash search-benchmark.sh | tee "$RESULTS_DIR/search-benchmark.log"
echo -e "${GREEN}✓ Search benchmark complete${NC}"
echo ""

# 3. Storage Analysis
echo -e "${BLUE}Test 3: Storage and Compression Analysis${NC}"
echo -e "${YELLOW}Running storage analysis...${NC}"
bash storage-analysis.sh | tee "$RESULTS_DIR/storage-analysis.log"
echo -e "${GREEN}✓ Storage analysis complete${NC}"
echo ""

# 4. Resource Monitoring
echo -e "${BLUE}Test 4: Resource Usage Monitoring${NC}"
echo -e "${YELLOW}Monitoring resources for 5 minutes...${NC}"
bash resource-monitoring.sh 300 10 | tee "$RESULTS_DIR/resource-monitoring.log"
echo -e "${GREEN}✓ Resource monitoring complete${NC}"
echo ""

# 5. Cost Calculation
echo -e "${BLUE}Test 5: Cost Analysis${NC}"
echo -e "${YELLOW}Running cost comparison calculator...${NC}"
cd "$PROJECT_ROOT/analysis/cost-calculator"
python3 cost-comparison.py | tee "$RESULTS_DIR/cost-analysis.log"
echo -e "${GREEN}✓ Cost analysis complete${NC}"
echo ""

# Generate summary report
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              Test Summary                                 ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

cat > "$RESULTS_DIR/summary.txt" <<EOF
Loki + Tempo PoC - Test Results Summary
Generated: $(date)

1. Integration Tests:
   - Location: $RESULTS_DIR/integration-tests.log
   - Check for PASS/FAIL counts

2. Search Performance:
   - Location: $RESULTS_DIR/search-benchmark.log
   - Check benchmark_results.csv for timing data

3. Storage Analysis:
   - Location: $RESULTS_DIR/storage-analysis.log
   - Check compression ratios and storage usage

4. Resource Usage:
   - Location: $RESULTS_DIR/resource-monitoring.log
   - Check CPU and memory consumption

5. Cost Analysis:
   - Location: $RESULTS_DIR/cost-analysis.log
   - Check cost_comparison_results.json for detailed breakdown

All results saved to: $RESULTS_DIR/
EOF

cat "$RESULTS_DIR/summary.txt"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              All Tests Complete! 🎉                       ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Results available in: $RESULTS_DIR/"
echo ""
echo "Next steps:"
echo "  1. Review test results in $RESULTS_DIR/"
echo "  2. Check comparison documentation: docs/comparison-results.md"
echo "  3. Review architecture: docs/architecture.md"
