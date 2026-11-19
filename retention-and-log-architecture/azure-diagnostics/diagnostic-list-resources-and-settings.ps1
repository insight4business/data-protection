# Problem solved : I need a coverage map of which resources send logs where.
# What it does    : Exports every resource with its diagnostic setting destinations and categories to CSV.
# Requires        : Az.Monitor; Reader
# Effect          : read-only
# Known issues    : v2 of the script; Temp path in output
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

###
# Install-Module Az
Import-Module Az

$ErrorActionPreference = 'Stop'
# $WarningPreference = 'SilentlyContinue'

$subscriptionId = "ENTRE_AQUI_COM_SEU_ID"

$currentDate = Get-Date -Format "yyyy-MM-dd"
$outputFilePath = "c:\Temp\Azure Resources Diagnotic\$currentDate - azureResourcesDiagosticSettings"

function GetDiagInformation {
    param ( 
        [Parameter(Mandatory = $true)]
        [Object] $resource, 
        [Object] $diag, 
        [String] $content
    )

    if ($null -ne $diag) {
        $obj = $null
        $obj = [PSCustomObject]@{
            ResourceType                       = $resource.ResourceType
            ResourceGroupName                  = $resource.ResourceGroupName
            ResourceName                       = $resource.ResourceName
            ResourceLocation                   = $resource.Location
            ResourceId                         = $resource.ResourceId
            DiagnosticSettingsName             = if ($diag.Name) { $diag.Name } else { "" }
            DiagnosticSettingsStorageAccountId = if ($diag.StorageAccountId) { $diag.StorageAccountId } else { "" }
            StorageAccountName                 = if ($diag.StorageAccountId) { $diag.StorageAccountId.Split('/')[-1] } else { "" }
            DiagnosticSettingsWorkspaceId      = if ($diag.WorkspaceId) { $diag.WorkspaceId } else { "" }
            WorkspaceName                      = if ($diag.WorkspaceId) { $diag.WorkspaceId.Split('/')[-1] } else { "" }
            DiagnosticSettingsMetrics          = $null
            DiagnosticSettingsLogs             = $null
        }
        
        if ($diag.Metrics.Count -gt 0) {
            $metrics = ""
            foreach ($m in $diag.Metrics) {
                if ($m.Enabled -eq $true) {
                    $metrics = $metrics + $m.Category + "; "
                }
            }
        }
        $obj.DiagnosticSettingsMetrics = $metrics

        if ($diag.Logs.Count -gt 0) {
            $logs = ""
            foreach ($l in $diag.Logs) {
                if ($l.Enabled -eq $true) {
                    $logs = $logs + $l.Category + "; "
                }
            }
        }
        $obj.DiagnosticSettingsLogs = $logs
    }
    return $obj
}


## Main
Connect-AzAccount -SubscriptionId $subscriptionId

$outputReport = [System.Collections.Generic.List[Object]]::new() # Create output file

# Headers for the file
$headers = [PSCustomObject]@{
    ResourceType                       = 'ResourceType'
    ResourceGroupName                  = 'ResourceGroupName'
    ResourceName                       = 'ResourceName'
    ResourceLocation                   = 'ResourceLocation'
    ResourceId                         = 'ResourceId'
    DiagnosticSettingsName             = 'DiagnosticSettingsName'
    DiagnosticSettingsStorageAccountId = 'DiagnosticSettingsStorageAccountId'
    StorageAccountName                 = 'StorageAccountName'
    DiagnosticSettingsWorkspaceId      = 'DiagnosticSettingsWorkspaceId'
    WorkspaceName                      = 'WorkspaceName'
    DiagnosticSettingsMetrics          = 'DiagnosticSettingsMetrics'
    DiagnosticSettingsLogs             = 'DiagnosticSettingsLogs'
}
$outputReport.Add($headers)

$resources = Get-AzResource
foreach ($resource in $resources) {
    $current = $resources.IndexOf($resource) + 1
    $total = $resources.Count
    Write-Progress -Activity "Processing resources" -Status "Processing resource $current of $total" -PercentComplete (($current / $total) * 100)

    $diagSettings = Get-AzDiagnosticSetting -ResourceId $resource.ResourceId -ErrorAction SilentlyContinue
    
    $obj = $null
    if ($diagSettings.Length -gt 1) {
        foreach ($diag in $diagSettings) {
            $obj = GetDiagInformation -Resource $resource -Diag $diag
            $outputReport.Add($obj)
        }
    }
    elseif ($diagSettings.Length -eq 1) {
        $obj = GetDiagInformation -Resource $resource -Diag $diagSettings
        $outputReport.Add($obj)
    }
}
Write-Progress -Activity "Processing resources" -Status "Done" -Completed

# $outputReport | Export-Csv -Path "$outputFilePath.csv" -NoTypeInformation
$outputReport | Export-Excel -Path "$outputFilePath.xlsx"