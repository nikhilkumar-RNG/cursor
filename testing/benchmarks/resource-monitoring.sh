#!/bin/bash
# Monitor Loki resource usage under load

set -e

DURATION="${1:-300}"  # Default 5 minutes
INTERVAL="${2:-10}"   # Sample every 10 seconds
RESULTS_DIR="./results"

mkdir -p "$RESULTS_DIR"
OUTPUT_FILE="$RESULTS_DIR/resource_usage_$(date +%Y%m%d_%H%M%S).csv"

echo "=== Loki Resource Usage Monitoring ==="
echo "Duration: ${DURATION}s"
echo "Interval: ${INTERVAL}s"
echo "Output: $OUTPUT_FILE"

# CSV header
echo "Timestamp,Component,CPU(cores),Memory(Mi),CPU%,Memory%" > "$OUTPUT_FILE"

echo ""
echo "Monitoring started. Press Ctrl+C to stop..."

elapsed=0
while [ $elapsed -lt $DURATION ]; do
    timestamp=$(date +%Y-%m-%dT%H:%M:%S)
    
    # Get resource usage for all components
    kubectl top pod -n monitoring --no-headers 2>/dev/null | while read -r line; do
        pod=$(echo "$line" | awk '{print $1}')
        cpu=$(echo "$line" | awk '{print $2}')
        memory=$(echo "$line" | awk '{print $3}')
        
        # Extract component name
        component="unknown"
        case "$pod" in
            loki-*)
                component="loki"
                ;;
            promtail-*)
                component="promtail"
                ;;
            fluent-bit-*)
                component="fluent-bit"
                ;;
            tempo-*)
                component="tempo"
                ;;
            grafana-*)
                component="grafana"
                ;;
            minio-*)
                component="minio"
                ;;
        esac
        
        # Remove 'm' from CPU and 'Mi' from memory
        cpu_val=$(echo "$cpu" | sed 's/m//')
        mem_val=$(echo "$memory" | sed 's/Mi//')
        
        echo "$timestamp,$component,$cpu_val,$mem_val,0,0" >> "$OUTPUT_FILE"
    done 2>/dev/null || echo "kubectl top not available"
    
    # Progress indicator
    echo -ne "\rElapsed: ${elapsed}s / ${DURATION}s"
    
    sleep "$INTERVAL"
    elapsed=$((elapsed + INTERVAL))
done

echo ""
echo ""
echo "=== Monitoring Complete ==="

# Generate summary
echo ""
echo "=== Resource Usage Summary ==="

for component in loki promtail fluent-bit tempo grafana minio; do
    echo ""
    echo "$component:"
    
    # Calculate average, min, max
    awk -F',' -v comp="$component" '
        $2 == comp {
            cpu[NR] = $3
            mem[NR] = $4
            count++
            cpu_sum += $3
            mem_sum += $4
            if (NR == 1 || $3 < cpu_min) cpu_min = $3
            if (NR == 1 || $3 > cpu_max) cpu_max = $3
            if (NR == 1 || $4 < mem_min) mem_min = $4
            if (NR == 1 || $4 > mem_max) mem_max = $4
        }
        END {
            if (count > 0) {
                printf "  CPU:    Avg: %dm, Min: %dm, Max: %dm\n", cpu_sum/count, cpu_min, cpu_max
                printf "  Memory: Avg: %dMi, Min: %dMi, Max: %dMi\n", mem_sum/count, mem_min, mem_max
            }
        }
    ' "$OUTPUT_FILE"
done

echo ""
echo "Detailed results saved to: $OUTPUT_FILE"
