#!/bin/bash
set -e

echo "🚀 GitHub Actions Setup Guide"
echo "============================="
echo ""
echo "This script will help you set up the required secrets and configurations"
echo "for GitHub Actions to work with your Azure infrastructure."
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI is not installed. Please install it first."
    echo "Visit: https://cli.github.com/"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo "❌ Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ Not logged in to GitHub. Please run 'gh auth login' first."
    exit 1
fi

echo "✅ Prerequisites check passed!"
echo ""

# Get Azure subscription info
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)
SUBSCRIPTION_NAME=$(az account show --query name --output tsv)

echo "📋 Azure Subscription Details:"
echo "  Name: $SUBSCRIPTION_NAME"
echo "  ID: $SUBSCRIPTION_ID"
echo "  Tenant: $TENANT_ID"
echo ""

# Confirm subscription
read -p "Is this the correct subscription? (y/N): " confirm_sub
if [[ ! "$confirm_sub" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Please switch to the correct subscription with 'az account set --subscription <subscription-id>'"
    exit 1
fi

# Setup Terraform backend first
echo "🗄️ Setting up Terraform backend..."
if [ ! -f "terraform/backend.tf" ]; then
    echo "Setting up Azure backend for Terraform state..."
    ./scripts/tf_backend_azure.sh
else
    echo "✅ Terraform backend already configured"
fi

# Create service principal
echo ""
echo "👤 Creating service principal for GitHub Actions..."
SP_NAME="sp-github-actions-$(basename $(pwd))-$(date +%s)"

SP_JSON=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role "Contributor" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --sdk-auth)

if [ $? -ne 0 ]; then
    echo "❌ Failed to create service principal"
    exit 1
fi

# Extract values
CLIENT_ID=$(echo $SP_JSON | jq -r '.clientId')
CLIENT_SECRET=$(echo $SP_JSON | jq -r '.clientSecret')

echo "✅ Service principal created: $SP_NAME"
echo ""

# Set GitHub secrets
echo "🔐 Setting GitHub secrets..."

gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID"
gh secret set AZURE_CLIENT_SECRET --body "$CLIENT_SECRET"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID"
gh secret set AZURE_CREDENTIALS --body "$SP_JSON"

# Get Terraform backend info
if [ -f "terraform/backend.tf" ]; then
    TERRAFORM_STATE_RG=$(grep 'resource_group_name' terraform/backend.tf | cut -d'"' -f4)
    TERRAFORM_STATE_SA=$(grep 'storage_account_name' terraform/backend.tf | cut -d'"' -f4)
    
    gh secret set TERRAFORM_STATE_RG --body "$TERRAFORM_STATE_RG"
    gh secret set TERRAFORM_STATE_SA --body "$TERRAFORM_STATE_SA"
fi

# Set database password
echo ""
echo "🔑 Setting database password..."
read -s -p "Enter PostgreSQL admin password (will be stored as GitHub secret): " POSTGRES_PASSWORD
echo ""

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "❌ Password cannot be empty"
    exit 1
fi

gh secret set POSTGRES_ADMIN_PASSWORD --body "$POSTGRES_PASSWORD"

echo ""
echo "✅ GitHub secrets setup complete!"
echo ""
echo "🔐 The following secrets have been set:"
echo "  - AZURE_CLIENT_ID"
echo "  - AZURE_CLIENT_SECRET"
echo "  - AZURE_SUBSCRIPTION_ID"
echo "  - AZURE_TENANT_ID"
echo "  - AZURE_CREDENTIALS"
echo "  - POSTGRES_ADMIN_PASSWORD"
echo "  - TERRAFORM_STATE_RG"
echo "  - TERRAFORM_STATE_SA"
echo ""
echo "🚀 You can now push to your repository to trigger deployments!"
echo ""
echo "📋 Next steps:"
echo "1. Push your code to GitHub"
echo "2. Go to Actions tab in your GitHub repository"
echo "3. Manually trigger the workflow or push to main branch"
echo "4. Monitor the deployment progress"
echo ""
echo "🔍 Verify secrets: gh secret list"