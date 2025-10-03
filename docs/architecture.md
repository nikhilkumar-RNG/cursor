# Loki + Tempo Architecture

## Overview

This document describes the architecture of the Loki + Tempo observability stack deployed in Kubernetes for log storage and distributed tracing.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                          │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                      Application Pods                         │ │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐                    │ │
│  │  │ API  │  │User  │  │Order │  │ ...  │                    │ │
│  │  │Gateway│  │Service│  │Service│        │                    │ │
│  │  └───┬──┘  └───┬──┘  └───┬──┘  └───┬──┘                    │ │
│  │      │         │         │          │                        │ │
│  │      │ stdout  │         │          │                        │ │
│  │      └─────────┴─────────┴──────────┘                        │ │
│  │                       │                                       │ │
│  └───────────────────────┼───────────────────────────────────────┘ │
│                          │                                         │
│  ┌───────────────────────▼────────────────┐                       │
│  │         Log Collection Layer           │                       │
│  │  ┌─────────────┐  ┌──────────────┐   │                       │
│  │  │  Promtail   │  │  Fluent Bit  │   │                       │
│  │  │ DaemonSet   │  │  DaemonSet   │   │                       │
│  │  │             │  │  (optional)  │   │                       │
│  │  └──────┬──────┘  └──────┬───────┘   │                       │
│  └─────────┼────────────────┼────────────┘                       │
│            │                │                                     │
│  ┌─────────▼────────────────▼────────────┐                       │
│  │              Loki                      │                       │
│  │  ┌──────────────────────────────────┐ │                       │
│  │  │      Distributor                 │ │                       │
│  │  └────────────┬─────────────────────┘ │                       │
│  │  ┌────────────▼─────────────────────┐ │                       │
│  │  │      Ingester (WAL)              │ │                       │
│  │  └────────────┬─────────────────────┘ │                       │
│  │  ┌────────────▼─────────────────────┐ │                       │
│  │  │      Querier                     │ │                       │
│  │  └────────────┬─────────────────────┘ │                       │
│  │  ┌────────────▼─────────────────────┐ │                       │
│  │  │      Compactor                   │ │                       │
│  │  └──────────────────────────────────┘ │                       │
│  └───────────────┬────────────────────────┘                       │
│                  │                                                │
│  ┌───────────────▼────────────────────────┐                       │
│  │         Object Storage (S3/MinIO)      │                       │
│  │  ┌──────────────┐  ┌──────────────┐   │                       │
│  │  │  loki-data   │  │  tempo-data  │   │                       │
│  │  │   bucket     │  │   bucket     │   │                       │
│  │  │              │  │              │   │                       │
│  │  │ [30d retain] │  │ [30d retain] │   │                       │
│  │  └──────────────┘  └──────────────┘   │                       │
│  └────────────────────────────────────────┘                       │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                   Distributed Tracing                         │ │
│  │                                                                │ │
│  │  Application Pods ──OTLP/Jaeger──▶ Tempo                    │ │
│  │                                       │                       │ │
│  │                                       ▼                       │ │
│  │                              ┌────────────────┐              │ │
│  │                              │  Distributor   │              │ │
│  │                              └────────┬───────┘              │ │
│  │                              ┌────────▼───────┐              │ │
│  │                              │   Ingester     │              │ │
│  │                              └────────┬───────┘              │ │
│  │                              ┌────────▼───────┐              │ │
│  │                              │   Querier      │              │ │
│  │                              └────────┬───────┘              │ │
│  │                                       │                       │ │
│  │                                       ▼                       │ │
│  │                              Object Storage (S3)             │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                        Grafana                                │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                   │ │
│  │  │   Loki   │  │   Tempo  │  │Prometheus│                   │ │
│  │  │Datasource│  │Datasource│  │Datasource│                   │ │
│  │  └─────┬────┘  └─────┬────┘  └─────┬────┘                   │ │
│  │        └──────────────┴─────────────┘                        │ │
│  │                      │                                        │ │
│  │          ┌───────────▼───────────┐                           │ │
│  │          │  Unified Explore UI   │                           │ │
│  │          │  - Logs ↔ Traces      │                           │ │
│  │          │  - Traces ↔ Metrics   │                           │ │
│  │          └───────────────────────┘                           │ │
│  └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Log Collection Layer

#### Promtail (Default)
- **Type**: DaemonSet (runs on every node)
- **Function**: Collects logs from `/var/log/pods` and `/var/log/containers`
- **Features**:
  - CRI (Container Runtime Interface) log parsing
  - Automatic Kubernetes metadata enrichment
  - Label extraction (namespace, pod, container, app)
  - Efficient log tailing with position tracking
- **Resource Usage**: ~100-200Mi RAM, ~50-100m CPU per node

#### Fluent Bit (Alternative)
- **Type**: DaemonSet
- **Function**: More flexible log processing pipeline
- **Advantages**:
  - More parsers and filters
  - Can send to multiple destinations
  - Better performance at high volumes
