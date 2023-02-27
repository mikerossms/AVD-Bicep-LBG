/*
The Backplane is simply a way of coordinating all of the moving part of this deployment so you dont have to deploy each section individually.
This bicep script will call the following in this order:

network.bicep
hostpool.bicep
hosts.bicep

The entire bicep script will be run in "Resource Group" mode, so the resources will need to be deployed into an existing RG

You might notice that diagnostics.bicep is not called here.  Why? Because the diagnostics bicep deploys to a different resource group to the rest of the components.
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
@description ('The local environment - this is appended to the name of a resource')
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
param workloadName string = 'avd'

//this is an example of where you can build the default value from other parameters already passed in (or using their defaults)
//in this case, it also converts the entire default value to lower case
@description ('The name of the already created resource group to deploy the AVD components into')
param rgAVDName string = toLower('rg-${workloadName}-${location}-${localEnv}-${uniqueName}')

//Diagnostics
@description ('Required: The name of the resource group where the diagnostics components have been deployed to')
param rgDiagName string

@description ('Required: The name of the Log Analytics workspace in the diagnostics RG')
param lawName string

@description ('Required: The name of the storage account in the diagnostics RG to be used for Boot Diagnostics')
param bootDiagStorageName string

//VARIABLES
// Variables are created at runtime and are usually used to build up resource names where not defined as a parameter, or to use functions and logic to define a value
// In most cases, you could just provide these as defaulted parameters, however you cannot use logic on parameters
//Variables are defined in the code and, unlike parameters, cannot be passed in and so remain fixed inside the template.

//RESOURCES
//Resources are all deployed as MODULES.  Each module defines a block of BICEP code and are listed above
//Both Modules and Resources have Inputs and Outputs.
//Please ntoe the use of "Scope" in the module definition.  This is how you tell the module which resource group to deploy to.

//Get the existing Diagnostics Module - the diagnostics module should already have been deployed to a different resource group
//Note the use of two components - existing and scope
//The existing keyword defines a resource that has already been deployed and that you are "pulling into" this deployment for use by the resources here.
//The scope defines where that resource is deployed.  In this case it is in the "resourceGoupe" in the current subscription defined by the name "rgDiagName" which is a parameter passed in
resource LAWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: lawName
  scope: resourceGroup(rgDiagName)
}

//Deploy the Network resources
module Network 'network.bicep' = {
  name: 'Network'
  scope: resourceGroup(rgAVDName)
  params: {

  }
}

//Deploy the HostPool resources
module HostPool 'hostpool.bicep' = {
  name: 'HostPool'
  scope: resourceGroup(rgAVDName)
  params: {

  }
}

//DEploy the Hosts for the host pool
module Hosts 'hosts.bicep' = {
  name: 'Hosts'
  scope: resourceGroup(rgAVDName)
  params: {

  }
}

