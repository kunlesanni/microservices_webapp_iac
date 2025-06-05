
# ================================
# scripts/cleanup.sh
# Cleanup script to remove all resources
# ================================

#!/bin/bash
set -e

echo "🧹 Cleanup Script - This will destroy ALL infrastructure!"
echo "⚠️  This action cannot be undone!"
echo ""

# Show what will be deleted
echo "📋 This will delete:"
echo "  - Kubernetes applications and ingress"
echo "  - Azure infrastructure (AKS, ACR, databases, etc.)"
echo "  - Resource groups"
echo "  - Terraform state (optional)"
echo ""

read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cleanup cancelled."
    exit 1
fi

# Get environment to clean up
echo ""
read -p "Enter environment to cleanup (dev/staging/prod): " environment

if [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
    echo "❌ Invalid environment. Must be dev, staging, or prod."
    exit 1
fi

PROJECT_NAME=${PROJECT_NAME:-"pyreact"}
NAMESPACE="${PROJECT_NAME}-${environment}"

echo ""
echo "🗑️  Cleaning up environment: $environment"
echo "📦 Namespace: $NAMESPACE"
echo ""

# Step 1: Clean up Kubernetes resources
echo "🔍 Checking Kubernetes connectivity..."
if kubectl cluster-info &> /dev/null; then
    echo "✅ Connected to Kubernetes cluster"
    
    # Delete namespace (this removes all apps)
    echo "🗑️  Deleting Kubernetes namespace: $NAMESPACE"
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    # Ask about ingress controller
    read -p "Delete NGINX Ingress Controller? (y/N): " delete_ingress
    if [[ "$delete_ingress" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "🗑️  Deleting NGINX Ingress Controller..."
        helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || echo "⚠️ NGINX Ingress Controller not found"
        kubectl delete namespace ingress-nginx --ignore-not-found=true
        echo "✅ NGINX Ingress Controller deleted"
    fi
    
    # Ask about cert-manager
    read -p "Delete Cert-Manager? (y/N): " delete_certmanager
    if [[ "$delete_certmanager" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "🗑️  Deleting Cert-Manager..."
        helm uninstall cert-manager -n cert-manager 2>/dev/null || echo "⚠️ Cert-Manager not found"
        kubectl delete namespace cert-manager --ignore-not-found=true
        echo "✅ Cert-Manager deleted"
    fi
    
    echo "✅ Kubernetes cleanup completed"
else
    echo "⚠️ Could not connect to Kubernetes cluster. Skipping K8s cleanup."
fi

# Step 2: Clean up Azure infrastructure with Terraform
echo ""
echo "🔍 Checking for Terraform infrastructure..."

if [ -d "terraform" ]; then
    cd terraform
    
    # Check if Terraform is initialized
    if [ -d ".terraform" ]; then
        echo "✅ Terraform found and initialized"
        
        # Get current infrastructure
        echo "📋 Current infrastructure:"
        terraform show 2>/dev/null | head -20 || echo "No infrastructure found"
        
        echo ""
        read -p "Destroy Azure infrastructure with Terraform? (type 'yes' to confirm): " confirm_terraform
        
        if [ "$confirm_terraform" = "yes" ]; then
            echo "💥 Destroying Azure infrastructure..."
            
            # Try to destroy with terraform
            if terraform destroy -auto-approve -var="environment=$environment"; then
                echo "✅ Terraform destroy completed successfully"
            else
                echo "❌ Terraform destroy failed. You may need to clean up resources manually."
                echo "🔍 Check Azure portal for remaining resources."
            fi
        else
            echo "⚠️ Skipping Terraform destroy"
        fi
    else
        echo "⚠️ Terraform not initialized. Run 'terraform init' first if you want to destroy infrastructure."
    fi
    
    cd ..
else
    echo "⚠️ No terraform directory found. Skipping Terraform cleanup."
fi

# Step 3: Clean up local development environment
echo ""
read -p "Clean up local development environment? (y/N): " cleanup_local
if [[ "$cleanup_local" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "🧹 Cleaning up local development environment..."
    
    if [ -f "docker-compose.yml" ]; then
        echo "🐳 Stopping and removing Docker containers..."
        docker-compose down -v 2>/dev/null || echo "⚠️ Docker Compose not running"
        
        # Remove images
        read -p "Remove Docker images? (y/N): " remove_images
        if [[ "$remove_images" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "🗑️  Removing Docker images..."
            docker images | grep pyreact | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || echo "⚠️ No pyreact images found"
        fi
    fi
    
    # Clean up generated files
    echo "📁 Cleaning up generated files..."
    rm -f .env.local
    rm -f .last-image-tag
    rm -rf .terraform 2>/dev/null || true
    rm -f terraform.tfstate* 2>/dev/null || true
    rm -f *.log
    
    echo "✅ Local cleanup completed"
fi

# Step 4: Optional - Clean up Terraform backend
echo ""
read -p "Clean up Terraform backend storage? (y/N): " cleanup_backend
if [[ "$cleanup_backend" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "⚠️  This will delete the Terraform state storage account!"
    read -p "Are you absolutely sure? (type 'DELETE' to confirm): " confirm_delete_backend
    
    if [ "$confirm_delete_backend" = "DELETE" ]; then
        if [ -f "terraform/backend.tf" ]; then
            # Extract backend config
            TERRAFORM_STATE_RG=$(grep 'resource_group_name' terraform/backend.tf | cut -d'"' -f4)
            
            if [ ! -z "$TERRAFORM_STATE_RG" ]; then
                echo "🗑️  Deleting Terraform backend resource group: $TERRAFORM_STATE_RG"
                az group delete --name "$TERRAFORM_STATE_RG" --yes --no-wait 2>/dev/null || echo "⚠️ Resource group not found or already deleted"
                echo "✅ Backend cleanup initiated (runs in background)"
            else
                echo "⚠️ Could not extract backend resource group from backend.tf"
            fi
        else
            echo "⚠️ No backend.tf found"
        fi
    else
        echo "⚠️ Backend cleanup cancelled"
    fi
fi

echo ""
echo "✅ Cleanup process completed!"
echo ""
echo "📋 Summary of actions taken:"
echo "  - Deleted Kubernetes namespace: $NAMESPACE"
[ "$delete_ingress" = "y" ] && echo "  - Deleted NGINX Ingress Controller"
[ "$delete_certmanager" = "y" ] && echo "  - Deleted Cert-Manager"
[ "$confirm_terraform" = "yes" ] && echo "  - Destroyed Azure infrastructure"
[ "$cleanup_local" = "y" ] && echo "  - Cleaned up local development environment"
[ "$confirm_delete_backend" = "DELETE" ] && echo "  - Initiated backend storage cleanup"
echo ""
echo "🔍 Manual verification recommended:"
echo "  - Check Azure Portal for any remaining resources"
echo "  - Verify resource groups are deleted"
echo "  - Check Docker images: docker images"
echo "  - Check Kubernetes contexts: kubectl config get-contexts"
echo ""
echo "Thank you for using the Python React Cloud Native template! 🚀"

