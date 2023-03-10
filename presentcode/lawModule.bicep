param lawName string
param location string

var lawSKU = 'PerGB2018'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: location
  name: lawName
  properties: {
    sku: {
      name: lawSKU
    }
  }
}

output lawID string = logAnalyticsWorkspace.id
