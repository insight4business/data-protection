# Problem solved : Management group activity logs are not going to Sentinel.
# What it does    : Creates a diagnostic setting on a management group via REST to a Log Analytics workspace.
# Requires        : Az.Accounts; Monitoring Contributor at management group
# Effect          : changes-state (review and test before use)
# Known issues    : Uses legacy token acquisition via RMProfileClient
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

### https://learn.microsoft.com/en-us/rest/api/monitor/management-group-diagnostic-settings/create-or-update?view=rest-monitor-2020-01-01-preview&tabs=HTTP

# $managementGroupId = "ENTRE_AQUI_COM_SEU_RECURSO"
$managementGroupId =  "ENTRE_AQUI_COM_SEU_ID"

$destinationSubscriptionId = "ENTRE_AQUI_COM_SEU_ID"
$destinationResourceGroup = "sentinel"
$destinationWorkspace = "ENTRE_AQUI_COM_SEU_RECURSO"

$settingName = "DiagLogs_TO_Sentinel"

##
Connect-AzAccount
	
$azContext = Get-AzContext
$azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
$token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
$authHeader = @{
    'Content-Type'  = 'application/json'
    'Authorization' = 'Bearer ' + $token.AccessToken
}

#
$restUri = "https://management.azure.com/providers/microsoft.management/managementGroups/$managementGroupId/providers/microsoft.insights/diagnosticSettings/$($settingName)?api-version=2020-01-01-preview"

$body = [PSCustomObject]@{
    properties = [PSCustomObject]@{
        workspaceId = "/subscriptions/$destinationSubscriptionId/resourceGroups/$destinationResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$destinationWorkspace"
        logs        = @(
            @{
                category = "Administrative"
                enabled  = $true
            },
            @{
                category = "Policy"
                enabled  = $true
            }
        )
    }
}

# 
$body = $body | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $restUri -Method Put -Headers $authHeader -Body $body -ContentType "application/json"

#
$listUri = "hhttps://management.azure.com/providers/microsoft.management/managementGroups/$managementGroupId/providers/microsoft.insights/diagnosticSettings?api-version=2020-01-01-preview"

Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -ContentType "application/json"
