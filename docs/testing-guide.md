# Testing Guide

## Overview

This guide explains how to run tests and benchmarks for the Loki + Tempo PoC.

## Quick Start

### Run All Tests

```bash
./scripts/run-tests.sh
```

This runs:
1. Integration tests
2. Search performance benchmarks
3. Storage analysis
4. Resource monitoring
5. Cost calculations

Results saved to: `test-results/`

## Individual Tests

### 1. Integration Test Suite

Tests that all components are working together correctly.

```bash
cd testing/integration
./integration-test-suite.sh
```

**Tests**:
- ✅ Component health checks (Loki, Tempo, Grafana)
- ✅ Data ingestion verification
- ✅ Query API functionality
- ✅ Storage backend connectivity
- ✅ Grafana datasource configuration
- ✅ Trace-log correlation
- ✅ Resource usage validation

**Expected Output**:
```
✓ PASS: Loki is ready
✓ PASS: Tempo is ready
✓ PASS: Grafana is healthy
✓ PASS: Loki is receiving logs
✓ PASS: Can query logs by trace_id in Loki
...
```

**Time**: ~2 minutes

### 2. Search Performance Benchmark

Measures query performance for different query types.

```bash
cd testing/benchmarks
./search-benchmark.sh
```

**Tests**:
- Label-based queries (fast)
- Label + line filters (medium)
- Complex aggregations (slower)
- Full-text search simulation (slowest)

**Output**: `results/benchmark_results.csv`

**Sample Results**:
```
Test,Query,Average Time (ms)
Query by namespace,{namespace="monitoring"},45
Query by app label,{app="log-generator"},52
Label + text filter (ERROR),{namespace="monitoring"} |= "ERROR",124
Full-text search across namespaces,{namespace=~".*"} |= "error",1247
```

**Time**: ~5 minutes

### 3. Storage & Compression Analysis

Analyzes storage usage, compression ratios, and object storage efficiency.

```bash
cd testing/benchmarks
./storage-analysis.sh
```

**Checks**:
- S3/MinIO bucket sizes
- Object counts
- Compression ratios
- Chunk statistics
- Lifecycle policies
- Storage efficiency calculations

**Output**: 
- `results/storage_analysis.md`
- `results/loki_storage.txt`
- `results/tempo_storage.txt`

**Time**: ~2 minutes

### 4. Resource Monitoring

Monitors CPU and memory usage under load.

```bash
cd testing/benchmarks
./resource-monitoring.sh 300 10  # 5 minutes, sample every 10 seconds
```

**Parameters**:
- Duration (seconds): 300
- Interval (seconds): 10

**Output**: `results/resource_usage_TIMESTAMP.csv`

**Generates**:
- Average, min, max for each component
- CPU usage over time
- Memory usage over time

**Time**: 5 minutes (configurable)

### 5. Cost Comparison Calculator

Calculates storage and infrastructure costs vs ELK.

```bash
cd analysis/cost-calculator
python3 cost-comparison.py
```

**Scenarios**:
- Small: 10 GB/day, 30 days retention
- Medium: 100 GB/day, 30 days retention
- Large: 1 TB/day, 30 days retention
- Extended: 100 GB/day, 90 days retention

**Output**: 
- Console output with detailed comparison
- `cost_comparison_results.json`

**Time**: < 1 minute

## Test Applications

### Log Generator

Generates test logs with various patterns.

```bash
kubectl apply -f testing/log-generator/log-generator.yaml
```

**Features**:
- Structured JSON logs
- Multiple log levels (INFO, WARN, ERROR, DEBUG)
- Trace IDs for correlation
- Configurable rate (1-10 logs/sec per pod)

**View logs**:
```bash
kubectl logs -n monitoring -l app=log-generator --tail=20
```

### Trace-Log Correlation Test App

Generates traces with OpenTelemetry and correlated logs.

```bash
kubectl apply -f testing/integration/trace-log-correlation-test.yaml
```

**Features**:
- Simulates multi-span traces
- Includes trace_id in logs
- Sends traces to Tempo via OTLP
- Generates RED metrics

**View logs**:
```bash
kubectl logs -n monitoring -l app=correlation-test-app --tail=20
```

## Sample Queries

### LogQL Queries

See detailed examples in: `testing/queries/sample-logql-queries.md`

**Basic queries**:
```logql
# By namespace
{namespace="monitoring"}

# By app with filter
{app="log-generator"} |= "ERROR"

# JSON parsing
{namespace="monitoring"} | json | level="ERROR"

# Aggregation
sum(rate({namespace="monitoring"}[5m]))
```

### TraceQL Queries

See detailed examples in: `testing/queries/sample-traceql-queries.md`

**Basic queries**:
```traceql
# All traces
{}

# By service
{service.name="correlation-test-app"}

# High latency
{duration>1s}

# Error traces
{status=error}
```

## Manual Testing in Grafana

### 1. Access Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Open: http://localhost:3000 (admin/admin)

