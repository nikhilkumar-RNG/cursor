# DCGM Exporter Action Plan

## Summary of Denis's Questions

1. **Why are we updating dcgm-exporter?**
   - Need to identify the specific version change and reason
   
2. **Why do we need two of them?**
   - Likely either: different metric profiles, different clusters, or accidental duplication
   
3. **They've had a distroless container**
   - NVIDIA provides distroless images for better security and smaller footprint

## Action Items

### Phase 1: Discovery (Required Before Proceeding)
- [ ] Identify current dcgm-exporter deployments in the cluster
- [ ] Document current image versions for each instance
- [ ] Capture current configurations (DaemonSet, ConfigMap, metrics config)
- [ ] Identify differences between the two instances
- [ ] Check if they're in different namespaces or targeting different node pools

**Commands to run:**
```bash
# Find all dcgm-exporter resources
kubectl get all -A | grep dcgm

# Get detailed configurations
kubectl get daemonset -A -o yaml | grep -A 50 dcgm

# Check current images
kubectl get pods -A -o jsonpath="{.items[*].spec.containers[*].image}" | tr -s '[[:space:]]' '\n' | grep dcgm
```

### Phase 2: Analysis
- [ ] Compare metric configurations between instances
- [ ] Analyze if both instances are necessary
- [ ] Check for version upgrade motivation (security CVEs, new features)
- [ ] Review distroless compatibility

### Phase 3: Decision Matrix

| Scenario | Action | Risk Level |
|----------|--------|------------|
| Identical instances | Consolidate to one | Low |
| Different metric profiles | Keep both, document purpose | Low |
| Legacy + new instance | Remove old after validation | Medium |
| Different clusters | Keep both, add labels | Low |
| One is unused | Decommission unused instance | Low |

### Phase 4: Implementation Plan

#### If Consolidating (Duplicate Instances)
1. Backup current configurations
2. Test consolidated version in dev/staging
3. Verify all required metrics are collected
4. Remove duplicate instance
5. Monitor for 24-48 hours

#### If Migrating to Distroless
1. Update image tag to distroless variant
2. Add security context (readOnlyRootFilesystem, runAsNonRoot)
3. Test in dev environment
4. Update runbooks for debugging without shell
5. Deploy to staging, validate metrics
6. Roll out to production with monitoring

#### If Keeping Both Instances
1. Add clear naming convention:
   - `dcgm-exporter-basic` (lightweight metrics)
   - `dcgm-exporter-profiling` (detailed metrics)
2. Document purpose of each in annotations
3. Add labels to identify their role
4. Update monitoring dashboards accordingly

## Recommended Deployment Structure

### Single Instance (Consolidated)
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dcgm-exporter
  namespace: gpu-monitoring
  annotations:
    description: "NVIDIA GPU metrics exporter for Prometheus"
spec:
  selector:
    matchLabels:
      app: dcgm-exporter
  template:
    metadata:
      labels:
        app: dcgm-exporter
        version: 3.3.5
    spec:
      nodeSelector:
        nvidia.com/gpu: "true"  # Only on GPU nodes
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: dcgm-exporter
        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-distroless
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        env:
        - name: DCGM_EXPORTER_LISTEN
          value: ":9400"
        - name: DCGM_EXPORTER_KUBERNETES
          value: "true"
        ports:
        - name: metrics
          containerPort: 9400
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 9400
          initialDelaySeconds: 45
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 9400
          initialDelaySeconds: 45
```

### Dual Instance (If Needed)
```yaml
# Instance 1: Basic metrics, all GPU nodes
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dcgm-exporter-basic
  namespace: gpu-monitoring
  annotations:
    description: "Basic GPU metrics (utilization, memory, temp) - all nodes"
spec:
  template:
    spec:
      nodeSelector:
        nvidia.com/gpu: "true"
      containers:
      - name: dcgm-exporter
        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-distroless
        env:
        - name: DCGM_EXPORTER_LISTEN
          value: ":9400"
        - name: DCGM_EXPORTER_COLLECTORS
          value: "/etc/dcgm-exporter/default-counters.csv"  # Basic metrics only

---
# Instance 2: Profiling metrics, specific nodes
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dcgm-exporter-profiling
  namespace: gpu-monitoring
  annotations:
    description: "Detailed profiling metrics - high-priority nodes only"
spec:
  template:
    spec:
      nodeSelector:
        nvidia.com/gpu: "true"
        gpu-profiling: "enabled"  # Only nodes with this label
      containers:
      - name: dcgm-exporter
        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-distroless
        env:
        - name: DCGM_EXPORTER_LISTEN
          value: ":9401"  # Different port!
        - name: DCGM_EXPORTER_COLLECTORS
          value: "/etc/dcgm-exporter/profiling-counters.csv"  # Detailed metrics
```

## Testing Checklist

- [ ] Metrics are being scraped by Prometheus
- [ ] No gaps in metric collection during migration
- [ ] Alert rules still function correctly
- [ ] Grafana dashboards display data
- [ ] Resource usage (CPU/memory) is acceptable
- [ ] No pod restart loops
- [ ] Metrics match between old and new configuration

## Rollback Plan

1. Keep old DaemonSet configuration backed up
2. If issues detected, immediately revert:
   ```bash
   kubectl apply -f dcgm-exporter-backup.yaml
   kubectl delete daemonset dcgm-exporter-new
   ```
3. Investigate issues in dev environment
4. Re-attempt migration after fixes

## Documentation Requirements

Create/update these documents:
1. **Architecture Decision Record (ADR)**: Why single vs dual instance
2. **Runbook**: How to debug distroless containers
3. **Monitoring Guide**: Which metrics to alert on
4. **Upgrade Procedure**: How to safely upgrade dcgm-exporter

## Security Improvements with Distroless

### Before (Ubuntu-based)
- ~500MB image size
- Contains shell, package manager, OS utilities
- Typical CVE count: 20-40 vulnerabilities
- Attack surface: High

### After (Distroless)
- ~150MB image size
- Only dcgm-exporter binary and runtime dependencies
- Typical CVE count: 0-5 vulnerabilities
- Attack surface: Minimal

### Debugging Without Shell

```bash
# Old way (Ubuntu-based)
kubectl exec -it dcgm-exporter-xxx -- /bin/bash

# New way (Distroless)
# Option 1: Use kubectl debug
kubectl debug dcgm-exporter-xxx -it --image=ubuntu:22.04 --target=dcgm-exporter

# Option 2: Check logs
kubectl logs dcgm-exporter-xxx -f

# Option 3: Port-forward to check metrics endpoint
kubectl port-forward dcgm-exporter-xxx 9400:9400
curl localhost:9400/metrics
```

## Cost Savings (Distroless)

Assuming 100 GPU nodes:
- **Storage**: 35GB saved (350MB per node * 100 nodes)
- **Network**: Faster image pulls (especially in CI/CD)
- **Scan Time**: Reduced security scan time (fewer packages to scan)

## Questions to Answer Before Proceeding

1. Which environments are affected? (dev, staging, prod)
2. What's the current version of each dcgm-exporter instance?
3. When was the last time dcgm-exporter was updated?
4. Are there any custom metrics configurations?
5. Is there a specific compliance or security requirement driving this?
6. What's the timeline for making this change?

---

**Next Step**: Gather current deployment information and configuration details to make specific recommendations.
