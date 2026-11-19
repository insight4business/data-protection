# Problem solved : Specific SQL databases must send audit logs to Sentinel.
# What it does    : Creates diagnostic settings to Log Analytics for a list of database resource IDs.
# Requires        : Az.Monitor; Monitoring Contributor
# Effect          : changes-state (review and test before use)
# Known issues    : Database resource ID list is org-specific placeholders; fill in
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

### Clears existing diagnostic settings for the specified resource type
### Recreates them, sending specified logs to Storage and to Sentinel
#

$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

## Constants
$subscriptionId = "ENTRE_AQUI_COM_SEU_ID"
$workspaceResourceGroup = "sentinel"
$workspaceName = "ENTRE_AQUI_COM_SEU_RECURSO"
$diagSettingSentinelName = "DiagLogs_TO_Sentinel"

## Parameters
$databasesToCreate = @(
    "/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/SystemStorage/providers/Microsoft.Sql/servers/ENTRE_AQUI_COM_SEU_RECURSO/databases/sqldb-ENTRE_AQUI_COM_SEU_RECURSO",
    "/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/SystemStorage/providers/Microsoft.Sql/servers/ENTRE_AQUI_COM_SEU_RECURSO/databases/sqldb-ENTRE_AQUI_COM_SEU_RECURSO",
    "/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/SystemStorage/providers/Microsoft.Sql/servers/ENTRE_AQUI_COM_SEU_RECURSO/databases/sqldb-ENTRE_AQUI_COM_SEU_RECURSO",
    "/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/SystemStorage/providers/Microsoft.Sql/servers/ENTRE_AQUI_COM_SEU_RECURSO/databases/sqldb-ENTRE_AQUI_COM_SEU_RECURSO",
    "/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/SystemStorage/providers/Microsoft.Sql/servers/ENTRE_AQUI_COM_SEU_RECURSO/databases/sqldb-ENTRE_AQUI_COM_SEU_RECURSO",
    "/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/SystemStorage/providers/Microsoft.Sql/servers/ENTRE_AQUI_COM_SEU_RECURSO/databases/sqldb-commerce-pay-data-prd",
    "/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/SystemStorage/providers/Microsoft.Sql/servers/ENTRE_AQUI_COM_SEU_RECURSO/databases/sqldb-checking-account-data-prd",
    "/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/SystemStorage/providers/Microsoft.Sql/servers/ENTRE_AQUI_COM_SEU_RECURSO/databases/sqldb-doc-composer-data-prd"
)

##
Connect-AzAccount -SubscriptionId $subscriptionId

# MAIN
$sqlServers = Get-AzResource -ResourceType "Microsoft.Sql/Servers"

$option = Read-Host "Continue recreating Diagnostic Settings for resource type '$($serverType)'? (Y/N) "

if ($option -ne "Y") {
    Write-Host "Stopping..."
    return
}

# Get diagnostic settings for resources
$diagSettings = @()
foreach ($server in $sqlServers) {
    Write-Progress -Id 1 -Activity "($($sqlServers.IndexOf($server)) of $($sqlServers.Count)) Getting settings for servers" -Status "Processing $($server.Name)" -PercentComplete ($sqlServers.IndexOf($server) / $sqlServers.Count * 100)

    $databases = [array](Get-AzSqlDatabase -ResourceGroupName $server.ResourceGroupName -ServerName $server.Name | Where-Object {$_.DatabaseName -ne "master"})

    foreach ($database in $databases) {
        Write-Progress -Id 2 -ParentId 1 -Activity "($($databases.IndexOf($database)) of $($databases.Count)) Getting settings for databases" -Status "Processing $($database.DatabaseName)" -PercentComplete ($databases.IndexOf($database) / $databases.Count * 100)

        if ($database.ResourceId -in $databasesToCreate) {    
            # Get possible log categories for the current resource
            $categories = (Get-AzDiagnosticSettingCategory -ResourceId $database.ResourceId -WarningAction SilentlyContinue)

            # Logs to configure to Sentinel
            $logsToEnable = @("SQLSecurityAuditEvents", "DevOpsOperationsAudit")

            $enableMetrics = @()
            $enableLogs = @()

            foreach ($l in $logsToEnable) {
                $log = $categories | Where-Object {$_.Name -eq $l}

                if ($log.CategoryType -eq "Metrics") {
                    $enableMetrics += (New-AzDiagnosticSettingMetricSettingsObject -Enabled $true -Category $log.Name)
                } else {
                    $enableLogs += (New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category $log.Name)
                }
            }

            Write-Output "Enabling logs for $($server.Name)/$($database.DatabaseName)..."

            $configureSetting = $null

            # $configureSetting = New-AzDiagnosticSetting -Name $diagSettingSentinelName -ResourceId $database.ResourceId -WorkspaceId "/subscriptions/$subscriptionId/resourceGroups/$workspaceResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName" -Log $enableLogs -Metric $enableMetrics -WarningAction SilentlyContinue    

            $setting = Get-AzDiagnosticSetting -ResourceId $database.ResourceId -WarningAction SilentlyContinue

            if ($null -ne $setting.$diagSettingSentinelName) {
                $diagnostic = $null

                $diagnostic = [PSCustomObject]@{
                    ResourceId = $database.ResourceId
                    ResourceName = $database.DatabaseName
                    Location = $database.Location
                    Setting    = $setting
                    SettingName = $setting.Name
                    WorkspaceId = $setting.WorkspaceId
                }
            }
            $diagSettings += $diagnostic
        }
    }
    Write-Progress -Id 2 -Completed
}
Write-Progress -Id 1 -Completed

