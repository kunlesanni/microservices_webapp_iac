# Cloud-Native Python FastAPI + React Application

## Project Overview

A modern, containerized full-stack application demonstrating **cloud-native architecture** patterns on Azure Kubernetes Service. This project showcases advanced infrastructure automation, microservices deployment, and DevSecOps practices with **container-first design**.

## Project Structure

```
python-react-cloud-native/
├── .github/
│   └── workflows/
│       └── infrastructure.yml           # Complete CI/CD pipeline
├── terraform/                           # Infrastructure as Code
│   ├── main.tf                          # AKS, ACR, PostgreSQL, Redis infrastructure
│   ├── variables.tf                     # Parameterized configuration
│   ├── outputs.tf                       # Infrastructure outputs
│   └── backend.tf                       # Remote state configuration
├── src/
│   ├── backend/
│   │   ├── main.py                      # FastAPI application
│   │   ├── requirements.txt             # Python dependencies
│   │   └── Dockerfile                   # Multi-stage container build
│   └── frontend/
│       ├── src/                         # React application
│       ├── package.json                 # Node.js dependencies
│       ├── Dockerfile                   # Nginx-based container
│       └── nginx.conf                   # Production web server config
├── k8s/                                 # Kubernetes manifests
│   ├── namespace.yaml                   # Kubernetes namespace
│   ├── secrets.yaml                     # Application secrets
│   ├── backend/                         # Backend Kubernetes manifests
│   ├── frontend/                        # Frontend Kubernetes manifests
│   ├── ingress/                         # Ingress configuration
│   ├── monitoring/                      # Prometheus monitoring
│   └── policies/                        # Security policies
├── scripts/                             # Automation scripts
│   ├── setup_infrastructure.sh         # Infrastructure bootstrap
│   ├── build_images.sh                 # Container build automation
│   ├── deploy_apps.sh                   # Application deployment
│   ├── github_setup.sh                 # GitHub Actions setup
│   └── utils/
│       └── check_yaml.sh               # YAML validation utility
├── docs/
│   └── GITHUB_ACTIONS_SETUP.md         # GitHub Actions setup guide
└── README.md
```

## Quick Start

### Option 1: GitHub Actions (Recommended)

1. **Setup GitHub Actions:**
   ```bash
   ./scripts/github_setup.sh
   ```

2. **Push to GitHub:**
   ```bash
   git add .
   git commit -m "Initial deployment"
   git push origin main
   ```

3. **Monitor deployment** in GitHub Actions tab

### Option 2: Local Deployment

1. **Setup infrastructure:**
   ```bash
   ./scripts/setup_infrastructure.sh
   ```

2. **Quick deploy everything:**
   ```bash
   ./scripts/quick_deploy.sh
   ```

## GitHub Actions Setup

### Prerequisites

Before pushing to GitHub, you need:

1. **Azure CLI** logged in (`az login`)
2. **GitHub CLI** logged in (`gh auth login`)
3. **Azure subscription** with appropriate permissions

### Automated Setup

Run the setup script to configure everything:

```bash
./scripts/github_setup.sh
```

This will:
- Create Azure service principal
- Set up Terraform backend storage
- Configure GitHub secrets
- Set database password

### Manual Workflow Triggers

Go to GitHub Actions → "Cloud-Native Infrastructure & Applications" → "Run workflow"

**Available options:**
- **Environment**: `dev`, `staging`, `prod`
- **Action**: `plan`, `apply`, `destroy`, `deploy-apps`

**Examples:**
- Deploy to dev: Environment=`dev`, Action=`apply`
- Deploy apps only: Environment=`dev`, Action=`deploy-apps`
- Destroy infrastructure: Environment=`dev`, Action=`destroy`

### Required GitHub Secrets

