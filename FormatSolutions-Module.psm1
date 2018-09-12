    <#
    .Synopsis
       This is a module written for Format Solutions
    .DESCRIPTION
       This is a module written for Format Solutions
    .NOTES
       Place this file in one of the PSModule paths.  Always create a folder to place the module in.  
       To find the paths available, use this command:  $env:PSModulePath
       Two common places to place a module are:
            %SystemRoot%\System32\WindowsPowerShell\v1.0\Modules\<moduleName>
            %SystemRoot%\users\<user>\Documents\WindowsPowerShell\Modules\<moduleName>.
       Written by Craig Franzen
    #>

function Azure-Login {
    <#
    .Synopsis
       A default Azure Login function
    .DESCRIPTION
       A default Azure Login function.  function validates that the user is correct my email.
    .EXAMPLE
       Azure-Login
    .EXAMPLE
       Azure-Login -UserName Craig@mtrgoose.com
    .INPUTS
       No input
    .OUTPUTS
       Output from this cmdlet (if any)
    .NOTES
       Written by Craig Franzen
       v2.0 - 19 Jan 2018 - Added menu
    #>
    Param (
        [Parameter(Mandatory=$false)]
        [string] $UserName,
        [Parameter(Mandatory=$false)]
        [switch]$Proxy,
        [Parameter(Mandatory=$false)]
        [switch]$BypassUserValidation
    )

$menu = @{}
    
# for the Cargill Proxy
if($Proxy) {[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials}
# Get Users email address from AD for logging into Azure
$strName = $env:username
$strFilter = "(&(objectCategory=User)(samAccountName=$strName))"
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.Filter = $strFilter
$objPath = $objSearcher.FindOne()
# this can be a few different variables
$UserName = $objPath.Properties.mail
$continue = Read-Host "Logging you into Azure using $UserName.  Is this correct? (N/y)"
while("y","n" -notcontains $continue )
{
	$continue = Read-Host "Please enter your response (N/y)"
}
Switch ($continue) 
{ 
	Y {Continue} 
	N {$UserName = Read-Host "Please input the username to log in with"} 
} 

if (!($BypassUserValidation)) {
    # Validates logged in user is same as one trying to access login
    $strName = $env:username
    $strFilter = "(&(objectCategory=User)(samAccountName=$strName))"

    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $objSearcher.Filter = $strFilter

    $objPath = $objSearcher.FindOne()
    # this can be a few different variables
    $UserEmail = $objPath.Properties.mail
    # $UserEmail = $objPath.userprincipalname
    if ($UserEmail -ne $UserName) {Write-Host "You are not the using your own credentials, quiting" ; break}
}
    	
    # create loging credential string
    $CredfileName = $UserName -replace "@","-" -replace "com","txt"
    if (!(Test-Path $env:USERPROFILE\Documents\$CredfileName)) {Write-Host "Unable to find password file.  Please enter your password now: ";Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File $env:USERPROFILE\Documents\$CredfileName}
    $password = cat $env:USERPROFILE\Documents\$CredfileName | convertto-securestring
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password

    Write-Host "Logging into Azure with $UserName" -ForegroundColor Green
    Try {Login-AzureRmAccount -Credential $cred -ErrorAction SilentlyContinue | Out-Null}
    Catch {$ErrorMessage = $_}
        
    # Creates menu for all available subscriptions
    $Subscriptions = Get-AzureRmSubscription
    
    Write-Host "`n`nPlease select the subscription to log into"
    for ($i=1;$i -le $Subscriptions.count; $i++) {
        Write-Host "$i. $($Subscriptions[$i-1].name)" 
        $menu.Add($i,($Subscriptions[$i-1].name))
    }

    [int]$ans = Read-Host 'Enter selection'
    $selection = $menu.Item($ans) ; Write-host "Logging into Subscription $Selection" -ForegroundColor Green ; Select-AzureRmSubscription -SubscriptionName $selection | Out-Null;
    
    # change window name
    $host.ui.RawUI.WindowTitle = "Azure Subscription - $selection" 
}

function Get-ModulePath {
    $env:PSModulePath.split(';')
}

function Get-Environments {
    Get-ChildItem env:
}

function Replicate-AllDomainController {
	# Found at https://sid-500.com/2017/10/14/active-directory-force-replication-of-all-domain-controllers-on-all-sites-at-once/
	(Get-ADDomainController -Filter *).Name | Foreach-Object {repadmin /syncall $_ (Get-ADDomain).DistinguishedName /e /A | Out-Null}; Start-Sleep 10; Get-ADReplicationPartnerMetadata -Target "$env:userdnsdomain" -Scope Domain | Select-Object Server, LastReplicationSuccess
}

function enable-proxy {
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
}

function add-azuredatadisk {
    #Add data disk to existing vm

    param (
        [Parameter(Mandatory=$true)]
        [array]$vmNames,
        [Parameter(Mandatory=$true)]
        [string]$DiskSize,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Premium_LRS","Standard_LRS")]
        [string]$storageType="Standard_LRS",
        [switch]$Proxy
    )


    #region
    Write-Host "=> Signing into Azure RM." -ForegroundColor Yellow
    Write-Host "=>" -ForegroundColor Yellow
    do {
        $azureAccess = $true
        Try {
            Get-AzureRmSubscription -ErrorAction Stop | Out-Null
        }
        Catch {
            $menu = @{}
            # Get Users email address from AD for logging into Azure
            $strName = $env:username
            $strFilter = "(&(objectCategory=User)(samAccountName=$strName))"
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
            $objSearcher.Filter = $strFilter
            $objPath = $objSearcher.FindOne()
            # this can be a few different variables
            $UserEmail = $objPath.Properties.mail
            $continue = Read-Host "Logging you into Azure using $UserEmail.  Is this correct? (N/y)"
            while("y","n" -notcontains $continue )
            {
                $continue = Read-Host "Please enter your response (N/y)"
            }
            Switch ($continue) 
            { 
                Y {Continue} 
                N {$UserEmail = Read-Host "Please input the username to log in with"} 
            } 
            $CredfileName = $UserEmail -replace "@","-" -replace "com","txt"
            if (!(Test-Path $env:USERPROFILE\Documents\$CredfileName)) {$password = Read-Host "Unable to find password file.  Please enter your password now: " -AsSecureString } else {$password = cat $env:USERPROFILE\Documents\$CredfileName | convertto-securestring}
            $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $CredfileName, $password

            # Log into Azure
            Write-Host "Logging into Azure with $CredfileName" -ForegroundColor Green
            if($Proxy) {[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials}
            Try {Login-AzureRmAccount -Credential $cred -ErrorAction SilentlyContinue | Out-Null}
            Catch {$ErrorMessage = $_;Break}
            # Creates menu for all available subscriptions
            $Subscriptions = Get-AzureRmSubscription

            Write-Host "`n`nPlease select the subscription to log into"
            for ($i=1;$i -le $Subscriptions.count; $i++) {
                Write-Host "$i. $($Subscriptions[$i-1].name)" 
                $menu.Add($i,($Subscriptions[$i-1].name))
            }
    
            [int]$ans = Read-Host 'Enter selection'
            $selection = $menu.Item($ans) ; Write-host "Logging into Subscription $Selection" -ForegroundColor Green ; Select-AzureRmSubscription -SubscriptionName $selection | Out-Null;
        
            # change window name
            $host.ui.RawUI.WindowTitle = "Add data disk to Azure VM(s)" 
        }
        Finally {
            Write-Host "=> OK, you are all logged in and ready to go" -ForegroundColor Yellow
            Write-Host "=>" -ForegroundColor Yellow
        }
    } while (! $azureAccess)
    Write-Host "=> You are now Logged into Azure Resource Manager." -ForegroundColor Yellow
    Write-Host "=>" -ForegroundColor Yellow
    #endregion

    foreach ($vmName in $vmNames) {
        $vm = $null
        Try {$vm = Get-AzureRMVM -ErrorAction Stop | where {$_.Name -match $vmName}}
        Catch {Write-Host "=> Ooopps!, there is no machine named $vmName.  Better go check to make sure the gremlins didn't eat it!" -ForegroundColor Yellow; continue}
        if ($vm -eq $null) {Write-Host "=> Ooopps!, there is no machine named $vmName.  Better go check to make sure the gremlins didn't eat it!" -ForegroundColor Yellow; continue}
        $rgName = $vm.ResourceGroupName
        $location = $vm.Location
        $diskNumber = ((Get-AzureRmDisk | Where {$_.ManagedBy -match $vmName -and $_.Name -match "DataDisk"}).Name).count + 1
        $dataDiskName = $VMName.replace("-vm","") + "-DataDisk0" + $diskNumber

        Write-Host "=> I am did a look up on $vmName.  It is in resource group $rgName.  I am adding on some disk!" -ForegroundColor Yellow

        if ((get-azurermvm -Name $vmname -ResourceGroupName $rgname -Status).statuses[1].DisplayStatus -ne "VM running") {Start-AzureRmVM -Name $vmname -ResourceGroupName $rgname;$started = $true} else {$started = $false}
    
        $diskConfig = New-AzureRmDiskConfig -SkuName $storageType -Location $location -CreateOption Empty -DiskSizeGB $DiskSize
        $dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName

        $vmName = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName 
        $vmName = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun $diskNumber

        Update-AzureRmVM -VM $vmName -ResourceGroupName $rgName

        $vmName = $vmName.Name
        Invoke-AzureRmVMRunCommand -ResourceGroupName $rgname -Name $vmname -CommandId RunPowerShellScript -ScriptPath .\initilizedisk.ps1

        if ($started -eq $true) {Stop-AzureRmVM -Name $vmname -ResourceGroupName $rgname -force}
    }
}

function Expand-AzureOSDisk {
    <#
    .Synopsis
       Resize the OS disk of any number of VM's
    .DESCRIPTION
       Resize the OS disk of any number of Vm's
    .EXAMPLE
       Expand-AzureOSDisk.ps1 -VMName AnyVM -DiskSize 1024
    .EXAMPLE
       Expand-AzureOSDisk.ps1 -VMName AnyVM, anotherVm, Thirdvm -DiskSize 1024,512,2048
        c:\pstemp\Azure\Expand-AzureOSDisk.ps1 -VMNames slav-test-vm, craigsdesktop -DiskSizes 536,536
    .INPUTS
       -VMNames : this is the name or names of vm's to expand the OS disk
       -DiskSizes : This is the size of the desired disk outcome.  This will be the new total size.
    .OUTPUTS
       Output from this cmdlet (if any)
    .NOTES
       Version
       v1.0		29 Aug 2018		Craig Franzen		original script 
       This script is based on this 
    .COMPONENT
       The component this cmdlet belongs to
    .ROLE
       The role this cmdlet belongs to
    .FUNCTIONALITY
       The functionality that best describes this cmdlet
    #>
    # Resize Managed Azure OS Disk
    param (
        [Parameter(Mandatory=$true)]
        [String[]]$VMNames,
        [Parameter(Mandatory=$true)]
        [int[]]$DiskSizes
    )
    Write-Host "=> " -ForegroundColor Yellow
    Write-Host "=> Lets Add some Disks!" -ForegroundColor Yellow
    If ($VMnames.count -ne $DiskSizes.count) {
        Write-Host "=> " -ForegroundColor Yellow
        Write-Host "=> Woh, stop.  You have a different number of VM's than you have sizes.  I don't guess on what size to make your new disk.  Try again!" -ForegroundColor Yellow
        Break
    }
    $VMNamelist = $VMNames -join ","
    Write-Host "=> " -ForegroundColor Yellow
    Write-Host "=> I will be adding disks to these VM's $VMNamelist.  if they are running, I will have to stop them." -ForegroundColor Yellow

    $AllVMs = Get-AzureRMVM
    $VMnamescount = $VMnames.count

    For($I=0;$I -lt $VMNames.count;$I++){
        $VM = $Null
        $VMName = $VMNames[$I]
        $NewSize = $DiskSizes[$I]
        $RoundCount = $I + 1
        Write-Progress -Activity "Expanding OS Disk on $VMnamescount" -Status "Expanding disk for $VMName to $NewSize GB.  $RoundCount of $VMNamescount"
        $VM = ($AllVMs | Where {$_.Name -eq $VMName})
        if ($VM -eq $Null) {
            Write-Host "=> " -ForegroundColor Yellow
            Write-Host "=> oh O, there is nothing found named $VMName.  I am moving on the next one." -ForegroundColor Yellow
            Continue
        }
        $VMRG = $vm.ResourceGroupName
        $deallocated = $true
        if (((Get-Azurermvm -Name $VMName -ResourceGroupName $VMRG -Status).Statuses[1].DisplayStatus) -ne "VM deallocated") {
            Write-Host "=> " -ForegroundColor Yellow
            Write-Host "=> Stopping $VMName now to add disk" -ForegroundColor Yellow
            Stop-AzureRMVM -Name $VMName -ResourceGroupName $VMRG -Force | Out-Null
            $deallocated = $false
        }
        Write-Host "=> " -ForegroundColor Yellow
        Write-Host "=> changing disk size on $VMName" -ForegroundColor Yellow
        
        $VMdisk= Get-AzureRmDisk -ResourceGroupName $VMRG -DiskName $VM.StorageProfile.OsDisk.Name 
        $VMdisk.DiskSizeGB = $NewSize
        Update-AzureRmDisk -ResourceGroupName $VMRG -Disk $VMdisk -DiskName $VMdisk.Name | Out-Null

        Write-Host "=> " -ForegroundColor Yellow
        Write-Host "=> Starting VM and expanding disk size on $VMName" -ForegroundColor Yellow

        Start-AzureRMVM -Name $VMName -ResourceGroupName $VMRG | Out-Null
        $ScriptDiskSize = ([string]($NewSize - 1) + 'GB')
        $InitializeDisk = "Resize-Partition -DriveLetter c -Size ($ScriptDiskSize)"
        $tmp = New-TemporaryFile
        Rename-Item $tmp "InitializeDisk.ps1" -Confirm:$false
        $InitialDiskScript = $tmp.DirectoryName + "\InitializeDisk.ps1"
        $InitializeDisk > $InitialDiskScript

        Invoke-AzureRmVMRunCommand -VMName $VMName -ResourceGroupName $VMRG -CommandId 'RunPowerShellScript' -ScriptPath $InitialDiskScript | Out-Null
        Remove-Item $InitialDiskScript -Force | Out-Null
        if ($deallocated -eq $true) {Stop-AzureRMVM -Name $VMName -ResourceGroupName $VMRG -Force | Out-Null}
        Write-Host "=> " -ForegroundColor Yellow
        Write-Host "=> Done with $VMName." -ForegroundColor Yellow

    }
}

function Change-AzureSubscription {
    <#
    .Synopsis
        Change Azure Subscription function
    .DESCRIPTION
        Change Azure Subscription function
    .EXAMPLE
        Change-AzureSbuscription
    .INPUTS
        No input
    .OUTPUTS
        Output from this cmdlet (if any)
    .NOTES
        Written by Craig Franzen
        v1.0 - 5 September 2018
    #>

    Param (
        [Parameter(Mandatory=$false)]
        [switch]$Proxy
    )
    $menu = @{}
    
    # for the Cargill Proxy
    if($Proxy) {[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials}
    
    # Creates menu for all available subscriptions
    $Subscriptions = Get-AzureRmSubscription

    Write-Host "`n`nPlease select the subscription to log into"
    for ($i=1;$i -le $Subscriptions.count; $i++) {
        Write-Host "$i. $($Subscriptions[$i-1].name)" 
        $menu.Add($i,($Subscriptions[$i-1].name))
    }

    [int]$ans = Read-Host 'Enter selection'
    $selection = $menu.Item($ans) ; Write-host "Logging into Subscription $Selection" -ForegroundColor Green ; Select-AzureRmSubscription -SubscriptionName $selection | Out-Null;

    # change window name
    $host.ui.RawUI.WindowTitle = "Azure Subscription - $selection" 

}

function Move-AzureRMVMSubscription {
    <#
    .Synopsis
       Moving ARM VM's from one subscription to another.
    .DESCRIPTION
       Long description
    .EXAMPLE
       Example of how to use this cmdlet
    .EXAMPLE
       Another example of how to use this cmdlet
    .INPUTS
       Inputs to this cmdlet (if any)
    .OUTPUTS
       Output from this cmdlet (if any)
    .NOTES
       Found at https://brianfarnhill.com/2017/11/10/moving-azure-vms-managed-disks-new-subscription/
       $SourceVMName = "2012Pervasive"
       $sourceResourceGroupName = "FMS_VM_Repository"
       $NewSubscriptionId = 'a3750e25-9701-422d-a956-31d87d93f99e'
       $NewResourceGroupName = 'Brill-labRG403125'
       $NewVMName = "2012-Pervasive"

    .COMPONENT
       The component this cmdlet belongs to
    .ROLE
       The role this cmdlet belongs to
    .FUNCTIONALITY
       The functionality that best describes this cmdlet
    #>

    Param (
	    # Param1 help description
	    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
	    [ValidateNotNullOrEmpty()]
	    [string[]]$SourceVMName,
	    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
	    [ValidateNotNullOrEmpty()]
	    [string[]]$sourceResourceGroupName,
	    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
	    [ValidateNotNullOrEmpty()]
	    [string[]]$NewResourceGroupName,
	    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
	    [ValidateNotNullOrEmpty()]
	    [string[]]$NewVMName
    )

    #Source Subscription
    $SourceSubscription = Get-AzureRmSubscription | Select Name, ID |  Out-GridView -OutputMode Single -Title 'Please select the source subscription'
    Select-AzureRmSubscription -SubscriptionId $SourceSubscription.Id | Out-Null

    $DestinationSubscription = Get-AzureRmSubscription | Select Name, ID |  Out-GridView -OutputMode Single -Title 'Please select the destination subscription'

    $NewvNet = Get-AzureRmVirtualNetwork | Select Name, ResourceGroupName | Out-GridView -OutputMode Single -Title 'Please select the new network'
    $NewNetwork = (Get-AzureRmVirtualNetwork -Name $NewvNet.Name -ResourceGroupName $NewvNet.ResourceGroupName).Subnets | Select Name | Out-GridView -OutputMode Single -Title 'Please select the new Subnet'
    $NewNetwork = (Get-AzureRmVirtualNetwork -Name $NewvNet.Name -ResourceGroupName $NewvNet.ResourceGroupName).Subnets | Where {$_.Name -eq $NewNetwork.Name}

    $Secret = '"' +(Get-AzureKeyVaultSecret -VaultName cloudopslab2861 -Name 'labsadmin').SecretValueText + '"'

    $Settings = '{
	    "Name": "cargill-fms.com",
	    "User": "cargill-fms\\labsadmin",
	    "Restart": "true",
	    "OUPath" : "OU=Dev_Test,OU=Managed Computers,OU=Enterprise,DC=Cargill-FMS,DC=com",
	    "Options": "3"
    }'

    $ProtectedSettings = "{""Password"": $Secret}"

    $SourceVM = Get-AzureRMVM -ResourceGroupName $sourceResourceGroupName -Name $SourceVMName 
    if ($SourceVM.StorageProfile.OsDisk.ManagedDisk -eq $Null) {Stop-AzureRMVM -ResourceGroupName $sourceResourceGroupName -Name $SourceVMName -Confirm:$false -Force; ConvertTo-AzureRmVMManagedDisk -ResourceGroupName $sourceResourceGroupName -VMName $SourceVMName}
    $managedDiskName = $SourceVM.StorageProfile.OsDisk.Name
    $vmSize = $SourceVM.HardwareProfile.VmSize
    if  ($vmSize -ne "Standard_D2s_v3" -and $vmSize -ne "Standard_D4s_v3") {Write-Host "VM is not a standard size.  It is currently $vmSize.  Do you wish to continue?"; Pause}
    Stop-AzureRMVM -ResourceGroupName $sourceResourceGroupName -Name $SourceVMName -Confirm:$false -Force -AsJob
    $managedDisk = Get-AzureRMDisk -ResourceGroupName $sourceResourceGroupName -DiskName $managedDiskName

    # Move to destination subscription
    Select-AzureRmSubscription -SubscriptionId $DestinationSubscription.Id | Out-Null
    $diskConfig = New-AzureRmDiskConfig -SourceResourceId $managedDisk.Id -Location $managedDisk.Location -CreateOption Copy 
    $newDiskName = $NewVMName + "_OSDisk"
    $NewDisk = New-AzureRmDisk -Disk $diskConfig -DiskName $newDiskName -ResourceGroupName $NewResourceGroupName

    $NicName = $NewVMName + "-nic"
    $nic = New-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $NewResourceGroupName -Location "centralus" -SubnetId $NewNetwork.id -IpConfigurationName "IPConfiguration1"
    $vmConfig = New-AzureRmVMConfig -VMName $NewVMName -VMSize $VMSize
    $vmconfig = Add-AzureRmVMNetworkInterface -VM $vmconfig -Id $nic.Id
    $vmConfig = Set-AzureRmVMOSDisk -VM $vmConfig -ManagedDiskId $NewDisk.Id -CreateOption Attach -Windows
    # $vmConfig = Add-AzureRmVMDataDisk -VM $vmConfig -ManagedDiskId $secondDisk.Id -Lun 0 -CreateOption Attach
    New-AzureRmVM -ResourceGroupName $NewResourceGroupName -Location "CentralUS" -VM $vmConfig

    Restart-AzureRmVM -ResourceGroupName $NewResourceGroupName -Name $NewVMName

    Set-AzureRmVMExtension `
    -ResourceGroupName $NewResourceGroupName `
    -Location "Central US" `
    -VMName $NewVMName `
    -ExtensionName "Join-Cargill-FMS" `
    -Publisher "Microsoft.Compute" `
    -ExtensionType "JsonADDomainExtension" `
    -TypeHandlerVersion "1.0" `
    -SettingString $Settings `
    -ProtectedSettingString $ProtectedSettings;
}

Export-ModuleMember -Function * -Alias * 

