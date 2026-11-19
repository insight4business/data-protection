# Problem solved : I need to read archived AzureActivity JSON blobs.
# What it does    : Parses locally downloaded blobs into a consolidated file.
# Requires        : PowerShell 7; ImportExcel
# Effect          : read-only
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

### To use this, download the logs from the storage using AzCopy (needs managed identity or SAS token) 
### or Azure Storage Explorer, then use the script to treat the logs.

### Using AzCopy
### https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-authorize-azure-active-directory#authorize-by-using-a-system-wide-managed-identity
### https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-blobs-download

### Using Azure Storage Explorer
### Open Storage Explorer, signin with an account that has the adequate permissions, navigate to the storage account, right click on the container and select "Download"

# Parameters
# Set the folder below to where the logs are downloaded, use only one table folder at a time, ex: path\am-usage
$downloadPath = "C:\Temp\DownloadedLogs\insights-activity-logs"

# Consolidated log file outputPath folder
$outputPath = "C:\Temp\DownloadedLogs"

# month between 01 and 12
# day between 00 and 31
$logStart = [PSCustomObject]@{
    Year = "2022"
    Month = "10"
    Day = "01"
}
$logStop = [PSCustomObject]@{
    Year = "2023"
    Month = "04"
    Day = "30"
}

# Constants
$workspaceName = "ENTRE_AQUI_COM_SEU_RECURSO"
$subscriptionId = "ENTRE_AQUI_COM_SEU_ID"

# Create folder if it doesn't exist
if ((Test-Path $outputPath) -eq $false) { New-Item -Path $outputPath -ItemType "directory"}

# Append filename to output path
$outputPath = "$outputPath\$($logStart.Year)$($logStart.Month)$($logStart.Day) - $($logStop.Year)$($logStop.Month)$($logStop.Day) - storage_accounts_logs-$($downloadPath.Split("\")[-1])"

# MAIN
# List all files in the download directory
$files = (Get-ChildItem -Path $downloadPath -Recurse -File).FullName

# If informed start and stop dates are valid
if (([int]$logStart.Year -ge 2022 -and ([int]($logStart.Month) -ge 1 -and [int]$logStart.Month -le 12) `
    -and ([int]$logStart.Day -ge 1 -and [int]$logStart.Day -le 31)) `
    -and ([int]$logStop.Year -ge 2022 -and ([int]($logStop.Month) -ge 1 -and [int]$logStop.Month -le 12) `
    -and ([int]$logStop.Day -ge 1 -and [int]$logStop.Day -le 31))) {

    $ErrorActionPreference = "Stop"
        
    $minDate = [datetime]"$($logStart.Year)/$($logStart.Month)/$($logStart.Day)"
    $maxDate = ([datetime]"$($logStop.Year)/$($logStop.Month)/$($logStop.Day)").AddDays(1)

    $filesToExtract = @()

    foreach ($file in $files) {
        # Check if file is in the correct date range
        if ($file -like "*insights-activity-logs*") {
            $fileDatetimeInfo = ($file -Split ("$subscriptionId\\"))[1].Split("\")
        } else {
            Write-Error "Wrong log type, please use only the activity logs."
            exit 1
        }

        $fileDatetime = [PSCustomObject]@{
            Year = $fileDatetimeInfo[0].Replace("y=","")
            Month = $fileDatetimeInfo[1].Replace("m=","")
            Day = $fileDatetimeInfo[2].Replace("d=","")
            Hour = $fileDatetimeInfo[3].Replace("h=","")
            Minute = $fileDatetimeInfo[4].Replace("m=","")
            TimeRange = $fileDatetimeInfo[5].Replace("PT","").Replace(".json","")
        }

        # Add datetime property to object
        $fileDatetime | Add-Member -Name "Datetime" -MemberType NoteProperty -Value ([datetime]("$($fileDatetime.Year)-$($fileDatetime.Month)-$($fileDatetime.Day) $($fileDatetime.Hour):$($fileDatetime.Minute):00"))
         
        # If file date is between min and max date
        if ($fileDatetime.Datetime -ge $minDate -and $fileDatetime.Datetime -lt $maxDate) {
            $filesToExtract += [PSCustomObject]@{
                FilePath = $file
                Datetime = $fileDatetime.Datetime
            }
        }
    }
}

# Extract the content from the downloaded blobs and append it to the output file
$outputFile = [System.Collections.Generic.List[Object]]::new() # Create output file

foreach ($file in $filesToExtract) {
    $current = $filesToExtract.IndexOf($file) + 1
    $total = $filesToExtract.Count
    Write-Progress -Activity "Extracting content from files..." -Status "[$($file.Datetime)] Extracting $current out of $total" -PercentComplete ($current / $total * 100)

    # Content
    $content = Get-Content $file.FilePath
    $contentFix = @()
    # $contentFix = [System.Collections.Generic.List[Object]]::new()
    foreach ($c in $content) {
        try {
            $contentFix += $c | ConvertFrom-Json
            # $json = $c | ConvertFrom-Json
            # $contentFix.Add($json)
        } catch {
            # File with duplicate EventName property
            $contentFix += $c.Replace("EventName", "_EventName")
            # $c = $c.Replace("EventName", "_EventName")
            # $contentFix.Add($json)
        }
    }

    if ($contentFix.Count -gt 0) {
        $content = $contentFix
    }

    # Treat file content
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
        if ($file -notlike "*insights-activity-logs*") {
            $c.TimeGenerated = $c.TimeGenerated.ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")
        }

        # Add table name and save to file object
        $c | Add-Member -Name "Table" -MemberType NoteProperty -Value $table
        $outputFile.Add($c)
    }
}
Write-Progress -Activity "Extracting content from files..." -Status "DONE" -PercentComplete 100

# $outputFile | ConvertTo-Json | Out-File "C:\temp\$table.json"
$outputFile | Export-Csv "$outputPath.csv" -NoTypeInformation
$outputFile | Export-Excel "$outputPath.xlsx"

# # Different export method for JSON files
# foreach ($line in $outputFile) {
#     $line | ConvertTo-Json -Depth 10 >> "$outputPath.json"
# }
