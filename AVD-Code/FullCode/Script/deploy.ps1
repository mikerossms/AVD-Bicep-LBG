<#
.SYNOPSIS
Deploys the bicep code to the subscription

.DESCRIPTION
To add
#>

#Get the runtime parameters from the user

$uniqueIdentifier = "001"
$location = "uksouth"
$localEnv = "dev"
$workloadNameAVD = "avd"
$workloadNameDiag = "diag"
$diagRGName = "rg-$workloadNameDiag-$location-$localEnv-$uniqueIdentifier"
$avdRGName = "rg-$workloadNameAVD-$location-$localEnv-$uniqueIdentifier"

#Log into Azure


#Create the diagnostics RG if it does not already exist
#Deploy the diagnostic bicep code

#Create the AVD ResourceGroup if it does not already exist
#Deploy the AVD backplane bicep code.
