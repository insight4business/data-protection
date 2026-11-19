# Azure Diagnostics

Scripts for the **azure-diagnostics** technology in this sub-process.

## Scripts adapted from field work

Each script solves one problem. They were adapted from real operations work: replace every `ENTRE_AQUI_COM_SEU_*` marker, review, and test in a non-production tenant first.

| Script | Problem it solves | What it does | Requires | Effect | Notes |
|---|---|---|---|---|---|
| `diagnostic-add-storage-destination-to-sentinel-resources.ps1` | Resources send logs to Sentinel only and I need cheap long-term retention in Storage. | Finds resources with diagnostic settings to Sentinel and adds a second setting to regional Storage. | Az.Monitor; Monitoring Contributor | changes-state | DEPRECATED in name; hard-coded org storage accounts. Useful pattern for dual routing |
| `diagnostic-list-resources-and-settings.ps1` | I need a coverage map of which resources send logs where. | Exports every resource with its diagnostic setting destinations and categories to CSV. | Az.Monitor; Reader | read-only | v2 of the script; Temp path in output |
| `diagnostic-recreate-for-any-resource-type.ps1` | I need to standardize diagnostic settings (Storage + Sentinel) for a chosen resource type. | Prompts for a resource type, clears existing diagnostic settings and recreates them to regional Storage and Log Analytics. | Az.Monitor; Monitoring Contributor | destructive | File name has DEPRECATED; kept as the generic template. Hard-coded org storage account IDs (ENTRE_AQUI_COM_SEU_RESOURCE_GROUP*) and workspace values must be parameterized |
| `diagnostic-sql-create-for-specific-databases.ps1` | Specific SQL databases must send audit logs to Sentinel. | Creates diagnostic settings to Log Analytics for a list of database resource IDs. | Az.Monitor; Monitoring Contributor | changes-state | Database resource ID list is org-specific placeholders; fill in |
| `diagnostic-sql-list-auditing-and-diagnostics.ps1` | I need to confirm every SQL server/database has auditing and diagnostics. | Reports auditing and diagnostic settings for all SQL servers and databases. | Az.Sql, Az.Monitor | read-only | Comments carry org subscription names |
| `management-group-set-diagnostic-settings.ps1` | Management group activity logs are not going to Sentinel. | Creates a diagnostic setting on a management group via REST to a Log Analytics workspace. | Az.Accounts; Monitoring Contributor at management group | changes-state | Uses legacy token acquisition via RMProfileClient |
