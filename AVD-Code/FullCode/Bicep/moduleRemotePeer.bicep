/*
  This module creates a peering from a local network to a remote network.  It works in any scope and pulls in the VNET that already exists
*/

//PARAMETERS

@description('Required. The name of the parent Virtual Network to add the peering to. Required if the template is used in a standalone deployment.')
param connectFromVnetName string

@description('Required. The Resource ID of the VNet that is this Local VNet is being peered to. Should be in the format of a Resource ID.')
param connectToVnetID string

@description('Optional. The Name of Vnet Peering resource. If not provided, default value will be localVnetName-remoteVnetName.')
param name string = '${connectFromVnetName}-${last(split(connectToVnetID, '/'))}'

@description('Optional. Whether the forwarded traffic from the VMs in the local virtual network will be allowed/disallowed in remote virtual network. Default is true.')
param allowForwardedTraffic bool = true

@description('Optional. If gateway links can be used in remote virtual networking to link to this virtual network. Default is false.')
param allowGatewayTransit bool = false

@description('Optional. Whether the VMs in the local virtual network space would be able to access the VMs in remote virtual network space. Default is true.')
param allowVirtualNetworkAccess bool = true

@description('Optional. If we need to verify the provisioning state of the remote gateway. Default is true.')
param doNotVerifyRemoteGateways bool = true

@description('Optional. If remote gateways can be used on this virtual network. If the flag is set to true, and allowGatewayTransit on remote peering is also true, virtual network will use gateways of remote virtual network for transit. Only one peering can have this flag set to true. This flag cannot be set if virtual network already has a gateway. Default is false.')
param useRemoteGateways bool = false

//RESOURCES
//Pull in the existing VNET which we are creating a peering FROM
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: connectFromVnetName
}

//Create the peering TO the remote VNET (based on the remote VNET ID)
resource virtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: name
  parent: virtualNetwork
  properties: {
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    doNotVerifyRemoteGateways: doNotVerifyRemoteGateways
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: connectToVnetID
    }
  }
}
