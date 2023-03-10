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

#>

#IMPORTANT: $domainName MUST match a domain name in Azure AD
#Get the runtime parameters from the user
param (
    [String]$domainName = 'lbgworkshop.local',
    [String]$identityRG = "rg-identity",
    [String]$location = "uksouth",
    [String]$subID = "8eef5bcc-4fc3-43bc-b817-048a708743c3",
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