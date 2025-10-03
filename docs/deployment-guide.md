# Deployment Guide: Loki + Tempo Stack

## Prerequisites

### Cluster Requirements
- Kubernetes 1.20+
- kubectl configured with cluster access
- At least 8 GB RAM and 4 CPUs available
- StorageClass for PersistentVolumes
- Helm 3.x (optional, for alternative deployment)

### Tools Required
- `kubectl`
- `kustomize` (built into kubectl 1.14+)
- `curl` (for testing)
- `mc` (MinIO client, optional for S3 verification)

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd loki-tempo-poc
```

### 2. Deploy Complete Stack

```bash
# Deploy all components
./scripts/deploy-all.sh

# Or deploy individually
kubectl create namespace monitoring
kubectl apply -k deployment/minio/
kubectl apply -k deployment/loki/
kubectl apply -k deployment/promtail/
kubectl apply -k deployment/tempo/
kubectl apply -k deployment/grafana/
```

### 3. Wait for Components

```bash
# Watch deployment
kubectl get pods -n monitoring -w

# Check status
kubectl get pods -n monitoring
```

Expected output:
```
NAME                      READY   STATUS    RESTARTS   AGE
loki-0                    1/1     Running   0          5m
promtail-xxxxx            1/1     Running   0          5m
promtail-yyyyy            1/1     Running   0          5m
tempo-0                   1/1     Running   0          5m
grafana-xxxxxxxxxx-zzzzz  1/1     Running   0          5m
minio-xxxxxxxxxx-aaaaa    1/1     Running   0          5m
```

### 4. Access Grafana

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Open browser
http://localhost:3000
# Username: admin
# Password: admin
```

## Detailed Deployment Steps

### Step 1: Deploy MinIO (Object Storage)

MinIO provides S3-compatible storage for lab/dev environments.

```bash
kubectl apply -k deployment/minio/
```

**Wait for MinIO to be ready:**
```bash
kubectl wait --for=condition=ready pod -l app=minio -n monitoring --timeout=300s
```

**Verify MinIO setup:**
```bash
# Check if setup job completed
kubectl get job -n monitoring minio-setup

# View setup logs
kubectl logs -n monitoring job/minio-setup
```

**Access MinIO Console (optional):**
```bash
kubectl port-forward -n monitoring svc/minio 9001:9001

# Open http://localhost:9001
# Username: minioadmin
# Password: minioadmin
```

### Step 2: Deploy Loki

```bash
kubectl apply -k deployment/loki/
```

**Components deployed:**
- Loki StatefulSet (1 replica)
- Loki Service
- Loki ConfigMap with boltdb-shipper + S3 config
- MinIO secret for S3 access

**Verify Loki:**
```bash
# Check pod status
kubectl get pods -n monitoring -l app=loki

# Check logs
kubectl logs -n monitoring loki-0 --tail=50

# Test Loki API
kubectl port-forward -n monitoring svc/loki 3100:3100
curl http://localhost:3100/ready
```

Expected: `ready`

**Check metrics:**
```bash
curl http://localhost:3100/metrics | grep loki_build_info
```

### Step 3: Deploy Promtail (Log Collector)

Choose either Promtail (recommended) or Fluent Bit.

#### Option A: Promtail (Recommended)

```bash
kubectl apply -k deployment/promtail/
```

**Verify Promtail:**
```bash
# Check DaemonSet
kubectl get daemonset -n monitoring promtail

# Check pods (one per node)
kubectl get pods -n monitoring -l app=promtail

# View logs
kubectl logs -n monitoring -l app=promtail --tail=20
```

#### Option B: Fluent Bit (Alternative)

```bash
kubectl apply -k deployment/fluent-bit/
```

**Note**: Don't deploy both Promtail and Fluent Bit simultaneously.

### Step 4: Deploy Tempo (Distributed Tracing)

```bash
kubectl apply -k deployment/tempo/
```

**Components deployed:**
- Tempo StatefulSet (1 replica)
- Tempo Service (multiple ports for different protocols)
- Tempo ConfigMap with metrics generator
- MinIO secret for S3 access

**Verify Tempo:**
```bash
# Check pod
kubectl get pods -n monitoring -l app=tempo

# Check logs
kubectl logs -n monitoring tempo-0 --tail=50

# Test Tempo API
kubectl port-forward -n monitoring svc/tempo 3200:3200
curl http://localhost:3200/ready
```

**Check supported protocols:**
```bash
kubectl get svc -n monitoring tempo -o yaml | grep -A 10 "^  ports:"
```

