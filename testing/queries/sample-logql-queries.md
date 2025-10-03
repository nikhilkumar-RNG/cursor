# Sample LogQL Queries for Testing

## Basic Label Queries (Fastest)

### By Namespace
```logql
{namespace="monitoring"}
```

### By Pod
```logql
{namespace="monitoring", pod="loki-0"}
```

### By App Label
```logql
{app="log-generator"}
```

### Multiple Labels
```logql
{namespace="monitoring", app="log-generator", container="generator"}
```

## Line Filters

### Simple Text Match
```logql
{namespace="monitoring"} |= "ERROR"
```

### Multiple Text Matches
```logql
{namespace="monitoring"} |= "ERROR" |= "timeout"
```

### NOT Filter
```logql
{namespace="monitoring"} != "DEBUG"
```

### Regex Filter
```logql
{namespace="monitoring"} |~ "ERROR|WARN|FATAL"
```

### Case-Insensitive Regex
```logql
{namespace="monitoring"} |~ "(?i)error"
```

## JSON Parsing

### Parse and Filter by JSON Field
```logql
{namespace="monitoring"} | json | level="ERROR"
```

### Parse Multiple JSON Fields
```logql
{namespace="monitoring"} | json | level="ERROR" | duration_ms > 1000
```

### Extract Specific JSON Fields
```logql
{namespace="monitoring"} | json message, trace_id, level
```

## Log Formatting

### Line Format
```logql
{namespace="monitoring"} | json | line_format "{{.timestamp}} {{.level}} {{.message}}"
```

### Label Format (create new labels)
```logql
{namespace="monitoring"} | json | label_format level="{{.level}}"
```

## Aggregations

### Count Logs Over Time
```logql
count_over_time({namespace="monitoring"}[5m])
```

### Sum by Label
```logql
sum by (namespace) (count_over_time({namespace=~".*"}[5m]))
```

### Rate of Logs
```logql
rate({namespace="monitoring"}[5m])
```

### Count by Level
```logql
sum by (level) (count_over_time({namespace="monitoring"} | json | __error__="" [5m]))
```

## Error Analysis

### Error Rate
```logql
sum(rate({namespace="monitoring"} |= "ERROR" [5m]))
```

### Error Percentage
```logql
(
  sum(rate({namespace="monitoring"} |= "ERROR" [5m]))
  /
  sum(rate({namespace="monitoring"} [5m]))
) * 100
```

### Top Error Messages
```logql
topk(10, sum by (message) (count_over_time({namespace="monitoring"} | json | level="ERROR" [1h])))
```

## Performance Queries

### High Latency Requests
```logql
{namespace="monitoring"} | json | duration_ms > 3000
```

### 99th Percentile Latency
```logql
quantile_over_time(0.99, {namespace="monitoring"} | json | unwrap duration_ms [5m])
```

### Average Duration by Service
```logql
avg_over_time({namespace="monitoring"} | json | unwrap duration_ms [5m]) by (service)
```

## Trace Correlation

### Find Logs by Trace ID
```logql
{namespace="monitoring"} | json | trace_id="abc123def456"
```

### Logs with Trace IDs
```logql
{namespace="monitoring"} | json | trace_id != ""
```

### Extract Trace IDs
```logql
{namespace="monitoring"} | regexp "trace_id=(?P<trace_id>\\w+)"
```

## Advanced Queries

### Pattern Matching
```logql
{namespace="monitoring"} | pattern "<timestamp> <level> [<service>] <_>"
```

### Decolorize Logs
```logql
{namespace="monitoring"} | decolorize
```

### Multi-line Parsing
```logql
{namespace="monitoring"} |= "Exception" | line_format "{{.}}"
```

### Combine Multiple Parsers
```logql
{namespace="monitoring"} 
  | json 
  | line_format "{{.level}}: {{.message}}" 
  | label_format service="{{.service}}"
```

## Alerting Queries

### High Error Rate Alert
```logql
sum(rate({namespace="monitoring"} |= "ERROR" [5m])) > 10
```

### No Logs Received Alert
```logql
absent_over_time({namespace="monitoring"}[5m]) == 1
```

### High Memory Usage in Logs
```logql
sum(count_over_time({namespace="monitoring"} |~ "OutOfMemory|OOM" [5m])) > 0
```

## Comparison Queries (Loki vs ELK)

### ELK (Elasticsearch Query DSL)
```json
{
  "query": {
    "bool": {
      "must": [
        {"match": {"namespace": "monitoring"}},
        {"match": {"level": "ERROR"}}
      ],
      "filter": [
        {"range": {"@timestamp": {"gte": "now-5m"}}}
      ]
    }
  }
}
```

### Loki Equivalent (LogQL)
```logql
{namespace="monitoring"} | json | level="ERROR"
```

**Key Differences:**
- Loki: Label-based filtering is fast, full-text search is slower
- ELK: Full-text search is fast, but requires more resources
- Loki: Simple query language, less verbose
- ELK: More complex query DSL, more features

## Performance Notes

1. **Fast Queries** (< 100ms):
   - Label selectors only: `{namespace="monitoring"}`
   - With simple text filter: `{namespace="monitoring"} |= "ERROR"`

2. **Medium Queries** (100ms - 1s):
   - JSON parsing with filters: `{namespace="monitoring"} | json | level="ERROR"`
   - Aggregations over short time: `count_over_time({namespace="monitoring"}[5m])`

3. **Slow Queries** (> 1s):
   - Wide label selectors: `{namespace=~".*"}`
   - Full-text search: `{namespace=~".*"} |~ "some text"`
   - Long time ranges: `[24h]` or `[7d]`

## Best Practices

1. **Always use specific labels first**
   ```logql
   ✅ {namespace="monitoring", app="loki"} |= "ERROR"
   ❌ {namespace=~".*"} |= "ERROR"
   ```

2. **Limit time ranges**
   ```logql
   ✅ {namespace="monitoring"}[5m]
   ❌ {namespace="monitoring"}[7d]
   ```

3. **Use label extraction for repeated queries**
   ```logql
   {namespace="monitoring"} | json | level="ERROR"  # Parse once, filter by label
   ```

4. **Avoid regex when possible**
   ```logql
   ✅ {namespace="monitoring"} |= "ERROR"
   ❌ {namespace="monitoring"} |~ ".*ERROR.*"
   ```
