variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "uksouth"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "pyreact"

  validation {
    condition     = can(regex("^[a-z0-9]{3,8}$", var.project_name))
    error_message = "Project name must be 3-8 characters, lowercase letters and numbers only."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = null
}

variable "node_count" {
  description = "Initial number of nodes in the default node pool"
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "Node count must be between 1 and 10."
  }
}

variable "user_node_count" {
  description = "Initial number of nodes in the user node pool"
  type        = number
  default     = 2

  validation {
    condition     = var.user_node_count >= 1 && var.user_node_count <= 20
    error_message = "User node count must be between 1 and 20."
  }
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "pgadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
  default     = "Password@12345"
}

variable "aks_admin_group_object_ids" {
  description = "Object IDs of Azure AD groups that should have admin access to AKS"
  type        = list(string)
  default     = []
}

variable "enable_container_insights" {
  description = "Enable Azure Monitor Container Insights"
  type        = bool
  default     = true
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy for AKS"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}