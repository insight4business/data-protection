# Problem solved : Items carry the wrong retention label and need relabelling.
# What it does    : Inventories a library with labels and exports to Excel, then sets a label on selected items.
# Requires        : PnP.PowerShell; ImportExcel
# Effect          : changes-state (review and test before use)
# Known issues    : Broken line 'Set-PnPRetentionLabel -List $ -ItemIds @(1,2,3) -Label "My demo label"' (demo values, missing list variable); client library name and '00. DELETE' marker.
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

###
# Install-Module PnP.PowerShell
Import-Module PnP.PowerShell


## PARAMETRS
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
  
$itemList | Export-Excel

$deleteItems = $itemList | Where-Object {$_.'File Name' -eq "00. DELETE"}

foreach ($item in $deleteItems) {
    # Change retention label
    Set-PnPRetentionLabel -List $ -ItemIds @(1,2,3) -Label "My demo label"
}
