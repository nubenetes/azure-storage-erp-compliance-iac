using 'main.bicep'

param environment = 'prod'
param projectName = 'erp'
param location = 'spaincentral'
param skuName = 'Standard_ZRS'
param retentionDays = 2190
param softDeleteDays = 30
param enableResourceLock = true
param containerNames = [
  'facturas'
  'pedidos'
]
