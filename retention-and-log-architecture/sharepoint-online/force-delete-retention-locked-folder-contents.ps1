# Problem solved : Files under a retention label cannot be deleted and fill a library.
# What it does    : Lists library items with their labels, then deletes (to recycle bin) the items in a specified folder; reset-label calls commented out.
# Requires        : PnP.PowerShell; SharePoint Administrator
# Effect          : destructive (review and test before use)
# Known issues    : Library name 'Service Desk - ITSM' and folder placeholder are client-specific; deleting retained records can breach retention policy: require approval.
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

###
# Install-Module PnP.PowerShell
Import-Module PnP.PowerShell

## PARAMETERS
$xmlQuery =  "<View Scope='RecursiveAll'><RowLimit>5000</RowLimit></View>"  

$siteURL = "https://ENTRE_AQUI_COM_SEU_TENANT.sharepoint.com/sites/ENTRE_AQUI_COM_SEU_SITE"  

$libraryName = "Service Desk - ITSM"

$rootFolderToDelete = "ENTRE_AQUI_COM_SEU_CAMINHO"

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

$deleteItems = $itemList | Where-Object {$_.'File URL' -eq $rootFolderToDelete}

foreach ($di in $deleteItems) {
    $subItems = Get-PnPListItem -Identity "https://ENTRE_AQUI_COM_SEU_TENANT.sharepoint.com$($di.'File URL')"

    foreach ($subItem in $subItems) {
        $delete = $null
        $delete = $itemList | Where-Object {$_.'File URL' -eq $subItem.ServerRelativeUrl}

        # Reset-PnPRetentionLabel -List $delete.'List Title' -ItemIds @($delete.ID)
        Remove-PnPFile -ServerRelativeUrl $subItem.ServerRelativeUrl -Force -Recycle

        if ($?) {
            Write-Host "Item $($subItem.ID) '$($subItem.ServerRelativeUrl)' deleted successfully" -ForegroundColor Green
        } else {
            Write-Host "Item $($subItem.ID) '$($subItem.ServerRelativeUrl)' deletion failed" -ForegroundColor Red
        }
    }

    # Reset-PnPRetentionLabel -List $di.'List Title' -ItemIds @($di.ID)
    Remove-PnPFile -ServerRelativeUrl $di.'File URL' -Force -Recycle

    if ($?) {
        Write-Host "Item $($di.ID) '$($di.'File URL')' deleted successfully" -ForegroundColor Green
    } else {
        Write-Host "Item $($di.ID) '$($di.'File URL')' deletion failed" -ForegroundColor Red
    }
}
