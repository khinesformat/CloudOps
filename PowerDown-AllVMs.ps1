<#
.Synopsis
   Retrives the previous power status for all systems in a subscription.  It then returns all systems to the previous powered state.
.DESCRIPTION
   Revrives the previous power status for all systems from a csv.  It then powers off,deallocates any systems that were previously deallocated.  
   It runs these jobs in parellel, and waits up to 30 minutes for it to complete.  If it doesn't complete in 30 minutes, it kills the remaining 
   jobs.  In a seperate log file, it records all systems stopping, any failure to stop, and the number of systems that did not complete the 
   stopping process.  Last it records the length of time to run, and logs it.
.EXAMPLE
   Restore-PowerState.ps1
   C:\pstemp\Azure\Restore-PowerState.ps1
.INPUTS
   VMPowerState.txt - This is a csv of the VMName, VMResourceGroupName, VMPowerState
.OUTPUTS
   ShutdownLog-2018-02-17.txt - This is a log of all output from the script, machines starting, starting failures, and jobs exceeding timeout.
.NOTES
   Created by:  Craig Franzen
   Date:      15 Feb 2018
   Version:    v1.0
   Change the login information.  It requires an enrypted password string to work.  It can be changed to Get-Credentials, for on the spot 
   validation.  The login and subscription can be removed when used as a runbook.
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>

#region ConnectAs
$connectionName = "AzureRunAsConnection"
try
{
# Get the connection "AzureRunAsConnection "
$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

"Logging in to Azure..."
Add-AzureRmAccount `
    -ServicePrincipal `
    -TenantId $servicePrincipalConnection.TenantId `
    -ApplicationId $servicePrincipalConnection.ApplicationId `
    -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
#endregion ConnectAs

#region variables
[string]$Name = "PowerupVMs"
[string]$StorageAccount = "cloudopsstorage"
[string]$StorageRG = "CloudOps-DevTest-RG"
[string]$Container = "windowsupdate-powerstatus"
$todaydate = Get-Date -Format MM-dd-yy 
$fileName = "$Name-$todaydate.csv" 
$file = New-Item -ItemType File -Name $fileName -Force
$script:jobs = @()
$acctKey = (Get-AzureRmStorageAccountKey -Name $StorageAccount -ResourceGroupName $StorageRG).Value[0]  #Get key to storage account
$storageContext = New-AzureStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $acctKey  #Map to the reports BLOB context
#Copy the file to the storage account
$blob = Get-AzureStorageBlobContent -Blob $fileName -Container $Container -Context $storageContext -Destination $file -Force
$PowerStateCSV = Import-Csv $file -ErrorAction:SilentlyContinue

#endregion variables

#region code
foreach ($VMCSV in $PowerStateCSV) {
    $VMName = $VMCSV.VMName
    $VMRG = $VMCSV.VMResourceGroupName
    if (($VMCSV.VMState -eq "VM running") -or ($VMState -eq "VM generalized")) {Continue}
    Try {$jobs += Stop-AzureRMVM -ResourceGroupName $VMRG -Name $VMName -Force -ErrorAction SilentlyContinue -AsJob}
    Catch {$_.Exception.Message;$FailedItem = $_.Exception.ItemName; Continue}
}
Wait-Job -Job $Jobs -Timeout 1800 | Out-Null
$IncompleteJobs = (Get-Job | Where-Object {$_.State -ne "Completed"} | Stop-Job).count
Get-Job | Where-Object {$_.State -ne "Completed"} | Stop-Job
Remove-Job -Job $Jobs
Remove-AzureStorageBlob -Blob $fileName -Container $Container -Context $storageContext -Confirm:$false -Force
#endregion code