- **Resource Usage**: ~100-200Mi RAM, ~100-200m CPU per node

### 2. Loki - Log Aggregation System

#### Architecture Components

**Distributor**
- Receives logs from collectors (Promtail/Fluent Bit)
- Validates log streams
- Hashes log streams to determine which ingester receives them
- Rate limiting and tenant isolation

**Ingester**
- Builds compressed chunks in memory
- Writes chunks to Write-Ahead Log (WAL) for durability
- Flushes chunks to object storage (S3)
- Maintains in-memory index for recent data

**Querier**
- Handles LogQL queries from Grafana
- Queries both ingesters (recent data) and object storage (historical data)
- Merges results and returns to client

**Query Frontend** (optional, for scale)
- Splits large queries into smaller chunks
- Caches query results
- Queues queries to prevent overload

**Compactor**
- Compacts index files in object storage
- Applies retention policies (30 days configured)
- Deletes old data based on retention rules

#### Storage Backend

**Schema**: boltdb-shipper
- Stores index in BoltDB files
- Ships index to S3 for sharing across instances
- More scalable than local-only index

**Object Storage**: S3/MinIO
- Stores compressed log chunks
- Lifecycle policies for automatic retention
- Cheaper than block storage (EBS)
- Built-in durability and replication

**Compression**
- Typical ratio: 8:1 for text logs
- Uses snappy compression by default
- Configurable per-tenant

### 3. Tempo - Distributed Tracing

#### Architecture Components

**Distributor**
- Receives traces via OTLP, Jaeger, or Zipkin protocols
- Validates and forwards spans to ingesters
- Load balancing across ingesters

**Ingester**
- Batches spans into blocks
- Writes to local disk and object storage
- Creates bloom filters for efficient trace lookups

**Querier**
- Executes TraceQL queries
- Searches across ingesters and object storage
- Returns trace data to Grafana

**Metrics Generator**
- Generates RED metrics from spans:
  - **R**ate: Request rate per service
  - **E**rrors: Error rate per service
  - **D**uration: Latency percentiles
- Pushes metrics to Prometheus
- Builds service graphs showing dependencies

**Compactor**
- Compacts trace blocks
- Applies retention policies
- Creates more efficient query indices

#### Storage Format

**Format**: Parquet (v2)
- Columnar storage format
- Excellent compression (~5:1)
- Fast search by tags
- Schema evolution support

### 4. Object Storage (MinIO/S3)

**MinIO** (Lab/Development)
- S3-compatible object storage
- Runs in Kubernetes
- Used for testing before production S3

**AWS S3** (Production)
- Highly durable (99.999999999%)
- Lifecycle policies for retention
- Cost-effective for large volumes
- Multiple storage classes available

**Buckets**:
- `loki-data`: Log chunks and indices
- `tempo-data`: Trace blocks

**Retention**:
- Configured via S3 lifecycle rules
- 30 days in this PoC
- Can be extended to 90, 365 days

### 5. Grafana - Unified Observability UI

**Datasources**:
- **Loki**: Log querying with LogQL
- **Tempo**: Trace exploration with TraceQL
- **Prometheus**: Metrics and span metrics

**Key Features**:

1. **Log-to-Trace Correlation**
   - Derived fields extract trace_id from logs
   - Click trace_id in logs → opens trace in Tempo
   - Automatic linking based on patterns

2. **Trace-to-Log Correlation**
   - Tempo datasource configured with log tags
   - "Logs for this span" button in trace view
   - Automatically constructs LogQL query

3. **Trace-to-Metric Correlation**
   - Tempo generates span metrics
   - Link from trace to corresponding metrics
   - See trends and anomalies

4. **Explore UI**
   - Unified interface for logs, traces, metrics
   - Split view for correlation
   - Context switching between datasources

## Data Flow

### Log Ingestion Flow

```
1. Application writes to stdout/stderr
2. Container runtime writes to /var/log/pods/
3. Promtail/Fluent Bit tails log files
4. Logs enriched with Kubernetes metadata (namespace, pod, labels)
5. Sent to Loki Distributor
6. Distributor validates and forwards to Ingester
7. Ingester builds chunks in memory (with WAL for safety)
8. Chunks flushed to S3 every 5 minutes
9. Compactor periodically compacts and applies retention
```

### Trace Ingestion Flow

```
1. Application generates spans (OpenTelemetry SDK)
2. Spans sent via OTLP/gRPC to Tempo
3. Tempo Distributor receives spans
4. Spans batched and sent to Ingester
5. Ingester writes to local disk and S3
6. Metrics Generator creates RED metrics
7. Metrics pushed to Prometheus
8. Compactor compacts blocks periodically
```

### Query Flow (Logs)

```
1. User enters LogQL query in Grafana
2. Grafana sends query to Loki
3. Loki Querier:
   a. Queries Ingesters for recent data (last ~5-30 min)
   b. Queries S3 for historical data
4. Results merged and deduplicated
5. Returned to Grafana for display
```

### Query Flow (Traces)