Ports available:
- 3200: HTTP API
- 4317: OTLP gRPC
- 4318: OTLP HTTP
- 14250: Jaeger gRPC
- 14268: Jaeger HTTP
- 9411: Zipkin

### Step 5: Deploy Grafana

```bash
kubectl apply -k deployment/grafana/
```

**Components deployed:**
- Grafana Deployment
- Grafana Service
- Datasources (Loki, Tempo, Prometheus)
- Pre-configured dashboards

**Verify Grafana:**
```bash
# Check pod
kubectl get pods -n monitoring -l app=grafana

# Wait for ready
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s

# Port forward
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

**Access Grafana:**
1. Open http://localhost:3000
2. Login: `admin` / `admin`
3. Navigate to Explore
4. Select Loki datasource
5. Run query: `{namespace="monitoring"}`

### Step 6: Deploy Test Applications

#### Log Generator

```bash
kubectl apply -f testing/log-generator/log-generator.yaml
```

This deploys a test application that generates logs with various patterns.

#### Trace-Log Correlation Test

```bash
kubectl apply -f testing/integration/trace-log-correlation-test.yaml
```

This deploys an application that generates traces and logs with trace_id for correlation.

**Verify test apps:**
```bash
# Check log generator
kubectl get pods -n monitoring -l app=log-generator

# Check correlation test app
kubectl get pods -n monitoring -l app=correlation-test-app

# View logs
kubectl logs -n monitoring -l app=log-generator --tail=10
kubectl logs -n monitoring -l app=correlation-test-app --tail=10
```

## Verification Steps

### 1. Verify Log Ingestion

```bash
# Port forward Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Query logs
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode "time=$(date +%s)" | jq .
```

### 2. Verify Trace Ingestion

```bash
# Port forward Tempo
kubectl port-forward -n monitoring svc/tempo 3200:3200

# Search for services
curl -s "http://localhost:3200/api/search?tags=service.name" | jq .
```

### 3. Verify Storage

```bash
# Install MinIO client
curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x /usr/local/bin/mc

# Configure access (port-forward MinIO first)
kubectl port-forward -n monitoring svc/minio 9000:9000
mc alias set myminio http://localhost:9000 minioadmin minioadmin

# Check buckets
mc ls myminio/loki-data
mc ls myminio/tempo-data

# Check storage usage
mc du myminio/loki-data
mc du myminio/tempo-data
```

### 4. Verify Grafana Integration

In Grafana (http://localhost:3000):

**Test Loki:**
1. Go to Explore
2. Select "Loki" datasource
3. Query: `{namespace="monitoring"} |= "ERROR"`
4. Should see logs with trace_id

**Test Tempo:**
1. Go to Explore
2. Select "Tempo" datasource
3. Search for traces
4. Click on a trace
5. Click "Logs for this span" → should open logs

**Test Correlation:**
1. In Loki logs, find a trace_id
2. Click on trace_id link
3. Should open trace in Tempo
4. Verify spans and timing

## Configuration Customization

### Adjust Retention Period

Edit `deployment/loki/loki-config.yaml`:
```yaml
limits_config:
  retention_period: 2160h  # Change to 90 days

compactor:
  compaction:
    block_retention: 2160h  # Match retention
```

Edit MinIO lifecycle (in `deployment/minio/minio-deployment.yaml` Job):
```json
{
  "Rules": [{
    "Expiration": {"Days": 90},  # Change to 90 days
    "Status": "Enabled"
  }]
}
```

### Change Storage Backend (Production S3)

Edit `deployment/loki/loki-config.yaml`:
```yaml
storage_config:
  aws:
    s3: s3://my-loki-bucket
    endpoint: s3.amazonaws.com  # Or regional endpoint
    region: us-east-1
    access_key_id: ${AWS_ACCESS_KEY_ID}
    secret_access_key: ${AWS_SECRET_ACCESS_KEY}
    s3forcepathstyle: false
    insecure: false
```

Update secrets:
```bash
kubectl create secret generic loki-s3-secret \
  --from-literal=access-key-id="YOUR_KEY" \
  --from-literal=secret-access-key="YOUR_SECRET" \
  -n monitoring
```

### Scale Loki

Edit `deployment/loki/loki-deployment.yaml`:
```yaml
spec:
  replicas: 3  # Increase replicas
```

Or use kubectl:
```bash
kubectl scale statefulset loki -n monitoring --replicas=3
```

### Adjust Resource Limits

Edit resource requests/limits in deployment files:
```yaml
resources:
  requests:
    cpu: 1000m      # Increase as needed
    memory: 2Gi
  limits:
    cpu: 4000m
    memory: 8Gi
