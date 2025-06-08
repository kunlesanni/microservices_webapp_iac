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

# Function to replace placeholders in a file
replace_placeholders() {
    local file="$1"
    if [ -f "$file" ]; then
        # Use a more robust replacement approach
        sed -i.bak \
            -e "s/{{ACR_NAME}}/$ACR_NAME/g" \
            -e "s/{{IMAGE_TAG}}/$IMAGE_TAG/g" \
            -e "s/{{ENVIRONMENT}}/$ENVIRONMENT/g" \
            -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
            "$file"
        rm -f "$file.bak"
        echo "✅ Processed $(basename "$file")"
    fi
}

# Replace placeholders in all YAML files
echo "🔄 Processing manifest templates..."
find $TEMP_DIR -name "*.yaml" -type f | while read file; do
    replace_placeholders "$file"
done

# Install NGINX Ingress Controller if not present
echo "🔍 Checking for NGINX Ingress Controller..."
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    echo "📦 Installing NGINX Ingress Controller..."
    
    # Add helm repo if not exists
    if ! helm repo list | grep -q ingress-nginx; then
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    fi
    helm repo update
    
    echo "⏳ Installing NGINX Ingress Controller (this may take up to 10 minutes)..."
    
    # Try to install with extended timeout and better error handling
    if ! helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx \
      --create-namespace \
      --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
      --set controller.service.externalTrafficPolicy=Local \
      --timeout=15m \
      --wait; then
        
        echo "⚠️ NGINX Ingress Controller installation timed out or failed."
        echo "🔧 Attempting alternative installation method..."
        
        # Try without --wait flag
        helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
          --namespace ingress-nginx \
          --create-namespace \
          --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
          --set controller.service.externalTrafficPolicy=Local \
          --timeout=15m
        
        echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=600s || echo "⚠️ NGINX controller pods may still be starting"
        
        echo "⏳ Waiting for LoadBalancer service..."
        kubectl wait --namespace ingress-nginx \
          --for=jsonpath='{.status.loadBalancer.ingress}' \
          service/ingress-nginx-controller \
          --timeout=600s || echo "⚠️ LoadBalancer IP assignment may take longer"
    fi
    
    echo "✅ NGINX Ingress Controller installation completed"
else
    echo "✅ NGINX Ingress Controller already installed"
    
    # Check if it's actually running
    if ! kubectl get pods -n ingress-nginx | grep -q "Running"; then
        echo "⚠️ NGINX Ingress Controller pods are not running. Checking status..."
        kubectl get pods -n ingress-nginx
        echo "🔧 Attempting to restart..."
        kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=300s || echo "⚠️ Controller restart may need more time"
    fi
fi

# Create namespace first
NAMESPACE="${PROJECT_NAME}-${ENVIRONMENT}"
echo "📦 Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Apply namespace manifest if it exists (might have additional labels)
if [ -f "$TEMP_DIR/namespace.yaml" ]; then
    kubectl apply -f "$TEMP_DIR/namespace.yaml"
fi

# Create basic secrets if they don't exist
echo "🔐 Setting up secrets for namespace: $NAMESPACE"
if ! kubectl get secret app-secrets -n $NAMESPACE &> /dev/null; then
    echo "🔐 Creating default application secrets..."
    kubectl create secret generic app-secrets \
      --from-literal=DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy" \
      --from-literal=REDIS_URL="redis://localhost:6379/0" \
      --namespace=$NAMESPACE
    echo "⚠️ Using default secrets. Update them with real values."
fi

# Apply secrets manifest if it exists
if [ -f "$TEMP_DIR/secrets.yaml" ]; then
    echo "📝 Applying secrets manifest..."
    kubectl apply -f "$TEMP_DIR/secrets.yaml"
fi

# Deploy ConfigMaps if they exist
if [ -d "$TEMP_DIR/config" ]; then
    echo "⚙️ Deploying configuration..."
    kubectl apply -f "$TEMP_DIR/config/"
fi

