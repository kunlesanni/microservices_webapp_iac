output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_node_resource_group" {
  description = "Auto-generated resource group for AKS nodes"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "container_registry_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "container_registry_url" {
  description = "Login server URL of the Azure Container Registry"
  value       = azurerm_container_registry.main.login_server
}

output "application_gateway_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.gateway.ip_address
}

output "postgres_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
  sensitive   = true
}

output "postgres_database_name" {
  description = "Name of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "redis_hostname" {
  description = "Hostname of the Redis cache"
  value       = azurerm_redis_cache.main.hostname
  sensitive   = true
}

output "redis_port" {
  description = "SSL port of the Redis cache"
  value       = azurerm_redis_cache.main.ssl_port
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# Output for kubectl configuration
output "kube_config" {
  description = "kubectl configuration for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

# Useful for CI/CD pipelines
output "cluster_info" {
  description = "AKS cluster information for deployments"
  value = {
    name                = azurerm_kubernetes_cluster.main.name
    resource_group      = azurerm_resource_group.main.name
    node_resource_group = azurerm_kubernetes_cluster.main.node_resource_group
    fqdn                = azurerm_kubernetes_cluster.main.fqdn
  }
}