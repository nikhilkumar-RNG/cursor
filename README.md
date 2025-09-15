# AWS Transcribe Metrics for Prometheus using YACE

This setup allows you to collect AWS Transcribe CloudWatch metrics in Prometheus using YACE (Yet Another CloudWatch Exporter).

## Overview

Since YACE doesn't support automatic discovery for AWS Transcribe, this configuration uses static job definitions to collect metrics from CloudWatch.

## Files Structure

```
.
├── yace-config.yaml                    # YACE configuration for AWS Transcribe metrics
├── docker-compose.yml                  # Docker compose for YACE, Prometheus, and Grafana
├── prometheus.yml                      # Prometheus configuration
└── grafana-provisioning/              # Grafana auto-provisioning
    ├── datasources/
    │   └── prometheus.yml             # Prometheus datasource config
    └── dashboards/
        ├── dashboard.yml              # Dashboard provisioning config
        └── aws-transcribe-dashboard.json  # AWS Transcribe dashboard
```

## Quick Start

1. **Configure AWS Credentials**
   
   Choose one of these methods in `docker-compose.yml`:
   
   - **Method 1**: Environment variables (not recommended for production)
     ```yaml
     environment:
       - AWS_ACCESS_KEY_ID=your_access_key
       - AWS_SECRET_ACCESS_KEY=your_secret_key
     ```
   
   - **Method 2**: AWS profile from host
     ```yaml
     volumes:
       - ~/.aws:/root/.aws:ro
     environment:
       - AWS_PROFILE=your_profile_name
     ```
   
   - **Method 3**: IAM role (recommended for EC2/ECS)
     - No configuration needed if running on EC2/ECS with proper IAM role

2. **Update Regions**
   
   Edit `yace-config.yaml` and update the regions to match where your AWS Transcribe services are running:
   ```yaml
   regions:
     - us-east-1
     - us-west-2
     - eu-west-1
   ```

3. **Start the Stack**
   ```bash
   docker-compose up -d
   ```

4. **Access Services**
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000 (admin/admin)
   - YACE metrics: http://localhost:5000/metrics

## YACE Configuration Details

The configuration collects the following AWS Transcribe metrics:

### Request Metrics
- `TotalRequestCount` - Total number of transcription requests
- `SuccessfulRequestCount` - Number of successful requests
- `UserErrorCount` - Client-side errors (4xx)
- `SyncServerErrorCount` - Server errors for synchronous requests
- `AsyncServerErrorCount` - Server errors for asynchronous requests
- `ThrottledCount` - Number of throttled requests
- `LimitExceededCount` - Requests that exceeded limits

### Performance Metrics
- `AudioDurationTime` - Duration of audio processed
- `AsyncJobsInQueue` - Number of jobs waiting in queue
- `AsyncJobsCompleted` - Number of completed async jobs
- `AsyncJobsFailed` - Number of failed async jobs

### Dimensions
The configuration collects metrics with these dimensions:
- `Domain` - The domain of the transcription (e.g., medical)
- `ServiceType` - Type of service (batch, streaming)
- `LanguageCode` - Language used for transcription
- `ModelName` - The model used for transcription

## Customization

### Adjusting Collection Intervals
In `yace-config.yaml`:
```yaml
period: 300  # CloudWatch period in seconds
length: 300  # Collection window in seconds
delay: 120   # Delay to ensure metrics are available
```

### Adding Specific Dimension Filters
To collect metrics only for specific languages or models, uncomment and modify the example at the bottom of `yace-config.yaml`.

### Prometheus Metric Relabeling
The `prometheus.yml` includes metric relabeling rules to make metrics more Prometheus-friendly. For example:
- `aws_transcribe_total_request_count_sum` → `transcribe_requests_total`
- `aws_transcribe_audio_duration_time_average` → `transcribe_audio_duration_seconds_avg`

## If You Already Have YACE Running

Since you mentioned you already have YACE running, you can:

1. **Add to existing YACE config**: Copy the `static` section from `yace-config.yaml` to your existing YACE configuration file.

2. **Update Prometheus**: Add the scrape job from `prometheus.yml` to your existing Prometheus configuration:
   ```yaml
   - job_name: 'yace-transcribe'
     static_configs:
       - targets: ['your-yace-host:5000']
     scrape_interval: 60s
     scrape_timeout: 55s
   ```

3. **Import Grafana Dashboard**: Import the dashboard from `grafana-provisioning/dashboards/aws-transcribe-dashboard.json` into your Grafana instance.

## Troubleshooting

### No Metrics Appearing
1. Check YACE logs: `docker-compose logs yace`
2. Verify AWS credentials and permissions
3. Ensure your AWS account has Transcribe activity in the configured regions
4. Check if metrics are available in CloudWatch console first

### Required IAM Permissions
Your AWS credentials need these permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    }
  ]
}
```

### Metric Delays
CloudWatch metrics may have a delay of 1-5 minutes. The configuration includes a 2-minute delay to account for this.

## Example Prometheus Queries

```promql
# Request rate per minute
rate(aws_transcribe_total_request_count_sum[5m]) * 60

# Success rate percentage
(sum(rate(aws_transcribe_successful_request_count_sum[5m])) / sum(rate(aws_transcribe_total_request_count_sum[5m]))) * 100

# Average audio duration by language
avg by (language_code) (aws_transcribe_audio_duration_time_average)

# Error rate by type
sum by (region) (rate(aws_transcribe_user_error_count_sum[5m]))
```

## Next Steps

1. Set up alerts in Prometheus for error rates and throttling
2. Create custom Grafana dashboards for your specific use cases
3. Consider using recording rules for frequently-used queries
4. Set up long-term storage for metrics if needed