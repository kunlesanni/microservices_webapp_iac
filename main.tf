# ================================
# main.tf - Container-First Cloud Infrastructure
# ================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.31"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "01851644-3134-4895-97d2-2dfadc5f91e3"
}

# Data sources
data "azurerm_client_config" "current" {}

# Local variables for configuration
locals {
  environment  = var.environment
  location     = var.location
  project_name = var.project_name

  # Naming convention
  resource_group_name = "rg-${local.project_name}-${local.environment}"
  acr_name            = "acr${local.project_name}${local.environment}"
  aks_name            = "aks-${local.project_name}-${local.environment}"
  app_gateway_name    = "agw-${local.project_name}-${local.environment}"
  key_vault_name      = "kv-${local.project_name}-${local.environment}"

  # Network configuration
  vnet_address_space    = ["10.0.0.0/8"]
  aks_subnet_cidr       = "10.240.0.0/16"
  gateway_subnet_cidr   = "10.1.0.0/24"
  private_endpoint_cidr = "10.2.0.0/24"

  # Common tags
  common_tags = {
    Environment  = local.environment
    Project      = local.project_name
    ManagedBy    = "Terraform"
    Repository   = "python-react-cloud-native"
    Architecture = "Microservices"
  }
}

# ================================
# Resource Group
# ================================
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = local.location
  tags     = local.common_tags
}

# ================================
# Networking Infrastructure
# ================================

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.project_name}-${local.environment}"
  address_space       = local.vnet_address_space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# AKS Subnet with Key Vault service endpoint
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.aks_subnet_cidr]

  service_endpoints = ["Microsoft.KeyVault"]
}

# Application Gateway Subnet  
resource "azurerm_subnet" "gateway" {
  name                 = "snet-gateway"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.gateway_subnet_cidr]
}

# Private Endpoints Subnet with Key Vault service endpoint
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.private_endpoint_cidr]

  service_endpoints = ["Microsoft.KeyVault"]
}

# ================================
# Azure Container Registry
# ================================
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium"
  admin_enabled       = false
  tags                = local.common_tags

  # Allow public access - can be restricted later with specific IP ranges
  public_network_access_enabled = true
}

# ================================
# Azure Kubernetes Service
# ================================

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.aks_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${local.project_name}${local.environment}"
  # Kubernetes version - use null for Azure default supported version
  kubernetes_version = var.kubernetes_version

  # Default node pool - only essential customizations
  default_node_pool {
    name           = "system"
    vm_size        = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
    zones          = ["1", "2", "3"]

    auto_scaling_enabled = true
    min_count            = 1
    max_count            = 10
    node_count           = var.node_count

    only_critical_addons_enabled = true
  }

  # System-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  # Network configuration - only what's needed for our VNet
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    service_cidr   = "192.168.0.0/16"
    dns_service_ip = "192.168.0.10"
  }

  # Essential integrations only
  azure_policy_enabled              = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.aks_admin_group_object_ids
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  tags = local.common_tags
  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count, # Allow auto-scaling to change node count
    ]
      
  }
}

# Assign role assignment to manage AKS cluster
resource "azurerm_role_assignment" "aks_admin" {
  principal_id   = data.azurerm_client_config.current.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope          = azurerm_kubernetes_cluster.main.id
}

# User node pool for applications - simplified
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.node_vm_size
  vnet_subnet_id        = azurerm_subnet.aks.id
  zones                 = ["1", "2", "3"]

  auto_scaling_enabled = true
  min_count            = 1
  max_count            = 20
  node_count           = var.user_node_count

  # Only the taint needed for workload separation
  node_taints = ["workload=application:NoSchedule"]

  tags = local.common_tags
}

# Grant AKS access to ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

