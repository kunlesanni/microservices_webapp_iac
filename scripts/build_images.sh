
# ================================
# scripts/build_images.sh
# Build and push container images to ACR
# ================================

#!/bin/bash
set -e

echo "🐳 Building and pushing container images..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo "❌ Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Get ACR name from Terraform output or environment variable
if [ -d "terraform" ]; then
    echo "📋 Getting ACR name from Terraform..."
    cd terraform
    ACR_NAME=$(terraform output -raw container_registry_name 2>/dev/null || echo "")
    cd ..
fi

# If not found, prompt user
if [ -z "$ACR_NAME" ]; then
    echo "🔧 ACR name not found in Terraform output."
    read -p "Enter your Azure Container Registry name: " ACR_NAME
fi

if [ -z "$ACR_NAME" ]; then
    echo "❌ ACR name is required. Exiting."
    exit 1
fi

echo "🏗️ Using ACR: $ACR_NAME"

# Set image tag (use Git commit hash if available, otherwise timestamp)
if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    IMAGE_TAG=$(git rev-parse --short HEAD)
    echo "📝 Using Git commit hash as tag: $IMAGE_TAG"
else
    IMAGE_TAG=$(date +%Y%m%d%H%M%S)
    echo "📝 Using timestamp as tag: $IMAGE_TAG"
fi

# Login to ACR
echo "🔐 Logging in to Azure Container Registry..."
az acr login --name $ACR_NAME

# Build and push backend image
echo "🏗️ Building backend image..."
if [ ! -d "src/backend" ]; then
    echo "❌ Backend source directory not found at src/backend"
    exit 1
fi

cd src/backend
echo "Building $ACR_NAME.azurecr.io/backend:$IMAGE_TAG"
az acr build --registry $ACR_NAME \
  --image backend:$IMAGE_TAG \
  --image backend:latest \
  --file Dockerfile \
  .

echo "✅ Backend image built and pushed successfully!"
cd ../..

# Build and push frontend image
echo "🏗️ Building frontend image..."
if [ ! -d "src/frontend" ]; then
    echo "❌ Frontend source directory not found at src/frontend"
    exit 1
fi

cd src/frontend
echo "Building $ACR_NAME.azurecr.io/frontend:$IMAGE_TAG"
az acr build --registry $ACR_NAME \
  --image frontend:$IMAGE_TAG \
  --image frontend:latest \
  --file Dockerfile \
  .

echo "✅ Frontend image built and pushed successfully!"
cd ../..

# List images in ACR
echo "📋 Images in registry:"
az acr repository list --name $ACR_NAME --output table

echo ""
echo "✅ All images built and pushed successfully!"
echo ""
echo "📋 Image details:"
echo "  Backend: $ACR_NAME.azurecr.io/backend:$IMAGE_TAG"
echo "  Frontend: $ACR_NAME.azurecr.io/frontend:$IMAGE_TAG"
echo ""
echo "🚀 Next steps:"
echo "1. Update Kubernetes manifests with new image tags"
echo "2. Deploy to Kubernetes: kubectl apply -f k8s/"
echo "3. Or run: ./scripts/deploy_apps.sh"

# Save image tag for use by other scripts
echo $IMAGE_TAG > .last-image-tag
echo "💾 Image tag saved to .last-image-tag for reference"
