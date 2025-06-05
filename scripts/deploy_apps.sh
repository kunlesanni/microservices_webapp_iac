
# ================================
# scripts/deploy-apps.sh
# Deploy applications to Kubernetes
# ================================

#!/bin/bash
set -e

echo "🚀 Deploying applications to Kubernetes..."

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install it first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster."
    echo "Run: az aks get-credentials --resource-group <rg-name> --name <cluster-name>"
    exit 1
fi

# Get cluster info
CLUSTER_INFO=$(kubectl cluster-info | head -n 1)
echo "📋 Connected to: $CLUSTER_INFO"

# Get required values
if [ -d "terraform" ]; then
    echo "📋 Getting values from Terraform..."
    cd terraform
    ACR_NAME=$(terraform output -raw container_registry_name 2>/dev/null || echo "")
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    AKS_CLUSTER=$(terraform output -raw aks_cluster_name 2>/dev/null || echo "")
    cd ..
fi

# Set defaults
ENVIRONMENT=${ENVIRONMENT:-"dev"}
PROJECT_NAME=${PROJECT_NAME:-"pyreact"}

# Get image tag
if [ -f ".last-image-tag" ]; then
    IMAGE_TAG=$(cat .last-image-tag)
    echo "📝 Using image tag from last build: $IMAGE_TAG"
else
    IMAGE_TAG="latest"
    echo "📝 Using default image tag: $IMAGE_TAG"
fi

# If ACR not found, prompt
if [ -z "$ACR_NAME" ]; then
    read -p "Enter your Azure Container Registry name: " ACR_NAME
fi

echo "🏗️ Deployment configuration:"
echo "  ACR: $ACR_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Image Tag: $IMAGE_TAG"
echo "  Project: $PROJECT_NAME"

# Check if Kubernetes manifests exist
if [ ! -d "k8s" ]; then
    echo "❌ Kubernetes manifests directory 'k8s' not found."
    exit 1
fi

# Create temporary directory for processed manifests
TEMP_DIR=$(mktemp -d)
echo "📁 Processing manifests in temporary directory: $TEMP_DIR"

