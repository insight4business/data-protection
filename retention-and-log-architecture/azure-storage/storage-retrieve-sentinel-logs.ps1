# Problem solved : I need to query old logs exported to Storage.
# What it does    : Downloads blobs by table/time from storage and consolidates them.
# Requires        : Az.Storage
# Effect          : read-only
# Known issues    : Warning: very slow; hard-coded workspace path
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

### WARNING: Really slow script. Use with caution.
### Script downloads file by file from Azure Storage Account, so it may take hours depending on the amount of data.

# Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
# Update-AzConfig -DisplayBreakingChangeWarning $false

# Constants
$subscriptionId = "ENTRE_AQUI_COM_SEU_ID"
$workspaceResourceGroup = "sentinel"
$workspaceName = "ENTRE_AQUI_COM_SEU_RECURSO"

$contentPath = "WorkspaceResourceId=\subscriptions\$($subscriptionId)\resourcegroups\$($workspaceResourceGroup)\providers\microsoft.operationalinsights\workspaces\$($workspaceName)"

# Parameters
# Paths
# $downloadPath = "$env:USERPROFILE\Desktop\storage_logs"
# $outputFile = "$downloadPath\storage_accounts_logs.csv"
$downloadPath = "C:\Temp\storage_logs"
$outputFile = "C:\Temp\storage_accounts_logs.csv"

$storageAccountName = "ENTRE_AQUI_COM_SEU_STORAGE"
$tables = @("am-Usage")

# month between 01 and 12
# day between 00 and 31
$logStart = [PSCustomObject]@{
    Year = "2022"
    Month = "07"
    Day = "01"
}
$logStop = [PSCustomObject]@{
    Year = "2022"
    Month = "12"
    Day = "01"
}


# MAIN
# Create output directory and file
if ((Test-Path $outputFile) -eq $false) {
    New-Item -Path $downloadPath -ItemType "directory"
    New-Item -Path $outputFile -ItemType "file"
}

# Create download directories
foreach ($table in $tables) {
    if ((Test-Path "$downloadPath\$table") -eq $false) {
        New-Item -Path "$downloadPath\$table" -ItemType "directory"
    }
}

# Connect-AzAccount
Connect-AzAccount -SubscriptionId $subscriptionId

# Get storage
$storage = (Get-AzStorageAccount) | Where-Object { $_.StorageAccountName -eq $storageAccountName }

$storageContainers = @()
foreach ($table in $tables) {
    $storageContainers += Get-AzStorageContainer -Name "$($table.ToLower())" -Context $storage.Context
}

