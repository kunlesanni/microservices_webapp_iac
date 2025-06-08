#!/bin/bash
set -e

echo "🔧 Fixing Kubernetes Cluster Issues"
echo "==================================="
echo ""

NAMESPACE=${1:-"pyreact-dev"}

# Function to check if AKS cluster needs scaling
check_and_scale_cluster() {
    echo "📊 Checking cluster capacity..."
    
    # Get cluster info from terraform if available
    if [ -d "terraform" ]; then
        cd terraform
        RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
        AKS_CLUSTER=$(terraform output -raw aks_cluster_name 2>/dev/null || echo "")
        cd ..
    fi
    
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$AKS_CLUSTER" ]; then
        echo "⚠️ Could not get cluster info from Terraform. Please provide manually:"
        read -p "Enter resource group name: " RESOURCE_GROUP
        read -p "Enter AKS cluster name: " AKS_CLUSTER
    fi
    
    echo "🔍 Current node pools:"
    az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $AKS_CLUSTER --output table
    
    echo ""
    echo "📈 Scaling system node pool to ensure capacity..."
    az aks nodepool scale \
        --resource-group $RESOURCE_GROUP \
        --cluster-name $AKS_CLUSTER \
        --name system \
        --node-count 2
    
    echo "📈 Scaling user node pool to ensure capacity..."
    az aks nodepool scale \
        --resource-group $RESOURCE_GROUP \
        --cluster-name $AKS_CLUSTER \
        --name user \
        --node-count 3
    
    echo "⏳ Waiting for nodes to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=600s
}

# Function to fix NGINX Ingress Controller
fix_ingress_controller() {
    echo "🌐 Fixing NGINX Ingress Controller..."
    
    # Remove existing installation if it's broken
    echo "🗑️ Cleaning up existing ingress installation..."
    helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || echo "No existing installation found"
    kubectl delete namespace ingress-nginx --ignore-not-found=true
    
    # Wait a bit for cleanup
    sleep 30
    
    # Reinstall with proper configuration for AKS
    echo "📦 Installing NGINX Ingress Controller for AKS..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.replicaCount=2 \
        --set controller.nodeSelector."kubernetes\.io/os"=linux \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
        --set controller.service.externalTrafficPolicy=Local \
        --set controller.service.type=LoadBalancer \
        --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
        --timeout=10m \
        --wait
    
    echo "✅ NGINX Ingress Controller installed"
}

# Function to fix application deployments
fix_application_deployments() {
    echo "🔧 Fixing application deployments..."
    
    # Remove node selector constraints that might be causing issues
    echo "📝 Updating deployments to remove problematic node selectors..."
    
    # Update backend deployment
    kubectl patch deployment backend -n $NAMESPACE -p '{"spec":{"template":{"spec":{"nodeSelector":null,"tolerations":null}}}}'
    
    # Update frontend deployment  
    kubectl patch deployment frontend -n $NAMESPACE -p '{"spec":{"template":{"spec":{"nodeSelector":null,"tolerations":null}}}}'
    
    # Restart deployments
    echo "🔄 Restarting deployments..."
    kubectl rollout restart deployment/backend -n $NAMESPACE
    kubectl rollout restart deployment/frontend -n $NAMESPACE
    
    # Wait for deployments
    echo "⏳ Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/backend -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/frontend -n $NAMESPACE
}

# Main execution
echo "🔍 Running cluster diagnostics first..."
./scripts/diagnose_cluster.sh $NAMESPACE

echo ""
read -p "Do you want to scale the cluster to fix capacity issues? (y/N): " scale_cluster
if [[ "$scale_cluster" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    check_and_scale_cluster
fi

echo ""
read -p "Do you want to reinstall NGINX Ingress Controller? (y/N): " fix_ingress
if [[ "$fix_ingress" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    fix_ingress_controller
fi

echo ""
read -p "Do you want to fix application deployments? (y/N): " fix_apps
if [[ "$fix_apps" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    fix_application_deployments
fi

echo ""
echo "✅ Cluster fixes completed!"
echo ""
echo "📊 Final status check:"
kubectl get nodes
echo ""
kubectl get pods -n $NAMESPACE
echo ""
kubectl get service ingress-nginx-controller -n ingress-nginx