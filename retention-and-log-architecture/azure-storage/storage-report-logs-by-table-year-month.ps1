# Problem solved : How much log data per table over time?
# What it does    : Counts stored logs by table, year, month.
# Requires        : Az.Storage
# Effect          : read-only
# Known issues    : Hard-coded org storage accounts
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

#

$subscriptionId = "ENTRE_AQUI_COM_SEU_ID"

# ResourceGroup/StorageName
$storageAccountNames = @(
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE",
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE",
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE"
)

$yearsToCheck = @("2021", "2022")
$monthsToCheck = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")

$outputPath = "C:\Temp\StoredLogs.csv"

Connect-AzAccount -SubscriptionId $subscriptionId


# MAIN
# Get storage accounts
$storageAccounts = @()
foreach ($storageAccountName in $storageAccountNames) {
    $storageAccounts += Get-AzStorageAccount -ResourceGroupName $storageAccountName.Split("/")[0] -StorageAccountName $storageAccountName.Split("/")[1]
}

# Get containers for each storage account
$storageContainers = @()
foreach ($storageAccount in $storageAccounts) {
    foreach ($container in (Get-AzStorageContainer -Context $storageAccount.Context)) {
        $storageContainers += [PSCustomObject]@{
            StorageAccount = $storageAccount
            Container = $container
        }
    }
}

# Storage containers with logs
$prefixes = @("am-", "insights-logs-", "insights-activity-logs")

# Check stored years and months
$outputReport = [System.Collections.Generic.List[Object]]::new() # Create output file
foreach ($prefix in $prefixes) {
    $containersToCheck = [array]($storageContainers | Where-Object { $_.Container.Name -like "$prefix*" })

    foreach ($container in $containersToCheck) {
        Write-Progress -Activity "Checking containers with '$prefix' prefix..." -Status "$($containersToCheck.IndexOf($container) + 1) / $($containersToCheck.Count) Checking '$($container.Container.Name)'" -PercentComplete (($containersToCheck.IndexOf($container) + 1) / $containersToCheck.Count * 100)

        $logStatus = [PSCustomObject]@{
            Storage = $container.StorageAccount.StorageAccountName
            Container = $container.Container.Name
        }
        $blobs = [array](Get-AzStorageBlob -Container $container.Container.Name -Context $container.StorageAccount.Context)

        foreach ($year in $yearsToCheck) {
            foreach ($month in $monthsToCheck) {
                $logStatus | Add-Member -MemberType NoteProperty -Name "$($year)/$($month)" -Value $false
                foreach ($blobName in $blobs.Name) {
                    if ($blobName -like "*/y=$year/m=$month/d=*") {
                        $logStatus."$($year)/$($month)" = $true
                    }
                }
            }
        }
        $outputReport.Add($logStatus)
    }
    Write-Progress -Activity "Checking containers with '$prefix' prefix..." -Status "Done" -PercentComplete 100
}
$outputReport | Export-CSV -NoTypeInformation -Force $outputPath


# #### Oldsentineleventslogs only
# $storage = Get-AzStorageAccount -ResourceGroupName 'ENTRE_AQUI_COM_SEU_RESOURCE_GROUP' -StorageAccountName 'ENTRE_AQUI_COM_SEU_STORAGE'
# $container = Get-AzStorageContainer -Container 'oldsentineleventslogs' -Context $storage.Context
# $blobs = Get-AzStorageBlob -Container 'oldsentineleventslogs' -Context $storage.Context
# $blobs | select Name, Length, AccessTier, IsDeleted, LastModified | Export-CSV -NoTypeInformation -Force "C:\Temp\StoredLogs-oldsentineleventslogs.csv"
