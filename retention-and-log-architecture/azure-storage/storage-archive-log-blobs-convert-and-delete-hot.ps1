# Problem solved : Log storage cost is high.
# What it does    : Copies blobs to archive account as Block blobs, tags and deletes from hot.
# Requires        : Az.Storage; Storage Blob Data Contributor
# Effect          : destructive (review and test before use)
# Known issues    : Org storage accounts; troubleshootingMode defaults to true
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

###

$troubleshootingMode = $true # Set to $false to copy blobs to archive, convert to Block type, delete from hot

# $ErrorActionPreference = "Stop"

$subscriptionId = "ENTRE_AQUI_COM_SEU_ID"

# ResourceGroup/StorageName
$storageAccountNames = @(
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE",
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE",
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE"
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE"
    "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE"
)

$destinationStorageAccountName = "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE"

$cutoffDate = (Get-Date).AddDays(-565)

# Connect-AzureAD with managed identity
$null = Connect-AzAccount -identity
$context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
$graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken
$aadToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.windows.net").AccessToken
# $null = Connect-AzureAD -AadAccessToken $aadToken -AccountId $context.Account.Id -TenantId $context.tenant.id

# Connect-AzAccount -SubscriptionId $subscriptionId

## MAIN
$startTime = Get-Date
# Get storage accounts
$storageAccounts = @()
foreach ($storageAccountName in $storageAccountNames) {
    $storageAccounts += Get-AzStorageAccount -ResourceGroupName $storageAccountName.Split("/")[0] -StorageAccountName $storageAccountName.Split("/")[1]
}

$destinationStorageAccount = Get-AzStorageAccount -ResourceGroupName $destinationStorageAccountName.Split("/")[0] -StorageAccountName $destinationStorageAccountName.Split("/")[1]

# Get containers for each storage account
$storageContainers = @()
foreach ($storageAccount in $storageAccounts) {
    foreach ($container in (Get-AzStorageContainer -Context $storageAccount.Context)) {
        $storageContainers += [PSCustomObject]@{
            StorageAccount = $storageAccount
            Container      = $container
        }
    }
}

$storageAccounts.Clear() # Clear storage accounts array to save memory

$outputReport = [System.Collections.Generic.List[Object]]::new() # Create output file

# Check stored diagnostic settings by resource, years and months
$prefixes = @("insights-logs-", "am-", "insights-activity-logs")

$containersToCheck = @()
foreach ($prefix in $prefixes) {
    $containersToCheck += [array]($storageContainers | Where-Object { $_.Container.Name -like "$prefix*" })
}

[System.GC]::Collect()

foreach ($container in $containersToCheck) {
# foreach ($container in $storageContainers) {
    Write-Progress -Id 1 -Activity "Checking container '$($container.Container.Name)'" -Status "Checking blobs" -PercentComplete (($containersToCheck.IndexOf($container) + 1) / $containersToCheck.Count * 100)

    $blobs = $null
    $destinationBlobs = $null

    try {
        $blobs = [System.Collections.ArrayList](Get-AzStorageBlob -Container $container.Container.Name -Context $container.StorageAccount.Context) | Select-Object Name
    } catch {
        try {
            Start-Sleep 3
            $blobs = [System.Collections.ArrayList](Get-AzStorageBlob -Container $container.Container.Name -Context $container.StorageAccount.Context)
        } catch {
            Write-Host "ERROR: $($container.StorageAccount.StorageAccountName)/$($container.Container.Name) --- $($_.Exception.Message)"
        }
    }

    # If container does not exist in destination StorageAccount, create it
    try {
        if ((Get-AzStorageContainer -Context $destinationStorageAccount.Context -Name $container.Container.Name).Length -eq 0) {
            if ($troubleshootingMode -eq $false) {
                New-AzStorageContainer -Context $destinationStorageAccount.Context -Name $container.Container.Name -PublicAccess Off
            }
        } else {
            $destinationBlobs = [System.Collections.ArrayList](Get-AzStorageBlob -Container $container.Container.Name -Context $destinationStorageAccount.Context) | Select-Object Name
        }
    } catch {
        # If the command fails to retrieve any storage, it will throw an error. In this case, create the container
        if ($troubleshootingMode -eq $false) {
            New-AzStorageContainer -Context $destinationStorageAccount.Context -Name $container.Container.Name -PublicAccess Off
        }
    }
    

    # for each blob
    foreach ($blob in $blobs) {
        $temp = ($blob.Name -split("/y="))[1]
        $temp = ($temp -split("/h="))[0]
        $year = ($temp -split("/"))[0]
        $month, $day = ($temp -split("/m="))[1] -split ("/d=")

        $temp = [datetime]::new($year, $month, $day)

        if ($temp -lt $cutoffDate) {
            # Write-Output "Copying from container '$($container.Container.Name)'; Blob '$($blob.Name)'"

            $outputReport.Add([PSCustomObject]@{
                Storage = $container.StorageAccount.StorageAccountName
                Container = $container.Container.Name
                Name = $blob.Name
                CreatedOn = $blob.BlobProperties.CreatedOn
                Status = "Copied"
            })
            
            # Copy blob to destination StorageAccount
            if ($null -ne $destinationBlobs -and $destinationBlobs.IndexOf($blob.Name) -ge 0) {
                    $outputReport[1].Status = "Already exists"
            } else {
                if ($troubleshootingMode -eq $false) {
                    $c = Copy-AzStorageBlob -SrcContainer $container.Container.Name -SrcBlob $blob.Name -Context $container.StorageAccount.Context -DestContainer $container.Container.Name -DestBlob $blob.Name -DestContext $destinationStorageAccount.Context -DestBlobType "Block" -StandardBlobTier Archive

                    # Mark destination blob as copied from
                    $t = Set-AzStorageBlobTag -Context $destinationStorageAccount.Context -Container $container.Container.Name -Blob $blob.Name -Tag @{"CopiedFrom" = "$($container.StorageAccount.StorageAccountName)"}
    
                    # Mark origin blob as copied to archive
                    $t = Set-AzStorageBlobTag -Context $container.StorageAccount.Context -Container $container.Container.Name -Blob $blob.Name -Tag @{"CopiedToArchive" = "true"}
                }
            }
        }
    }
    [System.GC]::Collect()
}

$currentTime = Get-Date
$totalTime = $currentTime - $startTime

Write-Output "Completed in $($currentTime)"
Write-Output "Time elapsed: $($totalTime.Days) days, $(($totalTime.Hours).ToString('00'))h$(($totalTime.Minutes).ToString('00'))m$(($totalTime.Seconds).ToString('00'))s"

if ($outputReport.Count -gt 0) {
    # Create temporary file with the content of the output report
    $tempFile = New-TemporaryFile
    $outputReport | Export-Excel -Path "$($tempFile.FullName)"
    
    # Define storage account and create blob
    $outputStorageName = "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/ENTRE_AQUI_COM_SEU_STORAGE"
    $outputStorage = Get-AzStorageAccount -ResourceGroupName $outputStorageName.Split("/")[0] -StorageAccountName $outputStorageName.Split("/")[1]
    Set-AzStorageBlobContent -Container "01-storage-move-logs" -File "$($tempFile.FullName)" -Blob "MoveLogsToArchive - $($currentTime.ToString('yyyy-MM-dd')).xlsx" -Context $outputStorage.Context -Force
}

# $outputReport | Export-Excel