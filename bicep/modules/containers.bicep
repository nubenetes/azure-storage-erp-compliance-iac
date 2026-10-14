@description('Name of the parent storage account')
param storageAccountName string

@description('List of container names to provision')
param containerNames array = ['facturas', 'pedidos']

@description('WORM retention period in days (2,190 days = 6 years Código de Comercio Art. 30)')
param retentionDays int = 2190

@description('Allow appending new blocks without modifying historical blocks')
param allowProtectedAppendWrites bool = true

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = [for name in containerNames: {
  parent: blobServices
  name: name
  properties: {
    publicAccess: 'None'
  }
}]

resource immutabilityPolicies 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2024-01-01' = [for (name, i) in containerNames: {
  parent: containers[i]
  name: 'default'
  properties: {
    immutabilityPeriodSinceCreationInDays: retentionDays
    allowProtectedAppendWrites: allowProtectedAppendWrites
  }
}]

output containerIds array = [for (name, i) in containerNames: containers[i].id]
