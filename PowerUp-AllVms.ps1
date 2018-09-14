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
$FileName = "$Name-$todaydate.csv" 
$file = New-Item -ItemType File -Name $FileName
#$VMs = Get-AzureRMVM | Where-Object {$_.Name -notmatch "FMS-DC02"}
$VMs = Get-AzureRMVM | Where {$_.Name -match "Brill"}
$script:jobs = @()
#endregion variables

#region functions
Function Get-VMPowerStatus() { 
	param (
		[Parameter(Mandatory=$true)]
		[string]$VMName,
		[Parameter(Mandatory=$true)]
		[string]$VMState,
		[Parameter(Mandatory=$true)]
		[string]$VMRG
	)
	#Create Object for Current state
	$Properties = New-Object PSObject -Property @{
		VMName = $VMName
		VMState = $VMState
		VMResourceGroupName = $VMRG
	}
    $Properties | Export-Csv -NoTypeInformation -Append $File
    If (($VMState -ne "VM running") -and ($VMState -ne "VM generalized")) {
	    Try {$global:jobs += Start-AzureRMVM -ResourceGroupName $VMRG -Name $VMName -ErrorAction Stop -AsJob}
        Catch {$_.Exception.Message; Continue}
	} 
}
#endregion functions

#region code
foreach ($VM in $vms) {
    $vmName = $vm.name
    $VMStatus = $VM | Get-AzureRMVM -Status -ErrorAction SilentlyContinue
    $VMState = $VMStatus.Statuses[1].DisplayStatus
    $VMRG = $VM.ResourceGroupName
    Get-VMPowerStatus -VMName $vmName -VMState $VMState -VMRG $VMRG
}

Wait-Job $global:jobs -Timeout 1800 | Out-Null
$IncompleteJobs = (Get-Job | Where-Object {$_.State -ne "Completed"}).count
Get-Job | Where-Object {$_.State -ne "Completed"} | Stop-Job
Get-Job | Remove-Job

# Set temp file to storage
$acctKey = (Get-AzureRmStorageAccountKey -Name $StorageAccount -ResourceGroupName $StorageRG).Value[0] #Get key to storage account
$storageContext = New-AzureStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $acctKey #Map to the reports BLOB context
Set-AzureStorageBlobContent -File $file -Container $Container -BlobType "Block" -Context $storageContext -Verbose -Force #Copy the file to the storage account
#endregion code
