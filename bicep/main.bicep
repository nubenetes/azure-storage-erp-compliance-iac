targetScope = 'resourceGroup'

@description('Deployment environment')
type environmentType = 'dev' | 'staging' | 'prod'

@description('Storage replication SKU (ZRS recommended for Madrid 3-zone HA)')
type skuType = 'Standard_LRS' | 'Standard_ZRS' | 'Standard_GRS' | 'Standard_GZRS'

@description('Deployment environment: dev, staging, prod')
param environment environmentType = 'prod'

@description('Project identifier')
param projectName string = 'erp'

@description('Azure Region (defaults to Spain Central - Madrid)')
param location string = 'spaincentral'

@description('Storage Account name. If empty, a unique name is generated.')
param storageAccountName string = ''

@description('Storage replication SKU (ZRS recommended for Madrid 3-zone HA)')
param skuName skuType = 'Standard_ZRS'

@description('WORM retention period in days (2,190 days = 6 years Código de Comercio Art. 30)')
param retentionDays int = 2190

@description('Soft delete retention in days')
param softDeleteDays int = 30

@description('Enable CanNotDelete management lock')
param enableResourceLock bool = true

@description('List of container names to create')
param containerNames array = ['facturas', 'pedidos']

@description('Tags for deployed resources')
param tags object = {
  Workload: 'ERP-Document-Archive'
  LegalCompliance: 'Codigo-de-Comercio-Art30-VeriFactu'
  Country: 'Spain'
  ManagedBy: 'Bicep'
}

var uniqueSuffix = substring(uniqueString(resourceGroup().id, projectName, environment), 0, 6)
var resolvedStorageAccountName = empty(storageAccountName) ? 'st${projectName}${environment}${uniqueSuffix}' : toLower(storageAccountName)

// 1. Storage Account & Blob Services
module storageModule './modules/storage.bicep' = {
  name: 'deploy-storage-${resolvedStorageAccountName}'
  params: {
    storageAccountName: resolvedStorageAccountName
    location: location
    skuName: skuName
    softDeleteDays: softDeleteDays
    tags: tags
  }
}

// 2. Blob Containers with WORM Retention Policy
module containersModule './modules/containers.bicep' = {
  name: 'deploy-containers-${resolvedStorageAccountName}'
  params: {
    storageAccountName: storageModule.outputs.name
    containerNames: containerNames
    retentionDays: retentionDays
    allowProtectedAppendWrites: true
  }
}

// 3. Lifecycle Management Policy (Tiering Hot -> Cool -> Cold -> Archive)
module lifecycleModule './modules/lifecycle.bicep' = {
  name: 'deploy-lifecycle-${resolvedStorageAccountName}'
  params: {
    storageAccountName: storageModule.outputs.name
    prefixMatches: [for c in containerNames: '${c}/']
    tierToCoolDays: 90
    tierToColdDays: 365
    tierToArchiveDays: 1095
  }
  dependsOn: [
    containersModule
  ]
}

// 4. CanNotDelete Resource Lock
module lockModule './modules/lock.bicep' = if (enableResourceLock) {
  name: 'deploy-lock-${resolvedStorageAccountName}'
  params: {
    storageAccountName: storageModule.outputs.name
  }
  dependsOn: [
    lifecycleModule
  ]
}

output storageAccountId string = storageModule.outputs.id
output storageAccountName string = storageModule.outputs.name
output primaryBlobEndpoint string = storageModule.outputs.primaryBlobEndpoint
output containerIds array = containersModule.outputs.containerIds
output lifecyclePolicyId string = lifecycleModule.outputs.id