# Get blobs within the specified time range
$resultBlobs = @()
foreach ($storageContainer in $storageContainers) {
    Write-Progress -Activity "Getting containers..." -Status "$(($storageContainers.IndexOf($storageContainer) + 1) / $storageContainers.Count) Downloading '$($storageContainer)/$($storageContainer.Name)'" -PercentComplete (($storageContainers.IndexOf($storageContainer) + 1) / $storageContainers.Count * 100)

    $containerBlobs = Get-AzStorageBlob -Container $storageContainer.Name -Context $storage.Context

    foreach ($blob in $containerBlobs) {
        # If date is valid
        if (([int]$logStart.Year -ge 2022 -and ([int]($logStart.Month) -ge 1 -and [int]$logStart.Month -le 12) `
        -and ([int]$logStart.Day -ge 1 -and [int]$logStart.Day -le 31)) `
        -and ([int]$logStop.Year -ge 2022 -and ([int]($logStop.Month) -ge 1 -and [int]$logStop.Month -le 12) `
        -and ([int]$logStop.Day -ge 1 -and [int]$logStop.Day -le 31))) {
            
            $minDate = [datetime]"$($logStart.Year)/$($logStart.Month)/$($logStart.Day)"
            $maxDate = ([datetime]"$($logStop.Year)/$($logStop.Month)/$($logStop.Day)").AddDays(1)

            $blobNameSplit = $blob.Name.Split("/")
            # If blob date is between min and max date
            $blobDate = [PSCustomObject]@{
                Year = $blobNameSplit[-6].Replace("y=","")
                Month = $blobNameSplit[-5].Replace("m=","")
                Day = $blobNameSplit[-4].Replace("d=","")
            }

            $blobDate | Add-Member -Name "Date" -MemberType NoteProperty -Value ([datetime]"$($blobDate.Year)/$($blobDate.Month)/$($blobDate.Day)")

            if ($blobDate.Date -ge $minDate -and $blobDate.Date -lt $maxDate) {
                $resultBlobs += [PSCustomObject]@{
                    Table = $storageContainer.Name
                    Blob = $blob
                }
            }
            
            # $resultBlobs += $blob | Where-Object { $_.Name -like "$($contentPath)/y=$($logYear)/m=$($logMonth)/d=$($logDay)/*" }
        }
    }
}
Write-Progress -Activity "Getting containers..." -Status "DONE" -PercentComplete 100

# Download blobs
foreach ($blob in $resultBlobs) {
    Write-Progress -Activity "Downloading blobs..." -Status "[$($resultBlobs.IndexOf($blob) + 1)/$($resultBlobs.Count)] Downloading '$($blob.Table)/$($blob.Blob.Name)'" -PercentComplete (($resultBlobs.IndexOf($blob) + 1) / $resultBlobs.Count * 100)
    
    try {
        $downloadedBlob = Get-AzStorageBlobContent -Blob $blob.Blob.Name -Container $blob.Blob.BlobBaseClient.BlobContainerName -Context $blob.Blob.Context -Destination "$($downloadPath)/$($blob.Table)" -Force
    } catch {
        # Avoid too many requests error
        Start-Sleep -Seconds 2s
        $downloadedBlob = Get-AzStorageBlobContent -Blob $blob.Blob.Name -Container $blob.Blob.BlobBaseClient.BlobContainerName -Context $blob.Blob.Context -Destination "$($downloadPath)/$($blob.Table)" -Force
    }
    Write-Host "DOWNLOADED: '$($downloadedBlob.Name.Replace($contentPath, ''))'"
}
Write-Progress -Activity "Downloading blobs..." -Status "DONE" -PercentComplete 100

# # Download batch test (faster)
# az login
# az account set --subscription $subscriptionId

# foreach ($blob in $resultBlobs) {
#     az storage blob download-batch -d . --pattern $contentPath -s $blob.Blob.BlobBaseClient.BlobContainerName --account-name $storageAccountName --auth-mode login
# }

# Extract the content from the downloaded blobs and append it to the output file
foreach ($table in $tables) {
    $fileObject = [System.Collections.Generic.List[Object]]::new() # Create output file
    $currentPath = @($downloadPath, $table, $contentPath)
    foreach ($year in Get-ChildItem ($currentPath -join "\")) {
        $currentPath += $year.Name
        foreach ($month in Get-ChildItem ($currentPath -join "\")) {
            $currentPath += $month.Name
            foreach ($day in Get-ChildItem ($currentPath -join "\")) {
                $currentPath += $day.Name
                foreach ($hour in Get-ChildItem ($currentPath -join "\")) {
                    $currentPath += $hour.Name
                    foreach ($minute in Get-ChildItem ($currentPath -join "\")) {
                        $currentPath += $minute.Name
                        
                        # Show current path
                        Write-Host (($currentPath -join "\").Replace($currentPath[0..2] -join "\", ''))

                        # Content
                        foreach ($file in Get-ChildItem ($currentPath -join "\")) {
                            # Get content from JSON file
                            $content = Get-Content "$($currentPath -join "\")\$($file.Name)" | ConvertFrom-Json
                            # $jsonContent = $content | ConvertTo-Json

                            foreach ($c in $content) {
                                $properties = $null
                                $fix = $null
                                $properties = $c.PSObject.Properties

                                # Properties to fix (output as System.Object[]),
                                $fix = ($properties | Where-Object {$_.Value -ne $null} | Where-Object { $_.TypeNameOfValue -eq 'System.Object[]' }).Name

                                # Compress JSON, remove formatting
                                foreach ($f in $fix) {
                                    $c.$f = $c.$f | ConvertTo-Json -Compress -Depth 5 -AsArray
                                }

                                $fix = $null
                                # Properties to fix (arrays which should be JSON Objects)
                                $fix = ($properties | Where-Object {$_.Value -ne $null} | Where-Object { $_.TypeNameOfValue -eq 'System.Management.Automation.PSCustomObject' }).Name

                                # Compress JSON, remove formatting, fix arrays which should be JSON Objects
                                foreach ($f in $fix) {
                                    $c.$f = $c.$f | ConvertTo-Json -Compress -Depth 5
                                }

                                # Transform empty object values into string '[]'
                                foreach ($p in $properties) {
                                    if ($c.($p.Name).GetType().Name -eq "Object[]" -and $c.($p.Name).Count -eq 0) {
                                        $c.($p.Name) = "[]"
                                    }
                                }

                                # Standardize TimeGenerated
                                $c.TimeGenerated = $c.TimeGenerated.ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")

                                # Add table name and save to file object
                                $c | Add-Member -Name "Table" -MemberType NoteProperty -Value $table
                                $fileObject.Add($c)
                            }
                        }

                        # Start return
                        $currentPath = $currentPath[0..(($currentPath.Length)-2)]
                    }
                    $currentPath = $currentPath[0..(($currentPath.Length)-2)]
                }
                $currentPath = $currentPath[0..(($currentPath.Length)-2)]
            }
            $currentPath = $currentPath[0..(($currentPath.Length)-2)]
        }
        $currentPath = $currentPath[0..(($currentPath.Length)-2)]
    }

    # $fileObject | ConvertTo-Json | Out-File "C:\temp\test-$table.json"
    $fileObject | Export-Csv "C:\temp\test-$table.csv" -NoTypeInformation
    $fileObject | Export-Excel "C:\temp\test-$table.xlsx"

    # Different export method for JSON files
    foreach ($line in $fileObject) {
        $line | ConvertTo-Json >> "C:\temp\test-$table.json"
    }
}

# Clear download logs
# Remove-Item -Path "$downloadPath\WorkspaceResourceId=" -Recurse -Force