# Problem solved : I need to confirm every SQL server/database has auditing and diagnostics.
# What it does    : Reports auditing and diagnostic settings for all SQL servers and databases.
# Requires        : Az.Sql, Az.Monitor
# Effect          : read-only
# Known issues    : Comments carry org subscription names
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

###
# Install-Module Az
Import-Module Az

$ErrorActionPreference = 'Stop'
# $WarningPreference = 'SilentlyContinue'

# $subscriptionId = "ENTRE_AQUI_COM_SEU_ID" # ENTRE_AQUI_COM_SEU_CLIENTE Corp
$subscriptionId = "ENTRE_AQUI_COM_SEU_ID" # Dev

$currentDate = Get-Date -Format "yyyy-MM-dd"
$outputFilePath = "c:\Temp\Azure Resources Diagnotic\$currentDate - azureResourcesDiagosticSettings - $subscriptionId"


## Main
Connect-AzAccount -SubscriptionId $subscriptionId

##
$servers = Get-AzResource -ResourceType "Microsoft.Sql/servers"

$outputReport = [System.Collections.Generic.List[Object]]::new() # Create output file
foreach ($sqlServer in $servers) {
    Write-Progress -Id 1 -Activity "Processing SQL Servers" -Status "($($servers.IndexOf($sqlServer)) of $($servers.Count)) Processing SQL Server '$($sqlServer.Name)'" -PercentComplete (($($servers.IndexOf($sqlServer)) / $($servers.Count)) * 100)

    $databases = $null
    $databases = Get-AzSqlDatabase -ServerName $sqlServer.Name -ResourceGroupName $sqlServer.ResourceGroupName

    $serverAuditing = Get-AzSqlServerAudit -ResourceGroupName $sqlServer.ResourceGroupName -ServerName $sqlServer.Name

    $outputReport.Add([PSCustomObject]@{
        ResourceType                              = $sqlServer.ResourceType
        ResourceGroupName                         = $sqlServer.ResourceGroupName
        ResourceName                              = $sqlServer.Name
        ResourceLocation                          = $sqlServer.Location
        ResourceId                                = $sqlServer.ResourceId
        DiagnosticSettingsStorageAccountName      = $null
        DiagnosticSettingsStorageAccountId        = $null
        DiagnosticSettingsStorageAccountMetrics   = $null
        DiagnosticSettingsStorageAccountLogs      = $null
        DiagnosticSettingsLogAnalyticsName        = $null
        DiagnosticSettingsLogAnalyticsWorkspaceId = $null
        DiagnosticSettingsLogAnalyticsMetrics     = $null
        DiagnosticSettingsLogAnalyticsLogs        = $null
        AuditingStorageEnabled                    = $serverAuditing.BlobStorageTargetState
        AuditingStorageAccountResourceId          = $serverAuditing.StorageAccountResourceId
        AuditingLogAnalyticsEnabled               = $serverAuditing.LogAnalyticsTargetState
        AuditingLogAnalyticsWorkspaceResourceId   = $serverAuditing.WorkspaceResourceId
        Tags                                      = "Environment: $($sqlServer.Tags.Environment)"
    })

    foreach ($sqlDatabase in ($databases | Where-Object { $_.DatabaseName -ne "master" })) {
        Write-Progress -Id 2 -ParentId 1 -Activity "Processing SQL Databases" -Status "($($databases.IndexOf($sqlDatabase)) of $($databases.Count)) Processing SQL Database '$($sqlDatabase.DatabaseName)'" -PercentComplete (($($databases.IndexOf($sqlDatabase)) / $($databases.Count)) * 100)

        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $sqlDatabase.ResourceId

        $databaseAuditing = Get-AzSqlDatabaseAudit -ResourceGroupName $sqlDatabase.ResourceGroupName -ServerName $sqlServer.Name -DatabaseName $sqlDatabase.DatabaseName

        $outputReport.Add([PSCustomObject]@{
            ResourceType                              = "Database"
            ResourceGroupName                         = $sqlDatabase.ResourceGroupName
            ResourceName                              = $sqlDatabase.DatabaseName
            ResourceLocation                          = $sqlDatabase.Location
            ResourceId                                = $sqlDatabase.ResourceId
            DiagnosticSettingsStorageAccountName      = $null
            DiagnosticSettingsStorageAccountId        = $null
            DiagnosticSettingsStorageAccountMetrics   = $null
            DiagnosticSettingsStorageAccountLogs      = $null
            DiagnosticSettingsLogAnalyticsName        = $null
            DiagnosticSettingsLogAnalyticsWorkspaceId = $null
            DiagnosticSettingsLogAnalyticsMetrics     = $null
            DiagnosticSettingsLogAnalyticsLogs        = $null
            AuditingStorageEnabled                    = $databaseAuditing.BlobStorageTargetState
            AuditingStorageAccountResourceId          = $databaseAuditing.StorageAccountResourceId
            AuditingLogAnalyticsEnabled               = $databaseAuditing.LogAnalyticsTargetState
            AuditingLogAnalyticsWorkspaceResourceId   = $databaseAuditing.WorkspaceResourceId
            Tags                                      = "Environment: $($sqlDatabase.Tags.Environment)"
        })

        if ($null -ne $diagnosticSettings) {
            foreach ($diag in $diagnosticSettings) {
                if ($null -ne $diag.WorkspaceId) {
                    $outputReport[-1].DiagnosticSettingsLogAnalyticsName = $diag.Name
                    $outputReport[-1].DiagnosticSettingsLogAnalyticsWorkspaceId = $diag.WorkspaceId

                    # List enabled metrics and logs
                    $metrics = ""
                    foreach ($m in $diag.Metrics) {
                        if ($m.Enabled -eq $true) {
                            $metrics = $metrics + $m.Category + "; "
                        }
                    }

                    $logs = ""
                    foreach ($l in $diag.Logs) {
                        if ($l.Enabled -eq $true) {
                            $logs = $logs + $l.Category + "; "
                        }
                    }

                    $outputReport[-1].DiagnosticSettingsLogAnalyticsMetrics = $metrics
                    $outputReport[-1].DiagnosticSettingsLogAnalyticsLogs = $logs
                }

                if ($null -ne $diag.StorageAccountId) {
                    $outputReport[-1].DiagnosticSettingsStorageAccountName = $diag.Name
                    $outputReport[-1].DiagnosticSettingsStorageAccountId = $diag.StorageAccountId
                    
                    # List enabled metrics and logs
                    $metrics = ""
                    foreach ($m in $diag.Metrics) {
                        if ($m.Enabled -eq $true) {
                            $metrics = $metrics + $m.Category + "; "
                        }
                    }

                    $logs = ""
                    foreach ($l in $diag.Logs) {
                        if ($l.Enabled -eq $true) {
                            $logs = $logs + $l.Category + "; "
                        }
                    }

                    $outputReport[-1].DiagnosticSettingsStorageAccountMetrics = $metrics
                    $outputReport[-1].DiagnosticSettingsStorageAccountLogs = $logs
                }
            }
        }
    }
    Write-Progress -Id 2 -ParentId 1 -Activity "Processing SQL Databases" -Completed

}
Write-Progress -Id 1 -Activity "Processing SQL Servers" -Completed

$outputReport | Export-Excel
