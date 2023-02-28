/*
The Diagnostics BICEP script deploys two resources - Log Analystic Workspace and a Storage Account.
The LAW is used for general diagnostic input from all the other deployed resources
The storage account is used for boot diagnostics.

The entire bicep script will be run in "Resource Group" mode, so the resources will need to be deployed into an existing RG
*/

//TARGET SCOPE
targetScope = 'resourceGroup'

//PARAMETERS
//Parameters provide a way to pass in values to the bicep script.  They are defined here and then used in the modules and variables below
//Some parameters are required, some are optional.  "optional" parameters are ones that have default values already set, so if you dont
//pass in a value, the default will be used.  If a parameter does not have a default value set, then you MUST pass it into the bicep script

//This is an example of an optional parameter.  If no value is passed in, UK South will be used as the default region to deploy to
@description ('Optional: The Azure region to deploy to')
param location string = 'uksouth'

//This is an example where the parameter passed in is limited to only that within the allowed list.  Anything else will cause an error
@description ('Optional: The local environment - this is appended to the name of a resource')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param localEnv string = 'dev' //dev, test, uat, prod

//This is an example of a required component.  Note there is no default value so the script will expect it to be passed in
//This is also limited to a maximum of 6 characters.  Any more an it will cause an error
@description ('Required: A unique name to define your resource e.g. you name.  Must not have spaces')
@maxLength(6)
param uniqueName string

@description ('Optional: The name of the workload to deploy - will make up part of the name of a resource')
param workloadName string = 'diag'

//This component is a bit more complex as it is an object.  This is passed in from powershell as a @{} type object
//Tags are really useful and show, as part of good practice, be applied to all resources and resource groups (where possible)
//They are used to help manage the service.  Resources that are tagged can then be used to create cost reports, or to find all resources assicated with a particular tag
@description('Optional: An object (think hash) that contains the tags to apply to all resources.')
param tags object = {
  environment: localEnv
  workload: workloadName
}

//Notice in this paramater case, we are using integers.  If passing in from powershell, we may need to use casting using the [int] type
@description('Optional: The number of days to retain data in the Log Analytics Workspace')
param lawDataRetention int = 30

//VARIABLES
// Variables are created at runtime and are usually used to build up resource names where not defined as a parameter, or to use functions and logic to define a value
// In most cases, you could just provide these as defaulted parameters, however you cannot use logic on parameters
//Variables are defined in the code and, unlike parameters, cannot be passed in and so remain fixed inside the template.

var lawName = toLower('law-${workloadName}-${location}-${localEnv}-${uniqueName}')
var lawSKU = 'PerGB2018'
var storageAccountName = toLower('st${workloadName}${location}${localEnv}${uniqueName}')

//RESOURCES

//Deploy the Log Analytics Workspace (notice the name is not actually log analytics workspace but Operational Insights)
//When you come to deploy an agent on the Hostpool Hosts, you will need to use the new Azure Monitoring Agent (AMA) and not the old Log Analytics (OMS) agent
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: location
  name: lawName
  tags: tags
  properties: {
    sku: {
      name: lawSKU
    }
    retentionInDays: lawDataRetention
  }
}


//Deploy the Storage account - this allows Azure Services to access the storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: tags
  properties: {
    allowSharedKeyAccess: true
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}


//Set up diagnostic logs on the storage account
resource storageAccount_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccountName}-diag'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    metrics: [
      {
        category: 'Capacity'
        enabled: true
        retentionPolicy: {
          days: lawDataRetention
          enabled: true
        }
      }
    ]
  }
  scope: storageAccount
}

//OUTPUTS
output lawName string = lawName
output lawID string = logAnalyticsWorkspace.id
output bootDiagStorageName string = storageAccountName
output bootDiagStorageID string = storageAccount.id