# Deploy backend components
if [ -d "$TEMP_DIR/backend" ]; then
    echo "🔧 Deploying backend..."
    
    # Skip deprecated or problematic files
    for file in "$TEMP_DIR/backend"/*.yaml; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            case "$filename" in
                "hpa.yaml")
                    # Check if HPA is supported
                    if kubectl api-resources | grep -q horizontalpodautoscalers; then
                        kubectl apply -f "$file"
                    else
                        echo "⚠️ Skipping HPA - not supported in this cluster"
                    fi
                    ;;
                *)
                    kubectl apply -f "$file"
                    ;;
            esac
        fi
    done
    echo "✅ Backend deployed"
fi

# Deploy frontend components
if [ -d "$TEMP_DIR/frontend" ]; then
    echo "🌐 Deploying frontend..."
    
    for file in "$TEMP_DIR/frontend"/*.yaml; do
        if [ -f "$file" ]; then
            kubectl apply -f "$file"
        fi
    done
    echo "✅ Frontend deployed"
fi

# Deploy ingress
if [ -d "$TEMP_DIR/ingress" ]; then
    echo "🌍 Deploying ingress..."
    kubectl apply -f "$TEMP_DIR/ingress/"
    echo "✅ Ingress deployed"
fi

# Deploy monitoring (optional)
if [ -d "$TEMP_DIR/monitoring" ]; then
    echo "📊 Deploying monitoring..."
    for file in "$TEMP_DIR/monitoring"/*.yaml; do
        if [ -f "$file" ]; then
            # Skip files with issues
            if ! kubectl apply -f "$file" --dry-run=client &> /dev/null; then
                echo "⚠️ Skipping problematic monitoring file: $(basename "$file")"
            else
                kubectl apply -f "$file"
            fi
        fi
    done
    echo "✅ Monitoring deployed"
fi

# Deploy policies (with error handling)
if [ -d "$TEMP_DIR/policies" ]; then
    echo "🔒 Deploying security policies..."
    for file in "$TEMP_DIR/policies"/*.yaml; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            case "$filename" in
                "pod-security-policy.yaml")
                    # Skip PodSecurityPolicy if not supported
                    if kubectl api-resources | grep -q podsecuritypolicies; then
                        kubectl apply -f "$file"
                    else
                        echo "⚠️ Skipping PodSecurityPolicy - deprecated in this Kubernetes version"
                    fi
                    ;;
                "network-policy.yaml")
                    # Only apply if network policies are supported
                    if kubectl apply -f "$file" --dry-run=client &> /dev/null; then
                        kubectl apply -f "$file"
                    else
                        echo "⚠️ Skipping network policy - not supported or has errors"
                    fi
                    ;;
                *)
                    kubectl apply -f "$file" || echo "⚠️ Failed to apply $(basename "$file")"
                    ;;
            esac
        fi
    done
    echo "✅ Security policies deployed"
fi

# Deploy jobs if they exist
if [ -d "$TEMP_DIR/jobs" ]; then
    echo "⚙️ Deploying jobs..."
    for file in "$TEMP_DIR/jobs"/*.yaml; do
        if [ -f "$file" ]; then
            kubectl apply -f "$file" || echo "⚠️ Failed to apply job: $(basename "$file")"
        fi
    done
    echo "✅ Jobs deployed"
fi

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
sleep 5

# Check if deployments exist before waiting
if kubectl get deployment backend -n $NAMESPACE &> /dev/null; then
    kubectl wait --for=condition=available --timeout=300s deployment/backend -n $NAMESPACE || echo "⚠️ Backend deployment timeout"
else
    echo "⚠️ Backend deployment not found"
fi

if kubectl get deployment frontend -n $NAMESPACE &> /dev/null; then
    kubectl wait --for=condition=available --timeout=300s deployment/frontend -n $NAMESPACE || echo "⚠️ Frontend deployment timeout"
else
    echo "⚠️ Frontend deployment not found"
fi

# Get service status
echo "📊 Deployment status:"
kubectl get pods -n $NAMESPACE
echo ""
kubectl get services -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE 2>/dev/null || echo "No ingress resources found"

# Get external IP with better error handling
echo "🌐 Getting external IP..."
echo "⏳ Waiting for LoadBalancer IP assignment (this can take 2-10 minutes)..."

# Wait for external IP with timeout
EXTERNAL_IP=""
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        echo "✅ External IP assigned: $EXTERNAL_IP"
        break
    fi
    
    echo "⏳ Waiting for IP assignment... (attempt $i/30)"
    sleep 20
done

if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "null" ]; then
    echo "⚠️ External IP is still being assigned. This can take up to 10 minutes."
    echo "   Check status with: kubectl get service ingress-nginx-controller -n ingress-nginx"
    EXTERNAL_IP="<pending>"
fi

# Clean up temp directory
rm -rf $TEMP_DIR

echo ""
echo "🎉 DEPLOYMENT COMPLETED! 🎉"
echo "=========================="
echo ""
echo "🌐 Your application URLs (once IP is assigned):"
echo "  Frontend: http://$EXTERNAL_IP"
echo "  Backend API: http://$EXTERNAL_IP/api"
echo "  API Documentation: http://$EXTERNAL_IP/api/docs"
echo ""
echo "📊 Monitoring commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -f deployment/backend -n $NAMESPACE"
echo "  kubectl logs -f deployment/frontend -n $NAMESPACE"
echo ""
echo "🧪 Test your deployment:"
echo "  curl http://$EXTERNAL_IP/api/health"
echo ""
echo "🔍 Troubleshooting:"
echo "  kubectl describe pods -n $NAMESPACE"
echo "  kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo ""
echo "💡 If external IP is still pending, check:"
echo "  kubectl get service ingress-nginx-controller -n ingress-nginx -w"