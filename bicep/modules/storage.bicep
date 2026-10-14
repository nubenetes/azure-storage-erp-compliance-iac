@description('Storage account name (3-24 lowercase alphanumerics)')
param storageAccountName string

@description('Azure region (defaults to Spain Central)')
param location string = 'spaincentral'

@description('Redundancy SKU')
@allowed(['Standard_LRS', 'Standard_ZRS', 'Standard_GRS', 'Standard_GZRS'])
param skuName string = 'Standard_ZRS'

@description('Soft delete retention in days')
param softDeleteDays int = 30

@description('Resource tags')
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices, Logging, Metrics'
      defaultAction: 'Allow'
    }
  }
  tags: tags
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    isVersioningEnabled: true
    changeFeed: {
      enabled: true
    }
    deleteRetentionPolicy: {
      enabled: true
      days: softDeleteDays
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: softDeleteDays
    }
  }
}

output id string = storageAccount.id
output name string = storageAccount.name
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
