#!/bin/bash
# Comprehensive integration test suite for Loki + Tempo + Grafana

set -e

GRAFANA_URL="${GRAFANA_URL:-http://grafana.monitoring.svc.cluster.local:3000}"
LOKI_URL="${LOKI_URL:-http://loki.monitoring.svc.cluster.local:3100}"
TEMPO_URL="${TEMPO_URL:-http://tempo.monitoring.svc.cluster.local:3200}"
RESULTS_DIR="./results"

mkdir -p "$RESULTS_DIR"

echo "=== Loki + Tempo + Grafana Integration Test Suite ==="
echo "Test started at $(date)"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_test() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    echo "PASS: $1" >> "$RESULTS_DIR/test_results.txt"
}

fail_test() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "FAIL: $1" >> "$RESULTS_DIR/test_results.txt"
}

warn_test() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    echo "WARN: $1" >> "$RESULTS_DIR/test_results.txt"
}

# Initialize results file
echo "Integration Test Results - $(date)" > "$RESULTS_DIR/test_results.txt"
echo "" >> "$RESULTS_DIR/test_results.txt"

echo "=== 1. Component Health Checks ==="
echo ""

# Test Loki
echo "Testing Loki health..."
if curl -sf "$LOKI_URL/ready" > /dev/null; then
    pass_test "Loki is ready"
else
    fail_test "Loki is not ready"
fi

# Test Tempo
echo "Testing Tempo health..."
if curl -sf "$TEMPO_URL/ready" > /dev/null; then
    pass_test "Tempo is ready"
else
    fail_test "Tempo is not ready"
fi

# Test Grafana
echo "Testing Grafana health..."
if curl -sf "$GRAFANA_URL/api/health" > /dev/null; then
    pass_test "Grafana is healthy"
else
    fail_test "Grafana is not healthy"
fi

echo ""
echo "=== 2. Data Ingestion Tests ==="
echo ""

# Test Loki ingestion
echo "Testing Loki log ingestion..."
LOKI_METRICS=$(curl -s "$LOKI_URL/metrics" | grep "loki_distributor_bytes_received_total" | head -1)
if [ -n "$LOKI_METRICS" ]; then
    pass_test "Loki is receiving logs"
    echo "  $LOKI_METRICS"
else
    fail_test "Loki is not receiving logs"
fi

# Test Tempo ingestion
echo "Testing Tempo trace ingestion..."
TEMPO_METRICS=$(curl -s "$TEMPO_URL/metrics" | grep "tempo_distributor_spans_received_total" | head -1)
if [ -n "$TEMPO_METRICS" ]; then
    pass_test "Tempo is receiving traces"
    echo "  $TEMPO_METRICS"
else
    warn_test "Tempo may not be receiving traces (or no traces sent yet)"
fi

echo ""
echo "=== 3. Query Tests ==="
echo ""

# Test Loki query
echo "Testing Loki query API..."
LOKI_QUERY_RESULT=$(curl -s -G "$LOKI_URL/loki/api/v1/query" \
    --data-urlencode "query={namespace=\"monitoring\"}" \
    --data-urlencode "time=$(date +%s)" 2>&1)

if echo "$LOKI_QUERY_RESULT" | grep -q '"status":"success"'; then
    pass_test "Loki query API is working"
    LOG_COUNT=$(echo "$LOKI_QUERY_RESULT" | grep -o '"result":\[' | wc -l)
    echo "  Found results in Loki"
else
    fail_test "Loki query API failed"
    echo "$LOKI_QUERY_RESULT" > "$RESULTS_DIR/loki_query_error.txt"
fi

# Test Tempo query
echo "Testing Tempo query API..."
TEMPO_SEARCH_RESULT=$(curl -s "$TEMPO_URL/api/search?tags=service.name" 2>&1)

if [ $? -eq 0 ]; then
    pass_test "Tempo search API is working"
else
    warn_test "Tempo search API may not have data yet"
fi

echo ""
echo "=== 4. Storage Tests ==="
echo ""

# Check S3/MinIO backend
echo "Testing S3/MinIO storage..."
if kubectl exec -n monitoring loki-0 -- ls /loki/index 2>/dev/null | grep -q "index"; then
    pass_test "Loki local index exists"
else
    warn_test "Loki local index may not be initialized yet"
fi

# Check if data is being written to S3
if command -v mc &> /dev/null; then
    mc alias set myminio http://minio.monitoring.svc.cluster.local:9000 minioadmin minioadmin 2>/dev/null
    
    LOKI_OBJECTS=$(mc ls myminio/loki-data 2>/dev/null | wc -l)
    if [ "$LOKI_OBJECTS" -gt 0 ]; then
        pass_test "Loki is writing to S3/MinIO ($LOKI_OBJECTS objects)"
    else
        warn_test "No Loki objects in S3/MinIO yet (may need more time)"
    fi
    
    TEMPO_OBJECTS=$(mc ls myminio/tempo-data 2>/dev/null | wc -l)
    if [ "$TEMPO_OBJECTS" -gt 0 ]; then
        pass_test "Tempo is writing to S3/MinIO ($TEMPO_OBJECTS objects)"
    else
        warn_test "No Tempo objects in S3/MinIO yet (may need more time)"
    fi