The setup script will create these automatically:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Service principal client ID |
| `AZURE_CLIENT_SECRET` | Service principal secret |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_CREDENTIALS` | Full service principal JSON |
| `POSTGRES_ADMIN_PASSWORD` | Database password |
| `TERRAFORM_STATE_RG` | Terraform state resource group |
| `TERRAFORM_STATE_SA` | Terraform state storage account |

## Architecture Highlights

### 🏗️ **Cloud-Native Infrastructure**

- **Azure Kubernetes Service (AKS)** with auto-scaling node pools
- **Azure Container Registry** with vulnerability scanning
- **Application Gateway** with Web Application Firewall
- **PostgreSQL Flexible Server** with high availability
- **Redis Cache** for session management and caching

### 🔒 **Enterprise Security**

- **Network policies** for micro-segmentation
- **Pod security policies** with non-root containers
- **Private networking** with service endpoints
- **Key Vault integration** for secrets management
- **RBAC** with Azure AD integration

### 📊 **Observability & Monitoring**

- **Azure Monitor** with Container Insights
- **Application Insights** for distributed tracing
- **Prometheus** metrics collection
- **Log Analytics** for centralized logging

### ⚡ **Modern Development Practices**

- **Multi-stage Docker builds** for optimized images
- **GitOps deployment** with GitHub Actions
- **Infrastructure as Code** with Terraform
- **Automated security scanning** with multiple tools

## Application Features

### 🐍 **FastAPI Backend**

- **RESTful API** with automatic OpenAPI documentation
- **PostgreSQL integration** with SQLAlchemy ORM
- **Redis caching** for performance optimization
- **Health checks** for Kubernetes probes
- **Structured logging** with request tracing

### ⚛️ **React Frontend**

- **Modern React 18** with functional components
- **Tailwind CSS** for responsive design
- **React Router** for client-side routing
- **Heroicons** for consistent iconography
- **Production-optimized** Nginx serving

### 🎯 **API Endpoints**

```bash
GET  /api/tasks           # List all tasks
POST /api/tasks           # Create new task
GET  /api/tasks/{id}      # Get specific task
PUT  /api/tasks/{id}      # Update task
DELETE /api/tasks/{id}    # Delete task
GET  /api/stats           # Get task statistics
GET  /health              # Health check endpoint
```

## Local Development

### **Docker Compose Setup**

```bash
# Start local development environment
./scripts/local_development.sh

# Or manually
docker-compose up -d

# Access applications
# Frontend: http://localhost:3000
# Backend API: http://localhost:8000
# API Docs: http://localhost:8000/docs
```

## Troubleshooting

### **YAML Validation**
```bash
./scripts/utils/check_yaml.sh
```

### **Common Issues**

**AKS Deployment Issues:**
```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl logs -f deployment/backend -n pyreact-dev
```

**Application Gateway Issues:**
```bash
kubectl get ingress -n pyreact-dev
kubectl describe ingress main-ingress -n pyreact-dev
```

**Database Connectivity:**
```bash
kubectl exec -it deployment/backend -n pyreact-dev -- \
  python -c "from main import engine; print(engine.execute('SELECT 1').scalar())"
```

## Cost Optimization

**Development Environment**: ~$200-400/month
- AKS with 2 Standard_D2s_v3 nodes
- PostgreSQL GP_Standard_D2s_v3
- Standard Redis cache
- Application Gateway v2

**Production Environment**: ~$800-1500/month
- Multi-zone AKS with auto-scaling
- High-availability PostgreSQL
- Premium Redis with clustering
- WAF-enabled Application Gateway

## Security Best Practices

### **Container Security**
- Non-root user execution
- Read-only root filesystems where possible
- Minimal base images (Alpine Linux)
- Regular security scanning in CI/CD

### **Network Security**
- Network policies for pod-to-pod communication
- Private endpoints for Azure services
- WAF protection at ingress layer
- Encrypted communication (TLS everywhere)

### **Identity & Access**
- Azure AD integration for cluster access
- Managed identities for Azure service authentication
- RBAC with principle of least privilege
- Secrets stored in Azure Key Vault

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request
5. Ensure all security scans pass

## Documentation

- [GitHub Actions Setup Guide](docs/GITHUB_ACTIONS_SETUP.md)
- [Architecture Deep Dive](docs/ARCHITECTURE.md) *(coming soon)*
- [Security Guide](docs/SECURITY.md) *(coming soon)*

This project demonstrates production-ready cloud-native architecture patterns and serves as a foundation for building scalable, secure applications on Azure.