```
1. User searches for traces in Grafana
2. TraceQL query sent to Tempo
3. Tempo Querier:
   a. Checks bloom filters to locate relevant blocks
   b. Queries ingesters for recent traces
   c. Reads blocks from S3 for historical traces
4. Matching traces returned
5. User clicks trace → full span details loaded
6. "Logs for span" → LogQL query auto-generated
```

## Scalability

### Horizontal Scaling

**Loki**:
- Distributors: Scale with ingestion rate
- Ingesters: Scale with write throughput
- Queriers: Scale with query load
- Each component can scale independently

**Tempo**:
- Similar architecture to Loki
- Scale components based on load
- Metrics generator can be disabled if not needed

### Vertical Scaling

**Small (< 50 GB/day)**:
- Loki: 1 replica, 2 CPU, 4 GB RAM
- Tempo: 1 replica, 1 CPU, 2 GB RAM

**Medium (50-200 GB/day)**:
- Loki: 2-3 replicas, 4 CPU, 8 GB RAM each
- Tempo: 2 replicas, 2 CPU, 4 GB RAM each

**Large (> 200 GB/day)**:
- Loki: 5+ replicas, 8 CPU, 16 GB RAM each
- Tempo: 3+ replicas, 4 CPU, 8 GB RAM each
- Consider splitting read/write paths

## High Availability

### Current Setup (PoC)
- Single replica for each component
- Suitable for lab/testing
- Data persisted to S3 (survives pod restarts)

### Production Setup
- 3+ replicas for each component
- Pod anti-affinity (different nodes)
- Ingester replication (RF=3)
- Multiple availability zones
- Load balancer in front

## Retention & Lifecycle

### Retention Configuration

**Loki**:
```yaml
limits_config:
  retention_period: 720h  # 30 days

compactor:
  retention_enabled: true
  retention_delete_delay: 2h
```

**Tempo**:
```yaml
compactor:
  compaction:
    block_retention: 720h  # 30 days
```

**S3 Lifecycle** (redundant but cost-effective):
```json
{
  "Rules": [{
    "Expiration": {"Days": 30},
    "Status": "Enabled"
  }]
}
```

### Data Lifecycle

```
0-5 min:   In memory (Ingester) + WAL
5 min-30 days: S3 object storage (queried on demand)
> 30 days: Deleted by compactor + S3 lifecycle
```

## Security Considerations

### Current Setup (PoC)
- Internal cluster communication only
- No authentication on Loki/Tempo
- MinIO with static credentials

### Production Recommendations
1. **Authentication**:
   - Enable multi-tenancy in Loki
   - Use X-Scope-OrgID headers
   - Grafana handles authentication

2. **Authorization**:
   - RBAC in Kubernetes
   - IAM roles for S3 access
   - Network policies

3. **Encryption**:
   - TLS for all communication
   - S3 encryption at rest
   - Encrypted etcd secrets

4. **Credential Management**:
   - AWS IAM roles (no static keys)
   - Kubernetes secrets with encryption
   - Rotate credentials regularly

## Monitoring & Alerting

### Self-Monitoring

Both Loki and Tempo expose Prometheus metrics:

**Key Loki Metrics**:
- `loki_distributor_bytes_received_total`: Ingestion rate
- `loki_ingester_chunks_flushed_total`: Flush rate
- `loki_request_duration_seconds`: Query latency
- `loki_ingester_memory_chunks`: In-memory chunks

**Key Tempo Metrics**:
- `tempo_distributor_spans_received_total`: Span ingestion
- `tempo_ingester_blocks_flushed_total`: Block flush rate
- `tempo_query_frontend_queries_total`: Query volume

### Recommended Alerts

1. **High error rate**: Ingestion failures
2. **High memory**: Ingester memory usage > 80%
3. **Slow queries**: P99 latency > 10s
4. **No logs received**: Gap in ingestion
5. **S3 access errors**: Object storage issues

## Comparison with ELK

| Aspect | Loki + Tempo | ELK + Jaeger |
|--------|--------------|--------------|
| Architecture | Distributed, stateless | Stateful cluster |
| Storage | Object storage (S3) | Block storage (EBS) |
| Indexing | Labels only | Full-text |
| Query Speed (labels) | Fast | Fast |
| Query Speed (full-text) | Slow | Fast |
| Storage Cost | Low (~8:1 compression) | High (~1.3x overhead) |
| Operational Complexity | Low | High |
| Scalability | Horizontal (easy) | Vertical + Horizontal |
| Resource Usage | Low | High |
| Trace Integration | Native (Tempo) | Separate (Jaeger) |

## Conclusion

The Loki + Tempo architecture provides:
- ✅ Cost-effective log and trace storage (85-95% cheaper than ELK)
- ✅ Simple operation (fewer components, less complexity)
- ✅ Native integration (logs, traces, metrics in one UI)
- ✅ Kubernetes-native (designed for cloud-native workloads)
- ⚠️ Trade-off: Label-based queries are fast, full-text search is slower
