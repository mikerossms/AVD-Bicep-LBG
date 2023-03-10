/*
This module is used to build out the host pool and its supporting components.  this is the bones of the AVD service
and provides a home for the Hosts, workspaces, application groups, and applications.
*/

@description ('Required: The Azure region to deploy to')
param location string

@description ('Required: The local environment - this is appended to the name of a resource')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param localEnv string

@description ('Required: A unique name to define your resource e.g. you name.  Must not have spaces')
@maxLength(6)
param uniqueName string

@description ('Required: The name of the workload to deploy - will make up part of the name of a resource')
param workloadName string

@description('Required: An object (think hash) that contains the tags to apply to all resources.')
param tags object

@description('Required: The ID of the Log Analytics workspace to which you would like to send Diagnostic Logs.')
param diagnosticWorkspaceId string

@description('Optional: Log retention policy - number of days to keep the logs.')
param diagnosticRetentionInDays int = 30

//Identity
@description('Required: The name of the Identity Keyvault')
param identityKeyvaultName string

@description('Required: The name of the domain to join the VMs to')
param domainName string

//HostPool Settings
@description('Optional: The template of the host to use for the Host Pool - can use both gallery and custom images')
param vmTemplate object = {
  domain:domainName
  galleryImageOffer: 'office-365'
  galleryImagePublisher: 'microsoftwindowsdesktop'
  galleryImageSKU: 'win11-22h2-avd-m365'
  imageType: 'Gallery'
  namePrefix: 'AVDv2'
  osDiskType: 'StandardSSD_LRS'
  useManagedDisks: true
  vmSize: {
      id: 'Standard_D2s_v3'
      cores: 2
      ram: 8
  }
}

@description('Optional: the maximum number of users allowed on each host (Host Session Limit)')
param maxUsersPerHost int = 4

@description('Optional: The type of load balancer to use for hosts - either breadth or depth')
@allowed([
  'BreadthFirst'
  'DepthFirst'
])
param loadBalancerType string = 'BreadthFirst'

@sys.description('Optional. Host Pool token validity length. Usage: \'PT8H\' - valid for 8 hours; \'P5D\' - valid for 5 days; \'P1Y\' - valid for 1 year. When not provided, the token will be valid for 48 hours.')
param tokenValidityLength string = 'PT48H'

@sys.description('Generated. Do not provide a value! This date value is used to generate a registration token.')
param baseTime string = utcNow('u')


//VARIABLES
var hostPoolName = toLower('hvdpool-${workloadName}-${location}-${localEnv}-${uniqueName}')
var hostPoolWorkspaceName = toLower('vdws-${workloadName}-${location}-${localEnv}-${uniqueName}')
var hostPoolAppGroupName = toLower('vdag-${workloadName}-${location}-${localEnv}-${uniqueName}')
var hostPoolScalePlanName = toLower('vdscaling-${workloadName}-${location}-${localEnv}-${uniqueName}')
var tokenExpirationTime = dateTimeAdd(baseTime, tokenValidityLength)

//Pull in the existing keyvault (required to access both the domain and local admin passwords)
resource keyVault 'Microsoft.KeyVault/vaults@2022-11-01' existing = {
  name: identityKeyvaultName
}

//Create the Host Pool
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' = {
  name: hostPoolName
  location: location
  tags: tags
  properties: {
    friendlyName: 'Host Pool for ${hostPoolName}'
    description: 'Host Pool for ${hostPoolName}'
    hostPoolType: 'Pooled'
    preferredAppGroupType: 'Desktop'
    maxSessionLimit: maxUsersPerHost
    loadBalancerType: loadBalancerType
    validationEnvironment: false
    registrationInfo: {
      expirationTime: tokenExpirationTime
      token: null
      registrationTokenOperation: 'Update'
    }
    vmTemplate: string(vmTemplate)
    agentUpdate: {
      maintenanceWindows: [
        {
          dayOfWeek: 'Friday'
          hour: 7
        }
        {
          dayOfWeek: 'Saturday'
          hour: 8
        }
      ]
      maintenanceWindowTimeZone: 'GMT Standard Time'
      type: 'Scheduled'
      useSessionHostLocalTime: false
    }
  }
}

resource hostPool_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${hostPoolName}-diag'
  scope: hostPool
  properties: {
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticRetentionInDays
        }
      }
    ]
  }
}

//Create the Application Group and connect it to the host pool
resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2022-09-09' = {
  name: hostPoolAppGroupName
  location: location
  tags: tags
  properties: {
    hostPoolArmPath: hostPool.id
    friendlyName: 'App Group for ${hostPoolName}'
    description: 'App GRoup for ${hostPoolName}'
    applicationGroupType: 'Desktop'
  }
}

//Configure the diagnostics for the application group
resource appGroup_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${hostPoolAppGroupName}-diag'
  scope: appGroup
  properties: {
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticRetentionInDays
        }
      }
    ]
  }
}

//Create the Workspace and connect it to the application group
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2022-09-09' = {
  name: hostPoolWorkspaceName
  location: location
  tags: tags
  properties: {
    description: 'Workspace for ${hostPoolName}'
    friendlyName: 'Workspace for ${hostPoolName}'
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}

//Configure the diagnostics for the workspace
resource workspace_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${hostPoolWorkspaceName}-diag'
  scope: workspace
  properties: {
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticRetentionInDays
        }
      }
    ]
  }
}

//Deploy the scaling plan and link it to the host pool - note this does not have any schedules set at this time
resource scalingPlan 'Microsoft.DesktopVirtualization/scalingPlans@2022-09-09' = {
  name: hostPoolScalePlanName
  location: location
  tags: tags
  properties: {
    friendlyName: 'Scaling plan for ${hostPoolName}'
    description: 'Scaling plan for ${hostPoolName}'
    timeZone: 'GMT Standard Time'
    hostPoolType: 'Pooled'
    hostPoolReferences: [
      {
        hostPoolArmPath: hostPool.id
        scalingPlanEnabled: false
      }
    ]
  }
}

resource scalingPlan_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${hostPoolScalePlanName}-diag'
  scope: scalingPlan
  properties: {
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticRetentionInDays
        }
      }
    ]
  }
}


output hostPoolName string = hostPoolName
output hostPoolWorkspaceName string = hostPoolWorkspaceName
output hostPoolAppGroupName string = hostPoolAppGroupName
output hostPoolScalePlanName string = hostPoolScalePlanName
output tokenExpirationTime string = tokenExpirationTime
output hostPoolId string = hostPool.id
output appGroupId string = appGroup.id
output workspaceId string = workspace.id
output scalingPlanId string = scalingPlan.id
