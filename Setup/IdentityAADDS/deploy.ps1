<#
.SYNOPSIS
    This script will deploy the AADDS bicep template and passes in the PFX certificate

.DESCRIPTION
    Notes:
    - Make sure you have generated the PFX certificate and updated that in the script below (use generateCert.ps1 as a local admin to generate this)
    - Ensure that the $domainName is correct (must match an AD domain name)
    - Ensure that the SubID is correct for your tenancy
    - This can take up to 60 mins to deploy and costs around £100/month
    - Add Domain Admins to the "AAD DC Administrators" group in Azure AD

    Ref: https://github.com/Azure/ResourceModules/tree/main/modules/Microsoft.AAD/DomainServices
    Ref: https://learn.microsoft.com/en-us/azure/active-directory-domain-services/tutorial-create-instance
    Ref: https://learn.microsoft.com/en-us/azure/active-directory-domain-services/powershell-create-instance
    Ref: https://learn.microsoft.com/en-us/azure/active-directory-domain-services/tutorial-create-instance#enable-user-accounts-for-azure-ad-ds 

#>

#IMPORTANT: $domainName MUST match a domain name in Azure AD
#Get the runtime parameters from the user
param (
    [String]$domainName = 'quberatron.com',
    [String]$identityRG = "rg-identity",
    [String]$location = "uksouth",
    [String]$subID = "152aa2a3-2d82-4724-b4d5-639edab485af",
    [Bool]$dologin = $true
)

$tags = @{
    Environment='prod'
    Owner="LBG"
}

#Base64 encoded PFX certificate (use generateCert.ps1 as a local admin to generate this)
$pfxCertificate = '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'

#Acquire the certificate password as a secure string
$pfxCertificatePassword = Read-Host -Prompt "Enter the PFX password" -AsSecureString

#Login to azure (if required) - if you have already done this once, then it is unlikley you will need to do it again for the remainer of the session
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    Connect-AzAccount -Subscription $subID
}

#check that the subscription ID we are connected to matches the one we want and change it if not
if ((Get-AzContext).Subscription.Id -ne $subID) {
    #they dont match so try and change the context
    Write-Host "Changing context to subscription: $subID" -ForegroundColor Yellow
    $context = Set-AzContext -SubscriptionId $subID

    if ($context.Subscription.Id -ne $subID) {
        Write-Host "ERROR: Cannot change to subscription: $subID" -ForegroundColor Red
        exit 1
    }

    Write-Host "Changed context to subscription: $subID" -ForegroundColor Green
}

#Create a resource group for the diagnostic resources if it does not already exist then check it has been created successfully
if (-not (Get-AzResourceGroup -Name $identityRG -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Resource Group: $identityRG" -ForegroundColor Green
    if (-not (New-AzResourceGroup -Name $identityRG -Location $location)) {
        Write-Host "ERROR: Cannot create Resource Group: $identityRG" -ForegroundColor Red
        exit 1
    }
}

#Check to make sure the AADDS Service Principal is present and if not create it
$id = Get-AzAdServicePrincipal -AppId "2565bd9d-da50-47d4-8b85-4c97f669dc36" -ErrorAction SilentlyContinue
if (-not $id) {
    Write-Host "Creating AADDS Service Principal" -ForegroundColor Green
    New-AzAdServicePrincipal -AppId "2565bd9d-da50-47d4-8b85-4c97f669dc36"
}

# Register the resource provider for Azure AD Domain Services with Resource Manager.
Register-AzResourceProvider -ProviderNamespace Microsoft.AAD

#Install the Azure AD module if not already installed
if (-not (Get-Module -Name AzureAD -ListAvailable)) {
    Write-Host "Installing AzureAD module" -ForegroundColor Green
    Install-Module -Name AzureAD -Force
}

#Deploy AADDS and pass in the PFX certificate (base 64 encoded) and Certificate password (secure string)
Write-Host "Deploying AADDS and supporting infrastructure"
New-AzResourceGroupDeployment -ResourceGroupName $identityRG `
 -TemplateFile .\aadds.bicep `
 -pfxCertificatePassword $pfxCertificatePassword `
 -TemplateParameterObject @{
    pfxCertificate = $pfxCertificate;
    domainName = $domainName;
    tags = $tags;
    location = $location
 }

Write-Host "Assuming no errors, AADDS should now be deployed and configured.  You can now join your VMs to the domain."
Write-Host 'Please add Domain Admin users to the "AAD DC Administrators" group in the Azure Portal' -ForegroundColor Yellow