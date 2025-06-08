#!/bin/bash
set -e

echo "🚀 Quick Fix for Pending Pods"
echo "============================="
echo ""

# Get the actual namespace
echo "🔍 Finding your namespace..."
ACTUAL_NAMESPACE=$(kubectl get pods --all-namespaces | grep -E "(backend|frontend)" | head -1 | awk '{print $1}' 2>/dev/null || echo "")

if [ -z "$ACTUAL_NAMESPACE" ]; then
    echo "❌ Could not find application namespace automatically"
    echo "📋 Available namespaces:"
    kubectl get namespaces
    echo ""
    read -p "Enter your application namespace: " ACTUAL_NAMESPACE
fi

echo "✅ Using namespace: $ACTUAL_NAMESPACE"
echo ""

# Check current pod status
echo "📊 Current pod status:"
kubectl get pods -n $ACTUAL_NAMESPACE
echo ""

# Check why pods are pending
echo "🔍 Checking why pods are pending..."
kubectl describe pods -n $ACTUAL_NAMESPACE | grep -A 5 "Events:" | head -20
echo ""

# Fix 1: Remove problematic node selectors
echo "🔧 Fix 1: Removing problematic node selectors..."
kubectl patch deployment backend -n $ACTUAL_NAMESPACE -p '{"spec":{"template":{"spec":{"nodeSelector":null,"tolerations":null}}}}' 2>/dev/null || echo "Backend deployment not found or already patched"

kubectl patch deployment frontend -n $ACTUAL_NAMESPACE -p '{"spec":{"template":{"spec":{"nodeSelector":null,"tolerations":null}}}}' 2>/dev/null || echo "Frontend deployment not found or already patched"

echo "✅ Node selectors removed"
echo ""

# Fix 2: Check node capacity
echo "🔍 Checking node capacity..."
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
kubectl get nodes -o wide
echo ""

# Fix 3: Scale deployments down and up to force rescheduling
echo "🔄 Restarting deployments..."
kubectl scale deployment backend --replicas=0 -n $ACTUAL_NAMESPACE 2>/dev/null || echo "Backend deployment not found"
kubectl scale deployment frontend --replicas=0 -n $ACTUAL_NAMESPACE 2>/dev/null || echo "Frontend deployment not found"

sleep 10

kubectl scale deployment backend --replicas=2 -n $ACTUAL_NAMESPACE 2>/dev/null || echo "Backend deployment not found"
kubectl scale deployment frontend --replicas=2 -n $ACTUAL_NAMESPACE 2>/dev/null || echo "Frontend deployment not found"

echo "⏳ Waiting for pods to start..."
sleep 30

echo "📊 New pod status:"
kubectl get pods -n $ACTUAL_NAMESPACE
echo ""

# Check if pods are still pending
PENDING_PODS=$(kubectl get pods -n $ACTUAL_NAMESPACE --field-selector=status.phase=Pending --no-headers | wc -l)

if [ "$PENDING_PODS" -gt 0 ]; then
    echo "⚠️ Still have $PENDING_PODS pending pods. Checking node resources..."
    
    echo "🔍 Node resource allocation:"
    kubectl describe nodes | grep -A 5 "Allocated resources" | head -20
    
    echo ""
    echo "💡 Next steps to try:"
    echo "1. Scale up your AKS cluster:"
    echo "   az aks nodepool scale --resource-group <rg> --cluster-name <cluster> --name system --node-count 3"
    echo "2. Check for node taints:"
    echo "   kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints"
    echo "3. Run the full cluster fix script:"
    echo "   ./scripts/fix_cluster_issues.sh $ACTUAL_NAMESPACE"
else
    echo "✅ All pods are now running!"
fi

echo ""
echo "🎯 Your namespace is: $ACTUAL_NAMESPACE"
echo "💾 Save this for future use: export NAMESPACE=$ACTUAL_NAMESPACE"