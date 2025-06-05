#!/bin/bash
# ================================
# scripts/setup_azure_backend.sh
# Sets up Azure backend for Terraform state management
# ================================

set -e

# Configuration
RESOURCE_GROUP_NAME="rg-terraform-state"
STORAGE_ACCOUNT_NAME="tfstate$(openssl rand -hex 4)"
CONTAINER_NAME="tfstate"
LOCATION="East US"

echo "🚀 Setting up Azure backend for Terraform state..."

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo "❌ Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
SUBSCRIPTION_NAME=$(az account show --query name --output tsv)

echo "📋 Current subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Create resource group
echo "📦 Creating resource group: $RESOURCE_GROUP_NAME"
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --output table

# Create storage account
echo "💾 Creating storage account: $STORAGE_ACCOUNT_NAME"
az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --encryption-services blob \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --output table

# Create storage container
echo "📁 Creating storage container: $CONTAINER_NAME"
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --auth-mode login \
    --output table

# Create backend configuration file
echo "📝 Creating backend configuration file..."
cat > terraform/backend.tf << EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP_NAME"
    storage_account_name = "$STORAGE_ACCOUNT_NAME"
    container_name       = "$CONTAINER_NAME"
    key                  = "dev.terraform.tfstate"
  }
}
EOF

# Output configuration for GitHub Secrets and manual use
echo ""
echo "✅ Azure backend setup complete!"
echo ""
echo "📋 Add these values to your GitHub Secrets:"
echo "TERRAFORM_STATE_RG=$RESOURCE_GROUP_NAME"
echo "TERRAFORM_STATE_SA=$STORAGE_ACCOUNT_NAME"
echo ""
echo "🔧 Backend configuration saved to terraform/backend.tf"
echo ""
echo "🚀 Next steps:"
echo "1. Run './scripts/setup_github_secrets.sh' to configure GitHub secrets"
echo "2. Run 'cd terraform && terraform init' to initialize with remote state"
echo "3. Run 'terraform plan' to see what will be created"
echo ""
