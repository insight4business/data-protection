# Problem solved : Audit log ingestion is not enabled so we have no activity evidence for investigations.
# What it does    : Runs Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true.
# Requires        : Exchange Online PowerShell; Compliance/Org Management role
# Effect          : changes-state (review and test before use)
# Known issues    : Uses legacy Connect-MsolService (retired) and Connect-AzAccount, neither needed; Set-AdminAuditLogConfig requires Connect-ExchangeOnline, so the script is likely broken as written.
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value




Connect-MsolService
Connect-AzAccount


Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true