```

## Troubleshooting

### Loki Not Receiving Logs

**Check Promtail logs:**
```bash
kubectl logs -n monitoring -l app=promtail --tail=50
```

Look for errors like:
- Connection refused → Loki service not ready
- 429 errors → Rate limit exceeded
- Authentication errors → Check secrets

**Check Loki logs:**
```bash
kubectl logs -n monitoring loki-0 --tail=100
```

**Verify network:**
```bash
kubectl exec -n monitoring -it loki-0 -- wget -O- http://loki:3100/ready
```

### S3/MinIO Connection Issues

**Check MinIO status:**
```bash
kubectl get pods -n monitoring -l app=minio
kubectl logs -n monitoring -l app=minio
```

**Verify buckets exist:**
```bash
kubectl exec -n monitoring -it loki-0 -- sh
# Inside pod
ls -la /loki/
```

**Check secrets:**
```bash
kubectl get secret -n monitoring loki-minio-secret -o yaml
```

### Tempo Not Receiving Traces

**Check if test app is sending traces:**
```bash
kubectl logs -n monitoring -l app=correlation-test-app --tail=20
```

Should see: "Sending traces to Tempo..."

**Check Tempo logs:**
```bash
kubectl logs -n monitoring tempo-0 --tail=100
```

**Test Tempo endpoints:**
```bash
kubectl port-forward -n monitoring svc/tempo 4317:4317
# Send test trace with grpcurl or similar
```

### Grafana Datasource Issues

**Check datasource configuration:**
1. In Grafana: Configuration → Data Sources
2. Click on Loki/Tempo
3. Click "Test" button
4. Should see "Data source is working"

**If test fails:**
- Check service names: `loki.monitoring.svc.cluster.local:3100`
- Check namespace
- Check pod status of target service

**View Grafana logs:**
```bash
kubectl logs -n monitoring -l app=grafana --tail=50
```

### High Memory Usage

**Check resource usage:**
```bash
kubectl top pods -n monitoring
```

**If Loki is high:**
- Reduce `max_query_series` in config
- Reduce `chunk_idle_period` to flush more frequently
- Increase memory limits or scale horizontally

**If Tempo is high:**
- Reduce `max_block_bytes` in config
- Flush traces more frequently
- Scale horizontally

## Performance Tuning

### For High Log Volume (> 100 GB/day)

1. **Increase replication:**
```yaml
spec:
  replicas: 3
```

2. **Tune chunk settings:**
```yaml
ingester:
  chunk_idle_period: 3m  # Flush more frequently
  chunk_block_size: 262144  # 256KB chunks
```

3. **Enable query splitting:**
```yaml
query_range:
  split_queries_by_interval: 15m
```

4. **Use separate read/write paths** (advanced):
   - Deploy separate querier pods
   - Deploy query-frontend for caching

### For Fast Queries

1. **Use specific labels:**
```logql
{namespace="prod", app="api"}  # Fast
{namespace=~".*"} |= "error"   # Slower
```

2. **Limit time range:**
```logql
{namespace="prod"}[5m]   # Fast
{namespace="prod"}[24h]  # Slower
```

3. **Enable caching:**
```yaml
query_range:
  cache_results: true
```

## Production Checklist

Before moving to production:

- [ ] Switch MinIO to AWS S3
- [ ] Enable authentication/multi-tenancy
- [ ] Configure TLS for all services
- [ ] Set up monitoring and alerting
- [ ] Configure backup strategy
- [ ] Test disaster recovery
- [ ] Document runbooks
- [ ] Set up log rotation
- [ ] Configure resource quotas
- [ ] Enable pod anti-affinity
- [ ] Test failure scenarios
- [ ] Configure network policies
- [ ] Set up CI/CD for updates
- [ ] Load test the system

## Uninstall

### Remove All Components

```bash
./scripts/cleanup.sh
```

Or manually:
```bash
kubectl delete -k deployment/grafana/
kubectl delete -k deployment/tempo/
kubectl delete -k deployment/promtail/
kubectl delete -k deployment/loki/
kubectl delete -k deployment/minio/

# Remove test apps
kubectl delete -f testing/log-generator/log-generator.yaml
kubectl delete -f testing/integration/trace-log-correlation-test.yaml

# Remove PVCs
kubectl delete pvc -n monitoring --all

# Remove namespace (optional)
kubectl delete namespace monitoring
```

## Next Steps

1. Review [Architecture Documentation](architecture.md)
2. Run [Performance Benchmarks](../testing/benchmarks/)
3. Review [Cost Analysis](../analysis/cost-calculator/)
4. Read [Comparison Results](comparison-results.md)
