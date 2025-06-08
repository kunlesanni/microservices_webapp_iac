# GitHub Actions Setup Guide

This guide will help you set up GitHub Actions for automated deployment of your cloud-native application.

## Prerequisites

Before setting up GitHub Actions, ensure you have:

1. **Azure CLI** installed and logged in (`az login`)
2. **GitHub CLI** installed and logged in (`gh auth login`)
3. **Azure subscription** with appropriate permissions
4. **GitHub repository** with Actions enabled

## Quick Setup

Run the automated setup script:

```bash
./scripts/github_setup.sh
```

This script will:
- Verify prerequisites
- Set up Terraform backend storage
- Create Azure service principal
- Configure GitHub secrets
- Set database password

## Manual Setup (Alternative)

If you prefer manual setup:

### 1. Create Azure Service Principal

```bash
az ad sp create-for-rbac \
  --name "sp-github-actions-your-app" \
  --role "Contributor" \
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID" \
  --sdk-auth
```

### 2. Set GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AZURE_CLIENT_ID` | Service principal client ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_CLIENT_SECRET` | Service principal secret | `your-secret-value` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID` | Azure tenant ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_CREDENTIALS` | Full service principal JSON | `{"clientId":"...","clientSecret":"..."}` |
| `POSTGRES_ADMIN_PASSWORD` | Database password | `YourSecurePassword123!` |
| `TERRAFORM_STATE_RG` | Terraform state resource group | `rg-terraform-state` |
| `TERRAFORM_STATE_SA` | Terraform state storage account | `tfstateabc123` |

## Workflow Triggers

The GitHub Actions workflow can be triggered in several ways:

### 1. Automatic Triggers

- **Push to main branch**: Automatically deploys to production
- **Push to develop branch**: Automatically deploys to development
- **Pull Request**: Runs infrastructure plan and security scans

### 2. Manual Triggers

Go to Actions tab → "Cloud-Native Infrastructure & Applications" → "Run workflow"

**Manual trigger options:**

| Input | Options | Description |
|-------|---------|-------------|
| Environment | `dev`, `staging`, `prod` | Target environment |
| Action | `plan`, `apply`, `destroy`, `deploy-apps` | Action to perform |

### Example Manual Triggers:

**Deploy to Development:**
- Environment: `dev`
- Action: `apply`

**Deploy Applications Only:**
- Environment: `dev` 
- Action: `deploy-apps`

**Destroy Infrastructure:**
- Environment: `dev`
- Action: `destroy`

## Workflow Stages

The complete workflow includes:

1. **Infrastructure Plan** (on PRs)
   - Terraform format check
   - Terraform plan
   - Security scanning

2. **Infrastructure Deploy** (on main/manual)
   - Terraform apply
   - Output infrastructure details

3. **Container Build** (parallel)
   - Build backend image
   - Build frontend image
   - Push to Azure Container Registry

4. **Application Deploy**
   - Install NGINX Ingress
   - Install Cert-Manager
   - Deploy applications
   - Run health checks

5. **Security Scanning** (parallel)
   - Terraform security scan (Checkov, TFSec)
   - Kubernetes manifest scan (Kubesec)
   - Container vulnerability scan

## Monitoring Deployments

### GitHub Actions UI
- Go to Actions tab in your repository
- Click on the running workflow
- Monitor each job's progress

### Azure Resources
- Check Azure Portal for created resources
- Monitor AKS cluster in Azure Portal
- View Application Gateway logs

### Application Health
- Frontend: `http://<external-ip>`
- Backend API: `http://<external-ip>/api`
- API Docs: `http://<external-ip>/api/docs`

## Troubleshooting

### Common Issues

**1. Service Principal Permissions**
```bash
# Grant additional permissions if needed
az role assignment create \
  --assignee <service-principal-id> \
  --role "User Access Administrator" \
  --scope "/subscriptions/<subscription-id>"
```

**2. Terraform State Issues**
```bash
# Check backend configuration
cat terraform/backend.tf

# Verify storage account access
az storage account show --name <storage-account> --resource-group <rg>
```

**3. Kubernetes Deployment Issues**
```bash
# Check cluster access
az aks get-credentials --resource-group <rg> --name <cluster>
kubectl get pods --all-namespaces

# Check ingress
kubectl get ingress -n <namespace>
```

### Debug Commands

**Check GitHub Secrets:**
```bash
gh secret list
```

**Validate YAML Manifests:**
```bash
./scripts/utils/check_yaml.sh
```

**Test Local Deployment:**
```bash
./scripts/deploy_apps.sh
```

## Security Considerations

1. **Secrets Management**: All sensitive data is stored in GitHub secrets
2. **Service Principal**: Limited to Contributor role on specific subscription
3. **Network Security**: Private networking with network policies
4. **Container Security**: Non-root containers with security scanning
5. **Infrastructure Security**: WAF, private endpoints, and encryption

## Cost Management

- **Development**: ~$200-400/month
- **Production**: ~$800-1500/month

Monitor costs in Azure Cost Management and set up budget alerts.

## Next Steps

After successful setup:

1. **Test the workflow** with a small change
2. **Set up monitoring** and alerting
3. **Configure custom domains** and SSL certificates
4. **Implement backup strategies**
5. **Set up additional environments** (staging, prod)

For more details, see the main [README.md](../README.md).