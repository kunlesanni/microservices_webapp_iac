# Cloud-Native Python FastAPI + React Application

## Project Overview

A modern, containerized full-stack application demonstrating **cloud-native architecture** patterns on Azure Kubernetes Service. This project showcases advanced infrastructure automation, microservices deployment, and DevSecOps practices with **container-first design**.

## Project Structure

```
python-react-cloud-native/
├── .github/
│   └── workflows/
│       └── infrastructure.yml           # Complete CI/CD pipeline
├── terraform/
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
├── k8s/
│   ├── namespace.yaml                   # Kubernetes namespace
│   ├── secrets.yaml                     # Application secrets
│   ├── backend/                         # Backend Kubernetes manifests
│   ├── frontend/                        # Frontend Kubernetes manifests
│   ├── ingress/                         # Ingress configuration
│   ├── monitoring/                      # Prometheus monitoring
│   └── policies/                        # Security policies
├── scripts/
│   ├── setup-infrastructure.sh         # Infrastructure bootstrap
│   ├── build-images.sh                 # Container build automation
│   └── deploy-apps.sh                   # Application deployment
└── README.md
```

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

## Quick Start Guide

### Prerequisites

1. **Azure CLI** logged in with appropriate permissions
2. **Terraform** >= 1.6.0
3. **kubectl** for Kubernetes management
4. **Docker** for local development
5. **GitHub repository** with Actions enabled

### Step 1: Infrastructure Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/python-react-cloud-native
cd python-react-cloud-native

# Setup Azure backend for Terraform state
./scripts/setup-infrastructure.sh

# Configure GitHub secrets
./scripts/setup-github-secrets.sh
```

### Step 2: Deploy Infrastructure

**Option A: GitHub Actions (Recommended)**

```bash
# Push to main branch for automatic deployment
git add .
git commit -m "Initial infrastructure deployment"
git push origin main
```

**Option B: Manual Deployment**

```bash
cd terraform

# Initialize and plan
terraform init
terraform plan -var="environment=dev"

# Deploy infrastructure
terraform apply -var="environment=dev"
```

### Step 3: Build and Deploy Applications

```bash
# Manual build and deployment
./scripts/build-images.sh
./scripts/deploy-apps.sh

# Or trigger via GitHub Actions workflow
gh workflow run "Cloud-Native Infrastructure & Applications" \
  --field environment=dev \
  --field action=deploy-apps
```

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

## Infrastructure Deep Dive

### **Azure Kubernetes Service Configuration**

```hcl
# Multi-zone, auto-scaling AKS cluster
resource "azurerm_kubernetes_cluster" "main" {
  kubernetes_version = "1.28.5"
  
  default_node_pool {
    enable_auto_scaling = true
    min_count          = 1
    max_count          = 10
    availability_zones = ["1", "2", "3"]
  }
  
  # Integrated Application Gateway Ingress
  ingress_application_gateway {
    enabled = true
  }
  
  # Container Insights monitoring
  oms_agent {
    enabled = true
  }
}
```

### **Database & Caching Architecture**

- **PostgreSQL Flexible Server** with zone-redundant high availability
- **Redis Cache** for session storage and API response caching
- **Private networking** with VNet integration
- **Automated backups** with 35-day retention

### **Security Implementation**

- **Network Security Groups** with least-privilege access
- **Pod Security Policies** enforcing security standards
- **Key Vault** for secrets management
- **Private endpoints** for database connectivity

## CI/CD Pipeline Features

### 🔄 **Automated Workflows**

1. **Infrastructure Plan** - Terraform planning on PRs
2. **Security Scanning** - Checkov, TFSec, Kubesec analysis
3. **Container Building** - Multi-arch images with vulnerability scanning
4. **Application Deployment** - Rolling updates with health checks
5. **Integration Testing** - Automated API and UI testing

### 📋 **GitHub Actions Workflow**

```yaml
# Parallel execution for efficiency
- Infrastructure provisioning
- Container image building (backend + frontend)
- Security scanning (infrastructure + containers)
- Kubernetes deployment with health validation
- Integration testing and monitoring setup
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

## Monitoring & Observability

### **Built-in Monitoring Stack**

- **Azure Monitor** - Infrastructure and application metrics
- **Application Insights** - Distributed tracing and performance
- **Container Insights** - Kubernetes cluster monitoring
- **Log Analytics** - Centralized log aggregation

### **Health Checks & Alerting**

- Kubernetes liveness and readiness probes
- Application Gateway health probes
- Automated scaling based on CPU/memory metrics
- Custom alerts for application-specific metrics

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

## Local Development

### **Docker Compose Setup**

```bash
# Start local development environment
docker-compose up -d

# Access applications
# Frontend: http://localhost:3000
# Backend API: http://localhost:8000
# API Docs: http://localhost:8000/docs
```

### **Development Workflow**

1. Make code changes
2. Test locally with Docker Compose
3. Create pull request for review
4. Automated testing and security scanning
5. Deploy to dev environment after merge

## Troubleshooting Guide

### **Common Issues**

**AKS Deployment Issues**:

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# View logs
kubectl logs -f deployment/backend -n pyreact-dev
```

**Application Gateway Issues**:

```bash
# Check ingress status
kubectl get ingress -n pyreact-dev
kubectl describe ingress main-ingress -n pyreact-dev
```

**Database Connectivity**:

```bash
# Test database connection from pod
kubectl exec -it deployment/backend -n pyreact-dev -- \
  python -c "from main import engine; print(engine.execute('SELECT 1').scalar())"
```

## Extending the Architecture

### **Additional Features to Add**

- **Service Mesh** (Istio) for advanced traffic management
- **GitOps** with ArgoCD for declarative deployments
- **Multi-region** deployment for high availability
- **API Gateway** (Azure API Management) for enterprise features
- **Event-driven architecture** with Azure Service Bus

### **Scaling Considerations**

- Horizontal Pod Autoscaler for application scaling
- Cluster Autoscaler for node scaling
- Database read replicas for read-heavy workloads
- CDN integration for static asset optimization

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request
5. Ensure all security scans pass

This project demonstrates production-ready cloud-native architecture patterns and serves as a foundation for building scalable, secure applications on Azure.
