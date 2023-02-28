/*
This BICEP script sets up a VNET for the AVD to reside in.
Note also that there is no TargetScope defined.  The reason for this is not that "ResourceGroup" is actually the default setting.
*/

//PARAMETERS
//As best practice it is always a good idea to try and maintain a naming convention and style for all your modules and resources
//You will notice a lot of these parameters take the same name as their parent, but notice that many are now required, feeding from the parent.
//This way, modules can be used for other projects as well without having to durplicate and edit defaults.

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

@description('Required: The address prefix (CIDR) for the virtual network.')
param vnetCIDR string

@description('Required: The address prefix (CIDR) for the virtual networks AVD subnet.')
param snetCIDR string

@description('Required: The ID of the identity network to peer to')
param identityVnetID string

@description('Optional: The ID of the Log Analytics workspace to which you would like to send Diagnostic Logs.')
param diagnosticWorkspaceId string = ''

@description('Optional: Log retention policy - number of days to keep the logs.')
param diagnosticRetentionInDays int = 30

//VARIABLES
var vnetName = toLower('vnet-${workloadName}-${location}-${localEnv}-${uniqueName}')
var snetName = toLower('snet-${workloadName}-${location}-${localEnv}-${uniqueName}')
var nsgName = toLower('nsg-${workloadName}-${location}-${localEnv}-${uniqueName}')
var nsgAVDRuleName = toLower('AllowRDPInbound')

//This defines the peering properties from the AVD vnet to the identity vnet
var vnetPeerToIdentityProperties = {
  allowForwardedTraffic: false
  allowGatewayTransit: false
  allowVirtualNetworkAccess: true
  useRemoteGateways: false
  remoteVirtualNetwork: {
    id: identityVnetID
  }
}

//And this defines the properties of the peering from the identity vnet to the AVD vnet
//Note that we are using the virtual ID of the vnet which has not yet been created?  In effect, this variable uses a DependOn to ensure the vnet is created
//first before the variable is then defined.  This also enforces the order of creation ensuring the vnet is created before the peering.
var vnetPeerFromIdentityProperties = {
  allowForwardedTraffic: false
  allowGatewayTransit: false
  allowVirtualNetworkAccess: true
  doNotVerifyRemoteGateways: false
  useRemoteGateways: false
  remoteVirtualNetwork: {
    id: virtualNetwork.id
  }
}

//Create the Network Security Group (there is very little to creating one, but it is a good idea to have one for each subnet)
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsgName
  location: location
  tags: tags
}

//Enable Diagnostics on the NSG
//In this case we have a scope in the resource which defines which resource that this diagnostic setting is for
//We are also using some logic, so if this is not passed in from the parent, then this will be skipped without causing errors
resource networkSecurityGroup_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticWorkspaceId)) {
  name: '${nsgName}-diag'
  scope: networkSecurityGroup
  properties: {
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    logs: [
      {
        category: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticRetentionInDays
        }
      }
    ]
  }
}

//Set up the AVD rule for the NSG
resource securityRule 'Microsoft.Network/networkSecurityGroups/securityRules@2022-07-01' = {
  name: nsgAVDRuleName
  parent: networkSecurityGroup
  properties: {
    access: 'Allow'
    description: 'Allow RDP access to AVD from the '
    direction: 'Inbound'
    priority: 1000
    protocol: 'Tcp'
    sourceAddressPrefix: 'VirtualNetwork'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '3389'
  }
}

//Enable Diagnostics on the NSG Rule
//Like the NSG itself, you can define diagnostic rules on the NSG rules themselves as well. This is a good idea to do, as it will allow you to see if the rule is being applied correctly
resource securityRule_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticWorkspaceId)) {
  name: '${nsgAVDRuleName}-diag'
  scope: securityRule
  properties: {
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    logs: [
      {
        category: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticRetentionInDays
        }
      }
    ]
  }
}

//Create the virtual network (vnet) and subnet (snet) objects
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCIDR
      ]
    }

    subnets: [
      {
        name: snetName
        properties: {
          addressPrefix: snetCIDR
          networkSecurityGroup: networkSecurityGroup
          serviceEndpoints: xx
        }
      }]
  }
}

