##########################################################
# Powershell Documentation
##########################################################

# .SYNOPSIS
# 	This is a script that will clean up dead entries in a scap results folder
# .DESCRIPTION
# 	This is a script that will clean up dead entries in a scap results folder
# .PARAMETER scanPath
# 	The path to the root SCC Results folder
# .PARAMETER removeOld
# 	If present, the out-dated scan results will be deleted.
# .PARAMETER manualExec
#	Whether of not to auto-execute
# .EXAMPLE
# 	C:\PS>.\cleanScapFolder.ps1 -scanPath "c:\scc\results\scap\" 
# 	This example will clean the designated path
# .INPUTS
# 	There are no inputs that can be directed to this script
# .OUTPUTS  
# 	All outputs are sent to the console and logged in the log folder
# .NOTES
# 	Author: Robert Weber
#	Version History:
# 		Feb 26, 2015 - initial release
#		Dec 2, 2015 - added code documentation

##########################################################
# API Documentation
##########################################################

##########################################################
# About: Script Information
#
# Filename - cleanScapFolder.ps1
# Synopsis - This is a script that will clean up dead entries in a scap results folder
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
# 	scanPath - The path to the root SCC Results folder
#	removeOld - If present, the out-dated scan results will be deleted.
#	manualExec - Whether or not to auto execute
#
# Examples:
#	.\cleanScapFolder.ps1 -scanPath "c:\scc\results\scap\" - This example will clean the designated path
#
# Links:
#	https://software.forge.mil/sf/projects/diacap_tools
#
# Authors:
#	Robert Weber
#
# Version History:
#	Feb 26, 2015 - Initial Script Creation
#	Dec 2, 2015 - Added code documentation
#
# Notes:
#
# Todo:
#
##########################################################
[CmdletBinding()]
param( $scanPath, [switch] $removeOld, [switch] $manualExec ) 
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

##########################################################
# Class: cleanScapFolderClass
# This is a script that will clean up dead entries in a scap results folder
#
# Dependencies:
#	- <PSClass>
#
# Provides:
#	- <cleanScapFolderClass>
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
$cleanScapFolderClass = new-PSClass cleanScapFolder{

	##########################################################
	# Variables: Static Properties
	#   PsScriptName - The name of the executing script
	#	Description - A description of what this script does
	##########################################################
	note -static PsScriptName "cleanScapFolder"
	note -static Description ( ($(((get-help .\cleanScapFolder.ps1).Description)) | select Text).Text)

	###########################################################
	# Variables: Private Instance Properties
	#	mainProgressBar - A Container for the main script progress bar
	#	scanPath - the path to scan for SCAP files
	#	removeOld - whether or not to delete old files
	#	gui - The gui object for the script
	###########################################################
	note -private mainProgressBar
	note -private scanPath
	note -private removeOld
	note -private gui
	
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
	#	- <utilities>
	#	- <guiClass>
	#
	# Returns:
	#	New <cleanScapFolderClass> Object
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
		$private.scanPath = $scanPath
		$private.removeOld = $removeOld
		
		while($utilities.isBlank($private.scanPath) -eq $true){
			$private.gui = $null
			$private.gui = $guiClass.New("cleanScapFolder.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnOpenFolderBrowser.add_Click({ $private.gui.Controls.txtScanPath.Text = $private.gui.actInvokeFolderBrowser() })
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.scanPath = $private.gui.Controls.txtScanPath.Text
			
			if($private.gui.Controls.chkRemoveOld.checked -eq $true){
				$private.removeOld = $true
			}
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
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		$hostProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
		
		#get the hosts
		$hostnames = @( gci $private.scanPath )
		$hi = 0
		
		foreach($hostName in $hostNames){
			if($hostNames.count -ne $null){
				$private.mainProgressBar.Activity("$hi / $($hostNames.count) : Scanning host results").Status("{0:N2}% complete" -f ( 100 * $hi / ($hostNames.count) ) ).Percent(100 * $hi / ($hostNames.count)).Render()
			}
			
			$uiClass.writeColor("$($uiClass.STAT_WAIT) #yellow#Analysing# container #green#$($hostName)#")
			$benchmarks = @( gci "$($private.scanPath)\$($hostName)" )
			
			$bi = 0 
			if($benchmarks.count -gt 0){
				foreach($benchmark in $benchmarks){
					$hostProgressBar.Activity("$bi / $($benchmarks.count) : Scanning benchmark results").Status("{0:N2}% complete" -f ( 100 * $bi / ($benchmarks.count) ) ).Percent(100 * $bi / ($benchmarks.count)).Render()
					
					$uiClass.writeColor("$($uiClass.STAT_WAIT)      #yellow#Analysing# benchmark #green#$($benchmark)#")
					$htmlCount = @( gci "$($private.scanPath)\$($hostName)\$($benchmark)" -recurse -filter "*.htm*" )
					if( $htmlCount -ne $null){
						$uiClass.writeColor("$($uiClass.STAT_OK)      Valid benchmark results found for #green#$($benchmark)#")
					}else{
						$uiClass.writeColor("$($uiClass.STAT_ERROR)      No valid benchmark results found for #green#$($benchmark)#")
						$uiClass.writeColor("$($uiClass.STAT_WAIT)           #red#Deleting# #green#$($private.scanPath)\$($hostName)\$($benchmark)#")
						remove-item "$($private.scanPath)\$($hostName)\$($benchmark)" -force -Confirm:$false -recurse
					}
					
					if($private.removeOld -ne $null){
						$benchmarkId = @( (gci "$($private.scanPath)\$($hostName)\$($benchmark)\").Name )
						$resultPaths = @( gci "$($private.scanPath)\$($hostName)\$($benchmark)\$benchmarkId\" | Sort LastWriteTime -Descending )
						if($resultPaths.count -gt 1){
							for($rpi = 1; $rpi -lt $resultPaths.count; $rpi++){
								$uiClass.writeColor("$($uiClass.STAT_ERROR)           #red#Deleting# old benchmark results #green#$($resultPaths[$rpi].Name)#")
								remove-item "$($private.scanPath)\$($hostName)\$($benchmark)\$benchmarkId\$($resultPaths[$rpi].Name)" -force -Confirm:$false -recurse
							}
						}				
					}
					$uiClass.writeColor()
					$bi++
				}
			}
			$uiClass.writeColor()
			$hi++
		}
			
		$hostProgressBar.Completed($true).Render()
		$private.mainProgressBar.Completed($true).Render() 

		$uiClass.errorLog()
	}
}

##########################################################
# Script: Execution
# 	This is where the script determines if it should 
# 	auto execute
#
# (start code)
# if($manualExec -ne $true){
# 	$cleanScapFolderClass.New().Execute() | out-null
# }
# (end code)
##########################################################
if($manualExec -ne $true){
	$cleanScapFolderClass.New().Execute() | out-null
}