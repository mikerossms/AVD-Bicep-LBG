param (
    [String]$subID = "152aa2a3-2d82-4724-b4d5-639edab485af",
    [Bool]$dologin = $true
)

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

#Assign the Azure Virtual Desktop Power On/Off contributor to the subscription
$objId = (Get-AzADServicePrincipal -AppId "9cdead84-a844-4324-93f2-b2e6bb768d07").Id
New-AzRoleAssignment -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" -ObjectId $objId -Scope /subscriptions/$subId
