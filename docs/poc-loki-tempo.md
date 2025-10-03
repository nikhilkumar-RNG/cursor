### PoC: Replacing ELK with Grafana Loki + Tempo for Kubernetes Logs

#### Objectives
- Replace Elasticsearch + Kibana for pod/service log storage and exploration with Loki.
- Reduce storage and operational costs using object storage (S3/MinIO) and simpler ops.
- Integrate logs with metrics (Prometheus) and traces (Tempo) for end-to-end correlation.

#### Scope (what we will do)
- Deploy Loki + Promtail in a lab/stage cluster with boltdb-shipper backed by S3/MinIO.
- Deploy Tempo and integrate Loki, Tempo, and Prometheus into Grafana Explore.
- Configure 30-day retention using object storage lifecycle (S3/MinIO ILM).
- Measure: chunk size, compression efficiency, search speed by labels vs full-text, and resource usage.
- Validate log-to-metric and trace-to-log correlation.
- Document functional gaps vs Kibana and log-alerting options.
- Provide cost comparison for 30/90 days at 100 GB/day and 1 TB/day ingestion.

#### High-level architecture
```mermaid
flowchart LR
  subgraph Kubernetes Cluster
    A[Applications/Pods] --> P[Promtail]
    P --> L[Loki (boltdb-shipper)]
    A -->|OTLP| T[Tempo]
    PM[Prometheus] --> G[Grafana]
    L --> G
    T --> G
  end
  L <--> S[(S3/MinIO - logs/index)]
  T <--> ST[(S3/MinIO - traces)]
```

#### Deliverables (this repo)
- `helm/loki-values.yaml`: Loki single-binary values (boltdb-shipper + S3/MinIO)
- `helm/promtail-values.yaml`: Promtail values with Kubernetes scrape + trace id extraction
- `helm/tempo-values.yaml`: Tempo values with OTLP receivers and object storage
- `helm/grafana-values.yaml`: Grafana provisioning for Loki/Prometheus/Tempo + derivedFields
- `helm/minio-values.yaml`: MinIO values for lab with buckets `loki`, `tempo`
- `storage/s3-lifecycle-30d.json`: S3 lifecycle rule for 30-day retention
- `storage/minio-ilm-30d.json`: MinIO ILM policy for 30-day retention
- `scripts/deploy.sh`: Helm-based deployment script

---

### Deployment

#### Prerequisites
- Kubernetes cluster with kubeconfig
- Helm v3.x
- Optional: Existing Prometheus (e.g., kube-prometheus-stack) and Alertmanager

#### Namespaces
```bash
kubectl create ns observability || true
```

#### Install MinIO (lab/stage only)
If using AWS S3, skip MinIO. For lab:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm upgrade --install minio bitnami/minio -n observability \
  -f helm/minio-values.yaml
```

Create lifecycle rule (30d) on buckets:
```bash
kubectl -n observability run mc --rm -it --restart=Never --image=minio/mc -- bash -lc '
mc alias set minio http://minio.observability.svc.cluster.local:9000 minio minio123 && 
mc ilm import minio/loki < /config/minio-ilm-30d.json && 
mc ilm import minio/tempo < /config/minio-ilm-30d.json'
```

Alternatively for AWS S3:
```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket $LOKI_BUCKET --lifecycle-configuration file://storage/s3-lifecycle-30d.json
```

#### Install Loki
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki -n observability \
  -f helm/loki-values.yaml
```

#### Install Promtail
```bash
helm upgrade --install promtail grafana/promtail -n observability \
  -f helm/promtail-values.yaml
```

#### Install Tempo
```bash
helm upgrade --install tempo grafana/tempo -n observability \
  -f helm/tempo-values.yaml
```

#### Install Grafana (or update existing)
If you already have Grafana, apply the provisioning under the existing chart. Otherwise:
```bash
helm upgrade --install grafana grafana/grafana -n observability \
  -f helm/grafana-values.yaml
```

---

### Configuration specifics

#### Loki storage: boltdb-shipper + S3/MinIO
- Indexes stored in object storage (no dedicated index DB). Compactor runs periodically.
- Retention enforced via object storage lifecycle; set Loki `retention_enabled=false`.
- Tune chunk target size and compression via defaults (Snappy) or `chunks_config` if needed.

#### Retention (30 days) with object storage lifecycle
- S3: use `storage/s3-lifecycle-30d.json`.
- MinIO: use `storage/minio-ilm-30d.json` via `mc ilm import`.

#### Grafana Explore correlation
- Datasources: Prometheus (metrics), Loki (logs), Tempo (traces)
- Derived fields: Extract `traceid`/`trace_id`/`traceId` from logs for Tempo link

---

### Validation & Measurements

#### Data ingestion sanity
- Generate sample logs (e.g., `kubectl run` with a pod producing logs)
- Verify in Grafana Explore that logs arrive and are labeled (`{namespace=..., app=..., pod=...}`)

#### Search performance
- Label lookup (fast path): `{namespace="foo", app="bar"} |= "error"`
- Full-text: `{cluster="stage"} |~ "(?i)timeout|timed out"`
- Use `logcli` to time queries and compare:
```bash
logcli query --limit=1000 --since=1h '{namespace="default", app="api"} |= "error"'
```

Collect (per query type):
- Wall time, scanned bytes, series matched (from query stats)
- Loki CPU/RAM during queries

Procedure:
- Enable query stats in Grafana Explore or use `logcli --stats`.
- Run a matrix: label-only vs label+text vs regex-only on 1h/6h/24h.
- Record p50/p95 latencies across 10 runs each; note scanned bytes.

