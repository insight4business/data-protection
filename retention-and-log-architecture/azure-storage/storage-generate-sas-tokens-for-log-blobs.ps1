# Problem solved : I need to share archived log blobs temporarily.
# What it does    : Creates SAS tokens for blobs in a container folder.
# Requires        : Az.Storage; Storage Account Key Operator
# Effect          : changes-state (review and test before use)
# Known issues    : Hard-coded expiration 2023-12-31 and org storage account; McasShadowItReporting folder
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

###

# Parameters
$storageAccountId = "/subscriptions/ENTRE_AQUI_COM_SEU_ID/resourceGroups/ENTRE_AQUI_COM_SEU_RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/ENTRE_AQUI_COM_SEU_STORAGE"

$resourceGroupName = $storageAccountId.Split("/")[4]
$storageAccountName = $storageAccountId.Split("/")[8]

$logsContainer = "00-query-logs"
$folderName = "McasShadowItReporting"

$expirationDate = "2023-12-31T00:00Z"


## MAIN
Connect-AzAccount

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName

$blobs = Get-AzStorageBlob -Container $logsContainer -Context $storageAccount.Context

$list = @()
$blobsToGenerateSas = $blobs | Where-Object {$_.Name -like "$folderName*.csv"}
foreach ($blob in $blobsToGenerateSas) {
    $list += (New-AzStorageBlobSASToken -Container $logsContainer -Blob $blob.Name -Permission r -ExpiryTime $expirationDate -Context $storageAccount.Context -FullUri)
}

Write-Host "SAS Token list for $storageAccountName/$logsContainer/$folderName"
$list
