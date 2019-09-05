#requires -version 3.0

function Add-RegKeyMember {
<#
.SYNOPSIS
Adds note properties containing the last modified time and class name of a 
registry key.

.DESCRIPTION
The Add-RegKeyMember function uses the unmanged RegQueryInfoKey Win32 function
to get a key's last modified time and class name. It can take a RegistryKey 
object (which Get-Item and Get-ChildItem output) or a path to a registry key.

.EXAMPLE
PS> Get-Item HKLM:\SOFTWARE | Add-RegKeyMember | Select Name, LastWriteTime

Show the name and last write time of HKLM:\SOFTWARE

.EXAMPLE
PS> Add-RegKeyMember HKLM:\SOFTWARE | Select Name, LastWriteTime

Show the name and last write time of HKLM:\SOFTWARE

.EXAMPLE
PS> Get-ChildItem HKLM:\SOFTWARE | Add-RegKeyMember | Select Name, LastWriteTime

Show the name and last write time of HKLM:\SOFTWARE's child keys

.EXAMPLE
PS> Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Control\Lsa | Add-RegKeyMember | where classname | select name, classname

Show the name and class name of child keys under Lsa that have a class name defined.

.EXAMPLE
PS> Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | Add-RegKeyMember | where lastwritetime -gt (Get-Date).AddDays(-30) | 
>> select PSChildName, @{ N="DisplayName"; E={gp $_.PSPath | select -exp DisplayName }}, @{ N="Version"; E={gp $_.PSPath | select -exp DisplayVersion }}, lastwritetime |
>> sort lastwritetime

Show applications that have had their registry key updated in the last 30 days (sorted by the last time the key was updated).
NOTE: On a 64-bit machine, you will get different results depending on whether or not the command was executed from a 32-bit
      or 64-bit PowerShell prompt.

#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName="ByKey", Position=0, ValueFromPipeline)]
        # Registry key object returned from Get-ChildItem or Get-Item
        [Microsoft.Win32.RegistryKey] $RegistryKey,
        [Parameter(Mandatory, ParameterSetName="ByPath", Position=0)]
        # Path to a registry key
        [string] $Path
    )

    begin {
        # Define the namespace (string array creates nested namespace):
        $Namespace = "CustomNamespace", "SubNamespace"

        # Make sure type is loaded (this will only get loaded on first run):
        Add-Type @"
            using System; 
            using System.Text;
            using System.Runtime.InteropServices; 

            $($Namespace | ForEach-Object {
                "namespace $_ {"
            })

                public class advapi32 {
                    [DllImport("advapi32.dll", CharSet = CharSet.Auto)]
                    public static extern Int32 RegQueryInfoKey(
                        Microsoft.Win32.SafeHandles.SafeRegistryHandle hKey,
                        StringBuilder lpClass,
                        [In, Out] ref UInt32 lpcbClass,
                        UInt32 lpReserved,
                        out UInt32 lpcSubKeys,
                        out UInt32 lpcbMaxSubKeyLen,
                        out UInt32 lpcbMaxClassLen,
                        out UInt32 lpcValues,
                        out UInt32 lpcbMaxValueNameLen,
                        out UInt32 lpcbMaxValueLen,
                        out UInt32 lpcbSecurityDescriptor,
                        out Int64 lpftLastWriteTime
                    );
                }
            $($Namespace | ForEach-Object { "}" })
"@
    
        # Get a shortcut to the type:    
        $RegTools = ("{0}.advapi32" -f ($Namespace -join ".")) -as [type]
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            "ByKey" {
                # Already have the key, no more work to be done :)
            }

            "ByPath" {
                # We need a RegistryKey object (Get-Item should return that)
                $Item = Get-Item -Path $Path -ErrorAction Stop

                # Make sure this is of type [Microsoft.Win32.RegistryKey]
                if ($Item -isnot [Microsoft.Win32.RegistryKey]) {
                    throw "'$Path' is not a path to a registry key!"
                }
                $RegistryKey = $Item
            }
        }

        # Initialize variables that will be populated:
        $ClassLength = 255 # Buffer size (class name is rarely used, and when it is, I've never seen 
                            # it more than 8 characters. Buffer can be increased here, though. 
        $ClassName = New-Object System.Text.StringBuilder $ClassLength  # Will hold the class name
        $LastWriteTime = $null
            
        switch ($RegTools::RegQueryInfoKey($RegistryKey.Handle,
                                    $ClassName, 
                                    [ref] $ClassLength, 
                                    $null,  # Reserved
                                    [ref] $null, # SubKeyCount
                                    [ref] $null, # MaxSubKeyNameLength
                                    [ref] $null, # MaxClassLength
                                    [ref] $null, # ValueCount
                                    [ref] $null, # MaxValueNameLength 
                                    [ref] $null, # MaxValueValueLength 
                                    [ref] $null, # SecurityDescriptorSize
                                    [ref] $LastWriteTime
                                    )) {

            0 { # Success
                $LastWriteTime = [datetime]::FromFileTime($LastWriteTime)

                # Add properties to object and output them to pipeline
                $RegistryKey | Add-Member -NotePropertyMembers @{
                    LastWriteTime = $LastWriteTime
                    ClassName = $ClassName.ToString()
                } -PassThru -Force
            }

            122  { # ERROR_INSUFFICIENT_BUFFER (0x7a)
                throw "Class name buffer too small"
                # function could be recalled with a larger buffer, but for
                # now, just exit
            }

            default {
                throw "Unknown error encountered (error code $_)"
            }
        }
    }
}

