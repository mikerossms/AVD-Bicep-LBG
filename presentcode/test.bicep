//PARAMETERS
param location string = 'uksouth'
param lawName string = 'myLaw'
param vnetName string = 'myVnet'

//Create an LAW and return its ID
module LAW 'lawModule.bicep' = {
  name: 'LAW'
  params: {
    location: location
    lawName: lawName
  }
}

//Call the VNET module and pass in the LAW ID
module VNET 'vnetModule.bicep' = {
  name: 'VNET'
  params: {
    location: location
    name: vnetName
    lawID: LAW.outputs.lawID
  }
}
