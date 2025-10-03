# Loki + Tempo PoC - Quick Start Guide

## 🚀 Get Started in 5 Minutes

### 1. Deploy the Stack

```bash
# Deploy everything
./scripts/deploy-all.sh

# Wait for pods to be ready (2-3 minutes)
kubectl get pods -n monitoring -w
```

### 2. Access Grafana

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Open http://localhost:3000
# Login: admin / admin
```

### 3. Explore Logs

In Grafana:
1. Go to **Explore**
2. Select **Loki** datasource
3. Run query: `{namespace="monitoring"}`
4. See logs with trace_id links

### 4. Explore Traces

In Grafana:
1. Select **Tempo** datasource
2. Click **Search**
3. Select service: `correlation-test-app`
4. Click a trace to see details

### 5. Test Correlation

1. In logs, click a `trace_id` link → Opens trace ✅
2. In trace, click "Logs for this span" → Opens logs ✅

## 📊 Run Tests

```bash
# Run all tests and benchmarks
./scripts/run-tests.sh

# Results in: test-results/
```

## 📖 Documentation

- **[Comparison Results](docs/comparison-results.md)** - Detailed Loki vs ELK analysis
- **[Architecture](docs/architecture.md)** - System design and components
- **[Deployment Guide](docs/deployment-guide.md)** - Detailed deployment instructions
- **[Testing Guide](docs/testing-guide.md)** - How to run tests
- **[Confluence Export](docs/confluence-export.md)** - Ready for publishing

## 💰 Key Findings

| Metric | Result |
|--------|--------|
| **Cost Savings** | 85-95% vs ELK |
| **Storage Efficiency** | 10x better (8:1 compression) |
| **Resource Usage** | 70% less CPU/RAM |
| **Query Performance** | Comparable for label queries |
| **Integration** | Native log-trace-metric correlation |

**Recommendation**: ✅ Adopt Loki + Tempo for DevOps/SRE use cases

## 🗂️ Project Structure

```
.
├── deployment/              # Kubernetes manifests
│   ├── loki/               # Loki with S3 backend
│   ├── promtail/           # Log collector
│   ├── tempo/              # Distributed tracing
│   ├── grafana/            # Unified UI
│   └── minio/              # S3-compatible storage (lab)
├── testing/                # Tests and benchmarks
│   ├── benchmarks/         # Performance tests
│   ├── integration/        # Integration tests
│   └── queries/            # Sample LogQL/TraceQL
├── analysis/               # Cost analysis
│   └── cost-calculator/    # Cost comparison tools
├── docs/                   # Documentation
│   ├── comparison-results.md
│   ├── architecture.md
│   ├── deployment-guide.md
│   └── confluence-export.md
└── scripts/                # Helper scripts
    ├── deploy-all.sh       # Deploy everything
    ├── run-tests.sh        # Run all tests
    └── cleanup.sh          # Clean up
```

## 🔄 Next Steps

1. ✅ Review comparison results: `docs/comparison-results.md`
2. ✅ Check cost analysis: `analysis/cost-calculator/cost-spreadsheet.csv`
3. ✅ Review architecture: `docs/architecture.md`
4. ✅ Plan migration: See recommendations in docs
5. ✅ Present findings: Use `docs/confluence-export.md`

## 🧹 Cleanup

```bash
# Remove everything
./scripts/cleanup.sh
```

## 📞 Support

- Documentation: See `docs/` directory
- Issues: Check deployment logs
- Questions: Review testing guide

---

**Status**: PoC Complete - Ready for Production Evaluation