# Copy and process manifests
cp -r k8s/* $TEMP_DIR/

# Replace placeholders in manifests
echo "🔄 Processing manifest templates..."
find $TEMP_DIR -name "*.yaml" -type f -exec sed -i "s|{{ACR_NAME}}|$ACR_NAME|g" {} \;
find $TEMP_DIR -name "*.yaml" -type f -exec sed -i "s|{{IMAGE_TAG}}|$IMAGE_TAG|g" {} \;
find $TEMP_DIR -name "*.yaml" -type f -exec sed -i "s|{{ENVIRONMENT}}|$ENVIRONMENT|g" {} \;
find $TEMP_DIR -name "*.yaml" -type f -exec sed -i "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" {} \;

# Install NGINX Ingress Controller if not present
echo "🔍 Checking for NGINX Ingress Controller..."
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    echo "📦 Installing NGINX Ingress Controller..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
    helm repo update
    
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx \
      --create-namespace \
      --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
      --set controller.service.externalTrafficPolicy=Local \
      --wait --timeout=300s
    
    echo "✅ NGINX Ingress Controller installed"
else
    echo "✅ NGINX Ingress Controller already installed"
fi

# Deploy namespace first
echo "📦 Creating namespace..."
kubectl apply -f $TEMP_DIR/namespace.yaml

# Get secrets from Azure Key Vault if available
NAMESPACE="${PROJECT_NAME}-${ENVIRONMENT}"
echo "🔐 Setting up secrets for namespace: $NAMESPACE"

if [ ! -z "$RESOURCE_GROUP" ] && [ ! -z "$ACR_NAME" ]; then
    # Try to get secrets from Key Vault
    echo "🔍 Attempting to get secrets from Azure Key Vault..."
    
    # Check if Key Vault exists
    KV_NAME=$(az keyvault list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv 2>/dev/null || echo "")
    
    if [ ! -z "$KV_NAME" ]; then
        echo "🔑 Found Key Vault: $KV_NAME"
        
        # Get secrets
        DATABASE_URL=$(az keyvault secret show --vault-name $KV_NAME --name database-url --query value -o tsv 2>/dev/null || echo "")
        REDIS_URL=$(az keyvault secret show --vault-name $KV_NAME --name redis-url --query value -o tsv 2>/dev/null || echo "")
        
        if [ ! -z "$DATABASE_URL" ] && [ ! -z "$REDIS_URL" ]; then
            echo "✅ Retrieved secrets from Key Vault"
            
            # Create or update Kubernetes secret
            kubectl create secret generic app-secrets \
              --namespace $NAMESPACE \
              --from-literal=DATABASE_URL="$DATABASE_URL" \
              --from-literal=REDIS_URL="$REDIS_URL" \
              --dry-run=client -o yaml | kubectl apply -f -
            
            echo "✅ Kubernetes secrets created"
        else
            echo "⚠️ Could not retrieve all secrets from Key Vault"
        fi
    else
        echo "⚠️ No Key Vault found in resource group"
    fi
else
    echo "⚠️ Terraform outputs not available, skipping Key Vault secret retrieval"
fi

# Apply secrets manifest if it exists
if [ -f "$TEMP_DIR/secrets.yaml" ]; then
    echo "📝 Applying secrets manifest..."
    kubectl apply -f $TEMP_DIR/secrets.yaml
fi

# Deploy backend
echo "🔧 Deploying backend..."
if [ -d "$TEMP_DIR/backend" ]; then
    kubectl apply -f $TEMP_DIR/backend/
    echo "✅ Backend deployed"
fi

# Deploy frontend
echo "🌐 Deploying frontend..."
if [ -d "$TEMP_DIR/frontend" ]; then
    kubectl apply -f $TEMP_DIR/frontend/
    echo "✅ Frontend deployed"
fi

# Deploy ingress
echo "🌍 Deploying ingress..."
if [ -d "$TEMP_DIR/ingress" ]; then
    kubectl apply -f $TEMP_DIR/ingress/
    echo "✅ Ingress deployed"
fi

# Deploy monitoring if exists
if [ -d "$TEMP_DIR/monitoring" ]; then
    echo "📊 Deploying monitoring..."
    kubectl apply -f $TEMP_DIR/monitoring/
    echo "✅ Monitoring deployed"
fi

# Deploy policies if exists
if [ -d "$TEMP_DIR/policies" ]; then
    echo "🔒 Deploying security policies..."
    kubectl apply -f $TEMP_DIR/policies/
    echo "✅ Security policies deployed"
fi

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/backend -n $NAMESPACE 2>/dev/null || echo "⚠️ Backend deployment timeout"
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n $NAMESPACE 2>/dev/null || echo "⚠️ Frontend deployment timeout"

# Get deployment status
echo "📋 Deployment status:"
kubectl get pods -n $NAMESPACE
echo ""
kubectl get services -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE

# Get external IP
echo "🌐 Getting external access information..."
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
    echo "⏳ Waiting for external IP..."
    EXTERNAL_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -z "$EXTERNAL_IP" ]; then
        sleep 10
    fi
done

# Clean up temporary directory
rm -rf $TEMP_DIR

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "🌐 Application URLs:"
echo "  Frontend: http://$EXTERNAL_IP"
echo "  Backend API: http://$EXTERNAL_IP/api"
echo "  API Documentation: http://$EXTERNAL_IP/api/docs"
echo ""
echo "🔍 Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -f deployment/backend -n $NAMESPACE"
echo "  kubectl logs -f deployment/frontend -n $NAMESPACE"
echo ""
echo "🧪 Test the deployment:"
echo "  curl http://$EXTERNAL_IP/api/health"
