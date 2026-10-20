@description('Storage account name')
param storageAccountName string

@description('Prefix matches for lifecycle rules')
param prefixMatches array = ['facturas/', 'pedidos/']

@description('Days before tiering to Cool')
param tierToCoolDays int = 90

@description('Days before tiering to Cold')
param tierToColdDays int = 365

@description('Days before tiering to Archive')
param tierToArchiveDays int = 1095

@description('Enable transition to Archive tier (not supported by Azure on ZRS/GZRS redundancy SKUs)')
param enableArchiveTier bool = false

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

var baseBlobActions = enableArchiveTier ? {
  tierToCool: {
    daysAfterModificationGreaterThan: tierToCoolDays
  }
  tierToCold: {
    daysAfterModificationGreaterThan: tierToColdDays
  }
  tierToArchive: {
    daysAfterModificationGreaterThan: tierToArchiveDays
  }
} : {
  tierToCool: {
    daysAfterModificationGreaterThan: tierToCoolDays
  }
  tierToCold: {
    daysAfterModificationGreaterThan: tierToColdDays
  }
}

var snapshotActions = enableArchiveTier ? {
  tierToCool: {
    daysAfterCreationGreaterThan: tierToCoolDays
  }
  tierToCold: {
    daysAfterCreationGreaterThan: tierToColdDays
  }
  tierToArchive: {
    daysAfterCreationGreaterThan: tierToArchiveDays
  }
} : {
  tierToCool: {
    daysAfterCreationGreaterThan: tierToCoolDays
  }
  tierToCold: {
    daysAfterCreationGreaterThan: tierToColdDays
  }
}

var versionActions = enableArchiveTier ? {
  tierToCool: {
    daysAfterCreationGreaterThan: tierToCoolDays
  }
  tierToCold: {
    daysAfterCreationGreaterThan: tierToColdDays
  }
  tierToArchive: {
    daysAfterCreationGreaterThan: tierToArchiveDays
  }
} : {
  tierToCool: {
    daysAfterCreationGreaterThan: tierToCoolDays
  }
  tierToCold: {
    daysAfterCreationGreaterThan: tierToColdDays
  }
}

resource managementPolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2024-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'tier-erp-invoices-and-orders'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: prefixMatches
            }
            actions: {
              baseBlob: baseBlobActions
              snapshot: snapshotActions
              version: versionActions
            }
          }
        }
      ]
    }
  }
}

output id string = managementPolicy.id
