# Problem solved : Resources send logs to Sentinel only and I need cheap long-term retention in Storage.
# What it does    : Finds resources with diagnostic settings to Sentinel and adds a second setting to regional Storage.
# Requires        : Az.Monitor; Monitoring Contributor
# Effect          : changes-state (review and test before use)
# Known issues    : DEPRECATED in name; hard-coded org storage accounts. Useful pattern for dual routing
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

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
$diagSettingName = "ENTRE_AQUI_COM_SEU_RECURSO"

Connect-AzAccount -SubscriptionId $subscriptionId

# MAIN
$azureResources = Get-AzResource

# Get diagnostic settings for resources
$diagSettings = @()
foreach ($azureResource in $azureResources) {
    # Try to get diagnostic settings for the resource
    try {
        $setting = Get-AzDiagnosticSetting -ResourceId $azureResource.ResourceId -WarningAction SilentlyContinue
    } catch {
        start-sleep -Seconds 1
        try {
            $setting = Get-AzDiagnosticSetting -ResourceId $azureResource.ResourceId -WarningAction SilentlyContinue
        } catch {
            $setting = $null
            Write-Host "ERROR: $($azureResource.ResourceId) does not have diagnostic settings"
        }
    }

    $diagnostic = [PSCustomObject]@{
        ResourceId = $azureResource.ResourceId
        Location = $azureResource.Location
        Setting    = $setting
    }

    $diagSettings += $diagnostic

    Write-Progress -Activity "$($azureResources.IndexOf($azureResource)+1)/$($azureResources.Count) Getting diagnostic settings" -Status "Getting diagnostic settings for $($azureResource.ResourceId)" -PercentComplete ((($azureResources.IndexOf($azureResource) + 1) / $azureResources.Count) * 100)

    # Break after x ocurrences, for testing
    # if (($azureResources.IndexOf($azureResource) + 1) -eq 150) {
    #     Write-Progress -Activity "Getting diagnostic settings" -Status "Done" -Completed
    #     Break
    # }
}

# Remove extra resources
foreach ($diagSetting in $diagSettings) {
    # Remove resources with no diagnostic settings and master databases
    if (($null -eq $diagSetting.Setting) -or ($diagSetting.ResourceId -like "*/databases/master")) {
        $diagSettings = $diagSettings | Where-Object { $_.ResourceId -ne $diagSetting.ResourceId }
    }
}

# Get only resources with diagnostic settings configured to Sentinel
foreach ($diagSetting in $diagSettings) {
    # Remove resources with no diagnostic settings and master databases
    if ($diagSetting.Setting.WorkspaceId -notlike "*/workspaces/$($workspaceName)*") {
        $diagSettings = $diagSettings | Where-Object { $_.ResourceId -ne $diagSetting.ResourceId }
    }
}

# Analyze remaining resources diagnostic settings
foreach ($diagSetting in $diagSettings) {
    foreach ($setting in $diagSetting.Setting) {
        # if ($null -eq $setting.StorageAccountId -and $null -ne $setting.WorkspaceId) {
        # Logs sent to Sentinel
        if ($setting.WorkspaceId -like "*/workspaces/$($workspaceName)*") {
            # Add categories
            $logsToEnable = @()
            $metricsToEnable = @()

            # If Logs are configured, list logs
            if ($null -ne $setting.Logs) {
                foreach ($log in $setting.Logs) {
                    if ($log.Enabled -eq $true) {
                        $logsToEnable += (New-AzDiagnosticDetailSetting -Log -Category $log.Category -Enabled -WarningAction SilentlyContinue)
                    }
                }
            }

            # If Metrics are configured, list metrics
            if ($null -ne $setting.Metrics) {
                foreach ($metric in $setting.Metrics) {
                    if ($metric.Enabled -eq $true) {
                        $metricsToEnable += (New-AzDiagnosticDetailSetting -Metric -Category $log.Category -Enabled -WarningAction SilentlyContinue)
                    }
                }
            }

            # Define the storage account to use based on the resource location
            if ($diagSetting.Location -eq "eastus") {
                $storageAccountToUse = $storageAccountIdEastUs
            } elseif ($diagSetting.Location -eq "eastus2") {
                $storageAccountToUse = $storageAccountIdEastUs2
            } elseif ($diagSetting.Location -eq "centralus") {
                $storageAccountToUse = $storageAccountIdCentralUs
            } else {
                $storageAccountToUse = $null
            }

            # If there are logs to enable
            if ($logsToEnable.Count -ne 0) { 
                $configureSetting = New-AzDiagnosticSetting -Name $diagSettingName -ResourceId $diagSetting.ResourceId -StorageAccountId $storageAccountToUse -Setting $logsToEnable
                # Set-AzDiagnosticSetting -InputObject $configureSetting
            }

            # If there are metrics to enable
            if ($metricsToEnable.Count -ne 0) {
                $configureSetting = New-AzDiagnosticSetting -Name $diagSettingName -ResourceId $diagSetting.ResourceId -StorageAccountId $storageAccountToUse -Setting $metricsToEnable
                # Set-AzDiagnosticSetting -InputObject $configureSetting
            }

            Write-Host "$($diagSetting.ResourceId) - $($logsToEnable.Category -join ",") - $($metricsToEnable.Category -join ",")"
        }
    }
}




# ## Apenas para teste (condição If DiagSettings > Sentinel)
# $psObj = @()
# foreach ($ds in $diagSettings) {
#     foreach ($s in $ds.Setting) {
#         if ($null -ne $s.WorkspaceId) {
#             $WorkspaceId = ($s.WorkspaceId).Replace("/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourcegroups/", "")
#         } else {
#             $WorkspaceId = $null
#         }

#         if ($null -ne $s.StorageAccountId) {
#             $StorageAccountId = ($s.StorageAccountId).Replace("/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/", "")
#         } else {
#             $StorageAccountId = $null
#         }

#         $psObj += [PSCustomObject]@{
#             ResourceId = ($ds.ResourceId).Replace("/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/", "")
#             Workspace = $WorkspaceId
#             Storage = $StorageAccountId
#         }
#     }
# }