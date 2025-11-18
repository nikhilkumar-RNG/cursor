# DCGM Exporter Discovery Script

Use these commands to audit your current dcgm-exporter deployment.

## 1. Find All DCGM Exporter Resources

```bash
#!/bin/bash

echo "=== Finding all dcgm-exporter resources ==="
echo ""

# Find DaemonSets
echo "📦 DaemonSets:"
kubectl get daemonsets -A | grep -i dcgm || echo "  None found"
echo ""

# Find Deployments (less common)
echo "📦 Deployments:"
kubectl get deployments -A | grep -i dcgm || echo "  None found"
echo ""

# Find Pods
echo "🔷 Pods:"
kubectl get pods -A -o wide | grep -i dcgm || echo "  None found"
echo ""

# Find Services
echo "🌐 Services:"
kubectl get services -A | grep -i dcgm || echo "  None found"
echo ""

# Find ServiceMonitors
echo "📊 ServiceMonitors:"
kubectl get servicemonitors -A | grep -i dcgm || echo "  None found"
echo ""
```

## 2. Get Detailed Configuration

```bash
#!/bin/bash

echo "=== DCGM Exporter Configuration Details ==="
echo ""

# Get all dcgm daemonsets
DAEMONSETS=$(kubectl get daemonsets -A -o jsonpath='{range .items[?(@.metadata.name contains "dcgm")]}{.metadata.namespace}{"|"}{.metadata.name}{"\n"}{end}')

if [ -z "$DAEMONSETS" ]; then
    echo "❌ No dcgm-exporter DaemonSets found"
    exit 0
fi

# Iterate through each daemonset
while IFS='|' read -r namespace name; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 DaemonSet: $name (namespace: $namespace)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Get image
    echo "🖼️  Image:"
    kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].image}' 
    echo ""
    echo ""
    
    # Get environment variables
    echo "🔧 Environment Variables:"
    kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].env[*]}' | jq -r 'try . catch "No env vars"'
    echo ""
    
    # Get node selector
    echo "🎯 Node Selector:"
    kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.nodeSelector}' | jq -r 'try . catch "No node selector"'
    echo ""
    echo ""
    
    # Get tolerations
    echo "⚙️  Tolerations:"
    kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.tolerations}' | jq -r 'try . catch "No tolerations"'
    echo ""
    echo ""
    
    # Get resource requests/limits
    echo "📊 Resources:"
    kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq -r 'try . catch "No resource limits"'
    echo ""
    echo ""
    
    # Get pod count
    echo "🔷 Pod Status:"
    kubectl get daemonset "$name" -n "$namespace" -o jsonpath='Desired: {.status.desiredNumberScheduled}, Current: {.status.currentNumberScheduled}, Ready: {.status.numberReady}'
    echo ""
    echo ""
    
    # Get creation timestamp
    echo "📅 Created:"
    kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.metadata.creationTimestamp}'
    echo ""
    echo ""
    
    # Get annotations
    echo "📝 Annotations:"
    kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.metadata.annotations}' | jq -r 'try . catch "No annotations"'
    echo ""
    echo ""
    
done <<< "$DAEMONSETS"
```

## 3. Compare Images

```bash
#!/bin/bash

echo "=== DCGM Exporter Image Analysis ==="
echo ""

# Get all images
IMAGES=$(kubectl get pods -A -o jsonpath="{.items[*].spec.containers[*].image}" | tr -s '[[:space:]]' '\n' | grep -i dcgm | sort -u)

echo "📦 Images in use:"
echo "$IMAGES"
echo ""

# Analyze each image
for image in $IMAGES; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Image: $image"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if distroless
    if echo "$image" | grep -q "distroless"; then
        echo "✅ Distroless: YES"
    else
        echo "⚠️  Distroless: NO (consider migrating)"
    fi
    
    # Extract version
    VERSION=$(echo "$image" | grep -oP ':\K[^:]+$')
    echo "📌 Version: $VERSION"
    
    # Count pods using this image
    POD_COUNT=$(kubectl get pods -A -o jsonpath="{.items[*].spec.containers[*].image}" | tr -s '[[:space:]]' '\n' | grep -c "$image")
    echo "🔷 Pods using this: $POD_COUNT"
    echo ""
done
```

## 4. Test Metrics Endpoint

```bash
#!/bin/bash

echo "=== Testing DCGM Exporter Metrics ==="
echo ""

# Get first dcgm pod
POD=$(kubectl get pods -A -l app=dcgm-exporter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
NAMESPACE=$(kubectl get pods -A -l app=dcgm-exporter -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)

if [ -z "$POD" ]; then
    echo "❌ No dcgm-exporter pods found with label app=dcgm-exporter"
    echo "   Trying alternative discovery..."
    POD=$(kubectl get pods -A -o jsonpath='{.items[?(@.metadata.name contains "dcgm")].metadata.name}' | awk '{print $1}')
    NAMESPACE=$(kubectl get pods -A -o jsonpath='{.items[?(@.metadata.name contains "dcgm")].metadata.namespace}' | awk '{print $1}')
fi

if [ -z "$POD" ]; then
    echo "❌ No dcgm-exporter pods found"
    exit 1
fi

echo "📦 Testing pod: $POD (namespace: $NAMESPACE)"
echo ""

# Port forward
echo "🔌 Setting up port-forward..."
kubectl port-forward -n "$NAMESPACE" "$POD" 9400:9400 &
PF_PID=$!
sleep 2

# Test health endpoint
echo "🏥 Testing /health endpoint:"
curl -s http://localhost:9400/health || echo "❌ Health check failed"
echo ""
echo ""

# Test metrics endpoint
echo "📊 Testing /metrics endpoint:"
echo "Sample metrics (first 20 lines):"
curl -s http://localhost:9400/metrics | head -20
echo ""

# Count metrics
METRIC_COUNT=$(curl -s http://localhost:9400/metrics | grep -c "^DCGM_")
echo "Total DCGM metrics: $METRIC_COUNT"
echo ""

# Kill port-forward
kill $PF_PID 2>/dev/null
```

