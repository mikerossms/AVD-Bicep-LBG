/*
This module is used to build a host vm and add them to both the host pool and the AD server.  Once these are up and running you should
be able to log into AVD.
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

//Host Settings
@description('Required: The local admin user name for the host')
param adminUserName string

@description('Required: The local admin password for the host (secure string)')
@secure()
param adminPassword string

@description('Required: The Domain account username that will be used to join the host to the domain')
param domainUsername string

@description('Required: The Domain account password that will be used to join the host to the domain (secure string)')
@secure()
param domainPassword string

@description('Required: The name of the domain to join the VMs to')
param domainName string

@description('Required: The OU path to join the VMs to (i.e. the LDAP path within the AD server visible under "users and computers")')
param domainOUPath string

@description('Optional: The size of the VM to deploy.  Default is Standard_D2s_v3')
param vmSize string = 'Standard_D2s_v3'

@description('Required: The ID of the subnet to deploy the VMs to')
param subnetID string

@description('Required: The name of the host pool to add the hosts to')
param hostPoolName string

param hostNumber int = 1

//VARIABLES
//the base base name for each VM created
var vmName = toLower('host-${workloadName}-${location}-${localEnv}-${uniqueName}-${hostNumber}')

//the base host name (i.e. within windows itself) for each VM created
var vmHostName = toLower('host${workloadName}${uniqueName}${hostNumber}')

//the base Network Interface name for each VM created
var vmNicName = toLower('nic-${workloadName}-${location}-${localEnv}-${uniqueName}${hostNumber}')

//The version of windows to deploy
var vmImageObject = {
  offer: 'office-365'
  publisher: 'microsoftwindowsdesktop'
  sku: 'win11-22h2-avd-m365'
  version: 'latest'
}

//A publically available zip file that contains a microsoft curated script to handle the join of a host to the host pool
var dscConfigURL = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration.zip'


//RESOURCES
//Pull in the LAW workspace
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: diagnosticWorkspaceId
}

//Create Network interfaces for each of the VMs being deployed
resource vmNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: vmNicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: subnetID
          }
        }
      }
    ]
  }
}

//Deploy "numberOfHostToDeploy" x virtual machines
resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    //The size of the VM to deploy
    hardwareProfile: {
      vmSize: vmSize
    }

    storageProfile: {
      //the type of the OS disk to set up and how it will be populated
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      //The OS image to deploy for this VM
      imageReference: vmImageObject
    }

    osProfile: {
      //Set up the host VM windows defaults e.g. local admin, name, patching etc.
      computerName: vmHostName
      adminUsername: adminUserName
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        timeZone: 'GMT Standard Time'
        patchSettings: {
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
          patchMode: 'AutomaticByOS'
        }
      }
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }

    //Enable the boot diagnostics
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

//VM Extensions - these are used to carry out actions and install components onto the VM
//Bicep naturally tries and deploy these in parallel which, depending on what the extension is doing can cause conflicts
//As a general rule of thumb it is usually a good idea to deploy extensions in a serial fashion using "dependsOn" to ensure they are deployed in the correct order

//Anti Malware Extension
// resource VMAntiMalware 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = [for i in range(0, numberOfHostsToDeploy): {
//   name: 'AntiMalware'
//   parent: vm[i]
//   location: location
//   tags: tags
//   properties: {
//     publisher: 'Microsoft.Azure.Security'
//     type: 'IaaSAntimalware'
//     typeHandlerVersion: '1.3'
//     autoUpgradeMinorVersion: true
//     settings: {
//       AntimalwareEnabled: 'true'
//       RealtimeProtectionEnabled: 'true'
//       ScheduledScanSettings: {
//         isEnabled: 'true'
//         day: 'Sunday'
//         time: '23:00'
//       }
//       Exclusions: {
//         extensions: ''
//         paths: ''
//         processes: ''
//       }
//     }
//   }
// }]

//Monitoring Extension
resource VMMonitoring 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: 'MicrosoftMonitoringAgent'
  parent: vm
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
    settings: {
      workspaceId: law.id
    }
    protectedSettings: {
      workspaceKey: law.listKeys().primarySharedKey
    }
  }
// dependsOn: [
//   vmAntiMalware[i]
//   ]
}


//Join the Domain (you can also now join the AAD in certain scenarios, but AVD is not yet supported for anything other than personal machines)
resource VMDomainJoin 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: 'JoinDomain'
  parent: vm
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainName
      OUPath: domainOUPath
      user: domainUsername
      restart: 'true'
      options: '3'
    }
    protectedSettings: {
      password: domainPassword
    }
  }
  dependsOn: [
    VMMonitoring
  ]
}

// //As we need the latest hostpool token, we need to pull in the Host Pool resource and get the latest token from there
// resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' existing = {
//   name: hostPoolName
// }


// //Finally join the VM to the AVD Host Pool using a Desired State Configuration extension deployment
// resource vmAVDJoin 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = [for i in range(0, numberOfHostsToDeploy): {
//   name: '${vmName}_${i}/ADJoin'
//   location: location
//   tags: tags
//   properties: {
//     publisher: 'Microsoft.Powershell'
//     type: 'DSC'
//     typeHandlerVersion: '2.80'
//     autoUpgradeMinorVersion: true
//     settings: {
//       modulesUrl: dscConfigURL
//       configurationFunction: 'Configuration.ps1\\AddSessionHost'
//       properties: {
//         HostPoolName: hostPoolName
//       }
//       protectedSettings: {
//         configurationArguments: {
//           HostPoolToken: hostPool.properties.registrationInfo.token
//         }
//       }
//     }
//   }
// }]


//Custom Script Extension (example only)
// resource vmScript 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = [for i in range(0, numberOfHostsToDeploy): {
//   name: '${vmName}_${i}/CustomScriptExtension'
//   location: location
//   tags: tags
//   properties: {
//     publisher: 'Microsoft.Compute'
//     type: 'CustomScriptExtension'
//     typeHandlerVersion: '1.10'
//     autoUpgradeMinorVersion: true
//     enableAutomaticUpgrade: false
//     settings: {
//       //File URI's and parameters here
//     protectedSettings: {
//       //Any protected settings for the custom script here
//     }
//   }
// }]

// //Network Watcher Extension (example only, not required for AVD)
// resource networkWatcher 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = [for i in range(0, numberOfHostsToDeploy): {
//   name: '${vmName}_${i}/-VM-NetworkWatcherAgent'
//   location: location
//   tags: tags
//   properties: {
//     publisher: 'Microsoft.Azure.NetworkWatcher'
//     type: 'NetworkWatcherAgent'
//     typeHandlerVersion: '1.4'
//     autoUpgradeMinorVersion: true
//     enableAutomaticUpgrade: false
//   }
// }]
