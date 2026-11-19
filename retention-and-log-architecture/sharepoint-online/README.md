# Sharepoint Online

Scripts for the **sharepoint-online** technology in this sub-process.

## Scripts adapted from field work

Each script solves one problem. They were adapted from real operations work: replace every `ENTRE_AQUI_COM_SEU_*` marker, review, and test in a non-production tenant first.

| Script | Problem it solves | What it does | Requires | Effect | Notes |
|---|---|---|---|---|---|
| `change-retention-label-on-library-items.ps1` | Items carry the wrong retention label and need relabelling. | Inventories a library with labels and exports to Excel, then sets a label on selected items. | PnP.PowerShell; ImportExcel | changes-state | Broken line 'Set-PnPRetentionLabel -List $ -ItemIds @(1,2,3) -Label "My demo label"' (demo values, missing list variable); client library name and '00. DELETE' marker. |
| `force-delete-retention-locked-folder-contents.ps1` | Files under a retention label cannot be deleted and fill a library. | Lists library items with their labels, then deletes (to recycle bin) the items in a specified folder; reset-label calls commented out. | PnP.PowerShell; SharePoint Administrator | destructive | Library name 'Service Desk - ITSM' and folder placeholder are client-specific; deleting retained records can breach retention policy: require approval. |
| `report-retention-labels-on-library-items.ps1` | We do not know which files and folders carry which retention label. | Lists all items in a library with their compliance tag and exports to Excel. | PnP.PowerShell; ImportExcel | read-only | Library name 'Service Desk - ITSM' hard-coded (client-specific); also in sibling retention scripts. |
| `reset-retention-label-and-delete-marked-items.ps1` | Items under a retention label cannot be removed after approval. | Finds items named '00. DELETE', intended to reset the label and delete them; both action lines commented out, success message prints regardless. | PnP.PowerShell | destructive | Client-specific marker '00. DELETE' and library name; success message is printed even though nothing runs (commented). Near-overlap with the force-delete script. |
