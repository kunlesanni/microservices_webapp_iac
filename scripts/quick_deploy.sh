# ================================
# scripts/quick_deploy.sh
# One-command deployment script
# ================================

#!/bin/bash
set -e

echo "🚀 Quick Deploy - Python React Cloud Native Application"
echo "======================================================="
echo ""

# Check if this is first run
if [ ! -f "terraform.tfvars" ]; then
    echo "🎯 First-time setup detected!"
    echo ""
    
    # Get basic configuration
    read -p "Enter environment name (dev/staging/prod) [dev]: " ENVIRONMENT
    ENVIRONMENT=${ENVIRONMENT:-dev}
    read -p "Enter Azure region [uksouth]: " LOCATION
    LOCATION=${LOCATION:-"uksouth"}

    read -p "Enter project name [pyreact]: " PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-pyreact}
    
    echo ""
    echo "🔐 Database configuration:"
    read -p "Enter PostgreSQL admin username [pgadmin]: " PG_USERNAME
    PG_USERNAME=${PG_USERNAME:-pgadmin}
    
    read -s -p "Enter PostgreSQL admin password: " PG_PASSWORD
    echo ""
    
    if [ -z "$PG_PASSWORD" ]; then
        echo "❌ Password cannot be empty"
        exit 1
    fi
    
    # Create terraform.tfvars
    echo "📝 Creating terraform.tfvars..."
    cat > terraform.tfvars << EOF
environment = "$ENVIRONMENT"
location = "$LOCATION"
project_name = "$PROJECT_NAME"
postgres_admin_username = "$PG_USERNAME"
postgres_admin_password = "$PG_PASSWORD"
aks_admin_group_object_ids = []
EOF

    echo "✅ Configuration saved to terraform.tfvars"
    echo ""
fi

# Phase 1: Infrastructure
echo "=========================================="
echo "🏗️  Phase 1: Deploying Infrastructure..."

if [ ! -d ".terraform" ]; then
    echo "🔧 Initializing Terraform..."
    terraform init
fi

echo "📋 Planning infrastructure..."
terraform plan -out=tfplan

echo "🚀 Deploying infrastructure (this may take 15-20 minutes)..."
terraform apply tfplan

# Get outputs
ACR_NAME=$(terraform output -raw container_registry_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AKS_CLUSTER=$(terraform output -raw aks_cluster_name)

echo "✅ Infrastructure deployed!"
echo "  ACR: $ACR_NAME"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  AKS Cluster: $AKS_CLUSTER"


# Phase 2: Get cluster credentials
echo "==========================================="
echo ""
echo "🔧 Phase 2: Configuring Kubernetes access..."
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --overwrite-existing

kubectl cluster-info
echo "✅ Kubernetes access configured!"

# Phase 3: Build and push images
echo "==========================================="
echo ""
echo "🐳 Phase 3: Building and pushing container images..."
export ACR_NAME=$ACR_NAME
./scripts/build_images.sh

# Phase 4: Deploy applications
echo ""
echo "🚀 Phase 4: Deploying applications to Kubernetes..."
export ENVIRONMENT=$(grep 'environment' terraform.tfvars | cut -d'"' -f2)
export PROJECT_NAME=$(grep 'project_name' terraform.tfvars | cut -d'"' -f2)
./scripts/deploy_apps.sh

echo ""
echo "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉"
echo "=========================================="
echo ""

# Get external IP
EXTERNAL_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending...")

echo "🌐 Your application is now available at:"
echo "  Frontend: http://$EXTERNAL_IP"
echo "  Backend API: http://$EXTERNAL_IP/api"
echo "  API Documentation: http://$EXTERNAL_IP/api/docs"
echo ""
echo "📊 Monitoring commands:"
echo "  kubectl get pods -n $PROJECT_NAME-$ENVIRONMENT"
echo "  kubectl logs -f deployment/backend -n $PROJECT_NAME-$ENVIRONMENT"
echo "  kubectl logs -f deployment/frontend -n $PROJECT_NAME-$ENVIRONMENT"
echo ""
echo "🧪 Test your deployment:"
echo "  curl http://$EXTERNAL_IP/api/health"
echo ""
echo "🛑 To clean up everything:"
echo "  ./scripts/cleanup.sh"
echo ""
echo "Thank you for using the Python React Cloud Native template! 🚀"
