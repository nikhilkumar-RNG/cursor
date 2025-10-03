# Sample TraceQL Queries for Testing

## Basic Queries

### Find All Traces
```traceql
{}
```

### Find Traces by Service
```traceql
{service.name="api-gateway"}
```

### Find Traces by Multiple Services
```traceql
{service.name="api-gateway" || service.name="user-service"}
```

## Span Queries

### Find Spans by Name
```traceql
{span.name="GET /api/users"}
```

### Find Spans by HTTP Method
```traceql
{span.http.method="POST"}
```

### Find Error Spans
```traceql
{status=error}
```

## Duration Queries

### High Latency Traces (> 1 second)
```traceql
{duration>1s}
```

### Very Fast Traces (< 100ms)
```traceql
{duration<100ms}
```

### Duration Range
```traceql
{duration>500ms && duration<2s}
```

## Resource Attributes

### Find by Resource Attribute
```traceql
{resource.namespace="monitoring"}
```

### Kubernetes Pod Filter
```traceql
{resource.k8s.pod.name=~"loki-.*"}
```

### Multiple Resource Filters
```traceql
{resource.namespace="monitoring" && resource.k8s.container.name="loki"}
```

## Span Attributes

### HTTP Status Codes
```traceql
{span.http.status_code=500}
```

### Specific User ID
```traceql
{span.user.id="12345"}
```

### Database Queries
```traceql
{span.db.system="postgresql" && span.db.operation="SELECT"}
```

## Aggregations

### Count Spans
```traceql
{} | count() by (service.name)
```

### Average Duration by Service
```traceql
{} | avg(duration) by (service.name)
```

### Max Duration
```traceql
{} | max(duration)
```

## Complex Queries

### Error Traces with High Latency
```traceql
{status=error && duration>1s}
```

### Specific Endpoint Errors
```traceql
{service.name="api-gateway" && span.http.route="/api/payment" && status=error}
```

### Cross-Service Traces
```traceql
{service.name="api-gateway"} && {service.name="payment-service"}
```

## Log-Trace Correlation

### From Trace to Logs (in Grafana)
1. Click on a trace in Tempo
2. Click "Logs for this span"
3. Grafana automatically constructs LogQL query:
   ```logql
   {namespace="monitoring", app="user-service"} 
     | json 
     | trace_id="<trace-id-from-span>"
   ```

### From Logs to Traces (in Grafana)
1. In Loki logs, derived fields extract trace_id
2. Click on trace_id link
3. Opens trace in Tempo

### Manual Correlation Query

**In Loki:**
```logql
{namespace="monitoring"} | json | trace_id="abc123def456"
```

**In Tempo:**
```traceql
{traceid="abc123def456"}
```

## Comparison: Tempo vs Jaeger

### Jaeger UI Query
```
service=api-gateway 
operation=GET /api/users 
min-duration=1s
```

### Tempo Equivalent (TraceQL)
```traceql
{service.name="api-gateway" && span.name="GET /api/users" && duration>1s}
```

## Performance Analysis Queries

### Top 10 Slowest Traces
```traceql
{} | top(10, duration)
```

### Error Rate by Service
```traceql
{status=error} | count() by (service.name)
```

### Latency Percentiles
```traceql
{} | quantile(0.95, duration) by (service.name)
```

### Request Volume
```traceql
{} | rate()
```

## Service Map Queries

### All Services
```traceql
{} | service_graph()
```

### Specific Service Dependencies
```traceql
{service.name="api-gateway"} | service_graph()
```

## Advanced Filtering

### Regex Match
```traceql
{span.name=~"GET /api/.*"}
```

### Not Equal
```traceql
{service.name!="health-check"}
```

### Multiple Conditions
```traceql
{
  service.name="api-gateway" 
  && span.http.method="POST" 
  && status=error 
  && duration>500ms
}
```

## Metrics Generation

Tempo's metrics-generator creates RED metrics:
- **Rate**: Request rate per service
- **Errors**: Error rate per service  
- **Duration**: Latency percentiles

### Query Generated Metrics (in Prometheus)

**Request Rate:**
```promql
sum(rate(traces_spanmetrics_calls_total{service="api-gateway"}[5m]))
```

**Error Rate:**
```promql
sum(rate(traces_spanmetrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m])) by (service)
```

**Latency (P95):**
```promql
histogram_quantile(0.95, 
  sum(rate(traces_spanmetrics_latency_bucket[5m])) by (le, service)
)
```

## Integration Scenarios

### Scenario 1: Investigate Error Logs

1. **Start in Loki** with error logs:
   ```logql
   {namespace="monitoring"} | json | level="ERROR"
   ```

2. **Extract trace_id** from log line

3. **View in Tempo**:
   ```traceql
   {traceid="<extracted-id>"}
   ```

4. **Analyze** full request flow and timing

### Scenario 2: High Latency Investigation

1. **Start in Tempo** with slow traces:
   ```traceql
   {service.name="payment-service" && duration>2s}
   ```

2. **Click on span** to see details

3. **Jump to logs** for detailed error messages

4. **Check metrics** in Prometheus for patterns

### Scenario 3: Service Dependency Analysis

1. **Service Map** in Tempo (auto-generated)

2. **Identify bottleneck** service

3. **Query traces** for that service:
   ```traceql
   {service.name="database-service" && duration>1s}
   ```

4. **Correlate with logs**:
   ```logql
   {app="database-service"} | json | duration_ms > 1000
   ```

## Best Practices

1. **Use specific filters first**
   ```traceql
   ✅ {service.name="api-gateway" && status=error}
   ❌ {status=error}  # Too broad
   ```

2. **Limit time ranges** (default last 1 hour)

3. **Use intrinsic fields for performance**
   - Intrinsic: `duration`, `status`, `service.name`
   - Custom attributes are slower to query

4. **Combine with metrics for context**
   - Use TraceQL for deep dives
   - Use Prometheus metrics for trends

5. **Enable span metrics** for faster aggregations
   ```yaml
   # Already configured in tempo-config.yaml
   metrics_generator:
     processor:
       span_metrics:
         enabled: true
   ```

## Query Performance

- **Fast** (< 100ms): Queries with service.name and time range
- **Medium** (100ms - 1s): Complex attribute filters
- **Slow** (> 1s): Full-text search, very wide time ranges

## Alerting Examples

### High Error Rate Alert (Prometheus)
```promql
sum(rate(traces_spanmetrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m])) 
/ 
sum(rate(traces_spanmetrics_calls_total[5m])) 
> 0.05
```

### High Latency Alert (Prometheus)
```promql
histogram_quantile(0.95, 
  sum(rate(traces_spanmetrics_latency_bucket{service="payment-service"}[5m])) by (le)
) > 2
```
