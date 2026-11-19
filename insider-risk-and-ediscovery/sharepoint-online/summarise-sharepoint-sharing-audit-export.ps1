# Problem solved : We cannot easily review who shared SharePoint content (links, group adds) from the audit log.
# What it does    : Reads audit log CSV exports, parses AuditData JSON, filters out personal sites and builds a sharing activity report.
# Requires        : Audit log CSV exports from Purview; ImportExcel (assumed)
# Effect          : read-only
# Known issues    : Input file paths are placeholders; relies on manual download of the audit search results; filter logic partly truncated in the sanitised copy.
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

# Install-Module ExchangeOnlineManagement
# Import-Module ExchangeOnlineManagement

# Connect-ExchangeOnline

# Get-AuditLogSearch
# https://security.microsoft.com/auditlogsearch
# SharingSet,AddedToGroup,AddedToSecureLink,AddedToSharingLink,SharingLinkCreated,SharingLinkUpdated,CompanyLinkCreated,CompanyLinkUpdated,SecureLinkCreated,SecureLinkUpdated

# Downloaded report path
# $path = "ENTRE_AQUI_COM_SEU_CAMINHO"

$paths = @(
    "ENTRE_AQUI_COM_SEU_CAMINHO"
    ,"ENTRE_AQUI_COM_SEU_CAMINHO"
    ,"ENTRE_AQUI_COM_SEU_CAMINHO"
)

$outputReport = [System.Collections.Generic.List[Object]]::new() # Create output file
foreach ($path in $paths) {
    # Get content from downloadedFile
    $content = Get-Content $path | ConvertFrom-Csv

    $contentAuditData = $content.AuditData | ConvertFrom-Json

    # Filters
    $contentAuditData = $contentAuditData | Where-Object {$_.SiteUrl -notlike "https://ENTRE_AQUI_COM_SEU_TENANT.sharepoint.com/personal/*"}
    $contentAuditData = $contentAuditData | Where-Object {$_.Operation -notin ('SecureLinkCreated', 'SecureLinkUpdated', 'AddedToSecureLink')}

    # Treat fields
    # Treat Data
    $contentAuditData = $contentAuditData | Select-Object *,@{Name="Date";Expression={[DateTime]::Parse($_.CreationTime)}} | Sort-Object Date -Descending

    $outputReport += ($contentAuditData | Select-Object * -ExcludeProperty AppAccessContext, Version, BrowserName, BrowserVersion, UserAgent, CreationTime)
    
}
$outputReport | Export-Excel -ShowPercent -NoNumberConversion ClientIP,DeviceDisplayName -NoHyperLinkConversion UserKey,UserId,SiteUrl,ObjectId,TargetUserOrGroupName

