# Problem solved : Old NSG flow logs settings must be reset before re-onboarding.
# What it does    : Iterates Network Watchers and removes flow log configs (removal commented out).
# Requires        : Az.Network; Network Contributor
# Effect          : destructive (review and test before use)
# Known issues    : Copy-pasted header says host pools; org storage account IDs; NSG flow logs retire in 2027
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

# Clears existing diagnostic settings for the specified all host pools
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

$resourceType = "microsoft.network/networksecuritygroups"

Connect-AzAccount -SubscriptionId $subscriptionId

# MAIN
$azureResources = Get-AzResource -ResourceType $resourceType

$option = Read-Host "Continue configuring NSG Flow Logs? (Y/N) "

if ($option -ne "Y") {
    Write-Host "Stopping..."
    return
}

# Get flow logs configured in the environment
$nws = Get-AzNetworkWatcher
$flowLogsConfigured = @()
foreach ($nw in $nws) {
    $flowLogs = Get-AzNetworkWatcherFlowLog -NetworkWatcher $nw
    foreach ($flowLog in $flowLogs) {
        Write-Progress -Activity "$($flowLogs.IndexOf($flowLog)+1)/$($flowLogs.Count) Getting Flow Logs for subscription '$subscriptionId'" -Status "Getting '$($flowLog.ResourceId)'" -PercentComplete ((($nws.IndexOf($flowLog) + 1) / $flowLogs.Count) * 100)
        $flowLogsConfigured += $flowLog
    }
}
Write-Progress -Activity "Getting Flow Logs for subscription '$subscriptionId'" -Status "DONE" -PercentComplete 100

# Get NSGs in the environment
$nsgs = @()
foreach ($azureResource in $azureResources) {
    Write-Progress -Activity "$($azureResources.IndexOf($azureResource)+1)/$($azureResources.Count) Getting Network Security Groups information for subscription '$subscriptionId'" -Status "Getting '$($azureResource.ResourceId)'" -PercentComplete ((($azureResources.IndexOf($azureResource) + 1) / $azureResources.Count) * 100)
    $nsgs += (Get-AzNetworkSecurityGroup -Name ($azureResource.ResourceId).Split("/")[-1])

}
Write-Progress -Activity "Getting Network Security Groups information for subscription '$subscriptionId'" -Status "DONE" -PercentComplete 100

# For each NSG, check if Flow Logs are enabled
$nsgFlowLogsStatus = @()
foreach ($nsg in $nsgs) {
    $exists = $false
    foreach ($flowLog in $flowLogsConfigured) {
        if ($($flowLog.TargetResourceId).ToLower() -eq $($nsg.Id).ToLower()) {
            $exists = $true
            break
        }    
    }
    # if ($exists -eq $false) { echo "Flow Logs not enabled for $($nsg.Name)" }
    $nsgFlowLogsStatus += [PSCustomObject]@{
        NSG             = $nsg
        FlowLogsEnabled = $exists
        FlowLogsSetting = $flowLog
    }
}

# Remove existing Flow Logs
foreach ($nsg in ($nsgFlowLogsStatus | Where-Object { $_.FlowLogsEnabled -eq $true })) { 
    $networkWatcherName = $nsg.FlowLogsSetting.Id.Split("/")[8]
    $resourceGroupName = $nsg.FlowLogsSetting.Id.Split("/")[4]
    $flowLogName = $nsg.FlowLogsSetting.Id.Split("/")[-1]
    # Remove-AzNetworkWatcherFlowLog -NetworkWatcherName $networkWatcherName -ResourceGroupName $resourceGroupName -Name $flowLogName
}