#### Resource usage under typical load
- Observe pods with `kubectl top pod -n observability`
- From Prometheus, scrape Loki metrics: `process_resident_memory_bytes`, `container_cpu_usage_seconds_total`
- Record steady-state vs peak during heavy queries

Procedure:
- Create 5-10 concurrent Explore queries (saved queries) for 5 minutes.
- Capture `container_memory_working_set_bytes` and CPU for Loki, Tempo, Promtail.
- Optional: test horizontal scaling by increasing replicas if available.

#### Chunk size & compression efficiency
- From S3/MinIO, sample total object size per day for `loki/` prefix vs ingested raw size
- From Loki metrics: `loki_chunk_store_index_*`, `loki_ingester_chunks_flushed_total`
- Report effective compression ratio: `stored_bytes / raw_ingested_bytes`

Procedure:
- Measure raw ingest via known generator volume or sum pod stdout.
- Compare with object storage usage for same window using `mc du minio/loki`.

#### Observability integration
- Log-to-metric: In Explore, “Logs” -> “Metrics” for label distribution/count
- Trace-to-log: From a Tempo trace, use “Show related logs” to hop to Loki; and from a log line with trace id, jump to Tempo

Procedure:
- Ensure apps emit trace ids in logs and send OTLP traces to Tempo.
- Verify derived fields in Grafana allow jumping from logs to traces and back.

#### Alerting from logs
- Use Loki ruler to count error rates:
  - Example expr: `sum by (app) (rate({app="api"} |= "ERROR" [5m])) > 0`
  - Notify via Alertmanager; manage in Grafana Alerting if desired

Procedure:
- Apply `k8s/loki-rules.yaml`; confirm rule group loads and alert fires with test errors.

---

### Comparison table (fill with results)

| Criterion | Loki + Tempo | ELK | Notes |
|---|---|---|---|
| Storage cost (30 days, 100 GB/day) | TBD | TBD | Object storage vs ES disks |
| Storage cost (90 days, 100 GB/day) | TBD | TBD |  |
| Storage cost (30 days, 1 TB/day) | TBD | TBD |  |
| Storage cost (90 days, 1 TB/day) | TBD | TBD |  |
| Label search latency (p50/p95) | TBD | TBD | 1h/6h/24h windows |
| Full-text/regex latency (p50/p95) | TBD | TBD |  |
| Ops complexity | Lower | Higher | No shard mgmt, object storage |
| Trace correlation | Native (Grafana Explore) | APM dependent |  |
| SIEM features | Limited | Strong | Keep ELK for SIEM |

---

### Functional limitations vs Kibana
- Full-text and ad-hoc search: Loki is label-first; full-text regex search is supported but slower than label-indexed queries. No Lucene DSL, no fielded search across arbitrary JSON fields without prior labeling.
- SIEM/Detection: Loki is not a SIEM; advanced detections, threat intel integrations, and security analytics remain in ELK/SIEM tools.
- Ecosystem & apps: Kibana apps (Security, APM, ML) are not present; Grafana has alternatives but feature parity differs.

---

### Cost analysis (methodology)
Assumptions (edit to match your environment):
- Ingestion: 100 GB/day and 1 TB/day scenarios
- Retention: 30 and 90 days
- S3 Standard pricing (us-east-1): ~$0.023/GB-month (first 50 TB)
- EBS gp3 pricing (for Elasticsearch data nodes): ~$0.08/GB-month (regional variance)
- Loki effective storage factor `f_loki` (post-compression and minimal index): assume 0.3× raw (70% reduction)
- ELK effective storage factor `f_elk` (index + 1 replica): assume 3.0× raw (varies 2–4×)

Formulas:
- Loki stored per day: `S_l = ingestion_per_day * f_loki`
- ELK stored per day: `S_e = ingestion_per_day * f_elk`
- Monthly storage cost: `cost = price_per_GB_month * (S * days_retained) / 30`

Estimates (storage-only):

| Ingest/day | Retention | Raw GB stored | Loki GB (0.3×) | S3 $/mo (@$0.023) | ELK GB (3.0×) | EBS $/mo (@$0.08) |
|---|---|---:|---:|---:|---:|---:|
| 100 GB | 30 days | 3,000 | 900 | $20.7 | 9,000 | $720 |
| 100 GB | 90 days | 9,000 | 2,700 | $62.1 | 27,000 | $2,160 |
| 1 TB | 30 days | 30,000 | 9,000 | $207 | 90,000 | $7,200 |
| 1 TB | 90 days | 90,000 | 27,000 | $621 | 270,000 | $21,600 |

Notes:
- Request costs are small compared to storage at these scales and ignored here.
- ELK typically requires SSDs and additional compute; these estimates are storage-only.

---

### Comparison and Recommendations
- Create a concise table (Loki+Tempo vs ELK) for: cost, search performance for SRE queries, ops complexity, retention flexibility, and limitations.
- Recommendation sketch:
  - Use Loki+Tempo for DevOps/SRE log exploration, label-based queries, and trace correlation, especially when object storage is preferred and cost matters.
  - Keep ELK for SIEM, advanced ad-hoc analytics, and use cases relying on Lucene DSL and Kibana apps.

---

### References
- Helm charts: `grafana/loki`, `grafana/promtail`, `grafana/tempo`, `grafana/grafana`, `bitnami/minio`
- LogQL and Ruler docs; Grafana derived fields; Tempo trace-to-logs correlation

