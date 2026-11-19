# Problem solved : What logs are stored per resource per day?
# What it does    : Counts and sizes of stored log blobs by table, resource, month and day.
# Requires        : Az.Storage
# Effect          : read-only
# Known issues    : Hard-coded org storage accounts and year
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

#

$subscriptionId = "ENTRE_AQUI_COM_SEU_ID"

# ResourceGroup/StorageName
$storageAccountNames = @(
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE",
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE",
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE"
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE"
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE"
)

# Year and Month to check (single month)
$yearToCheck = "2024"
$monthToCheck = "07"

$currentDay = Get-Date -Format "yyyy-MM-dd"
$outputPath = "C:\Temp\$yearToCheck-$monthToCheck - StoredDiagnosticSettingsByResources - Generated $currentDay"
# $outputPath = "$env:HOME\Temp\$yearToCheck-$monthToCheck - StoredDiagnosticSettingsByResources - Generated $currentDay"  # Path for Azure Cloud Shell

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

$outputReport = [System.Collections.Generic.List[Object]]::new() # Create output file
$startTime = Get-Date

# Check stored diagnostic settings by resource, years and months
# $prefix = "insights-logs-"
$prefixes = @("insights-logs-", "am-", "insights-activity-logs")

foreach ($prefix in $prefixes) {
    $prefixStartTime = Get-Date

    $containersToCheck = [array]($storageContainers | Where-Object { $_.Container.Name -like "$prefix*" })

    foreach ($container in $containersToCheck) {
        $counter = $containersToCheck.IndexOf($container) + 1
        $current = ($container.Container.Name).Replace("$prefix", "")

        # Calculate remaining time
        $elapsedTime = (Get-Date) - $prefixStartTime
        $timeLeft = [TimeSpan]::FromMilliseconds((($elapsedTime.TotalMilliseconds / $counter) * ($containersToCheck.Count - $counter)))

        Write-Progress -Activity "Checking '$prefix'..." -Id 1 -Status "$($counter) / $($containersToCheck.Count) '$current'. Remaining: $($timeLeft.Days) days, $(($timeLeft.Hours).ToString('00'))h$(($timeLeft.Minutes).ToString('00'))m$(($timeLeft.Seconds).ToString('00'))s..." -PercentComplete (($counter) / $containersToCheck.Count * 100)
        Write-Progress -Activity "Checking blobs..." -ParentId 1 -Status "Waiting blobs for '$($container.Container.Name)'" -PercentComplete 0
        
        # Get blob list with Name, Size(bytes) and last modified date
        try {
            $blobs = [array](Get-AzStorageBlob -Container $container.Container.Name -Context $container.StorageAccount.Context -Blob "*/y=$yearToCheck/m=$monthToCheck/d=*") | Select-Object Name, Length, LastModified
        } catch {
            try {
                Start-Sleep 3
                $blobs = [array](Get-AzStorageBlob -Container $container.Container.Name -Context $container.StorageAccount.Context -Blob "*/y=$yearToCheck/m=$monthToCheck/d=*") | Select-Object Name, Length, LastModified
            } catch {
                Write-Host "ERROR: $($container.StorageAccount.StorageAccountName)/$($container.Container.Name) --- $($_.Exception.Message)"
            }
        }

        # Get only unique blobnames, based on year, month and day only, all lowercase
        $uniqueBlobsNames = [array]($blobs.Name)
        foreach ($name in $uniqueBlobsNames) {
            $uniqueBlobsNames[$uniqueBlobsNames.IndexOf($name)] = ($name -split "/h=")[0].ToLower()
        }
        $uniqueBlobsNames = [array]($uniqueBlobsNames | Select-Object -Unique)

        $blobsToCheck = [array]($uniqueBlobsNames)

        # for each blob name, if it contains the year and month to check
        foreach ($blobName in $blobsToCheck) {
            $current = ($container.Container.Name).Replace("$prefix", "")

            # Calculate remaining time
            $elapsedTime = (Get-Date) - $prefixStartTime
            $timeLeft = [TimeSpan]::FromMilliseconds((($elapsedTime.TotalMilliseconds / $counter) * ($containersToCheck.Count - $counter)))
            
            Write-Progress -Activity "Checking '$prefix'..." -Id 1 -Status "$($counter) / $($containersToCheck.Count) '$current'. Estimated time remaining: $($timeLeft.Days) days, $(($timeLeft.Hours).ToString('00'))h$(($timeLeft.Minutes).ToString('00'))m$(($timeLeft.Seconds).ToString('00'))s..." -PercentComplete (($counter) / $containersToCheck.Count * 100)
            Write-Progress -Activity "Checking blobs..." -ParentId 1 -Status "$($blobsToCheck.IndexOf($blobName) + 1) / $($blobsToCheck.Count) Checking blobs for '$($container.Container.Name)'" -PercentComplete (($blobsToCheck.IndexOf($blobName) + 1) / $blobsToCheck.Count * 100)

            $logStatus = $null
            # Create object to store data
            $logStatus = [PSCustomObject]@{
                Storage = $container.StorageAccount.StorageAccountName
                Container = $container.Container.Name
                resourceExists = $false
                resourceId = (($blobName -split "/y=")[0] -split "resourceid=")[1]
                resourceResourceGroup = ($blobName -split "resourcegroups/")[-1].Split("/")[0]
                resourceName = ($blobName -split "/y=")[0].Split("/")[-1]
            }

            $logStatus | Add-Member -MemberType NoteProperty -Name "resourceType" -Value ((($blobName -split "providers/")[-1] -split "/y=")[0] -split $logStatus.resourceName)[0].TrimEnd("/")

            # Fix logic apps ID
            if ($logStatus.resourceType -eq "microsoft.logic/workflows") {
                $logStatus.resourceId = (($blobName -split "/y=")[0] -split "workflowid=")[1]
            # Fix AAD Logs
            } elseif ($null -eq $logStatus.resourceId -and $logStatus.resourceName -like "tenantid=*") {
                $logStatus.resourceId = $logStatus.resourceName.Split("=")[1]
                $logStatus.resourceResourceGroup = "Azure Active Directory"
                $logStatus.resourceName = "Azure Active Directory"
                $logStatus.resourceType = "Azure Active Directory"
            }

            # If resource is not in the report object yet, add new object, else edit existing object
            $objectExists = $null
            $objectExists = $outputReport | Where-Object { $_.Storage -eq $logStatus.Storage `
                -and $_.Container -eq $logStatus.Container `
                -and $_.resourceResourceGroup -eq $logStatus.resourceResourceGroup `
                -and $_.resourceType -eq $logStatus.resourceType `
                -and $_.resourceName -eq $logStatus.resourceName }
            
            $daysInMonth = [datetime]::DaysInMonth($yearToCheck,$monthToCheck)
            if ($null -eq $objectExists) {
                # Check if logs exist for year and month
                foreach ($day in (1..$daysInMonth)) {
                    $day = $day.ToString("00")
                    $logStatus | Add-Member -MemberType NoteProperty -Name "$yearToCheck-$monthToCheck-$day" -Value $false
                    if ($blobName -like "*/y=$yearToCheck/m=$monthToCheck/d=$day*") {
                        $logStatus."$yearToCheck-$monthToCheck-$day" = $true
                    }
                }
                $outputReport.Add($logStatus)
            } else {
                foreach ($day in (1..$daysInMonth)) {
                    $day = $day.ToString("00")
                    if ($blobName -like "*/y=$yearToCheck/m=$monthToCheck/d=$day*") {
                        $objectExists."$yearToCheck-$monthToCheck-$day" = $true
                        break
                    }
                }
            }
        }
        Write-Progress -Activity "Checking blobs..." -ParentId 1 -Status "DONE: $($container.Container.Name)" -PercentComplete 100
    }

    if ($prefix -eq "insights-logs-") {
        # Check if resource still exists
        $azureResources = Get-AzResource

        foreach ($object in $outputReport) {
            Write-Progress -Activity "Checking if resources exist..." -Id 1 -Status "Checking '$($object.ResourceName)'..."  -PercentComplete (($outputReport.IndexOf($object) + 1) / $outputReport.Count * 100)
            foreach ($resourceId in ($azureResources.ResourceId).ToLower()) {
                if ($object.resourceId -eq $resourceId) {
                    $object.resourceExists = $true
                    break
                }
            }
        }
        Write-Progress -Activity "Checking if resources exist..." -Id 1 -Status "DONE" -PercentComplete 100
    }
    Write-Progress -Activity "Checking '$prefix'..." -Id 1 -Status "DONE" -PercentComplete 100
}

$currentTime = Get-Date
$totalTime = $currentTime - $startTime

Write-Host "Completed in $($currentTime)"
Write-Host "Time elapsed: $($totalTime.Days) days, $(($totalTime.Hours).ToString('00'))h$(($totalTime.Minutes).ToString('00'))m$(($totalTime.Seconds).ToString('00'))s"
Write-Output "Completed in $($currentTime)" >> "$outputPath-Log.txt"
Write-Output "Time elapsed: $($totalTime.Days) days, $(($totalTime.Hours).ToString('00'))h$(($totalTime.Minutes).ToString('00'))m$(($totalTime.Seconds).ToString('00'))s" >> "$outputPath-Log.txt"

$outputReport | Export-CSV -NoTypeInformation -Force "$outputPath.csv"
$outputReport | Export-Excel "$outputPath.xlsx"