# ================================
# Azure Database for PostgreSQL
# ================================
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "psql-${local.project_name}-${local.environment}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "15"
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  zone                   = "1"

  storage_mb   = 32768
  storage_tier = "P10"
  sku_name     = "GP_Standard_D2s_v3"

  backup_retention_days        = 35
  geo_redundant_backup_enabled = false

  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 8
    start_minute = 0
  }

  # Enable public access for now - can be restricted with firewall rules
  public_network_access_enabled = true

  tags = local.common_tags
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "${local.project_name}_${local.environment}"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Remove the private DNS zone and related resources since we're using public access
# Private DNS Zone for PostgreSQL - REMOVED
# resource "azurerm_private_dns_zone" "postgres" {
#   name                = "${local.project_name}-${local.environment}.postgres.database.azure.com"
#   resource_group_name = azurerm_resource_group.main.name
#   tags                = local.common_tags
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
#   name                  = "postgres-dns-link"
#   resource_group_name   = azurerm_resource_group.main.name
#   private_dns_zone_name = azurerm_private_dns_zone.postgres.name
#   virtual_network_id    = azurerm_virtual_network.main.id
#   tags                  = local.common_tags
# }

# ================================
# Redis Cache
# ================================
resource "azurerm_redis_cache" "main" {
  name                 = "redis-${local.project_name}-${local.environment}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  capacity             = 1
  family               = "C"
  sku_name             = "Standard"
  non_ssl_port_enabled = false
  minimum_tls_version  = "1.2"

  redis_configuration {
    authentication_enabled = true
  }

  tags = local.common_tags
}

# ================================
# Application Gateway
# ================================

# Public IP for Application Gateway
resource "azurerm_public_ip" "gateway" {
  name                = "pip-${local.app_gateway_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = local.app_gateway_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  # Auto-scaling configuration (required for WAF_v2)
  autoscale_configuration {
    min_capacity = 2
    max_capacity = 10
  }

  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = azurerm_subnet.gateway.id
  }

  frontend_port {
    name = "frontend-port-80"
    port = 80
  }

  frontend_port {
    name = "frontend-port-443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-configuration"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  backend_address_pool {
    name = "aks-backend-pool"
  }

  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-configuration"
    frontend_port_name             = "frontend-port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "backend-http-settings"
    priority                   = 100
  }

  # WAF Configuration
  waf_configuration {
    enabled                  = true
    firewall_mode            = "Prevention"
    rule_set_type            = "OWASP"
    rule_set_version         = "3.2"
    request_body_check       = true
    max_request_body_size_kb = 128

    disabled_rule_group {
      rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
      rules           = ["920230", "920440"]
    }
  }

  #   # Auto-scaling
  #   autoscale_configuration {
  #     min_capacity = 2
  #     max_capacity = 10
  #   }
}

# ================================
# Key Vault for Secrets
# ================================
resource "azurerm_key_vault" "main" {
  name                          = local.key_vault_name
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  enable_rbac_authorization     = true
  public_network_access_enabled = true

  # Network ACLs
  #   network_acls {
  #     default_action = "Deny"
  #     bypass         = "AzureServices"

  #     virtual_network_subnet_ids = [
  #       azurerm_subnet.aks.id,
  #       azurerm_subnet.private_endpoints.id
  #     ]
  #   }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "key_vault_access" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.main.id
}

# wait for 2 minutes to ensure Key Vault role assignment is applied
resource "null_resource" "wait_for_key_vault" {
  depends_on = [azurerm_role_assignment.key_vault_access]
  provisioner "local-exec" {
    command = "sleep 120"
  }
}

# Key Vault access for AKS
resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Store database connection string
resource "azurerm_key_vault_secret" "database_url" {
  depends_on   = [azurerm_role_assignment.key_vault_access]
  name         = "database-url"
  value        = "postgresql://${var.postgres_admin_username}:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.main.fqdn}/${azurerm_postgresql_flexible_server_database.main.name}?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id
}

# Store Redis connection string
resource "azurerm_key_vault_secret" "redis_url" {
  depends_on   = [azurerm_role_assignment.key_vault_access]
  name         = "redis-url"
  value        = "redis://:${azurerm_redis_cache.main.primary_access_key}@${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port}?ssl_cert_reqs=required"
  key_vault_id = azurerm_key_vault.main.id
}

# ================================
# Monitoring & Observability
# ================================

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.project_name}-${local.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-${local.project_name}-${local.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.common_tags
}

# Store Application Insights connection string
resource "azurerm_key_vault_secret" "app_insights_connection_string" {
  depends_on   = [azurerm_role_assignment.key_vault_access]
  name         = "app-insights-connection-string"
  value        = azurerm_application_insights.main.connection_string
  key_vault_id = azurerm_key_vault.main.id
}