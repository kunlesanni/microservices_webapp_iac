# ================================
# scripts/setup_github_secrets.sh
# Sets up GitHub secrets for the project
# ================================

#!/bin/bash
set -e

echo "🔐 Setting up GitHub Secrets for Python React Cloud Native Project..."

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI is not installed. Please install it first."
    echo "Visit: https://cli.github.com/"
    echo ""
    echo "On Ubuntu/Debian:"
    echo "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
    echo "sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg"
    echo "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
    echo "sudo apt update && sudo apt install gh"
    exit 1
fi

# Check if logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo "❌ Not logged in to GitHub. Please run 'gh auth login' first."
    exit 1
fi

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    exit 1
fi

if ! az account show &> /dev/null; then
    echo "❌ Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Get current subscription details
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

echo "Current subscription: $SUBSCRIPTION_ID"
echo "Current tenant: $TENANT_ID"

# Create service principal for GitHub Actions
echo "👤 Creating service principal for GitHub Actions..."
SP_JSON=$(az ad sp create-for-rbac \
    --name "sp-github-actions-python-react-cloud" \
    --role "Contributor" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --sdk-auth)

# Extract values from service principal JSON
CLIENT_ID=$(echo $SP_JSON | jq -r '.clientId')
CLIENT_SECRET=$(echo $SP_JSON | jq -r '.clientSecret')

# Set GitHub secrets
echo "🔧 Setting GitHub secrets..."

gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID"
gh secret set AZURE_CLIENT_SECRET --body "$CLIENT_SECRET"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID"
gh secret set AZURE_CREDENTIALS --body "$SP_JSON"

# Set database password
echo ""
echo "🔑 Setting database password..."
read -s -p "Enter PostgreSQL admin password: " POSTGRES_PASSWORD
echo ""
gh secret set POSTGRES_ADMIN_PASSWORD --body "$POSTGRES_PASSWORD"

# Set Terraform backend secrets (if backend setup was run)
if [ -f "terraform/backend.tf" ]; then
    echo "🗄️ Setting Terraform backend secrets..."
    TERRAFORM_STATE_RG=$(grep 'resource_group_name' terraform/backend.tf | cut -d'"' -f4)
    TERRAFORM_STATE_SA=$(grep 'storage_account_name' terraform/backend.tf | cut -d'"' -f4)
    
    gh secret set TERRAFORM_STATE_RG --body "$TERRAFORM_STATE_RG"
    gh secret set TERRAFORM_STATE_SA --body "$TERRAFORM_STATE_SA"
    echo "✅ Terraform backend secrets set"
else
    echo "⚠️ No backend.tf found. Run './scripts/tf_backend_azure.sh' first if using remote state"
fi

echo ""
echo "✅ GitHub secrets setup complete!"
echo ""
echo "🔐 The following secrets have been set:"
echo "- AZURE_CLIENT_ID"
echo "- AZURE_CLIENT_SECRET" 
echo "- AZURE_SUBSCRIPTION_ID"
echo "- AZURE_TENANT_ID"
echo "- AZURE_CREDENTIALS"
echo "- POSTGRES_ADMIN_PASSWORD"
if [ -f "terraform/backend.tf" ]; then
    echo "- TERRAFORM_STATE_RG"
    echo "- TERRAFORM_STATE_SA"
fi
echo ""
echo "🚀 You can now push to your repository to trigger deployments!"
echo "🔍 Check your secrets: gh secret list"
