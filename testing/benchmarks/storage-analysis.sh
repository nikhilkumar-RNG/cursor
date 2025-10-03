#!/bin/bash
# Loki Storage and Compression Analysis

set -e

MINIO_ENDPOINT="${MINIO_ENDPOINT:-minio.monitoring.svc.cluster.local:9000}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-minioadmin}"
RESULTS_DIR="./results"

mkdir -p "$RESULTS_DIR"

echo "=== Loki Storage & Compression Analysis ==="
echo "Starting analysis at $(date)"

# Function to format bytes
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

echo ""
echo "=== 1. S3/MinIO Storage Usage ==="

# Check if mc (MinIO client) is available
if command -v mc &> /dev/null; then
    mc alias set myminio "http://$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" 2>/dev/null
    
    echo ""
    echo "Loki bucket (loki-data):"
    mc du myminio/loki-data | tee "$RESULTS_DIR/loki_storage.txt"
    
    echo ""
    echo "Tempo bucket (tempo-data):"
    mc du myminio/tempo-data | tee "$RESULTS_DIR/tempo_storage.txt"
    
    echo ""
    echo "Object count in loki-data:"
    mc ls -r myminio/loki-data | wc -l | tee "$RESULTS_DIR/loki_object_count.txt"
    
    echo ""
    echo "Recent chunks (last 20):"
    mc ls -r myminio/loki-data --recursive | tail -20
else
    echo "MinIO client (mc) not available. Install with: curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x /usr/local/bin/mc"
fi

echo ""
echo "=== 2. Kubernetes Volume Usage ==="

# Check Loki pod storage
echo "Loki StatefulSet storage:"
kubectl exec -n monitoring loki-0 -- df -h /loki 2>/dev/null | tee "$RESULTS_DIR/loki_volume_usage.txt" || echo "Could not access Loki pod"

echo ""
echo "Loki disk usage breakdown:"
kubectl exec -n monitoring loki-0 -- du -sh /loki/* 2>/dev/null || echo "Could not access Loki pod"

echo ""
echo "=== 3. Chunk Analysis ==="

# Get chunk statistics from Loki metrics
LOKI_METRICS_URL="${LOKI_URL:-http://loki.monitoring.svc.cluster.local:3100}/metrics"

if command -v curl &> /dev/null; then
    echo ""
    echo "Ingestion statistics (last hour):"
    curl -s "$LOKI_METRICS_URL" | grep -E "loki_ingester_chunk|loki_distributor_bytes" | tee "$RESULTS_DIR/chunk_metrics.txt"
    
    echo ""
    echo "Compression statistics:"
    curl -s "$LOKI_METRICS_URL" | grep -E "loki_chunk_compression_ratio" | tee -a "$RESULTS_DIR/chunk_metrics.txt"
fi

echo ""
echo "=== 4. Retention Configuration ==="

echo "Checking MinIO lifecycle policies:"
if command -v mc &> /dev/null; then
    mc ilm ls myminio/loki-data | tee "$RESULTS_DIR/loki_lifecycle.txt"
    mc ilm ls myminio/tempo-data | tee "$RESULTS_DIR/tempo_lifecycle.txt"
fi

echo ""
echo "=== 5. Storage Efficiency Calculation ==="

# Calculate compression ratio and storage efficiency
cat > "$RESULTS_DIR/storage_analysis.md" <<EOF
# Loki Storage Analysis Report

Generated: $(date)

## Storage Metrics

### Raw Data Ingestion
- **Ingestion Rate**: Check loki_distributor_bytes_received_total metric
- **Time Period**: Last 24 hours
- **Estimated Daily Volume**: Calculate from rate

### Compressed Storage
- **S3 Bucket Size**: See MinIO bucket usage above
- **Number of Chunks**: See object count above
- **Average Chunk Size**: Total size / number of chunks

### Compression Efficiency
- **Compression Ratio**: Typically 5:1 to 10:1 for logs
- **Storage Efficiency**: Compressed size vs raw data

## Comparison with Elasticsearch

### Assumptions
- Elasticsearch replication factor: 1
- Loki compression ratio: ~8:1 (typical)
- Elasticsearch overhead: ~30% (mappings, indices)

### Cost Calculation (30 days retention)

#### For 100GB/day raw logs:
- **Loki Storage**: 100GB / 8 = 12.5GB per day → 375GB total
- **S3 Storage Cost**: 375GB × $0.023/GB = ~$8.60/month
- **Elasticsearch**: 100GB × 1.3 × 30 = 3,900GB total
- **EBS Storage Cost**: 3,900GB × $0.10/GB = ~$390/month

**Savings: ~$381/month (97.8%)**

#### For 1TB/day raw logs:
- **Loki Storage**: 1TB / 8 = 125GB per day → 3.75TB total
- **S3 Storage Cost**: 3,750GB × $0.023/GB = ~$86/month
- **Elasticsearch**: 1TB × 1.3 × 30 = 39TB total
- **EBS Storage Cost**: 39,000GB × $0.10/GB = ~$3,900/month

**Savings: ~$3,814/month (98%)**

## Recommendations

1. **Storage Optimization**
   - Enable chunk compression (already configured)
   - Set appropriate retention periods
   - Use S3 lifecycle policies for cost savings

2. **Query Optimization**
   - Use label-based queries when possible
   - Avoid full-text searches on large time ranges
   - Create alerts based on label queries

3. **Monitoring**
   - Track ingestion rate and storage growth
   - Monitor query performance
   - Set up alerts for storage thresholds

EOF

cat "$RESULTS_DIR/storage_analysis.md"

echo ""
echo "=== Analysis Complete ==="
echo "Results saved to: $RESULTS_DIR/"
