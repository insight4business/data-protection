# Problem solved : Items under a retention label cannot be removed after approval.
# What it does    : Finds items named '00. DELETE', intended to reset the label and delete them; both action lines commented out, success message prints regardless.
# Requires        : PnP.PowerShell
# Effect          : destructive (review and test before use)
# Known issues    : Client-specific marker '00. DELETE' and library name; success message is printed even though nothing runs (commented). Near-overlap with the force-delete script.
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

###
# Install-Module PnP.PowerShell
Import-Module PnP.PowerShell

## PARAMETERS
$xmlQuery =  "<View Scope='RecursiveAll'><RowLimit>5000</RowLimit></View>"  

$siteURL = "https://ENTRE_AQUI_COM_SEU_TENANT.sharepoint.com/sites/ENTRE_AQUI_COM_SEU_SITE"  

$libraryName = "Service Desk - ITSM"

##
Connect-PnPOnline -Url $siteURL -Interactive

##
$lists = Get-PnPList | Where-Object {$_.BaseTemplate -eq 101 -and $_.Hidden -eq $false}

$library = $lists | Where-Object {$_.Title -eq $libraryName}

$itemList = @() 
foreach ($lib in $library) {
   $items = Get-PnPListItem -List $lib.Title -PageSize 5000 -Query $xmlQuery

   foreach ($item in $items) {
      $itemList += [PSCustomObject]@{
        "List ID" = $lib.Id
        "List Title" = $lib.Title
        "ID" = $item.Id
        "File URL" = $item.FieldValues.FileRef
        "File Name" = $item.FieldValues.FileLeafRef
        "Type" = if ($item.FieldValues.FSObjType -eq 1) {"Folder"} else {"File"}
        "Label" = $item.FieldValues._ComplianceTag
      }
   }
}
  
# $itemList | Export-Excel

$deleteItems = $itemList | Where-Object {$_.'File Name' -eq "00. DELETE"}

foreach ($item in $deleteItems) {
    # Reset-PnPRetentionLabel -List $item.'List Title' -ItemIds @($item.ID)
    # Remove-PnPListItem -List $item.'List Title' -Identity $item.ID -Recycle -Force

    if ($?) {
        Write-Host "Item $($item.ID) '$($item.'File URL')' deleted successfully" -ForegroundColor Green
    } else {
        Write-Host "Item $($item.ID) '$($item.'File URL')' deletion failed" -ForegroundColor Red
    }
}
