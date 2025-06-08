#!/bin/bash
set -e

echo "🔍 Finding Your Actual Namespace"
echo "================================"
echo ""

# Clear any incorrect environment variable
unset NAMESPACE

echo "📋 All namespaces in your cluster:"
kubectl get namespaces
echo ""

echo "🔍 Looking for your application namespaces:"
kubectl get namespaces | grep -E "(pyreact|microiac|dev|staging|prod)" || echo "No application namespaces found with common patterns"
echo ""

echo "📦 Looking for pods in all namespaces:"
kubectl get pods --all-namespaces | grep -E "(backend|frontend|pending)" || echo "No application pods found"
echo ""

echo "🎯 Your actual namespace appears to be:"
ACTUAL_NAMESPACE=$(kubectl get pods --all-namespaces | grep -E "(backend|frontend)" | head -1 | awk '{print $1}' || echo "")

if [ -n "$ACTUAL_NAMESPACE" ]; then
    echo "✅ Found: $ACTUAL_NAMESPACE"
    echo ""
    echo "📊 Pods in this namespace:"
    kubectl get pods -n $ACTUAL_NAMESPACE
    echo ""
    echo "🔧 To use this namespace, run:"
    echo "export NAMESPACE=$ACTUAL_NAMESPACE"
else
    echo "❌ Could not automatically detect namespace"
    echo "Please check the output above and identify your namespace manually"
fi