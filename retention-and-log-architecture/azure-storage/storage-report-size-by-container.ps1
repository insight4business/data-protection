# Problem solved : How much storage does each container use?
# What it does    : Sums blob sizes per container/account.
# Requires        : Az.Storage
# Effect          : read-only
# Known issues    : Hard-coded org storage account list
# Origin          : adapted from field work; replace every ENTRE_AQUI_COM_SEU_* marker with your own value

# this script will show how to get the total size of the blobs in a container
# before running this, you need to create a storage account, create a container,
#    and upload some blobs into the container 
# note: this retrieves all of the blobs in the container in one command. 
#       if you are going to run this against a container with a lot of blobs
#       (more than a couple hundred), use continuation tokens to retrieve
#       the list of blobs.


Connect-AzAccount

$currentDay = Get-Date -Format "yyyy-MM-dd"
$outputPath = "C:\Temp\$currentDay - Storage Account size report"

# these are for the storage account to be used
$storageAccounts = @(
    [PSCustomObject]@{
        ResourceGroupName = "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP"
        StorageAccountName = "ENTRE_AQUI_COM_SEU_STORAGE"
    },
    [PSCustomObject]@{
        ResourceGroupName = "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP"
        StorageAccountName = "ENTRE_AQUI_COM_SEU_STORAGE"
    },
    [PSCustomObject]@{
        ResourceGroupName = "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP"
        StorageAccountName = "ENTRE_AQUI_COM_SEU_STORAGE"
    },
    [PSCustomObject]@{
        ResourceGroupName = "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP"
        StorageAccountName = "ENTRE_AQUI_COM_SEU_STORAGE"
    },
    [PSCustomObject]@{
        ResourceGroupName = "ENTRE_AQUI_COM_SEU_RESOURCE_GROUP"
        StorageAccountName = "ENTRE_AQUI_COM_SEU_STORAGE"
    }
)

$outputReport = [System.Collections.Generic.List[Object]]::new() # Create output file

foreach ($storageAccount in $storageAccounts) {
    Write-Progress -Id 1 -Activity "Processing storage account $($storageAccount.StorageAccountName)" -Status "Getting containers" -PercentComplete ($storageAccounts.IndexOf($storageAccount) / $storageAccounts.Count * 100)
    # get a reference to the storage account and the context
    $sa = Get-AzStorageAccount -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName

    $ctx = $sa.Context 

    $containers = [array](Get-AzStorageContainer -Context $ctx)

    foreach ($container in $containers) {
        Write-Progress -ParentId 1 -Activity "Processing container $($container.Name)" -Status "Getting blobs" -PercentComplete ($containers.IndexOf($container) / $containers.Count * 100)
        # get a list of all of the blobs in the container 
        $listOfBlobs = Get-AzStorageBlob -Container $container.Name -Context $ctx

        # zero out our total
        $length = 0

        # this loops through the list of blobs and retrieves the length for each blob
        #   and adds it to the total
        $listOfBlobs | ForEach-Object {$length = $length + $_.Length}

        # output the blobs and their sizes and the total 
        Write-Host "Storage '$($storageAccount.StorageAccountName)'; Container '$($container.Name)'; Total Length = $length"
        $outputReport.Add([PSCustomObject]@{
            StorageAccountName = $storageAccount.StorageAccountName
            ContainerName = $container.Name
            TotalLength = $length
        })
    }
    Write-Progress -ParentId 1 -Activity "Processing storage account $($storageAccount.StorageAccountName)" -Status "Getting blobs" -PercentComplete 100
}
Write-Progress -Id 1 -Activity "Processing storage account $($storageAccount.StorageAccountName)" -Status "Getting containers" -PercentComplete 100

$outputReport | Export-Excel "$outputPath.xlsx"