## 5. Check for Duplicates

```bash
#!/bin/bash

echo "=== Checking for Duplicate DCGM Exporters ==="
echo ""

# Get all dcgm daemonsets with details
DAEMONSETS=$(kubectl get daemonsets -A -o json | jq -r '.items[] | select(.metadata.name | contains("dcgm")) | "\(.metadata.namespace)|\(.metadata.name)|\(.spec.template.spec.containers[0].image)|\(.spec.template.spec.containers[0].env)"')

COUNT=$(echo "$DAEMONSETS" | wc -l)

echo "Found $COUNT dcgm-exporter DaemonSet(s)"
echo ""

if [ "$COUNT" -eq 0 ]; then
    echo "✅ No dcgm-exporters found"
    exit 0
elif [ "$COUNT" -eq 1 ]; then
    echo "✅ Only one dcgm-exporter found (good!)"
    echo "$DAEMONSETS"
else
    echo "⚠️  Multiple dcgm-exporters found:"
    echo ""
    
    while IFS='|' read -r namespace name image env; do
        echo "  - $name (namespace: $namespace)"
        echo "    Image: $image"
        echo "    Env: $env"
        echo ""
    done <<< "$DAEMONSETS"
    
    echo "❓ Questions to answer:"
    echo "   1. Do they have different configurations?"
    echo "   2. Do they target different node pools?"
    echo "   3. Are they in different namespaces for a reason?"
    echo "   4. Is one a leftover from a migration?"
    echo ""
    echo "💡 If they're identical, consider consolidating into one."
fi
```

## 6. Security Audit

```bash
#!/bin/bash

echo "=== DCGM Exporter Security Audit ==="
echo ""

# Get all dcgm daemonsets
DAEMONSETS=$(kubectl get daemonsets -A -o jsonpath='{range .items[?(@.metadata.name contains "dcgm")]}{.metadata.namespace}{"|"}{.metadata.name}{"\n"}{end}')

while IFS='|' read -r namespace name; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Security Audit: $name (namespace: $namespace)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check image
    IMAGE=$(kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].image}')
    if echo "$IMAGE" | grep -q "distroless"; then
        echo "✅ Image: Distroless (secure)"
    else
        echo "⚠️  Image: Not distroless (consider migrating)"
    fi
    echo "   $IMAGE"
    echo ""
    
    # Check runAsNonRoot
    RUN_AS_NON_ROOT=$(kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}')
    if [ "$RUN_AS_NON_ROOT" == "true" ]; then
        echo "✅ runAsNonRoot: true"
    else
        echo "⚠️  runAsNonRoot: not set or false"
    fi
    echo ""
    
    # Check readOnlyRootFilesystem
    READ_ONLY=$(kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}')
    if [ "$READ_ONLY" == "true" ]; then
        echo "✅ readOnlyRootFilesystem: true"
    else
        echo "⚠️  readOnlyRootFilesystem: not set or false"
    fi
    echo ""
    
    # Check allowPrivilegeEscalation
    PRIV_ESC=$(kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}')
    if [ "$PRIV_ESC" == "false" ]; then
        echo "✅ allowPrivilegeEscalation: false"
    else
        echo "⚠️  allowPrivilegeEscalation: not set or true"
    fi
    echo ""
    
    # Check capabilities
    CAPS=$(kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop}')
    if echo "$CAPS" | grep -q "ALL"; then
        echo "✅ Capabilities: dropped ALL"
    else
        echo "⚠️  Capabilities: not all dropped"
    fi
    echo ""
    
done <<< "$DAEMONSETS"
```

## Run All Checks

```bash
#!/bin/bash

echo "╔════════════════════════════════════════════╗"
echo "║  DCGM Exporter Complete Audit              ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Save to file
OUTPUT_FILE="dcgm-audit-$(date +%Y%m%d-%H%M%S).txt"

{
    echo "Audit Date: $(date)"
    echo "Cluster: $(kubectl config current-context)"
    echo ""
    
    # Run all checks
    bash discovery-1-find-resources.sh
    echo ""
    bash discovery-2-detailed-config.sh
    echo ""
    bash discovery-3-compare-images.sh
    echo ""
    bash discovery-5-check-duplicates.sh
    echo ""
    bash discovery-6-security-audit.sh
    
} | tee "$OUTPUT_FILE"

echo ""
echo "✅ Audit complete! Results saved to: $OUTPUT_FILE"
```
