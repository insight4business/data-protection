# Problem solved : I need to standardize diagnostic settings (Storage + Sentinel) for a chosen resource type.
# What it does    : Prompts for a resource type, clears existing diagnostic settings and recreates them to regional Storage and Log Analytics.
# Requires        : Az.Monitor; Monitoring Contributor
# Effect          : destructive (review and test before use)
# Known issues    : File name has DEPRECATED; kept as the generic template. Hard-coded org storage account IDs (ENTRE_AQUI_COM_SEU_RESOURCE_GROUP*) and workspace values must be parameterized
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

# Clears existing diagnostic settings for the specified resource type
# Recreates them, sending specified logs to Storage and to Sentinel
#

# Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
# Update-AzConfig -DisplayBreakingChangeWarning $false
$WarningPreference = "SilentlyContinue"

# Constants
$subscriptionId = "ENTRE_AQUI_COM_SEU_ID"
$storageAccountIdEastUs = "/subscriptions/$subscriptionId/resourceGroups/ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/ENTRE_AQUI_COM_SEU_STORAGE"
$storageAccountIdEastUs2 = "/subscriptions/$subscriptionId/resourceGroups/ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/ENTRE_AQUI_COM_SEU_STORAGE"
$storageAccountIdCentralUs = "/subscriptions/$subscriptionId/resourceGroups/ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/ENTRE_AQUI_COM_SEU_STORAGE"
$workspaceResourceGroup = "sentinel"
$workspaceName = "ENTRE_AQUI_COM_SEU_RECURSO"
$diagSettingStorageName = "DiagLogs_TO_Storage"
$diagSettingSentinelName = "DiagLogs_TO_Sentinel"

Connect-AzAccount -SubscriptionId $subscriptionId


# MAIN
$resourceType = Read-Host "Insert resource type (ex. 'microsoft.web/sites')"
$azureResources = Get-AzResource -ResourceType $resourceType

$option = Read-Host "Continue recreating Diagnostic Settings for resource type '$($resourceType)'? (Y/N) "

if ($option -ne "Y") {
    Write-Host "Stopping..."
    return
}

# Get diagnostic settings for resources
$diagSettings = @()
foreach ($resource in $azureResources) {
    # Try to get diagnostic settings for the resource
    try {
        $setting = Get-AzDiagnosticSetting -ResourceId $resource.ResourceId -WarningAction SilentlyContinue
    } catch {
        start-sleep -Seconds 1
        try {
            $setting = Get-AzDiagnosticSetting -ResourceId $resource.ResourceId -WarningAction SilentlyContinue
        } catch {
            $setting = $null
            Write-Host "ERROR: $($resource.ResourceId) does not have diagnostic settings"
        }
    }

    $diagnostic = [PSCustomObject]@{
        ResourceId = $resource.ResourceId
        Location = $resource.Location
        Setting    = $setting
        SettingName = $setting.Name
        WorkspaceId = $setting.WorkspaceId
        StorageAccountId = $setting.StorageAccountId
    }

    $diagSettings += $diagnostic

    Write-Progress -Activity "$($azureResources.IndexOf($resource)+1)/$($azureResources.Count) Getting diagnostic settings" -Status "Getting diagnostic settings for '$($resource.ResourceId)'" -PercentComplete ((($azureResources.IndexOf($resource) + 1) / $azureResources.Count) * 100)
}
Write-Progress -Activity "Getting diagnostic settings" -Status "DONE" -PercentComplete 100

# # Clear diagnostic settings
# foreach ($diagSetting in $diagSettings) {
#     Write-Progress -Activity "$($diagSettings.IndexOf($diagSetting)+1)/$($diagSettings.Count) Clearing Diagnostic Settings" -Status "Clearing $($diagSetting.ResourceId)" -PercentComplete ((($diagSettings.IndexOf($diagSetting) + 1) / $diagSettings.Count) * 100)

#     # Remove resources with no diagnostic settings
#     if ($null -eq $diagSetting.Setting) {
#         $diagSettings = $diagSettings | Where-Object { $_.ResourceId -ne $diagSetting.ResourceId }
#     } else {
#         # Clear current diagnostic settings if existing
#         # Remove-AzDiagnosticSetting -Name "$($diagSetting.Setting.Name)" -ResourceId $diagSetting.ResourceId -WarningAction SilentlyContinue
#     }
# }
# Write-Progress -Activity "Clearing Diagnostic Settings" -Status "DONE" -PercentComplete 100

$errorList = @()
# Recreate diagnostic settings
foreach ($resource in $azureResources) {
    Write-Progress -Activity "$($azureResources.IndexOf($resource)+1)/$($azureResources.Count) Configuring new Diagnostic Settings" -Status "Setting diagnostic settings for $($resource.ResourceId)" -PercentComplete ((($azureResources.IndexOf($resource) + 1) / $azureResources.Count) * 100)
    
    # Get possible log categories for the current resource
    $categories = (Get-AzDiagnosticSettingCategory -TargetResourceId $resource.ResourceId -WarningAction SilentlyContinue)
    # $categories = (Get-AzDiagnosticSettingCategory -TargetResourceId $azureResources[0].ResourceId -WarningAction SilentlyContinue)

    $configureSetting = $null
    
    # Define the storage account to use based on the resource location
    if ($resource.Location -eq "eastus") {
        $storageAccountToUse = $storageAccountIdEastUs
    } elseif ($resource.Location -eq "eastus2") {
        $storageAccountToUse = $storageAccountIdEastUs2
    } elseif ($resource.Location -eq "centralus") {
        $storageAccountToUse = $storageAccountIdCentralUs
    } else {
        $storageAccountToUse = $null
    }

    # $enable = @()
    
    # # default audit logs to configure Sentinel
    # $logsToEnable = @("Checkpoint", "Error", "Management")

    # foreach ($l in $logsToEnable) {
    #     $enable += (New-AzDiagnosticDetailSetting -Log -Category $l -Enabled -WarningAction SilentlyContinue)
    # }

    # # Set new diagnostic settings for Sentinel
    # $configureSetting = New-AzDiagnosticSetting -Name $diagSettingSentinelName -ResourceId $resource.ResourceId -WorkspaceId "/subscriptions/$subscriptionId/resourceGroups/$workspaceResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName" -Setting $enable -WarningAction SilentlyContinue
    # $result = Set-AzDiagnosticSetting -InputObject $configureSetting -WarningAction SilentlyContinue

    # Write-Host "DONE: Set Sentinel diagnostic settings for '$($resource.ResourceId)'"


    # Enable all logs to Storage
    $enable = @()
    foreach ($c in ($categories | Where-Object {$_.CategoryType -eq "Logs"})) {
        $enable += (New-AzDiagnosticDetailSetting -Log -Category $c.Name -Enabled -WarningAction SilentlyContinue)
    }

    # Set new diagnostic settings for Storage
    $configureSetting = New-AzDiagnosticSetting -Name $diagSettingStorageName -ResourceId $resource.ResourceId -StorageAccountId $storageAccountToUse -Setting $enable -WarningAction SilentlyContinue
    try {
        $result = Set-AzDiagnosticSetting -InputObject $configureSetting -WarningAction SilentlyContinue
    } catch {
        $errorList += [PSCustomObject]@{
            ResourceId = $resource.ResourceId
            Error = $_
            Result = $result
        }
        Write-Host "ERROR: $($resource.ResourceId) - $($result)"
    }

    Write-Host "DONE: Set Storage diagnostic settings for '$($resource.ResourceId)'"
}
Write-Progress -Activity "Configuring new Diagnostic Settings" -Status "DONE" -PercentComplete 100
