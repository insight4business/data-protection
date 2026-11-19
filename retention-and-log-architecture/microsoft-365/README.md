# Microsoft 365

Scripts for the **microsoft-365** technology in this sub-process.

## Scripts adapted from field work

Each script solves one problem. They were adapted from real operations work: replace every `ENTRE_AQUI_COM_SEU_*` marker, review, and test in a non-production tenant first.

| Script | Problem it solves | What it does | Requires | Effect | Notes |
|---|---|---|---|---|---|
| `enable-unified-audit-log.ps1` | Audit log ingestion is not enabled so we have no activity evidence for investigations. | Runs Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true. | Exchange Online PowerShell; Compliance/Org Management role | changes-state | Uses legacy Connect-MsolService (retired) and Connect-AzAccount, neither needed; Set-AdminAuditLogConfig requires Connect-ExchangeOnline, so the script is likely broken as written. |
