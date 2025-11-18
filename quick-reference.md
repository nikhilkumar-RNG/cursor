# Quick Reference: DCGM Exporter Answers

## Denis's Questions - Quick Answers

### 1. Why are we updating dcgm-exporter?

**Typical reasons:**
- **Security patches** (CVE fixes)
- **New GPU support** (H100, L40S, etc.)
- **Bug fixes** (memory leaks, stability issues)
- **New metrics** or improved performance

**You should update when:**
- ✅ Critical security vulnerabilities exist
- ✅ Supporting new GPU hardware
- ✅ Experiencing bugs fixed in newer versions
- ❌ "Just because" without testing

### 2. Why do we need two of them?

**Valid reasons:**
- ✅ **Different metric profiles**: Basic + Profiling metrics
- ✅ **Different node pools**: Training vs Inference clusters
- ✅ **Different scrape intervals**: High-frequency vs low-frequency
- ✅ **Multi-tenancy**: Different namespaces/teams

**Invalid reasons (consolidate!):**
- ❌ Accidental duplication
- ❌ Legacy instance not cleaned up
- ❌ Identical configurations
- ❌ "We forgot why we have two"

### 3. They've had a distroless container

**YES! Use it.**

**Distroless benefits:**
- ✅ **70% smaller** image size (150MB vs 500MB)
- ✅ **90% fewer** CVEs (no OS packages)
- ✅ Better security posture
- ✅ Faster deployments

**How to migrate:**
```yaml
# Change from:
image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-ubuntu22.04

# To:
image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-distroless
```

**Trade-off:**
- ⚠️ No shell access (use `kubectl debug` instead)

## Recommended Configuration (2024)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dcgm-exporter
  namespace: gpu-monitoring
spec:
  selector:
    matchLabels:
      app: dcgm-exporter
  template:
    metadata:
      labels:
        app: dcgm-exporter
    spec:
      # Only run on nodes with GPUs
      nodeSelector:
        nvidia.com/gpu: "true"
      
      # Allow scheduling on GPU nodes even if tainted
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      
      containers:
      - name: dcgm-exporter
        # Use distroless for security
        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-distroless
        
        # Security hardening
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        
        # Configuration
        env:
        - name: DCGM_EXPORTER_LISTEN
          value: ":9400"
        - name: DCGM_EXPORTER_KUBERNETES
          value: "true"
        
        # Expose metrics
        ports:
        - name: metrics
          containerPort: 9400
          protocol: TCP
        
        # Resource limits
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        
        # Health checks
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

---
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: dcgm-exporter
  namespace: gpu-monitoring
spec:
  selector:
    matchLabels:
      app: dcgm-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## If You Need Two Instances

**Clear naming and documentation:**

```yaml
# Basic monitoring (all nodes)
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dcgm-exporter-basic
  namespace: gpu-monitoring
  annotations:
    purpose: "Basic GPU metrics for all GPU nodes"
    metrics: "utilization, memory, temperature"
    scrape-interval: "30s"
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

---
# Profiling (specific nodes)
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dcgm-exporter-profiling
  namespace: gpu-monitoring
  annotations:
    purpose: "Detailed profiling metrics for intensive workloads"
    metrics: "all profiling metrics including PCIe, NVLink"
    scrape-interval: "5s"
spec:
  template:
    spec:
      nodeSelector:
        nvidia.com/gpu: "true"
        gpu-profiling: "enabled"  # Only specific nodes
      containers:
      - name: dcgm-exporter
        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-distroless
        env:
        - name: DCGM_EXPORTER_LISTEN
          value: ":9401"  # Different port!
```

## Migration Checklist

- [ ] **Audit**: Identify all dcgm-exporter instances
- [ ] **Document**: Why each instance exists
- [ ] **Consolidate**: If duplicates, merge into one
- [ ] **Distroless**: Switch to distroless images
- [ ] **Test**: Verify in dev/staging first
- [ ] **Monitor**: Watch for metric gaps after deployment
- [ ] **Update Runbooks**: Document debugging without shell

## Common Metrics Exported

| Metric | Description | Use Case |
|--------|-------------|----------|
| `DCGM_FI_DEV_GPU_UTIL` | GPU utilization (%) | Basic monitoring |
| `DCGM_FI_DEV_MEM_COPY_UTIL` | Memory utilization (%) | Memory pressure |
| `DCGM_FI_DEV_GPU_TEMP` | GPU temperature (°C) | Thermal monitoring |
| `DCGM_FI_DEV_POWER_USAGE` | Power usage (W) | Power/cost tracking |
| `DCGM_FI_DEV_PCIE_REPLAY_COUNTER` | PCIe errors | Hardware issues |
| `DCGM_FI_PROF_SM_ACTIVE` | SM active cycles | Performance profiling |
| `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE` | Tensor core usage | AI/ML workloads |

## Debugging Distroless Containers

```bash
# You can't do this anymore:
kubectl exec -it dcgm-exporter-xxx -- /bin/bash  # ❌ No shell!

# Instead, do this:

# 1. Check logs
kubectl logs dcgm-exporter-xxx -f

# 2. Check metrics endpoint
kubectl port-forward dcgm-exporter-xxx 9400:9400
curl localhost:9400/metrics

# 3. Debug with ephemeral container
kubectl debug dcgm-exporter-xxx -it --image=ubuntu:22.04 --target=dcgm-exporter

# 4. Describe pod for events
kubectl describe pod dcgm-exporter-xxx
```

## Version Compatibility

| DCGM Exporter | DCGM Version | GPU Drivers | Kubernetes |
|---------------|--------------|-------------|------------|
| 3.3.5-3.4.0 | 3.4.0 | 525+ | 1.25+ |
| 3.3.0-3.3.0 | 3.3.0 | 515+ | 1.23+ |
| 3.2.0-3.2.0 | 3.2.0 | 510+ | 1.20+ |

**Always check**: https://github.com/NVIDIA/dcgm-exporter/releases

## Resources

- **Official Docs**: https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/dcgm-exporter.html
- **GitHub**: https://github.com/NVIDIA/dcgm-exporter
- **Container Registry**: https://ngc.nvidia.com/catalog/containers/nvidia:k8s:dcgm-exporter
- **Metrics Guide**: https://docs.nvidia.com/datacenter/dcgm/latest/dcgm-api/dcgm-api-field-ids.html
