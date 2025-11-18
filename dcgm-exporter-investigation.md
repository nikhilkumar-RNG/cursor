# DCGM Exporter Investigation

## Context
Denis Kolobnev raised three important questions about our DCGM exporter usage:
1. Why are we updating dcgm-exporter?
2. Why do we need two of them?
3. They've had a distroless container available

## About DCGM Exporter

DCGM (Data Center GPU Manager) Exporter is a tool built by NVIDIA to export GPU metrics to Prometheus. It exposes GPU telemetry data for monitoring GPU health, utilization, and performance.

### Repository
- **Official Repo**: https://github.com/NVIDIA/dcgm-exporter
- **Container Registry**: https://ngc.nvidia.com/catalog/containers/nvidia:k8s:dcgm-exporter

## Question 1: Why are we updating dcgm-exporter?

Common reasons for updating DCGM exporter include:

### Security & Stability
- **CVE Fixes**: NVIDIA regularly patches security vulnerabilities
- **Bug Fixes**: Improved stability and error handling
- **Memory Leaks**: Older versions had known memory leak issues

### Feature Updates
- **New GPU Support**: Support for newer GPU architectures (H100, L40S, etc.)
- **Additional Metrics**: New metrics for better observability
- **Performance Improvements**: Reduced overhead and better resource efficiency

### Best Practice
- Stay within 2-3 minor versions of latest release
- Critical security updates should be applied promptly
- Breaking changes may require configuration updates

**Recommendation**: Document the specific version upgrade path and the reasons (security, features, or compatibility) in your deployment documentation.

## Question 2: Why do we need two instances of dcgm-exporter?

There are several legitimate reasons for running multiple DCGM exporter instances:

### Scenario A: Different Metric Profiles
```yaml
# Instance 1: Lightweight metrics for all GPUs
dcgm-exporter-basic:
  metrics: default  # Basic metrics (utilization, memory, temperature)
  scrape_interval: 30s

# Instance 2: Detailed profiling metrics for specific workloads
dcgm-exporter-profiling:
  metrics: profiling  # Detailed metrics (PCIe, NVLink, power, clocks)
  scrape_interval: 5s
  node_selector:
    gpu-intensive: "true"
```

**Why**: Profiling metrics have higher overhead. Running two instances allows:
- Low-overhead monitoring across all nodes
- Detailed metrics only where needed
- Different scrape intervals for different metric types

### Scenario B: Multi-Cluster or Multi-Namespace Setup
```yaml
# Instance 1: Training cluster
namespace: gpu-training
metrics: training-focused

# Instance 2: Inference cluster  
namespace: gpu-inference
metrics: inference-focused
```

**Why**: Different workload types benefit from different metrics

### Scenario C: High Availability / Redundancy
- Primary instance for monitoring
- Secondary instance for backup or different Prometheus endpoint

### Scenario D: Legacy Migration
- Old instance running during migration period
- New instance with updated configuration
- **This is often temporary and should be cleaned up**

### **Common Anti-Pattern** ⚠️
Running two identical instances is usually a configuration mistake:
- Duplicate resource usage
- Increased cost
- No added value
- Port conflicts

**Recommendation**: 
1. Audit both instances to identify their specific purpose
2. Document why each exists and what metrics they export
3. If they're identical, consolidate into a single instance
4. If different, clearly label them (e.g., `dcgm-exporter-basic` and `dcgm-exporter-profiling`)

## Question 3: Distroless Container Support

### What is Distroless?
Distroless containers contain only the application and its runtime dependencies, without:
- Shell
- Package managers
- Unnecessary utilities

### Benefits
✅ **Security**: Dramatically reduced attack surface (no shell, no package manager)
✅ **Size**: Smaller image size (100-200MB vs 500MB+)
✅ **Compliance**: Easier to pass security scans
✅ **Performance**: Faster image pulls and startup times

### DCGM Exporter Distroless Support

NVIDIA has provided distroless images for dcgm-exporter:

```yaml
# Traditional image (Ubuntu-based)
image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-ubuntu22.04

# Distroless image (available since v3.3.0+)
image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-distroless
```

### Migration Considerations

**Advantages of Switching:**
- ✅ Reduced CVE count (no OS packages to patch)
- ✅ Smaller image footprint
- ✅ Better security posture
- ✅ Compliance requirements

**Potential Challenges:**
- ⚠️ No shell access for debugging (need to use `kubectl debug`)
- ⚠️ Cannot exec into container for troubleshooting
- ⚠️ Some init scripts or sidecars may expect shell availability
- ⚠️ Need to verify all dependencies are included

**Recommended Migration Path:**
1. **Test in dev/staging first**
2. **Verify metrics collection works identically**
3. **Update runbooks** - document how to debug without shell access
4. **Train team** on `kubectl debug` for troubleshooting
5. **Roll out to production** with proper monitoring

### Example Kubernetes Deployment Change

```yaml
# Before (Ubuntu-based)
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dcgm-exporter
spec:
  template:
    spec:
      containers:
      - name: dcgm-exporter
        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-ubuntu22.04
        # Can use: kubectl exec -it <pod> -- /bin/bash

# After (Distroless)
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dcgm-exporter
spec:
  template:
    spec:
      containers:
      - name: dcgm-exporter
        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-distroless
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          allowPrivilegeEscalation: false
        # For debugging: kubectl debug <pod> -it --image=busybox --target=dcgm-exporter
```

## Recommendations

### Immediate Actions
1. **Audit Current Deployment**
   - Document which versions are currently running
   - Identify why there are two instances
   - Determine if both are necessary

2. **Evaluate Distroless Migration**
   - Check current image tags
   - Plan migration to distroless for improved security
   - Test in non-production environment first

3. **Consolidate if Possible**
   - If running duplicate instances, merge into one
   - If running different configurations, document the rationale
   - Update deployment documentation

### Long-term Strategy
- **Version Policy**: Stay current with DCGM exporter releases (within 1-2 minor versions)
- **Image Policy**: Use distroless images for production workloads
- **Monitoring**: Set up alerts for dcgm-exporter pod health and metric gaps
- **Documentation**: Maintain clear documentation on why each instance exists

## Next Steps

Please provide:
1. Current deployment manifests or Helm values for both dcgm-exporter instances
2. Current image versions in use
3. The Kubernetes namespace(s) where they're deployed
4. Any custom metrics configurations

This will allow for a specific recommendation on consolidation and distroless migration.

---

**Investigation Date**: 2025-11-18
**Investigating Branch**: `cursor/investigate-dcgm-exporter-instances-and-distroless-usage-3d87`