#Trezor One =    "*VID_534C*"
#Trezor T =      "*VID_1209*"
#Ledger Nano S = "*VID_2C97*"
#KeepKey =       "*VID_2B24*"

cls

"`nThis PowerShell script will find evidence of cryptocurrency hardware wallets and return the serial number of the device and the time and date it was last entered into the machine.`n"

pause

"`nLooking for the Trezor One (Vendor ID 534C)...`n"
Start-Sleep -s 1
get-itemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\* | Where-Object HardwareID -like "*VID_534C*" | Select-Object @{Name="DeviceDesc"; Expression={ $_.DeviceDesc -split ";" | select -last 1 }}, @{Name="SerialNumber"; Expression={ $_.PsChildName }}, @{Name="LastModified"; Expression={ (Add-RegKeyMember $_.PsPath).LastWriteTime }}

"`n========================================================"
"`nLooking for the Trezor T (Vendor ID 1209)...`n"
Start-Sleep -s 1
get-itemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\* | Where-Object HardwareID -like "*VID_1209*" | Select-Object @{Name="DeviceDesc"; Expression={ $_.DeviceDesc -split ";" | select -last 1 }}, @{Name="SerialNumber"; Expression={ $_.PsChildName }}, @{Name="LastModified"; Expression={ (Add-RegKeyMember $_.PsPath).LastWriteTime }}

"`n========================================================"
"`nLooking for the Ledger Nano S (Vendor ID 2C97)...`n"
Start-Sleep -s 1
get-itemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\* | Where-Object HardwareID -like "*VID_2C97*" | Select-Object @{Name="DeviceDesc"; Expression={ $_.DeviceDesc -split ";" | select -last 1 }}, @{Name="SerialNumber"; Expression={ $_.PsChildName }}, @{Name="LastModified"; Expression={ (Add-RegKeyMember $_.PsPath).LastWriteTime }}

"`n========================================================"
"`nLooking for the KeepKey (Vendor ID 2B24)...`n"
Start-Sleep -s 1
get-itemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\* | Where-Object HardwareID -like "*VID_2B24*" | Select-Object @{Name="DeviceDesc"; Expression={ $_.DeviceDesc -split ";" | select -last 1 }}, @{Name="SerialNumber"; Expression={ $_.PsChildName }}, @{Name="LastModified"; Expression={ (Add-RegKeyMember $_.PsPath).LastWriteTime }}



