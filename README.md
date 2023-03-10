# AVD Bicep Workshop

Welcome to the AVD Bicep Workshop.  This repository provides both the bare bones template code and completed example code for you to use.  during the course, we will be using the template code base for you to build you and develop.

## Prerequisites

- Account on the tenant where you will be building resources
- Contributor Access to an Azure Subscription on that tenant
- Visual Studio Code
- The ability to run PowerShell
- Ability to set up / Access to an AD server or Azure Active Directory Domain Services (AADDS)

**Recommended VSCode Extensions**
- Azure Tools
- Azure Resources
- Bicep Extension
- PowerShell

##

## Testing the Setup

1. Open VSCode
1. Open a Terminal Window
1. Try the following commands

```Powershell
#Log into Azure
Connect-AzAccount

#List the subscriptions
Get-AzSubscription

#Set the correct subscription (from list above)
#Take note of the name and subscription ID - you will need it later
Set-AzContext -subscriptionName <name of subscription from list above>

#Create a resource group to test abaility to create resources
#Note: Make your naem unique by adding 3 random letters to the end of the "Name" field
New-AzResourceGroup -Name avdtest<3 random numbers> -Location uksouth

#Delete the resource group
Remove-AzResourceGroup -Name avdtest<3 random numbers>
```

