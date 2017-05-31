##########################################################
# Powershell Documentation
##########################################################
# .SYNOPSIS
# 	This is a script that will archive the event logs from remote computers to a local directory
# .DESCRIPTION
# 	This is a script that will archive the event logs from remote computers to a local directory.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters
# .PARAMETER hostCsvPath
# 	The path the a CSV File containing hosts
# .PARAMETER computers
# 	A comma separated list of hostnames
# .PARAMETER OU
# 	An Organizational Unit in Active Directory to pull host names from
# .PARAMETER archiveLocation
# 	The location the event logs should be stored
# .PARAMETER onlyFull
# 	If present, the log files will only be archived if they are above 90% of the log file capacity
# .PARAMETER clearLogs
# 	If present, the log files will be cleared after being archived
# .PARAMETER manualExec
#	Whether of not to auto-execute
# .EXAMPLE    
# 	C:\PS>.\archiveEventlogs.ps1 -computers "hostname1,hostname2" -archiveLocation "c:\logarchive\"
# 	This example will gather the events from  the computers entered into the command line
# .INPUTS
# 	There are no inputs that can be directed to this script
# .OUTPUTS  
# 	All outputs are sent to the console and logged in the log folder
# .NOTES
# 	Author: Robert Weber
# 	Date:   Dec 30, 2014

##########################################################
# API Documentation
##########################################################
 
##########################################################
# About: Script Information
#
# Filename - archiveEventLogs.ps1
# Synopsis -  This is a script that will archive the event logs from remote computers to a local directory
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
#	archiveLocation -The location the event logs should be stored
#	onlyFull - If present, the log files will only be archived if they are above 90% of the log file capacity
#	clearLogs -If present, the log files will be cleared after being archived
#	manualExec - Whether or not to auto execute
#
# Examples:
# 	.\archiveEventlogs.ps1 -computers "hostname1,hostname2" -archiveLocation "c:\logarchive\" - This example will gather the events from  the computers entered into the command line
#
# Links:
#	https://software.forge.mil/sf/projects/diacap_tools
#
# Authors:
#	Robert Weber
#
# Version History:
#	Dec 30, 2014 - Initial Script Creation
#	Dec 2, 2015 - Added code documentation
#
# Notes:
#
# Todo:
#
##########################################################
[CmdletBinding()]
param( $hostCsvPath = "", $computers = @(), $OU = "", $archiveLocation, [switch] $onlyFull, [switch] $clearLogs, [switch] $manualExec ) 
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

