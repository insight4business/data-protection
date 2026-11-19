# Problem solved : Read archived logs from any table.
# What it does    : Parses downloaded blobs for any table to Excel/CSV.
# Requires        : PowerShell 7; ImportExcel
# Effect          : read-only
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

### To use this, download the logs from the storage using Azure Storage Explorer, then use the script to treat the logs.

### Using Azure Storage Explorer
### Open Storage Explorer, signin with an account that has the adequate permissions, navigate to the storage account, right click on the container and select "Download

### Use Powershell 6+, Powershell 5.1 has issues with the JSON formatting

### Required modules
### Install-Module ImportExcel

Import-Module ImportExcel

# Parameters
# Set the folder below to where the logs are downloaded, use only one table folder at a time, ex: path\am-usage
$downloadPath = "C:\Temp\DownloadedLogs\am-emailevents"
$tableName = $($downloadPath.Split("\")[-1])

# Consolidated log file outputPath folder
$outputPath = "C:\Temp\DownloadedLogs"

# month between 01 and 12
# day between 00 and 31
$logStart = [PSCustomObject]@{
    Year = "2023"
    Month = "12"
    Day = "01"
}
$logStop = [PSCustomObject]@{
    Year = "2023"
    Month = "12"
    Day = "05"
}

# Constants
$workspaceName = "ENTRE_AQUI_COM_SEU_RECURSO"

# Create folder if it doesn't exist
if ((Test-Path $outputPath) -eq $false) {New-Item -Path $outputPath -ItemType "directory"}

# MAIN
$minDate, $maxDate = $null, $null
$minDate = [datetime]"$($logStart.Year)/$($logStart.Month)/$($logStart.Day)"
$maxDate = [datetime]"$($logStop.Year)/$($logStop.Month)/$($logStop.Day)"

$maxDate = $maxDate.AddDays(1)

# Check dates
if ($minDate -gt $maxDate) {
    Write-Host "Start date is greater than end date, please check the dates and try again."
    exit 1
} elseif ($minDate -eq $maxDate) {
    Write-Host "Start date is equal to end date, please check the dates and try again."
    exit 1
} elseif ($minDate -lt $maxDate -and $minDate -ne $null -and $maxDate -ne $null) {
    Write-Host "Dates are valid, proceeding..."
}

# If informed start and stop dates are valid
$ErrorActionPreference = "Stop"

# List all files in the download directory
$files = (Get-ChildItem -Path $downloadPath -Recurse -File).FullName

# Treat files, get datetime information
$filesWithInformation = @()
foreach ($file in $files) {
    Write-Progress -Id 1 -Activity "Getting datetime information from files..." -Status "$($files.IndexOf($file)) / $($files.Count)" -PercentComplete ($files.IndexOf($file) / $files.Count * 100)

    # Get datetime information for each file
    $fileDatetimeInfo = $null
    $fileDatetimeInfo = ($file -Split ("$workspaceName\\"))[1].Split("\")

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
    
    $filesWithInformation += [PSCustomObject]@{
        FilePath = $file
        Datetime = $fileDatetime.Datetime
    }
}
Write-Progress -Id 1 -Activity "Getting datetime information from files..." -Status "DONE" -PercentComplete 100

# Clear unnecessary variables
Clear-Variable -Name "files"

# Iterate each month between min and max date
$current = [PSCustomObject]@{
    StartDate = $minDate
    EndDate = $minDate.AddMonths(1)
}

while ($current.StartDate -lt $maxDate) {
    Write-Progress -Id 1 -Activity "Iterating" -Status "($tableName) Current Time Period: $($current.StartDate.ToString("yyyy-MM-dd")) - $($current.EndDate.ToString("yyyy-MM-dd"))" -PercentComplete (($current.StartDate - $minDate).Days / ($maxDate - $minDate).Days * 100)

    # Limit final date to maxDate
    if ($current.EndDate -gt $maxDate) {
        $current.EndDate = $maxDate
    }

    # Append filename to output path
    $currentOutputPath = $null
    $currentOutputPath = "$outputPath\$($current.StartDate.ToString("yyyyMMdd"))-$($current.EndDate.ToString("yyyyMMdd"))-storageLogs-$($tableName)"

    # List files to extract based on dates
    $filesToExtract = @()
    $filesToExtract = $filesWithInformation | Where-Object {$_.Datetime -ge $current.StartDate -and $_.Datetime -lt $current.EndDate}

    # Extract the content from the downloaded blobs and append it to the output file
    $outputFile = [System.Collections.Generic.List[Object]]::new() # Create output file

    foreach ($file in $filesToExtract) {
        $currentFile = $filesToExtract.IndexOf($file) + 1
        $total = $filesToExtract.Count
        Write-Progress -Id 2 -ParentId 1 -Activity "Extracting content from files..." -Status "[$($file.Datetime)] Extracting $currentFile out of $total" -PercentComplete ($currentFile / $total * 100)

        # Content
        $content = Get-Content $file.FilePath | ConvertFrom-Json

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
            if (($c.TimeGenerated).GetType.FullName -eq "System.DateTime") {
                $c.TimeGenerated = ($c.TimeGenerated).ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")
            }

            # Add table name and save to file object
            $c | Add-Member -Name "Table" -MemberType NoteProperty -Value $table
            $outputFile.Add($c)
        }
    }
    Write-Progress -Id 2 -ParentId 1 -Activity "Extracting content from files..." -Status "DONE" -PercentComplete 100

    # Exports
    if ($outputFile.Count -eq 0) {
        Write-Host "Nothing to export for $($current.StartDate.ToString("yyyy-MM-dd")) - $($current.EndDate.ToString("yyyy-MM-dd"))"
    } else {
        Write-Host "Exporting for $($current.StartDate.ToString("yyyy-MM-dd")) - $($current.EndDate.ToString("yyyy-MM-dd"))"
        $outputFile | Export-Csv "$currentOutputPath.csv" -NoTypeInformation
        $outputFile | Export-Excel "$currentOutputPath.xlsx"

        # # Different export method for JSON files
        # foreach ($line in $outputFile) {
        #     $line | ConvertTo-Json >> "$currentOutputPath.json"
        # }
    }

    # Update current date (iterate monthly)
    $current.StartDate = $current.StartDate.AddMonths(1)
    $current.EndDate = $current.EndDate.AddMonths(1)
}
Write-Progress -Id 1 -Activity "Iterating" -Status "DONE" -PercentComplete 100


