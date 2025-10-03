#!/bin/bash
# Loki Search Performance Benchmark Script

set -e

LOKI_URL="${LOKI_URL:-http://loki.monitoring.svc.cluster.local:3100}"
RESULTS_DIR="./results"
mkdir -p "$RESULTS_DIR"

echo "=== Loki Search Performance Benchmark ==="
echo "Loki URL: $LOKI_URL"
echo "Starting benchmark at $(date)"

# Function to measure query performance
benchmark_query() {
    local query="$1"
    local description="$2"
    local iterations="${3:-5}"
    
    echo ""
    echo "Testing: $description"
    echo "Query: $query"
    
    total_time=0
    for i in $(seq 1 $iterations); do
        start=$(date +%s%3N)
        
        response=$(curl -s -w "\n%{http_code}" \
            -G "$LOKI_URL/loki/api/v1/query_range" \
            --data-urlencode "query=$query" \
            --data-urlencode "start=$(date -d '1 hour ago' +%s)" \
            --data-urlencode "end=$(date +%s)" \
            --data-urlencode "limit=1000")
        
        http_code=$(echo "$response" | tail -n1)
        end=$(date +%s%3N)
        duration=$((end - start))
        total_time=$((total_time + duration))
        
        echo "  Iteration $i: ${duration}ms (HTTP $http_code)"
        
        if [ "$http_code" != "200" ]; then
            echo "  Error: Non-200 response"
            echo "$response" | head -n-1
        fi
    done
    
    avg_time=$((total_time / iterations))
    echo "  Average: ${avg_time}ms"
    echo "$description,$query,$avg_time" >> "$RESULTS_DIR/benchmark_results.csv"
}

# Initialize results file
echo "Test,Query,Average Time (ms)" > "$RESULTS_DIR/benchmark_results.csv"

echo ""
echo "=== 1. Label-based Queries (Fast) ==="

# By namespace
benchmark_query '{namespace="monitoring"}' "Query by namespace" 10

# By app label
benchmark_query '{app="log-generator"}' "Query by app label" 10

# By multiple labels
benchmark_query '{namespace="monitoring",app="log-generator"}' "Query by namespace + app" 10

# By pod name pattern
benchmark_query '{namespace="monitoring",pod=~"loki-.*"}' "Query by pod pattern" 10

echo ""
echo "=== 2. Label + Line Filter (Medium) ==="

# Label + simple text match
benchmark_query '{namespace="monitoring"} |= "ERROR"' "Label + text filter (ERROR)" 10

# Label + regex
benchmark_query '{namespace="monitoring"} |~ "ERROR|WARN"' "Label + regex filter" 10

# Label + JSON parsing
benchmark_query '{namespace="monitoring"} | json | level="ERROR"' "Label + JSON parsing" 10

echo ""
echo "=== 3. Complex Queries (Slower) ==="

# Aggregation
benchmark_query 'sum(count_over_time({namespace="monitoring"}[5m]))' "Count over time aggregation" 5

# Rate calculation
benchmark_query 'rate({namespace="monitoring"}[5m])' "Rate calculation" 5

# Multiple filters and parsing
benchmark_query '{namespace="monitoring"} | json | level="ERROR" | line_format "{{.message}}"' "Complex parsing + filter" 5

echo ""
echo "=== 4. Full-text Search Simulation (Slowest) ==="

# Wide label selector + text search
benchmark_query '{namespace=~".*"} |= "connection timeout"' "Full-text search across namespaces" 5

# Complex text search
benchmark_query '{namespace=~".*"} |~ "(?i)(error|exception|failed)"' "Case-insensitive text search" 5

echo ""
echo "=== Resource Usage Measurement ==="

# Get Loki pod metrics
kubectl top pod -n monitoring -l app=loki > "$RESULTS_DIR/loki_resource_usage.txt" 2>&1 || echo "kubectl top not available"

# Get Loki metrics from Prometheus
if command -v curl &> /dev/null; then
    curl -s "$LOKI_URL/metrics" > "$RESULTS_DIR/loki_metrics.txt"
fi

echo ""
echo "=== Benchmark Summary ==="
cat "$RESULTS_DIR/benchmark_results.csv"

echo ""
echo "Results saved to: $RESULTS_DIR/"
echo "Benchmark completed at $(date)"