//As for the NSG, we can also apply diagnostics to the VNET (and subnets automatically)
//You will note that the diagnostic settings follow a very similar pattern.  This is a prime candidate for a module
resource virtualNetwork_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticWorkspaceId)) {
  name: '${vnetName}-diag'
  scope: virtualNetwork
  properties: {
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    logs: [
      {
        category: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: diagnosticRetentionInDays
        }
      }
    ]
  }
}

//This next set of resources defines the peering between two networks.  Note that Peering is a two-sided process, i.e. you need to apply the peering as
//two separate transations, one at each end of the link.
//So this first resource uses the existing vnet that we created earlier to link to the identity vnet using the vnets resource id
resource virtualNetworkPeeringToIdentity 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${vnetName}-to-identity'
  parent: virtualNetwork
  properties: vnetPeerToIdentityProperties
}

//The second one is a little more challenging as we need to scope the resource to the identity vnet.  So to do that we 
//need to pull in the identity vnet based on its resource ID.  this is done using the "existing" function

//Get the identity vnet from its resource ID


resource virtualNetworkPeeringFromIdentity 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: 'identity-to-${vnetName}'
  parent: virtualNetwork
  properties: vnetPeerToIdentityProperties
}

// // Local to Remote peering
// module virtualNetwork_peering_local 'virtualNetworkPeerings/deploy.bicep' = [for (peering, index) in virtualNetworkPeerings: {
//   name: '${uniqueString(deployment().name, location)}-virtualNetworkPeering-local-${index}'
//   params: {
//     localVnetName: virtualNetwork.name
//     remoteVirtualNetworkId: peering.remoteVirtualNetworkId
//     name: contains(peering, 'name') ? peering.name : '${name}-${last(split(peering.remoteVirtualNetworkId, '/'))}'
//     allowForwardedTraffic: contains(peering, 'allowForwardedTraffic') ? peering.allowForwardedTraffic : true
//     allowGatewayTransit: contains(peering, 'allowGatewayTransit') ? peering.allowGatewayTransit : false
//     allowVirtualNetworkAccess: contains(peering, 'allowVirtualNetworkAccess') ? peering.allowVirtualNetworkAccess : true
//     doNotVerifyRemoteGateways: contains(peering, 'doNotVerifyRemoteGateways') ? peering.doNotVerifyRemoteGateways : true
//     useRemoteGateways: contains(peering, 'useRemoteGateways') ? peering.useRemoteGateways : false
//     enableDefaultTelemetry: enableReferencedModulesTelemetry
//   }
// }]

// // Remote to local peering (reverse)
// module virtualNetwork_peering_remote 'virtualNetworkPeerings/deploy.bicep' = [for (peering, index) in virtualNetworkPeerings: if (contains(peering, 'remotePeeringEnabled') ? peering.remotePeeringEnabled == true : false) {
//   name: '${uniqueString(deployment().name, location)}-virtualNetworkPeering-remote-${index}'
//   scope: resourceGroup(split(peering.remoteVirtualNetworkId, '/')[2], split(peering.remoteVirtualNetworkId, '/')[4])
//   params: {
//     localVnetName: last(split(peering.remoteVirtualNetworkId, '/'))!
//     remoteVirtualNetworkId: virtualNetwork.id
//     name: contains(peering, 'remotePeeringName') ? peering.remotePeeringName : '${last(split(peering.remoteVirtualNetworkId, '/'))}-${name}'
//     allowForwardedTraffic: contains(peering, 'remotePeeringAllowForwardedTraffic') ? peering.remotePeeringAllowForwardedTraffic : true
//     allowGatewayTransit: contains(peering, 'remotePeeringAllowGatewayTransit') ? peering.remotePeeringAllowGatewayTransit : false
//     allowVirtualNetworkAccess: contains(peering, 'remotePeeringAllowVirtualNetworkAccess') ? peering.remotePeeringAllowVirtualNetworkAccess : true
//     doNotVerifyRemoteGateways: contains(peering, 'remotePeeringDoNotVerifyRemoteGateways') ? peering.remotePeeringDoNotVerifyRemoteGateways : true
//     useRemoteGateways: contains(peering, 'remotePeeringUseRemoteGateways') ? peering.remotePeeringUseRemoteGateways : false
//     enableDefaultTelemetry: enableReferencedModulesTelemetry
//   }
// }]
