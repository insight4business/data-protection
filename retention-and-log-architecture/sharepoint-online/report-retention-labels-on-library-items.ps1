# Problem solved : We do not know which files and folders carry which retention label.
# What it does    : Lists all items in a library with their compliance tag and exports to Excel.
# Requires        : PnP.PowerShell; ImportExcel
# Effect          : read-only
# Known issues    : Library name 'Service Desk - ITSM' hard-coded (client-specific); also in sibling retention scripts.
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
         "ID" = $lib.Id
         "List Title" = $lib.Title
         "File URL" = $item.FieldValues.FileRef
         "File Name" = $item.FieldValues.FileLeafRef
         "Type" = if ($item.FieldValues.FSObjType -eq 1) {"Folder"} else {"File"}
         "Label" = $item.FieldValues._ComplianceTag
      }
   }
}
  
$itemList | Export-Excel