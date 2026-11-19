# Problem solved : I need to know sensitive columns found vs already labeled.
# What it does    : Exports applied and recommended classifications.
# Requires        : Az.Sql
# Effect          : read-only
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

###
# Install-Module Az
Import-Module Az.Accounts
Import-Module Az.Sql


##
$subscriptionId = "ENTRE_AQUI_COM_SEU_ID"


##
Connect-AzAccount -SubscriptionId $subscriptionId


## MAIN
$sqlServers = Get-AzSqlServer

# List databases for each server
$sqlDatabases = @()
foreach ($sqlServer in $sqlServers) {
    Write-Progress -Id 1 -Activity "Processing servers..." -Status "($($sqlServers.IndexOf($sqlServer)) / $($sqlServers.Count)) Processing server: $($sqlServer.ServerName)" -PercentComplete (($sqlServers.IndexOf($sqlServer) / $sqlServers.Count) * 100)

    $sqlDatabases += Get-AzSqlDatabase -ResourceGroupName $sqlServer.ResourceGroupName -ServerName $sqlServer.ServerName
}
Write-Progress -Id 1 -Completed

# Filter 'Master' databases
$sqlDatabases = $sqlDatabases | Where-Object {$_.DatabaseName -ne 'master'}

$report = @()
foreach ($db in $sqlDatabases) {
    Write-Progress -Id 2 -Activity "Processing databases..." -Status "($($sqlDatabases.IndexOf($db)) / $($sqlDatabases.Count)) Processing database: $($db.DatabaseName)" -PercentComplete (($sqlDatabases.IndexOf($db) / $sqlDatabases.Count) * 100)

    # Get recommendations
    $recommendations = $db | Get-AzSqlDatabaseSensitivityRecommendation

    foreach ($r in $recommendations.SensitivityLabels) {
        Write-Progress -Id 3 -ParentId 2 -Activity "Processing recommendations..." -Status "($($recommendations.SensitivityLabels.IndexOf($r)) / $($recommendations.SensitivityLabels.Count)) Processing recommendation: $($r.ColumnName)" -PercentComplete (($recommendations.SensitivityLabels.IndexOf($r) / $recommendations.SensitivityLabels.Count) * 100)

        $report += [PSCustomObject]@{
            Date = Get-Date -Format "yyyy-MM-dd"
            ServerName = $db.ServerName
            DatabaseName = $db.DatabaseName
            SchemaName = $r.SchemaName
            TableName = $r.TableName
            ColumnName = $r.ColumnName
            InformationType = $r.InformationType
            SensitivityLabel = $r.SensitivityLabel
            Rank = $r.Rank
            Status = "Recommendation"
        }
    }

    # Get applied classifications
    $applied = $db | Get-AzSqlDatabaseSensitivityClassification

    foreach ($a in $applied.SensitivityLabels) {
        Write-Progress -Id 3 -ParentId 2 -Activity "Processing classifications..." -Status "($($applied.SensitivityLabels.IndexOf($a)) / $($applied.SensitivityLabels.Count)) Processing classified item: $($a.ColumnName)" -PercentComplete (($applied.SensitivityLabels.IndexOf($a) / $applied.SensitivityLabels.Count) * 100)

        $report += [PSCustomObject]@{
            Date = Get-Date -Format "yyyy-MM-dd"
            ServerName = $db.ServerName
            DatabaseName = $db.DatabaseName
            SchemaName = $a.SchemaName
            TableName = $a.TableName
            ColumnName = $a.ColumnName
            InformationType = $a.InformationType
            SensitivityLabel = $a.SensitivityLabel
            Rank = $a.Rank
            Status = "Applied"
        }
    }
    Write-Progress -Id 3 -Completed
}
Write-Progress -Id 2 -Completed

# Export to Excel
$report | Export-Excel -WorksheetName "DataClassification"

