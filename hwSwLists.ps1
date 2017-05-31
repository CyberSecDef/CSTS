##########################################################
# Powershell Documentation
##########################################################

# .SYNOPSIS
#   This is a script that will pull the hardware and software lists for a list of computers
# .DESCRIPTION
# 	This is a script that will pull the hardware and software lists for a list of computers
# .PARAMETER hostCsvPath
# 	The path the a CSV File containing hosts
# .PARAMETER computers
# 	A comma separated list of hostnames
# .PARAMETER OU
# 	An Organizational Unit in Active Directory to pull host names from
# .PARAMETER manualExec
#	Whether of not to auto-execute
# .INPUTS
# 	There are no inputs that can be directed to this script
# .OUTPUTS  
# 	All outputs are sent to the console and logged in the log folder
# .LINK
#	https://software.forge.mil/sf/projects/diacap_tools
# .NOTES
#	Author: Robert Weber
#	Version History:
#		Feb 25, 2015 - Initial Script Creation
#		Nov 30, 2015 - Updated documentation

##########################################################
# API Documentation
##########################################################

##########################################################
# About: Script Information
#
# Filename - hwswlist.ps1
# Synopsis -  This is a script that will pull the hardware and software lists for a list of computers.
# Input - There are no inputs that can be directed to this script
# Output - All output is sent to the console and logged in the log folder
#
# Requirements:
#	- Powershell V2
#	- Admin Privileges
#
# Deprecated:
#	FALSE
#
# Command Line Arguments:
# 	OU - An Organizational Unit in Active Directory to pull host names from
#	hostCsvPath -The path the a CSV File containing hosts
#	computers - A comma separated list of hostnames
#	manualExec - Whether or not to auto execute
#
# Links:
#	https://software.forge.mil/sf/projects/diacap_tools
#
# Authors:
#	Robert Weber
#
# Version History:
#	Feb 25, 2015 - Initial Script Creation
#	Nov 30, 2015 - Updated documentation
#
# Notes:
#
# Todo:
#
##########################################################
[CmdletBinding()]
param( $hostCsvPath = "", $computers = @(), $OU = "", [switch] $manualExec) 
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