##########################################################
# Class: ArchiveEventLogClass
# 	This is a script that will archive the event logs from remote computers to a local directory.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters
#
# Dependencies:
#	- <PSClass>
#
# Provides:
#	- <ArchiveEventLogClass>
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
$archiveEventLogClass = new-PSClass ArchiveEventLog{

	##########################################################
	# Variables: Static Properties
	#   PsScriptName - The name of the executing script
	#	Description - A description of what this script does
	##########################################################
	note -static PsScriptName "archiveEventlogs"
	note -static Description ( ($(((get-help .\archiveEventlogs.ps1).Description)) | select Text).Text)
	
	###########################################################
	# Variables: Private Properties
	#   HostObj - An object containing all the hosts to be scanned
	#   mainProgressBar - A Container for the main script progress bar
	#	gui - The gui object for the script
	#	archiveLocation - the path for where the archives will be stored
	#	onlyFull - A flag to only archive logs closed to full
	#	clearLogs - A flag to clear the logs once archived
	###########################################################
	note -private HostObj @{}
	note -private gui
	note -private archiveLocation
	note -private onlyFull
	note -private clearLogs
	note -private mainProgressBar
	
	##########################################################
	# Method: Constructor
	# 	Creates a new object for the <archiveEventLogClass> Script
	#
	# Parameters:
	#	NA
	#
	# Scope:
	#	Public
	#
	# Dependencies:
	#	- <HostsClass>
	#	- <utilities>
	#	- <uiClass>
	#	- <guiClass>
	#
	# Returns:
	#	New <applyPoliciesClass> Object
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
		$private.HostObj = $HostsClass.New($hostCsvPath, $computers, $OU)
		
		$private.archiveLocation = $archiveLocation
		$private.onlyFull = $onlyFull
		$private.clearLogs = $clearLogs
		
		while($utilities.isBlank($private.archiveLocation) -eq $true){
			$private.gui = $null
			$private.gui = $guiClass.New("archiveEventlogs.xml")
			$private.gui.generateForm();
			
			$private.gui.Controls.btnOpenFolderBrowser.add_Click({ $private.gui.Controls.txtArchiveLocation.Text =  $private.gui.actInvokeFolderBrowser() })
			
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.archiveLocation = $private.gui.Controls.txtArchiveLocation.Text
			$private.onlyFull = $private.gui.Controls.chkOnlyFull.Checked
			$private.clearLogs = $private.gui.Controls.chkClearLogs.Checked
		}
	}
	
	##########################################################
	# Method: Execute
	# 	Executes the body of this script
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

		if($private.HostObj.Count -gt 0){
		
			$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
			
			$private.HostObj.Hosts.keys | % {
				$currentComputer = $currentComputer + 1
				$i = (100*($currentComputer / $private.HostObj.Hosts.count))
			
				$private.mainProgressBar.Activity("$currentComputer / $($private.HostObj.Hosts.count): Processing system $_").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			
				$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($_.Trim())'"
				if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
					if($_.length -ge 1) { 
						$uiClass.writeColor( "$($uiClass.STAT_OK) Processing $_" )
						
						$this.getBackUpFolder($_)
					}
				} else { 
				
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) Skipping $_ .. not accessible" )
				}
			} 
			$private.mainProgressBar.Completed($true).Render() 
		}
		$uiClass.errorLog()
	}
	
	##########################################################
	# Method: getBackUpFolder
	# 	Creates the archive folder path and a temporary folder 
	#	on the remote host
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
	method getBackUpFolder{
		param(
			[string] $computer
		)
		#create a folder on log server for event logs
		$folder = "{0:yyyyMMdd-HHmmss}" -f [DateTime]::now
		New-Item "$($private.ArchiveLocation)\$computer\$folder" -type Directory -force
		
		# create folder on remote system to temporarily hold logs
		If(!(Test-Path "\\$computer\c$\LogFolder\$folder")){
			New-Item "\\$computer\c$\LogFolder\$folder" -type Directory -force | out-Null
		} 
		$this.backupEventLogs($computer, $folder)
	} 
	
	##########################################################
	# Method: backupEventLogs
	# 	Copies the event logs from the remote host to the 
	#	temporary folder on the remote host
	#
	# Parameters:
	#	computer - The host being archived
	#	folder - The folder on the remote host to temporarily store the event logs
	#
	# Scope:
	#	Public
	#
	# Dependencies:
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
	
	method backupEventLogs{
		param(
			$computer,
			$folder
		)
	
		$Eventlogs = Get-WmiObject -Class Win32_NTEventLogFile -ComputerName $computer
		Foreach($log in $EventLogs){
			if($utilities.isblank($log) -eq $false){
				if($private.onlyFull){
					if($log.FileSize / $log.MaxFileSize -gt .9){
						$uiClass.writeColor("$($uiClass.STAT_OK)     Archiving #green#$($log.LogFileName)# Log")
						$path = "\\$computer\c$\LogFolder\$folder\{0}.evt" -f $log.LogFileName
						try{
							$log.BackupEventLog($path) | out-null	
						}catch{
							$uiClass.writeColor("$($uiClass.STAT_ERROR)     Error Archiving #yellow#$($log.LogFileName)# Log on #green#$($computer)#")
						}
					}else{
						$uiClass.writeColor("$($uiClass.STAT_WARN)     Skipping #green#$($log.LogFileName)# Log, log file not nearing capacity.")
					}
				}else{
					$uiClass.writeColor("$($uiClass.STAT_OK)     Archiving #green#$($log.LogFileName)# Log")
					$path = "\\$computer\c$\LogFolder\$folder\{0}.evt" -f $log.LogFileName
					try{
						$log.BackupEventLog($path) | out-null	
					}catch{
						$uiClass.writeColor("$($uiClass.STAT_ERROR)     Error Archiving #yellow#$($log.LogFileName)# Log on #green#$($computer)#")
					}
				}
				if($private.clearLogs){
					$log.ClearEventLog()
				}
			} 
		}
		$this.copyEventLogsToArchive($computer,$folder)
		remove-item "\\$computer\c$\LogFolder\" -recurse
	} 
	
	##########################################################
	# Method: copyEventLogsToArchive
	# 	Copies the event logs from the active host to the 
	#	archiveLog location
	#
	# Parameters:
	#	computer - The host being archived
	#	folder - The folder on the remote host to temporarily store the event logs
	#
	# Scope:
	#	Public
	#
	# Dependencies:
	#	- <utilities>
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
	method copyEventLogsToArchive{
		param(
			$computer,
			$folder
		)
		Copy-Item "\\$computer\c$\LogFolder\$folder\*" "$($private.ArchiveLocation)\$computer\$folder" -force
		$utilities.zipFolder("$($private.ArchiveLocation)\$computer\$folder")
		remove-item "$($private.ArchiveLocation)\$computer\$folder" -recurse
	} 
}

##########################################################
# Script: Execution
# 	This is where the script determines if it should 
# 	auto execute
#
# (start code)
# if($manualExec -ne $true){
# 	$ArchiveEventLogClass.New().Execute() | out-null
# }
# (end code)
##########################################################
if($manualExec -ne $true){
	$ArchiveEventLogClass.New().Execute() | out-null
}