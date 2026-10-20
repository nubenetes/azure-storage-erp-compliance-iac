locals {
  resource_group_name  = length(var.resource_group_name) > 0 ? var.resource_group_name : "rg-${var.project_name}-storage-${var.environment}-${var.location}"
  storage_account_name = length(var.storage_account_name) > 0 ? lower(var.storage_account_name) : "st${lower(var.project_name)}${var.environment}${random_string.sa_suffix.result}"
  # Azure Blob Storage does not support Archive tier on accounts with ZRS or GZRS redundancy.
  # When ZRS/GZRS is configured, archive tiering is safely omitted (data stays in Cold tier online).
  is_zrs_or_gzrs       = contains(["ZRS", "GZRS"], var.account_replication_type)
  archive_tier_days    = local.is_zrs_or_gzrs ? null : var.tier_to_archive_days
}

resource "random_string" "sa_suffix" {
  length  = 6
  special = false
  upper   = false
}

# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

# 2. General Purpose v2 Storage Account (Spain Central, ZRS/LRS)
resource "azurerm_storage_account" "sa" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_kind                    = "StorageV2"
  account_tier                    = var.account_tier
  account_replication_type        = var.account_replication_type
  access_tier                     = var.access_tier
  https_traffic_only_enabled      = true
  min_tls_version                 = var.min_tls_version
  allow_nested_items_to_be_public = var.allow_nested_items_to_be_public
  shared_access_key_enabled       = var.shared_access_key_enabled
  public_network_access_enabled   = true

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  network_rules {
    default_action = var.network_rules_default_action
    bypass         = ["AzureServices", "Logging", "Metrics"]
    ip_rules       = var.allowed_ip_ranges
  }

  tags = var.tags
}

# 3. Dedicated ERP Blob Containers (facturas, pedidos)
resource "azurerm_storage_container" "containers" {
  for_each              = toset(var.container_names)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# 4. WORM Immutability Policy (Time-Based Retention: 2,190 days / 6 years)
resource "azurerm_storage_container_immutability_policy" "worm_policies" {
  for_each                              = azurerm_storage_container.containers
  storage_container_resource_manager_id = each.value.id
  immutability_period_in_days           = var.immutability_retention_days
  protected_append_writes_enabled       = var.protected_append_writes_enabled
  locked                                = var.lock_immutability_policy
}

# 5. Lifecycle Management Policy (Tiering: Hot -> Cool -> Cold -> Archive)
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.sa.id

  rule {
    name    = "tier-erp-invoices-and-orders"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = [for c in var.container_names : "${c}/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.tier_to_cool_days
        tier_to_cold_after_days_since_modification_greater_than    = var.tier_to_cold_days
        tier_to_archive_after_days_since_modification_greater_than = local.archive_tier_days
      }

      snapshot {
        change_tier_to_cool_after_days_since_creation       = var.tier_to_cool_days
        tier_to_cold_after_days_since_creation_greater_than = var.tier_to_cold_days
        change_tier_to_archive_after_days_since_creation    = local.archive_tier_days
      }

      version {
        change_tier_to_cool_after_days_since_creation       = var.tier_to_cool_days
        tier_to_cold_after_days_since_creation_greater_than = var.tier_to_cold_days
        change_tier_to_archive_after_days_since_creation    = local.archive_tier_days
      }
    }
  }
}

# 6. Azure Management Lock (CanNotDelete)
resource "azurerm_management_lock" "sa_lock" {
  count      = var.enable_resource_lock ? 1 : 0
  name       = "lock-${azurerm_storage_account.sa.name}-prevent-deletion"
  scope      = azurerm_storage_account.sa.id
  lock_level = "CanNotDelete"
  notes      = "Protects ERP compliance storage account against accidental or malicious deletion."
}
