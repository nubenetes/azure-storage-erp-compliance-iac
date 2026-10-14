variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., prod, staging, dev)."
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  type        = string
  description = "Project name identifier used in resource naming."
  default     = "erp"
}

variable "location" {
  type        = string
  description = "Azure region for deployment. Defaults to Spain Central (Madrid) for data residency and low latency."
  default     = "spaincentral"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group. If empty, a default standardized name is generated."
  default     = ""
}

variable "storage_account_name" {
  type        = string
  description = "Explicit name for the Storage Account (3-24 lowercase alphanumerics). If empty, a unique name is generated."
  default     = ""
}

variable "account_replication_type" {
  type        = string
  description = "Storage account redundancy SKU. ZRS (Zone-redundant across 3 Madrid availability zones) recommended for production; LRS can be used for dev/test."
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS"], var.account_replication_type)
    error_message = "Replication type must be one of: LRS, ZRS, GRS, GZRS."
  }
}

variable "account_tier" {
  type        = string
  description = "Performance tier for the storage account."
  default     = "Standard"
}

variable "access_tier" {
  type        = string
  description = "Default access tier for newly created blobs."
  default     = "Hot"
}

variable "min_tls_version" {
  type        = string
  description = "Minimum allowed TLS version for incoming requests."
  default     = "TLS1_2"
}

variable "allow_nested_items_to_be_public" {
  type        = bool
  description = "Allow or disallow public anonymous access to all blobs or containers in the storage account."
  default     = false
}

variable "shared_access_key_enabled" {
  type        = bool
  description = "Indicates whether the storage account permits requests to be authorized with the account access key (recommended false when using Entra ID RBAC only)."
  default     = true
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Number of days that deleted blobs and containers remain recoverable in soft delete."
  default     = 30

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 365
    error_message = "Soft delete retention must be between 7 and 365 days."
  }
}

variable "container_names" {
  type        = list(string)
  description = "List of blob containers to create for ERP documents."
  default     = ["facturas", "pedidos"]
}

variable "immutability_retention_days" {
  type        = number
  description = "Time-based WORM retention period in days. Default is 2190 days (6 calendar years) pursuant to Art. 30 of the Spanish Commercial Code."
  default     = 2190

  validation {
    condition     = var.immutability_retention_days >= 1 && var.immutability_retention_days <= 146000
    error_message = "Immutability retention period must be between 1 and 146000 days."
  }
}

variable "lock_immutability_policy" {
  type        = bool
  description = "CRITICAL: If true, permanently locks the container immutability policy (irreversible WORM mode). Keep false during initial deployment and testing."
  default     = false
}

variable "protected_append_writes_enabled" {
  type        = bool
  description = "Allow appending new blocks to append blobs while keeping past blocks immutable (VeriFactu / audit trail compliance)."
  default     = true
}

variable "enable_resource_lock" {
  type        = bool
  description = "Deploy a CanNotDelete management lock on the Storage Account to protect against accidental deletion."
  default     = true
}

variable "tier_to_cool_days" {
  type        = number
  description = "Days after modification before transitioning blobs to Cool tier."
  default     = 90
}

variable "tier_to_cold_days" {
  type        = number
  description = "Days after modification before transitioning blobs to Cold tier."
  default     = 365
}

variable "tier_to_archive_days" {
  type        = number
  description = "Days after modification before transitioning blobs to Archive tier."
  default     = 1095
}

variable "network_rules_default_action" {
  type        = string
  description = "Default network rule action: Allow or Deny."
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_rules_default_action)
    error_message = "Default network action must be Allow or Deny."
  }
}

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "List of public IPv4 addresses or CIDR blocks permitted to access the storage account when default action is Deny."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all deployed Azure resources."
  default = {
    Workload        = "ERP-Document-Archive"
    ManagedBy       = "Terraform"
    LegalCompliance = "Codigo-de-Comercio-Art30-VeriFactu"
    Country         = "Spain"
    CostCenter      = "IT-Finance"
  }
}
