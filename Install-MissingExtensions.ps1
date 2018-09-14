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

#region Variables
$ExtensionsNeeded =@('BGInfo','joindomain','MicrosoftMonitoringAgent')
$VMs = Get-AzureRMVM | Where-Object {$_Name -match "Brill"}
$DSCAccount = "EUS-AAA-FS-Dev"
$DSCRG = "EUS-RSG-ALL-DEV"
#endregion Variables

#region Functions
function joindomain {
    $PoweredUp = $false
    $Secret = '"' +(Get-AzureKeyVaultSecret -VaultName cloudops-dev -Name 'labsadmin').SecretValueText + '"'
    $Settings = '{
        "Name": "cargill-fms.com",
        "User": "cargill-fms\\labsadmin",
        "Restart": "true",
        "OUPath": "OU=DEV_TEST,OU=Managed Computers,OU=Enterprise,DC=cargill-fms,DC=com",
        "Options": "3"
    }'
    $ProtectedSettings = "{""Password"": $Secret}"

    Invoke-AzureRmVMRunCommand -ResourceGroupName $VMRG -Name $ComputerName -CommandId EnableRemotePS

    Set-AzureRmVMExtension -ResourceGroupName $VMRG -Location $VMLocation -VMName $VMName `
        -ExtensionName "joindomain" -Publisher "Microsoft.Compute" `
        -ExtensionType "JsonADDomainExtension" -TypeHandlerVersion "1.0" `
		-SettingString $Settings -ProtectedSettingString $ProtectedSettings -ForceRerun $($VMName + (Get-Date -Format MM-dd-yy))
}

function BGInfo {
    $PoweredUp = $false
    Set-AzureRmVMExtension -ResourceGroupName $VMRG -Location $VMLocation -VMName $VMName `
        -ExtensionName BGInfo -Publisher Microsoft.Compute -Version 2.1 -ExtensionType BGInfo -ForceRerun $($VMName + (Get-Date -Format MM-dd-yy))
}

function MicrosoftMonitoringAgent {
    $PoweredUp = $false
    $PublicSettings = @{"workspaceId" = "c4595b30-6705-4e15-989c-5addd5a97841" }
    $ProtectedSettings = @{"workspaceKey" = '"3Aap96E8khc7Kw6hrHOnOK1Z1hVXKncy2rTffF4ntmcMwjS4GSH5oicFVF+HVHe03jQrb7lcBKuE5bTJt+pkiw=="' }
    Set-AzureRmVMExtension  -ResourceGroupName $VMRG -Location $VMLocation -VMName $VMName `
        -ExtensionName "Microsoft.EnterpriseCloud.Monitoring" -Publisher "Microsoft.EnterpriseCloud.Monitoring" `
        -ExtensionType "MicrosoftMonitoringAgent" -TypeHandlerVersion 1.0 `
        -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -ForceRerun $($VMName + (Get-Date -Format MM-dd-yy))
}
#endregion Functions

foreach ($VM in $VMS) {
    $Extensions = ($vm.Extensions.Id) | %{$_.Split('/')[10];}
    $VMName = $VM.Name
    $VMRG = $VM.ResourceGroupName
    $VMLocation = $VM.Location
    $PoweredUp = $true
    if ((Get-AzureRMVM -ResourceGroupName $VMRG -Name $VMName -Status).Statuses[1].DisplayStatus -ne "VM running") {$PoweredUp = $false}
    foreach ($Match in $ExtensionsNeeded) {
        if (!($extensions -match $Match)) {
            Write-Host "The host, $VMName is missing the extension $Match."
            if ($PoweredUp -eq $false) {Write-Host "VM, $VMName is powered off.  I need to start it"; Start-AzureRmVM -ResourceGroupName $VMRG -Name $VMName}
            if ($Match -eq "joindomain") {joindomain}
            if ($Match -eq "BGInfo") {BGInfo}
            if ($Match -eq "MicrosoftMonitoringAgent") {MicrosoftMonitoringAgent}
        }
    }

    if ($PoweredUp -eq $false) {Write-Host "Powering off VM, $VMName."; Stop-AzureRmVM -ResourceGroupName $VMRG -Name $VMName -Force}

    if (!(Get-AzureRmAutomationDscNode -AutomationAccountName $DSCAccount -ResourceGroupName $DSCRG -Name $VMName )) {
        Write-Host "The host, $VMName, is not in DSC."
        Register-AzureRmAutomationDscNode -AutomationAccountName $DSCAccount -ResourceGroupName $DSCRG -AzureVMName $VMName -NodeConfigurationName "CyberSecurityDSC.localhost"
    }
}
