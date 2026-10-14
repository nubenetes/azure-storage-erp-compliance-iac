output "resource_group_name" {
  description = "Name of the created Resource Group."
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Azure Region of the Resource Group."
  value       = azurerm_resource_group.rg.location
}

output "storage_account_id" {
  description = "Resource ID of the Storage Account."
  value       = azurerm_storage_account.sa.id
}

output "storage_account_name" {
  description = "Name of the Storage Account."
  value       = azurerm_storage_account.sa.name
}

output "primary_blob_endpoint" {
  description = "Primary Blob Service REST endpoint URL."
  value       = azurerm_storage_account.sa.primary_blob_endpoint
}

output "container_names" {
  description = "List of created blob containers."
  value       = [for c in azurerm_storage_container.containers : c.name]
}

output "immutability_policies" {
  description = "Details of configured WORM immutability policies."
  value = {
    for k, p in azurerm_storage_container_immutability_policy.worm_policies : k => {
      id                              = p.id
      immutability_period_in_days     = p.immutability_period_in_days
      locked                          = p.locked
      protected_append_writes_enabled = p.protected_append_writes_enabled
    }
  }
}

output "lifecycle_management_policy_id" {
  description = "ID of the applied Lifecycle Management Policy."
  value       = azurerm_storage_management_policy.lifecycle.id
}

output "management_lock_id" {
  description = "ID of the CanNotDelete resource lock (if enabled)."
  value       = var.enable_resource_lock ? azurerm_management_lock.sa_lock[0].id : null
}