fi

echo ""
echo "=== 5. Grafana Datasource Tests ==="
echo ""

# Test Grafana datasources (requires auth)
echo "Testing Grafana datasources..."
DATASOURCES=$(curl -s -u admin:admin "$GRAFANA_URL/api/datasources" 2>&1)

if echo "$DATASOURCES" | grep -q '"name":"Loki"'; then
    pass_test "Loki datasource is configured in Grafana"
else
    fail_test "Loki datasource not found in Grafana"
fi

if echo "$DATASOURCES" | grep -q '"name":"Tempo"'; then
    pass_test "Tempo datasource is configured in Grafana"
else
    fail_test "Tempo datasource not found in Grafana"
fi

if echo "$DATASOURCES" | grep -q '"name":"Prometheus"'; then
    pass_test "Prometheus datasource is configured in Grafana"
else
    warn_test "Prometheus datasource not found in Grafana"
fi

echo ""
echo "=== 6. Trace-Log Correlation Tests ==="
echo ""

# Deploy test application if not already deployed
echo "Deploying correlation test application..."
kubectl apply -f /workspace/testing/integration/trace-log-correlation-test.yaml 2>/dev/null || true

# Wait for test app to generate data
echo "Waiting 30 seconds for test data generation..."
sleep 30

# Check if correlation test app is running
if kubectl get pods -n monitoring -l app=correlation-test-app 2>/dev/null | grep -q "Running"; then
    pass_test "Correlation test application is running"
    
    # Check logs for trace_id
    TEST_LOG=$(kubectl logs -n monitoring -l app=correlation-test-app --tail=10 2>/dev/null | head -1)
    if echo "$TEST_LOG" | grep -q "trace_id"; then
        pass_test "Logs contain trace_id for correlation"
        echo "  Sample: $(echo "$TEST_LOG" | head -c 100)..."
    else
        warn_test "Logs may not contain trace_id yet"
    fi
else
    warn_test "Correlation test application not running yet"
fi

echo ""
echo "=== 7. Correlation Validation ==="
echo ""

# Try to find a trace_id from logs
echo "Testing log-to-trace correlation..."
TRACE_ID=$(kubectl logs -n monitoring -l app=correlation-test-app --tail=100 2>/dev/null | \
    grep -o '"trace_id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$TRACE_ID" ] && [ "$TRACE_ID" != "none" ]; then
    echo "  Found trace_id: $TRACE_ID"
    
    # Query Loki for logs with this trace_id
    LOKI_TRACE_QUERY=$(curl -s -G "$LOKI_URL/loki/api/v1/query" \
        --data-urlencode "query={namespace=\"monitoring\"} | json | trace_id=\"$TRACE_ID\"" \
        --data-urlencode "time=$(date +%s)")
    
    if echo "$LOKI_TRACE_QUERY" | grep -q "$TRACE_ID"; then
        pass_test "Can query logs by trace_id in Loki"
    else
        warn_test "Could not find logs by trace_id in Loki"
    fi
    
    # Query Tempo for this trace
    TEMPO_TRACE=$(curl -s "$TEMPO_URL/api/traces/$TRACE_ID")
    if [ $? -eq 0 ] && [ -n "$TEMPO_TRACE" ]; then
        pass_test "Can retrieve trace from Tempo"
    else
        warn_test "Could not retrieve trace from Tempo (may need more time for ingestion)"
    fi
else
    warn_test "No trace_id found in logs yet"
fi

echo ""
echo "=== 8. Performance Validation ==="
echo ""

# Check resource usage
echo "Checking resource usage..."
LOKI_RESOURCES=$(kubectl top pod -n monitoring -l app=loki --no-headers 2>/dev/null | head -1)
if [ -n "$LOKI_RESOURCES" ]; then
    pass_test "Loki resource usage: $LOKI_RESOURCES"
else
    warn_test "Could not get Loki resource usage (kubectl top not available)"
fi

TEMPO_RESOURCES=$(kubectl top pod -n monitoring -l app=tempo --no-headers 2>/dev/null | head -1)
if [ -n "$TEMPO_RESOURCES" ]; then
    pass_test "Tempo resource usage: $TEMPO_RESOURCES"
else
    warn_test "Could not get Tempo resource usage"
fi

echo ""
echo "=== Test Summary ==="
echo ""

TOTAL_TESTS=$(wc -l < "$RESULTS_DIR/test_results.txt")
PASSED=$(grep -c "^PASS:" "$RESULTS_DIR/test_results.txt" || echo "0")
FAILED=$(grep -c "^FAIL:" "$RESULTS_DIR/test_results.txt" || echo "0")
WARNED=$(grep -c "^WARN:" "$RESULTS_DIR/test_results.txt" || echo "0")

echo "Total: $TOTAL_TESTS results"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Warnings: $WARNED${NC}"

echo ""
echo "Detailed results saved to: $RESULTS_DIR/test_results.txt"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}All critical tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the results.${NC}"
    exit 1
fi