### 2. Test Loki Datasource

1. Go to **Explore**
2. Select **Loki** datasource
3. Try these queries:

**View all logs in monitoring namespace**:
```logql
{namespace="monitoring"}
```

**Find errors**:
```logql
{namespace="monitoring"} |= "ERROR"
```

**Parse JSON and filter**:
```logql
{app="log-generator"} | json | level="ERROR"
```

### 3. Test Tempo Datasource

1. Go to **Explore**
2. Select **Tempo** datasource
3. Click **Search**
4. Select service: `correlation-test-app`
5. Click **Run query**

### 4. Test Log-Trace Correlation

**From Logs to Traces**:
1. In Loki, query: `{app="correlation-test-app"} | json`
2. Find a log line with `trace_id`
3. Click on the trace_id link
4. Opens trace in Tempo ✅

**From Traces to Logs**:
1. In Tempo, find a trace
2. Click on a span
3. Click **"Logs for this span"**
4. Opens correlated logs in Loki ✅

### 5. Test Service Map

1. In Tempo, go to **Service Graph** (if metrics-generator is enabled)
2. View service dependencies
3. Click on services to see traces

## Troubleshooting Tests

### No logs in Loki

**Check Promtail**:
```bash
kubectl logs -n monitoring -l app=promtail --tail=50
```

**Verify Loki is receiving**:
```bash
kubectl port-forward -n monitoring svc/loki 3100:3100
curl http://localhost:3100/metrics | grep loki_distributor_bytes_received_total
```

### No traces in Tempo

**Check if test app is running**:
```bash
kubectl get pods -n monitoring -l app=correlation-test-app
```

**Check app logs**:
```bash
kubectl logs -n monitoring -l app=correlation-test-app --tail=20
```

Should see traces being sent.

**Verify Tempo is receiving**:
```bash
kubectl port-forward -n monitoring svc/tempo 3200:3200
curl http://localhost:3200/metrics | grep tempo_distributor_spans_received_total
```

### Benchmark script fails

**Check dependencies**:
```bash
# curl required
command -v curl || sudo apt-get install curl

# jq useful for parsing
command -v jq || sudo apt-get install jq
```

**Check connectivity**:
```bash
kubectl port-forward -n monitoring svc/loki 3100:3100 &
curl http://localhost:3100/ready
```

### Storage analysis fails

**Install MinIO client**:
```bash
curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x /usr/local/bin/mc
```

**Port forward MinIO**:
```bash
kubectl port-forward -n monitoring svc/minio 9000:9000 &
```

## Performance Baseline

Expected performance on typical setup:

| Metric | Value |
|--------|-------|
| Label query (namespace) | 30-60 ms |
| Label + text filter | 100-200 ms |
| JSON parsing + filter | 150-300 ms |
| Aggregation (5m range) | 300-500 ms |
| Full-text search | 1-3 seconds |
| Trace query by ID | 50-150 ms |
| Trace search | 200-800 ms |

**Resources (100 GB/day)**:
- Loki: 1-2 CPU cores, 2-4 GB RAM
- Tempo: 0.5-1 CPU cores, 1-2 GB RAM
- Promtail: 0.1 CPU cores, 128 MB RAM per node

## Continuous Testing

### Automated Testing

Create a cron job for continuous testing:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: loki-tempo-tests
  namespace: monitoring
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: tests
            image: appropriate/curl
            command:
            - /bin/sh
            - -c
            - |
              # Run basic health checks
              curl -f http://loki.monitoring.svc.cluster.local:3100/ready
              curl -f http://tempo.monitoring.svc.cluster.local:3200/ready
          restartPolicy: OnFailure
```

### Alerting on Test Failures

Set up alerts for:
- Loki ingestion stopped
- Tempo ingestion stopped
- Query latency > threshold
- Storage usage > threshold

## Test Results Interpretation

### Integration Tests

**All PASS**: ✅ System is working correctly
**Some WARN**: ⚠️ May need more time for data ingestion
**Any FAIL**: ❌ Check component logs

### Search Benchmarks

**Acceptable**:
- Label queries: < 100 ms
- JSON parsing: < 300 ms
- Aggregations: < 1 second

**Needs tuning**:
- Label queries: > 200 ms
- Aggregations: > 2 seconds

### Storage Analysis

**Good compression**: 6:1 to 10:1 ratio
**Normal compression**: 4:1 to 6:1 ratio
**Poor compression**: < 4:1 ratio (check log format)

### Resource Usage

**Normal for 100 GB/day**:
- Loki: 1-2 cores, 2-4 GB RAM
- Tempo: 0.5-1 cores, 1-2 GB RAM

**Concerning**:
- Loki: > 4 cores or > 8 GB RAM
- Memory constantly increasing (leak?)

## Next Steps

After testing:
1. Review results in `test-results/`
2. Compare with baseline expectations
3. Check [Comparison Results](comparison-results.md)
4. Review [Architecture](architecture.md)
5. Plan deployment to production
