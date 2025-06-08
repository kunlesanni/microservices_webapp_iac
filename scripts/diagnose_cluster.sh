#!/bin/bash
set -e

echo "🔍 Kubernetes Cluster Diagnostics"
echo "================================="
echo ""

# Check cluster connectivity
echo "📋 Cluster Information:"
kubectl cluster-info
echo ""

# Check nodes
echo "🖥️ Node Status:"
kubectl get nodes -o wide
echo ""

# Check node resources
echo "📊 Node Resource Usage:"
kubectl top nodes 2>/dev/null || echo "⚠️ Metrics server not available"
echo ""

# Check system pods
echo "🔧 System Pods Status:"
kubectl get pods -n kube-system
echo ""

# Check ingress-nginx namespace
echo "🌐 NGINX Ingress Status:"
kubectl get all -n ingress-nginx
echo ""

# Check events for issues
echo "⚠️ Recent Cluster Events:"
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
echo ""

# Check pending pods details
echo "🔍 Pending Pods Details:"
NAMESPACE=${1:-"pyreact-dev"}
kubectl get pods -n $NAMESPACE -o wide
echo ""

echo "📋 Pod Scheduling Issues:"
for pod in $(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Pending -o name); do
    echo "--- $pod ---"
    kubectl describe $pod -n $NAMESPACE | grep -A 10 "Events:"
    echo ""
done

# Check resource quotas
echo "📏 Resource Quotas:"
kubectl get resourcequota --all-namespaces
echo ""

# Check if nodes have taints
echo "🏷️ Node Taints:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
echo ""

# Check node conditions
echo "🔍 Node Conditions:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,REASON:.status.conditions[-1].reason
echo ""

echo "💡 Troubleshooting Tips:"
echo "1. If nodes show 'NotReady', check node health"
echo "2. If 'Insufficient resources', scale up the cluster"
echo "3. If 'FailedScheduling', check node selectors and taints"
echo "4. If ingress-nginx pods are pending, check node pool configuration"