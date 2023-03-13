/*
This BICEP sets up and deploys an Identity VNET, Subnet and sets up and configures AADDS (if required)
This is not part of the AVD deployment course, but is a pre-requisite for the course if an existing solution has not been deployed
Please feel free to have a look though it and use it as a reference for your own deployments
*/

// This code comes from the curated modules: https://github.com/Azure/ResourceModules/tree/main/modules/Microsoft.AAD/DomainServices

@description('Required. The domain name specific to the Azure ADDS service.')
param domainName string

@description('Optional. The name of the AADDS resource. Defaults to the domain name specific to the Azure ADDS service.')
param name string = domainName

@description('Optional. The name of the SKU specific to Azure ADDS Services.')
@allowed([
  'Standard'
  'Enterprise'
  'Premium'
])
param sku string = 'Standard'

@description('Optional. The location to deploy the Azure ADDS Services.')
param location string = resourceGroup().location

@description('Conditional. The certificate required to configure Secure LDAP. Should be a base64encoded representation of the certificate PFX file. Required if secure LDAP is enabled and must be valid more than 30 days.')
@secure()
param pfxCertificate string = ''

@description('Conditional. The password to decrypt the provided Secure LDAP certificate PFX file. Required if secure LDAP is enabled.')
@secure()
param pfxCertificatePassword string = ''

@description('Optional. The email recipient value to receive alerts.')
param additionalRecipients array = []

@description('Optional. The value is to provide domain configuration type.')
@allowed([
  'FullySynced'
  'ResourceTrusting'
])
param domainConfigurationType string = 'FullySynced'

@description('Optional. The value is to synchronize scoped users and groups.')
param filteredSync string = 'Enabled'

@description('Optional. The value is to enable clients making request using TLSv1.')
@allowed([
  'Enabled'
  'Disabled'
])
param tlsV1 string = 'Disabled'

@description('Optional. The value is to enable clients making request using NTLM v1.')
@allowed([
  'Enabled'
  'Disabled'
])
param ntlmV1 string = 'Disabled'

@description('Optional. The value is to enable synchronized users to use NTLM authentication.')
@allowed([
  'Enabled'
  'Disabled'
])
#disable-next-line secure-secrets-in-params // Not a secret
param syncNtlmPasswords string = 'Enabled'

@description('Optional. The value is to enable on-premises users to authenticate against managed domain.')
@allowed([
  'Enabled'
  'Disabled'
])
#disable-next-line secure-secrets-in-params // Not a secret
param syncOnPremPasswords string = 'Enabled'

@description('Optional. The value is to enable Kerberos requests that use RC4 encryption.')
@allowed([
  'Enabled'
  'Disabled'
])
param kerberosRc4Encryption string = 'Disabled'

@description('Optional. The value is to enable to provide a protected channel between the Kerberos client and the KDC.')
@allowed([
  'Enabled'
  'Disabled'
])
param kerberosArmoring string = 'Enabled'

@description('Optional. The value is to notify the DC Admins.')
@allowed([
  'Enabled'
  'Disabled'
])
param notifyDcAdmins string = 'Enabled'

@description('Optional. The value is to notify the Global Admins.')
@allowed([
  'Enabled'
  'Disabled'
])
param notifyGlobalAdmins string = 'Enabled'

@description('Optional. The value is to enable the Secure LDAP for external services of Azure ADDS Services.')
@allowed([
  'Enabled'
  'Disabled'
])
param externalAccess string = 'Enabled'

@description('Optional. A flag to determine whether or not Secure LDAP is enabled or disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param ldaps string = 'Enabled'

@description('Optional. Tags of the resource.')
param tags object = {}


//AADDS VNET
param aaddsVnetName string = 'vnet-identity'
param aaddsVnetAddressPrefix string = '10.240.0.0/24'
param aaddsSnetName string = 'snet-identity'
param aaddsSnetAddressPrefix string = '10.240.0.0/24'
param aaddsNSGName string = 'aadds-nsg'

//VARIABLES
var replicaSets = [
  {
    location: location
    subnetId: snet.id
  }
]

//Set up an NSG
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: aaddsNSGName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRD'
        properties: {
          priority: 201
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'CorpNetSaw'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowPSRemoting'
        properties: {
          priority: 301
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '5986'
          sourceAddressPrefix: 'AzureActiveDirectoryDomainServices'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

//Create a vnet and subnet for the AADDS
resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: aaddsVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        aaddsVnetAddressPrefix
      ]
    }
  }
}

//Create the Subnet for AADDS
resource snet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' = {
  name: aaddsSnetName
  parent: vnet
  properties: {
    addressPrefix: aaddsSnetAddressPrefix
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

//Set up AADDS and connect it to the new VNET
resource domainService 'Microsoft.AAD/domainServices@2022-12-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    domainName: domainName
    domainConfigurationType: domainConfigurationType
    filteredSync: filteredSync
    notificationSettings: {
      additionalRecipients: additionalRecipients
      notifyDcAdmins: notifyDcAdmins
      notifyGlobalAdmins: notifyGlobalAdmins
    }
    ldapsSettings: {
      ldaps: 'Disabled'
      externalAccess: 'Disabled'
    }
    // ldapsSettings: {
    //   externalAccess: externalAccess
    //   ldaps: ldaps
    //   pfxCertificate: !empty(pfxCertificate) ? pfxCertificate : null
    //   pfxCertificatePassword: !empty(pfxCertificatePassword) ? pfxCertificatePassword : null
    // }
    replicaSets: replicaSets
    domainSecuritySettings: {
      tlsV1: tlsV1
      ntlmV1: ntlmV1
      syncNtlmPasswords: syncNtlmPasswords
      syncOnPremPasswords: syncOnPremPasswords
      kerberosRc4Encryption: kerberosRc4Encryption
      kerberosArmoring: kerberosArmoring
    }
    sku: sku
  }
}
