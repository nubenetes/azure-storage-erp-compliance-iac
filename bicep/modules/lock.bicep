@description('Storage account name')
param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource storageLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'lock-${storageAccountName}-prevent-deletion'
  scope: storageAccount
  properties: {
    level: 'CanNotDelete'
    notes: 'Protects ERP compliance storage account against accidental or malicious deletion.'
  }
}

output lockId string = storageLock.id
