<#
.SYNOPSIS
Deploys the bicep code to the subscription

.DESCRIPTION
To add
#>

#Get the runtime parameters from the user
param (
    [String]$uniqueIdentifier = "001",
    [String]$location = "uksouth",
    [String]$localEnv = "dev",
    [String]$subID = "8eef5bcc-4fc3-43bc-b817-048a708743c3",
    [String]$workloadNameAVD = "avd",
    [String]$workloadNameDiag = "diag",
    [Bool]$dologin = $true
)


$diagRGName = "rg-$workloadNameDiag-$location-$localEnv-$uniqueIdentifier"
$avdRGName = "rg-$workloadNameAVD-$location-$localEnv-$uniqueIdentifier"

$domainName = "lbgworkshop.local"
$domainAdminUsername = "commander"
$domainAdminPassword = Read-Host -Prompt "Enter the Domain Admin password" -AsSecureString
$localAdminUsername = "localadmin"
$localAdminPassword = Read-Host -Prompt "Enter the Local Admin password" -AsSecureString

$avdVnetCIDR = "10.220.1.0/24"
$avdSnetCIDR = $avdVnetCIDR

$adServerIPAddresses = @(
  '10.230.0.5'
  '10.230.0.6'
)

$tags = @{
    Environment=$localEnv
    Owner="LBG"
}

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
if (-not (Get-AzResourceGroup -Name $diagRGName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Resource Group: $diagRGName" -ForegroundColor Green
    if (-not (New-AzResourceGroup -Name $diagRGName -Location $location)) {
        Write-Host "ERROR: Cannot create Resource Group: $diagRGName" -ForegroundColor Red
        exit 1
    }
}

#Deploy the diagnostic.bicep code to that RG we just created
Write-Host "Deploying diagnostic.bicep to Resource Group: $diagRGName" -ForegroundColor Green
$diagOutput = New-AzResourceGroupDeployment -Name "Deploy-Diagnostics" -ResourceGroupName $diagRGName -TemplateFile "$PSScriptRoot/../Bicep/diagnostics.bicep" -Verbose -TemplateParameterObject @{
    location=$location
    localEnv=$localEnv
    tags=$tags
    workloadName=$workloadNameDiag
    uniqueName=$uniqueIdentifier
}

if (-not $diagOutput ) {
    Write-Host "ERROR: Cannot deploy diagnostic.bicep to Resource Group: $diagRGName" -ForegroundColor Red
    exit 1
}


#Create a resource group for the AVD resources if it does not already exist then check it has been created successfully
if (-not (Get-AzResourceGroup -Name $avdRGName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Resource Group: $avdRGName" -ForegroundColor Green
    if (-not (New-AzResourceGroup -Name $avdRGName -Location $location)) {
        Write-Host "ERROR: Cannot create Resource Group: $avdRGName" -ForegroundColor Red
        exit 1
    }
}

#Deploy the AVD backplane bicep code.
Write-Host "Deploying backplane.bicep to Resource Group: $avdRGName" -ForegroundColor Green
$backplaneOutput = New-AzResourceGroupDeployment -Name "Deploy-Backplane" `
 -ResourceGroupName $avdRGName `
 -TemplateFile "$PSScriptRoot/../Bicep/backplane.bicep" `
 -domainAdminPassword $domainAdminPassword `
 -localAdminPassword $localAdminPassword `
 -Verbose `
 -TemplateParameterObject @{
    location=$location
    localEnv=$localEnv
    uniqueName=$uniqueIdentifier
    tags=$tags
    workloadName=$workloadNameDiag
    rgAVDName=$avdRGName
    rgDiagName=$diagRGName
    lawName=$diagOutput.Outputs.lawName.Value
    bootDiagStorageName=$diagOutput.Outputs.bootDiagStorageName.Value
    domainName=$domainName
    domainAdminUsername=$domainAdminUsername
    localAdminUsername=$localAdminUsername
    avdVnetCIDR=$avdVnetCIDR
    avdSnetCIDR=$avdSnetCIDR
    adServerIPAddresses=$adServerIPAddresses
}

