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

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource managementPolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
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
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: tierToCoolDays
                }
                tierToCold: {
                  daysAfterModificationGreaterThan: tierToColdDays
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: tierToArchiveDays
                }
              }
              snapshot: {
                tierToCool: {
                  daysAfterCreationGreaterThan: tierToCoolDays
                }
                tierToCold: {
                  daysAfterCreationGreaterThan: tierToColdDays
                }
                tierToArchive: {
                  daysAfterCreationGreaterThan: tierToArchiveDays
                }
              }
              version: {
                tierToCool: {
                  daysAfterCreationGreaterThan: tierToCoolDays
                }
                tierToCold: {
                  daysAfterCreationGreaterThan: tierToColdDays
                }
                tierToArchive: {
                  daysAfterCreationGreaterThan: tierToArchiveDays
                }
              }
            }
          }
        }
      ]
    }
  }
}

output id string = managementPolicy.id
