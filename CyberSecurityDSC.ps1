<#
.Synopsis
   Master DSC configuration
.DESCRIPTION
   This is the master DSC for all systems.  This configuration holds all of the software required to be considerd a "hardened image" by TGRC.
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   Created on 19 June 2018 by Craig Franzen
   Software deployed:
   Symantec EndPoint Protection v14.0.2461.020			C:\Deploy\CyberSecurity\SymantecEndpointProtection_14.0.2461.0207\Install x64\Install.exe						No Arguments
   FlexNet Inventory Agent v11.0						\\fms-fileserver\DSC_Share\CyberSecurity\FlexNet Inventory Agent 11.10.12572 for Azure\Install\Install.exe		No Arguments

   Software removed:
   Symantec EndPoint Protection v12.1. (64-bit x64)	\\fms-fileserver\DSC_Share\RemovalSoftware\Symantec Endpoint Protection 12.1.7004.6500\Install x64\Install.exe	no arguments

   To add a new installation, you will need to move the current one.  Copy to installion Package.  Change the title to "Remove-"softwareName.  Change Ensure from "Present" to "Absent".  
   Now, change the Name of the installation, use the current version or date the change was made.  Change the Path to the new installation directory.  
   If it needs to be local, add it to the local copy.  Than change the date of the Script-SyncInstallFolder to the current date.
   Change the ProductId.  This can be found on a machine that already has the software installed by runnint the command:  Get-CimInstance -ClassName Win32_Product | Sort Vendor, Name| Select Vendor, Name, IdentifyingNumber
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>

configuration CyberSecurityDSC
{
    node localhost
    {
        File InstallLogDir
        {
            #Create directory for logs
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = "C:\DSCInstall-Logs"
        }
        File CyberSecurity-2018-07-02
        {
            Ensure = "Present" # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            Recurse = $true # Ensure presence of subdirectories, too
            SourcePath = "\\fms-fileserver\DSC_Share\RequiredSoftware\CyberSecurity"
            DestinationPath = "C:\Deploy\CyberSecurity"
            MatchSource = $true
            Checksum = "SHA-256"
            Force = $true
        }
        
        # Use this to find the ProductId:     Get-CimInstance -ClassName Win32_Product | Sort Vendor, Name| Select Vendor, Name, IdentifyingNumber
        Package TaniumClient-6-25-2018
        {
            Ensure = "Present"
            Name = 'Tanium Client 6.0.314.1540'
            Path = '\\fms-fileserver\DSC_Share\RequiredSoftware\CyberSecurity\TaniumClient-6.0.314.1540\InstallTanium.exe'
            ProductId = ''
            LogPath = "C:\DSCInstall-Logs\TaniumClient6.0.log"
            Dependson = @("[file]InstallLogDir")
        }
        Package Remove-Symantec-12_1_7004_6500
        {
            Ensure = "Absent"
            Name = 'Symantec EndPoint Protection v12.1. (64-bit x64)'
            Path = '\\fms-fileserver\DSC_Share\RemovalSoftware\Symantec Endpoint Protection 12.1.7004.6500\Install x64\Install.exe'
            ProductId = 'F90EEB64-A4CB-484A-8666-812D9F92B37B'
            LogPath = "C:\DSCInstall-Logs\Symantec12.1.log"
            Dependson = @("[file]InstallLogDir")
        }
        Package Symantec-14_0_2461_0207
        {
            Ensure = "Present"
            Name = 'Symantec Endpoint Protection'
            Path = 'C:\Deploy\CyberSecurity\SymantecEndpointProtection_14.0.2461.0207\Install x64\Install.exe'
            ProductId = '3FB00667-A375-4344-8B54-92AA155DC95B'
            LogPath = "C:\DSCInstall-Logs\Symantec14.0.log"
            Dependson = @("[file]CyberSecurity-2018-07-02","[file]InstallLogDir")
        }
        Package FlexNet-11_10_12572
        {
            Ensure = "Present"
            Name = 'FlexNet Inventory Agent'
            Path = '\\fms-fileserver\DSC_Share\CyberSecurity\FlexNet Inventory Agent 11.10.12572 for Azure\Install\Install.exe'
            ProductId = '6015A890-136D-45F4-A2C7-CF4137F4CDF6'
            LogPath = "C:\DSCInstall-Logs\FlexNet11.0.log"
            Dependson = @("[file]InstallLogDir")
        }
        Log AfterDirectoryCopy
        {
            # The message below gets written to the Microsoft-Windows-Desired State Configuration/Analytic log
            Message = "Finished running the file resource with ID FileCopy"
            DependsOn = @("[Package]TaniumClient-6-25-2018","[Package]Remove-Symantec-12_1_7004_6500","[Package]Symantec-14_0_2461_0207","[file]CyberSecurity-2018-07-02","[file]InstallLogDir")
        }
    }
} 
