/*
This BICEP script sets up a VNET for the AVD to reside in.
Note also that there is no TargetScope defined.  The reason for this is not that "ResourceGroup" is actually the default setting.
*/

//TODO: Update VNET DNS to point to the AD server, Go into AADDS and define the DNS peer within DNS otherwise VMs cannot see the internet or MS services

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

@description('Optional: The ID of the Log Analytics workspace to which you would like to send Diagnostic Logs.')
param diagnosticWorkspaceId string = ''

@description('Optional: Log retention policy - number of days to keep the logs.')
param diagnosticRetentionInDays int = 30

//Identity Vnet Parameters
@description('Optional: The name of the identity vnet to peer to')
param identityVnetName string = 'vnet-identity'

@description('Optional: The resource group containing the identity vnet to peer to')
param identityVnetRG string = 'rg-identity'

@description('Required: The IP Address of the AD Server or AADDS Server to use as the DNS server for the VNET')
param adServerIPAddresses array

//VARIABLES
var vnetName = toLower('vnet-${workloadName}-${location}-${localEnv}-${uniqueName}')
var snetName = toLower('snet-${workloadName}-${location}-${localEnv}-${uniqueName}')
var nsgName = toLower('nsg-${workloadName}-${location}-${localEnv}-${uniqueName}')
var nsgAVDRuleName = toLower('AllowRDPInbound')

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

//Create the virtual network (vnet) and subnet (snet) objects
//Note that the SNET will have a set of storage endpoints and keyvault endpoints enabled
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
    dhcpOptions: {
      dnsServers: adServerIPAddresses
    }
    subnets: [
      {
        name: snetName
        properties: {
          addressPrefix: snetCIDR
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          // serviceEndpoints: [
          //   {
          //     service: 'Microsoft.Storage'
          //   }
          //   {
          //     service: 'Microsoft.Keyvault'
          //   }
          // ]
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

//This next set of resources defines the peering between two networks.  Note that Peering is a two-sided process, i.e. you need to apply the peering as
//two separate transations, one at each end of the link.  this is provided as a module.  the reason for this is that we need to provide two
//different scopes - one for each end and you can only scope modules in Bicep.

//So first lets pull in the existing identity vnet
resource identityVnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: identityVnetName
  scope: resourceGroup(identityVnetRG)
}

//So this first resource uses the existing vnet that we created earlier to link to the identity vnet using the vnets resource id
//No scope is required on this one as it wull run in the scope as everything else we are creating.  We are just going to use
//the modules defaults for the majority of this
module outboundPeering 'moduleRemotePeer.bicep' = {
  name: 'outboundPeering'
  params: {
    connectFromVnetName: virtualNetwork.name
    connectToVnetID: identityVnet.id
  }
}

//So this module does the reverse part of the connection FROM the remote VNET to this local VNET.  In this case it does need to be scoped
//as we will be working on the REMOTE resource this time.
module inboundPeering 'moduleRemotePeer.bicep' = {
  name: 'inboundPeering'
  scope: resourceGroup(identityVnetRG)
  params: {
    connectFromVnetName: identityVnetName
    connectToVnetID: virtualNetwork.id
  }
}

//OUTPUTS
output vnetName string = virtualNetwork.name
output vnetID string = virtualNetwork.id
output snetName string = virtualNetwork.properties.subnets[0].name
output snetID string = virtualNetwork.properties.subnets[0].id
output nsgName string = networkSecurityGroup.name
output nsgID string = networkSecurityGroup.id
