<#  
.SYNOPSIS
	This script will clean up the history of usb devices connected to a selected machine
.DESCRIPTION
	This script will clean up the history of usb devices connected to a selected machine
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.PARAMETER test
	If present, the script will only display what it would have deleted
.PARAMETER reboot
	If present, the system will be rebooted after the updates are made.
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Oct 19, 2015
#>
[CmdletBinding()]
param( $hostCsvPath = "", $computers = @(), $OU = "", [switch] $test, [switch] $reboot ) 

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$cleanUsbHistoryClass = new-PSClass cleanUsbHistory{
	note -static PsScriptName "cleanUsbHistory"
	note -static Description ($(((get-help .\cleanUsbHistory.ps1).Description)) | select Text).Text
	
	note -private HostObj @{}
	
	note -private mainProgressBar
	note -private gui
	
	note -private reboot
	note -private test
	
	note -private deviceTypes @()
	
	
	constructor{
		param()
		$private.HostObj = $HostsClass.New()
		
		$private.reboot = $reboot
		$private.test = $test
		
		$private.gui = $null
		$private.gui = $guiClass.New("cleanUsbHistory.xml")
		$private.gui.generateForm();
		$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
		
		$private.gui.Controls.chkAll.add_Click({
			if($private.gui.Controls.chkAll.checked -eq $true){
				$private.gui.Controls.keys | ? { $_ -like 'chk*' } | % { $private.gui.Controls.$($_).checked = $true;  }
			}else{
				$private.gui.Controls.keys | ? { $_ -like 'chk*' } | % { $private.gui.Controls.$($_).checked = $false }
			}

		})
		
		$private.gui.Form.ShowDialog()| Out-Null
		
		$private.reboot = $private.gui.Controls.Reboot.checked
		$private.test = $private.gui.Controls.Test.checked
		
		$private.gui.Controls.keys | ? { $_ -like 'chk*' } | % {
			if( $private.gui.Controls.$($_).checked -eq $true){
				$private.deviceTypes += ( $_ -replace "chk","" -creplace '([A-Z]+)', ' $1' -creplace '([A-Z])([a-z])',' $1$2' -creplace '  ',' ').Trim()
			}
		}
	}
	
	method Execute{
		
		$currentComputer = 0
		if($private.HostObj.Count -gt 0){
			$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		
			foreach($computerName in ( $private.HostObj.Hosts.keys ) ){
				
				$i = (100*($currentComputer / $private.HostObj.Hosts.count))
				$private.mainProgressBar.Activity("$currentComputer / $($private.HostObj.Hosts.count): Processing system $computerName").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
				
				$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($computerName.Trim())'"
				if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
				
					$uiClass.writeColor( "$($uiClass.STAT_OK) Processing #green#$($computerName)#" )
				
					if($private.deviceTypes -contains 'All'){
						$private.uninstallUsbStor($computerName)
						$private.uninstallUsbVendor($computerName,'')
					}else{
						$private.deviceTypes | % {
							switch($_){
								'USBSTOR'	{ $private.uninstallUsbStor($computerName) }
								'WPD' 		{ $private.uninstallWPD($computerName) }
								default 	{ $private.uninstallUsbVendor($computerName, $_) }
							}
						}
					}
					
					if($private.reboot){
						$private.restartComputer($computerName)
					}
					
				}else{
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) Skipping #green#$($_)#... not accessible" )
				}
				$currentComputer = $currentComputer + 1
			}
		}
		$uiClass.errorLog()
	}
	
	method -private restartComputer{
		param($computerName)
		
		Restart-Computer -ComputerName $computerName -Force
	}
	
	method -private uninstallUsbStor{
		param($computerName)
		$uiClass.writeColor("$($uiClass.STAT_OK) Searching for #yellow#UsbStor# devices on #green#$($computerName)#")
		
		New-Item "\\$($computerName)\c`$\tsg\" -type directory -force
		$d = "{0:yyyyMMdd-HHmmss}" -f [DateTime]::now
		$e = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg" "export" "hklm\system\currentcontrolset\enum\usbstor" "c:\tsg\$($computerName)_$($d)_UsbStor.reg"
		move-item "\\$($computerName)\c`$\tsg\$($computerName)_$($d)_UsbStor.reg" "$($pwd)\results\" -force
		
		$t = .\bin\psexec.exe \\$($computerName) -s cmd /c reg query "hklm\system\currentcontrolset\enum\usbstor"
		$t | ? { $utilities.isBlank($_) -eq $false } | % {
			if(!$private.test){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Deleting #yellow#$($_)# Key on #green#$($computerName)#")
				$d = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg.exe" "delete" "$($_.replace('&','^&'))" "/f"
			}else{
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Found #yellow#$($_)# Key on #green#$($computerName)#")
			}
		}
	}
	
	method -private uninstallUsbVendor{
		param($computerName, $context)
		
		$uiClass.writeColor("$($uiClass.STAT_OK) Searching for #yellow#$($context)# devices on #green#$($computerName)#")
		New-Item "\\$($computerName)\c`$\tsg\" -type directory -force
		$d = "{0:yyyyMMdd-HHmmss}" -f [DateTime]::now
		$e = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg" "export" "hklm\system\currentcontrolset\enum\usb" "c:\tsg\$($computerName)_$($d)_Usb$($context).reg"
		move-item "\\$($computerName)\c`$\tsg\$($computerName)_$($d)_UsbVendor.reg" "$($pwd)\results\" -force
		
		$vendors = .\bin\psexec.exe \\$($computerName) -s cmd /c reg query "HKLM\system\currentcontrolset\enum\usb"
		foreach($vendor in ( $vendors | ? { $utilities.isBlank($_) -eq $false } ) ){
			$devices = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg.exe" "query" "$($vendor.replace('&','^&'))"
			foreach($device in ( $devices | ? { $utilities.isBlank($_) -eq $false } )){
				$deviceDesc = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg.exe" "query" "$($device.replace('&','^&'))" "/v" "DeviceDesc"
				$deviceDesc | ? { $_ -like "*$($context)*" -or $_ -like "*$($context -replace ' ','' )*"  } | % {
					if(!$private.test){
						$uiClass.writeColor("$($uiClass.STAT_WAIT) Deleting #yellow#$($device)# Key on #green#$($computerName)#")
						$d = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg.exe" "delete" "$($device.replace('&','^&'))" "/f"
					}else{
						$uiClass.writeColor("$($uiClass.STAT_WAIT) Found #yellow#$($device)# Key on #green#$($computerName)#")
					}
				}
			}
		}
	}
	
	method -private uninstallWPD{
		param($computerName)
		$uiClass.writeColor("$($uiClass.STAT_OK) Searching for #yellow#Windows Portable Devices# Key on #green#$($computerName)#")
		New-Item "\\$($computerName)\c`$\tsg\" -type directory -force
		$d = "{0:yyyyMMdd-HHmmss}" -f [DateTime]::now
		$e = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg" "export" "hklm\system\currentcontrolset\enum\usb" "c:\tsg\$($computerName)_$($d)_UsbWPD.reg"
		move-item "\\$($computerName)\c`$\tsg\$($computerName)_$($d)_UsbWPD.reg" "$($pwd)\results\" -force
		
		$vendors = .\bin\psexec.exe \\$($computerName) -s cmd /c reg query "HKLM\system\currentcontrolset\enum\usb"
		foreach($vendor in ( $vendors | ? { $utilities.isBlank($_) -eq $false } ) ){
			$devices = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg.exe" "query" "$($vendor.replace('&','^&'))"
			foreach($device in ( $devices | ? { $utilities.isBlank($_) -eq $false } )){
				$deviceDesc = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg.exe" "query" "$($device.replace('&','^&'))" "/v" "Class"
				$deviceDesc | ? { $_ -like '*WPD*' } | % {
					if(!$private.test){
						$uiClass.writeColor("$($uiClass.STAT_WAIT) Deleting #yellow#$($device)# Key on #green#$($computerName)#")
						$d = .\bin\psexec.exe \\$($computerName) -s cmd /c "reg.exe" "delete" "$($device.replace('&','^&'))" "/f"
					}else{
						$uiClass.writeColor("$($uiClass.STAT_WAIT) Found #yellow#$($device)# Key on #green#$($computerName)#")
					}
				}
			}
		}
	}
}

$cleanUsbHistoryClass.New().Execute()  | out-null