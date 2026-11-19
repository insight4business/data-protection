# Azure Storage

Scripts for the **azure-storage** technology in this sub-process.

## Scripts adapted from field work

Each script solves one problem. They were adapted from real operations work: replace every `ENTRE_AQUI_COM_SEU_*` marker, review, and test in a non-production tenant first.

| Script | Problem it solves | What it does | Requires | Effect | Notes |
|---|---|---|---|---|---|
| `storage-archive-log-blobs-convert-and-delete-hot.ps1` | Log storage cost is high. | Copies blobs to archive account as Block blobs, tags and deletes from hot. | Az.Storage; Storage Blob Data Contributor | destructive | Org storage accounts; troubleshootingMode defaults to true |
| `storage-consolidate-azureactivity-logs.ps1` | I need to read archived AzureActivity JSON blobs. | Parses locally downloaded blobs into a consolidated file. | PowerShell 7; ImportExcel | read-only |  |
| `storage-consolidate-downloaded-logs.ps1` | Read archived logs from any table. | Parses downloaded blobs for any table to Excel/CSV. | PowerShell 7; ImportExcel | read-only |  |
| `storage-generate-sas-tokens-for-log-blobs.ps1` | I need to share archived log blobs temporarily. | Creates SAS tokens for blobs in a container folder. | Az.Storage; Storage Account Key Operator | changes-state | Hard-coded expiration 2023-12-31 and org storage account; McasShadowItReporting folder |
| `storage-report-logs-by-table-resource-month-day.ps1` | What logs are stored per resource per day? | Counts and sizes of stored log blobs by table, resource, month and day. | Az.Storage | read-only | Hard-coded org storage accounts and year |
| `storage-report-logs-by-table-year-month.ps1` | How much log data per table over time? | Counts stored logs by table, year, month. | Az.Storage | read-only | Hard-coded org storage accounts |
| `storage-report-size-by-container.ps1` | How much storage does each container use? | Sums blob sizes per container/account. | Az.Storage | read-only | Hard-coded org storage account list |
| `storage-retrieve-sentinel-logs.ps1` | I need to query old logs exported to Storage. | Downloads blobs by table/time from storage and consolidates them. | Az.Storage | read-only | Warning: very slow; hard-coded workspace path |