##########################################################
# Class: hwSwListClass
# Creates an excel document containing the scanned hosts' hardware and software
#
# Dependencies:
#	- <PSClass>
#
# Provides:
#	- <hwSwListClass>
#
# Deprecated:
#	FALSE
#
# See Also:
#
# Links:
#
# Notes:
#
# Todo:
#
##########################################################
$hwSwListClass = new-PSClass hwSwList{

	##########################################################
	# Variables: Static Properties
	#   PsScriptName - The name of the executing script
	#	Description - A description of what this script does
	##########################################################
	note -static PsScriptName "hwswlist"
	note -static Description ( ($(((get-help .\hwswlists.ps1).Description)) | select Text).Text)
	
	###########################################################
	# Variables: Private Instance Properties
	#   HostObj - An object containing all the hosts to be scanned
	#   mainProgressBar - A Container for the main script progress bar
	#   Hardware - A container for each hosts hardware
	#   Software - A container for each hosts software
	#   Assets - A container for each Asset
	#   UninstallKeys - The registry Keys to search through
	###########################################################
	note -private HostObj @{}
	note -private mainProgressBar
	note -private Hardware @{}
	note -private Software @{}
	note -private Assets @{}
	note -private TpmUefiOs @{}
	note -private Registry 
	
	note -private UninstallKeys @(
		"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
		"SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
	)
	
	##########################################################
	# Method: Constructor
	# 	Creates a new object for the <hwswlistsClass> Script
	#
	# Parameters:
	#	NA
	#
	# Scope:
	#	Public
	#
	# Dependencies:
	#	- <HostsClass> object
	#
	# Returns:
	#	New <hwSwListClass> Object
	#
	# Deprecated:
	#	False
	#
	# See Also:
	#
	# Links:
	#
	# Notes:
	#
	# Todo:
	#
	##########################################################
	constructor{
		param()
		$private.HostObj = $HostsClass.New()
		$private.Registry = $registryClass.new()
	}
	
	##########################################################
	# Method: Execute
	# Executes the body of this script
	#
	# Parameters:
	#	NA
	#
	# Scope:
	#	Public
	#
	# Dependencies:
	#	- <progressBarClass>
	#	- <uiClass>
	#
	# Deprecated:
	#	False
	#
	# Returns:
	#	N/A
	#
	# See Also:
	#
	# Links:
	#
	# Notes:
	#
	# Todo:
	#
	##########################################################
	method Execute{
		$currentComputer = 0
						
		$path = @(
			'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
			'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
		)
		
		if($private.HostObj.Count -gt 0){
		
			$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
			
			$private.HostObj.Hosts.keys | % {
				$currentComputer = $currentComputer + 1
				$i = (50*($currentComputer / $private.HostObj.Hosts.count))
			
				$private.mainProgressBar.Activity("$currentComputer / $($private.HostObj.Hosts.count): Processing system $_").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			
				$subProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
			
				try{
					$uiClass.writeColor( "$($uiClass.STAT_OK) Processing #green#$($_)#" )
					$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($_.Trim())'"
					if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
						$subProgressBar.Activity("Analysing hardware for system $_").Status("33% complete").Percent(33).Render()
						
						if($private.Hardware.keys -notContains $_){
							$private.Hardware.add($_.Trim(), (gwmi win32_PnPEntity -computerName $_.Trim() | Sort Service, Manufacturer, Name | Select Name, Manufacturer, Description, Service, DeviceID ) )
						}
		
						$subProgressBar.Activity("Analysing installed Software Products for system $_").Status("66% complete").Percent(66).Render()
						#software comes in the form of win32_product and registry entries.
						#get wmi programs
						 if($private.Software.keys -notContains $_.Trim()){
							$private.Software.add($_.Trim(), @() )
						 }
						
						$subProgressBar.Activity("Analysing  Software Registry Keys  for system $_").Status("90% complete").Percent(90).Render()
						
						#now read registry
						$remReg = @()						
						$remoteRegistry = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',"$($_.Trim())")  
						
						#check for IE
						$remoteRegistryKey = $remoteRegistry.OpenSubKey("SOFTWARE\\Microsoft\\Internet Explorer")
						if($remoteRegistryKey -ne $null){
							
							$remReg += @{
								"Name"  = "Internet Explorer"
								"Vendor" = "Microsoft"
								"InstallDate" = ""
								"Version" = @( $remoteRegistryKey.getValue("svcVersion"),  $remoteRegistryKey.getValue("version") )[ ( $remoteRegistryKey.getValue("version").toString().subString(0,1) -lt 10 ) ]
							}
						}
						
						#check for java
						gci "\\$($_.Trim())\c`$\Program Files (x86)\Java" -recurse -include "java.exe" -errorAction silentlyContinue| % { 
							$remReg += @{
								"Name"  = "Java - 32 Bit"								
								"Vendor" = "Oracle"
								"InstallDate" = ""
								"Version" = [system.diagnostics.fileversioninfo]::GetVersionInfo( $_.FullName  ).FileVersion
							}
						}
						#check for java
						gci "\\$($_.trim())\c`$\Program Files\Java" -recurse -include "java.exe" -errorAction silentlyContinue | % { 
							$remReg += @{
								"Name"  = "Java - 64 Bit"								
								"Vendor" = "Oracle"
								"InstallDate" = ""
								"Version" = [system.diagnostics.fileversioninfo]::GetVersionInfo( $_.FullName  ).FileVersion
							}
						}
						
						#other software
						foreach($key in $private.UninstallKeys){
							$remoteRegistryKey = $remoteRegistry.OpenSubKey($key)  
							if($remoteRegistryKey -ne $null){
								$remoteSubKeys = $remoteRegistryKey.GetSubKeyNames()
								
								$remoteSubKeys | % {
									$remoteSoftwareKey = $remoteRegistry.OpenSubKey("$key\\$_")
									if( $remoteSoftwareKey.GetValue("DisplayName") -and $remoteSoftwareKey.GetValue("UninstallString") ){
										$remReg += @{
											"Name"  = $remoteSoftwareKey.GetValue("DisplayName");
											"Vendor" = $remoteSoftwareKey.GetValue("Publisher");
											"InstallDate" = $remoteSoftwareKey.GetValue("InstallDate");
											"Version" =$remoteSoftwareKey.GetValue("DisplayVersion");
										}
									}
								}
							}
						}	

						$private.Software.$($_.Trim()) = ($remReg | sort {$_.Name} -unique)
						
						
						#getting asset information for inclusion in hardware list in ca plan
						$private.Assets.Add($_.Trim(),@{
							"Manufacturer" = (gwmi win32_computerSystem -computerName $_.trim()).Manufacturer;
							"Model Number" = (gwmi win32_computerSystem -computerName $_.trim()).Model;
							"Firmware" = (gwmi win32_bios -computerName $_.trim()).SMBIOSBIOSVersion;
							"IA Enabled (Y/N)" = "";
							"CC Eval Status" = "";
							"Purpose" = "";					
						});
						
						
						#get DirectX version
						$private.Registry.Open($_.trim(),'LocalMachine')
						$private.Registry.OpenSubKey("SOFTWARE\Microsoft\DirectX") | out-null
						$dx = $private.Registry.GetValue( "Version")
						$private.Registry.close()
				
						switch ($dx) { 
							"4.02.0095"      { $strVersion = "1.0"  } 
							"4.03.00.1096"   { $strVersion = "2.0"  } 
							"4.04.0068"      { $strVersion = "3.0"  } 
							"4.04.0069"      { $strVersion = "3.0"  } 
							"4.05.00.0155"   { $strVersion = "5.0"  } 
							"4.05.01.1721"   { $strVersion = "5.0"  } 
							"4.05.01.1998"   { $strVersion = "5.0"  } 
							"4.06.02.0436"   { $strVersion = "6.0"  } 
							"4.07.00.0700"   { $strVersion = "7.0"  } 
							"4.07.00.0716"   { $strVersion = "7.0a" } 
							"4.08.00.0400"   { $strVersion = "8.0"  } 
							"4.08.01.0881"   { $strVersion = "8.1"  } 
							"4.08.01.0810"   { $strVersion = "8.1"  } 
							"4.09.0000.0900" { $strVersion = "9.0"  } 
							"4.09.00.0900"   { $strVersion = "9.0"  } 
							"4.09.0000.0901" { $strVersion = "9.0a" } 
							"4.09.00.0901"   { $strVersion = "9.0a" } 
							"4.09.0000.0902" { $strVersion = "9.0b" } 
							"4.09.00.0902"   { $strVersion = "9.0b" } 
							"4.09.00.0904"   { $strVersion = "9.0c" } 
							"4.09.0000.0904" { $strVersion = "9.0c" } 
						} 
				
				
						#getting tpm/bios/os information  
						$private.TpmUefiOs.Add($_.Trim(),@{
							"OS" = (gwmi win32_operatingSystem -computerName $_.trim()).caption;
							"TPM" = ( gwmi win32_pnpEntity -computername $_.trim() | ? { $_.name -like '*trusted platform*'  }   ).Caption;
							"Bios" = (Select-String 'Detected boot environment' "\\$($_.trim())\c$\Windows\Panther\setupact.log" -AllMatches ).line -replace '.*:\s+';
							"BiosVersion" = (gwmi win32_bios -computerName $_.trim()).SMBIOSBIOSVersion;
							"CPU" = (gwmi win32_processor -computerName $_.trim() | select -first 1).Name;
							"CPUSpeed" = (gwmi win32_Processor -computerName $_.trim() | select -first 1 -expand MaxClockSpeed);
							"TotalRam"  = [math]::round((gwmi win32_ComputerSystem -computerName $_.trim() | select -expand TotalPhysicalMemory) / 1GB,2)
							"DirectX" = $strVersion;
						});
						
					
					}else{
						$uiClass.writeColor( "$($uiClass.STAT_ERROR) Connection failed for #yellow#$($_)#")
					}
				} catch { 
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) $_ " )
				}

			} 
			$subProgressBar.Completed($true).Render()
			$this.Export()
			
			$private.mainProgressBar.Completed($true).Render() 
			
		}
		$uiClass.errorLog()
	}
	
	##########################################################
	# Method: Export
	# 	Exports the scanned data into a readable Excel spreadsheet
	#
	# Parameters:
	#	NA
	#
	# Scope:
	#	Public
	#
	# Dependencies:
	#	- <progressBarClass>
	#	- <uiClass>
	#	- <ExportClass>
	#
	# Deprecated:
	#	False
	#
	# Returns:
	#	N/A
	#
	# See Also:
	#
	# Links:
	#
	# Notes:
	#
	# Todo:
	#
	##########################################################
	method Export{
	
		$colHeaders = @{}
		$sheets = @{}
		
		$export = $ExportClass.New()
		
		$colHeaders.add("TPM_Bios",@("Host","OS","TPM","Bios","Bios Version","CPU", "CPU Speed (> 1GHz)", "Total RAM (> 1GB)", "DirectX Version (> 9)" ))
		$colHeaders.add("Hardware",@("Host","Name","Manufacturer","Description","Service","ServiceID"))
		$colHeaders.add("Software", @("Host","Name","Vendor","InstallDate","Version"))
		$colHeaders.add("Assets", @( "Device Name", "Manufacturer", "Model Number", "Firmware", "IA Enabled (Y/N)", "CC Eval Status", "Purpose"))
		$colHeaders.add("PkgSoftware", @( "Application", "Version", "Publisher", "IA Enabled (Y/N)", "CC Eval Status", "FAM Status","DADMS ID","Purpose"))
		
		$export.addWorkSheet('TPM_Bios')
		$export.addWorkSheet('PkgSoftware')
		$export.addWorkSheet('Assets')
		$export.addWorkSheet('Software')
		$export.addWorkSheet('Hardware')
		
		$i = 50
		foreach($sheet in @("Hardware","Software")  ){
			$private.mainProgressBar.Activity("Exporting $sheet sheet").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			
			$hostBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
			
			$export.selectSheet($sheet)
			
			$col = 1
			$colHeaders.$sheet | %{
				$export.updateCell(1,$col,$_)
				$col = $col + 1
			}
		
			$row = 2
			
			$currentExportHost = 0
			$totalExportHost = $private.$sheet.keys.count
			
			foreach($hostname in ($private.$sheet.keys | Sort )){
				$currentExportHost++
				$hostBar.Activity("$currentExportHost / $totalExportHost : Exporting $sheet Rows for $hostname").Status(("{0:N2}% complete" -f (100 * $currentExportHost / $totalExportHost)  )).Percent( (100 * $currentExportHost / $totalExportHost) ).Render()
				
				$itemBar =  $progressBarClass.New( @{ "parentId" = 2; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 4 }).Render() 
			
				$itemCount = ( $private.$sheet.$hostname ).count
				$currentItem = 0
				
				( $private.$sheet.$hostname | sort -unique { $_.Name } ) | % {
					
					$currentItem++
					$hi = (100 * $currentItem / $itemCount)
					$itemBar.Activity("$currentItem / $itemCount : Exporting $sheet Rows").Status(("{0:N2}% complete" -f $hi)).Percent($hi).Render()
				
					$export.updateCell($row,1,$hostname)
					
					$col = 2
					foreach($colHeader in ( $colHeaders.$sheet ) ){
						if($colHeader -ne 'Host'){
							$export.updateCell($row,$col, $_.$($colHeader))
							
							$col++
						}
					}
					$row++
				}
				
				$itemBar.Completed($true).Render() 
				$row++
			}
			$export.autoFilterWorksheet()
			
			$hostBar.Completed($true).Render() 
			
			
			$i = $i + 20
		}
		
		$private.mainProgressBar.Activity("Exporting Assets sheet").Status(("{0:N2}% complete" -f 80)).Percent(80).Render()
		
		$export.selectSheet('Assets')
		#udpate Assets List
		$row = 1
		$col = 1
		$colHeaders.Assets | %{
			$export.updateCell(1,$col, $_)
			
			$col = $col + 1
		}
		$row = 2
		foreach($hostname in ($private.Assets.keys | Sort )){
			$export.updateCell($row,1, $hostname)
			$export.updateCell($row,2, $private.Assets.$hostname.Manufacturer)
			$export.updateCell($row,3, $private.Assets.$hostname."Model Number")
			$export.updateCell($row,4, $private.Assets.$hostname.Firmware)
			
			$row++
		}
				
		$private.mainProgressBar.Activity("Exporting Package Software sheet").Status(("{0:N2}% complete" -f 90)).Percent(90).Render()
		
		#get all software for package
		$pkgSoftware = @()
		foreach($hostname in ($private.Software.keys | Sort )){
			$private.Software.$hostname | ? { $_.Name -notlike '*gdr*' -and $_.Name -notlike '*security*' -and $_.Name -notlike '*update*' -and $_.Name -notlike '*driver*' -and $_.Name -notlike '*runtime*' -and $_.Name -notlike '*redistributable*' -and $_.Name -notlike '*framework*'-and $_.Name -notlike '*hotfix*'  -and $_.Name -notlike '*plugin*' -and $_.Name -notlike '*plug-in*' -and $_.Name -notlike '*debug*' -and $_.Name -notlike '*addin*' -and $_.Name -notlike '*add-in*' -and $_.Name -notlike '*library*'} | % {
				$pkgSoftware += $_
			}
		}
		
		$export.autoFilterWorksheet()
				
		$export.selectSheet('PkgSoftware')
		$row = 1
		$col = 1
		$colHeaders.PkgSoftware | %{
			$export.updateCell(1,$col, $_)
			$col = $col + 1
		}
		$row = 2
		$pkgSoftware | sort -unique {$_.name} | % {
			$export.updateCell($row,1, $_.Name)
			$export.updateCell($row,2, $_.Version)
			$export.updateCell($row,3, $_.Vendor)
			$row++
		}
		
		$export.autoFilterWorksheet()
		$export.autofitAllColumns()
		$export.formatAllFirstRows([export.excelStyle]::Header)
		
		
		
		
		$export.selectSheet('TPM_Bios')
		#udpate Assets List
		$row = 1
		$col = 1
		$colHeaders.TPM_Bios | %{
			$export.updateCell(1,$col, $_)
			
			$col = $col + 1
		}
		$row = 2
		foreach($hostname in ($private.Assets.keys | Sort )){
			$export.updateCell($row,1, $hostname)
			$export.updateCell($row,2, $private.TpmUefiOs.$hostname.OS)
			$export.updateCell($row,3, $private.TpmUefiOs.$hostname.TPM)
			$export.updateCell($row,4, $private.TpmUefiOs.$hostname.Bios)
			$export.updateCell($row,5, $private.TpmUefiOs.$hostname.BiosVersion)
			$export.updateCell($row,6, $private.TpmUefiOs.$hostname.CPU)
			$export.updateCell($row,7, $private.TpmUefiOs.$hostname.CPUSpeed)
			$export.updateCell($row,8, $private.TpmUefiOs.$hostname.TotalRam)
			$export.updateCell($row,9, $private.TpmUefiOs.$hostname.DirectX)
			
			$row++
		}
		
		

		
		
		$ts = (get-date -format "yyyyMMddHHmmss")
		$export.saveAs([System.IO.Path]::GetFullPath("$($pwd.ProviderPath)\results\$($hwSwListClass.PsScriptName)_$ts.xml"))
	}
}

##########################################################
# Script: Execution
# This is where the script determines if it should 
# auto execute
#
# (start code)
# if($manualExec -ne $true){
# 	$hwSwListClass.New().Execute() | out-null
# }
# (end code)
##########################################################
if($manualExec -ne $true){
	$hwSwListClass.New().Execute() | out-null
}