##########################################################
# Powershell Documentation
##########################################################

# .SYNOPSIS
# 	This is a script that will attempt to apply machine and user policies without the user logging on
# .DESCRIPTION
# 	This is a script that will attempt to apply machine and user policies without the user logging on.  This will push multiple SCAP, GPO or Registry.pol settings to all profiles on a system and the machine profile.
# .PARAMETER hostCsvPath
# 	The path the a CSV File containing hosts
# .PARAMETER computers
# 	A comma separated list of hostnames
# .PARAMETER OU
# 	An Organizational Unit in Active Directory to pull host names from
# .PARAMETER userGpoPath
# 	A path to a GPO to pull user settings from
# .PARAMETER machineGpoPath
# 	A path to a GPO to pull machine settings from
# .PARAMETER userGpo
# 	A domain GPO to pull user settings from
# .PARAMETER machineGpo
# 	A domain GPO to pull machine settings from
# .PARAMETER xccdfPath
# 	A path to a SCAP Xccdf file to pull user and machine settings from.
# .PARAMETER ovalPath
# 	A path to a SCAP Oval file to pull user and machine settings from.
# .PARAMETER profile
# 	The profile within the SCAP file to use
# .PARAMETER manualExec
#	Whether of not to auto-execute
# .EXAMPLE
# 	C:\PS>.\ApplyPolicies.ps1 
# 	This will present the user with a gui to choose the hosts and policies to apply.
# .INPUTS
# 	There are no inputs that can be directed to this script
# .OUTPUTS  
# 	All outputs are sent to the console and logged in the log folder
# .NOTES
# 	Author: Robert Weber
# 	Date:   Sep 09, 2015

##########################################################
# API Documentation
##########################################################

##########################################################
# About: Script Information
#
# Filename - applyPolicies.ps1
# Synopsis -  This is a script that will attempt to apply machine and user policies without the user logging on
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
# 	userGpoPath - A path to a GPO to pull user settings from
# 	machineGpoPath - A path to a GPO to pull machine settings from
# 	userGpo - A domain GPO to pull user settings from
#  	machineGpo - A domain GPO to pull machine settings from
# 	xccdfPath - A path to a SCAP Xccdf file to pull user and machine settings from.
# 	ovalPath - A path to a SCAP Oval file to pull user and machine settings from.
# 	profile - The profile within the SCAP file to use
#	manualExec - Whether or not to auto execute
# 	force - rename remote user profiles that can't be updated
#
# Examples:
# 	.\ApplyPolicies.ps1 - This will present the user with a gui to choose the hosts and policies to apply.
#
# Links:
#	https://software.forge.mil/sf/projects/diacap_tools
#
# Authors:
#	Robert Weber
#
# Version History:
#	Sep 09, 2015 - Initial Script Creation
#	Dec 2, 2015 - Added code documentation
#
# Notes:
#
# Todo:
#
##########################################################
[CmdletBinding()]
param (	
	$hostCsvPath = "", 
	$computers = @(), 
	$OU = "", 
	$userGpoPath = "", 
	$machineGpoPath = "", 
	$userGpo = "", 
	$machineGpo = "", 
	$xccdfPath = "", 
	$ovalPath = "", 
	$profile = "",
	[switch] $manualExec,
	[switch] $force
) 

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }
	
if(!(test-path "$pwd\bin\PolFileEditor.dll")){
	Add-Type -Language CSharpVersion3 -TypeDefinition ([System.IO.File]::ReadAllText("$pwd\types\PolFileEditor.cs")) -OutputAssembly "$pwd\bin\PolFileEditor.dll" -outputType Library
}
if(!("TJX.PolFileEditor.PolFile" -as [type])){
	Add-Type -path "$pwd\bin\PolFileEditor.dll"
}

Import-Module groupPolicy -errorAction SilentlyContinue

##########################################################
# Class: applyPoliciesClass
# 	This is a script that will attempt to apply machine and user policies without the user logging on.  This will push multiple SCAP, GPO or Registry.pol settings to all profiles on a system and the machine profile.
#
# Dependencies:
#	- <PSClass>
#	- <TJX.PolFileEditor.PolFile>
#
# Provides:
#	- <ApplyPoliciesClass>
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
$applyPoliciesClass = new-PSClass ApplyPolicies{

	##########################################################
	# Variables: Static Properties
	#   PsScriptName - The name of the executing script
	#	Description - A description of what this script does
	##########################################################
	note -static PsScriptName "applyPolicies"
	note -static Description ( ($(((get-help .\applyPolicies.ps1).Description)) | select Text).Text)
		
	###########################################################
	# Variables: Private Properties
	#   HostObj - An object containing all the hosts to be scanned
	#   mainProgressBar - A Container for the main script progress bar
	#	gpoPol - Profile object that can parse GPO Registry Files
	#	Verbose - switch that allows extra details to be sent to the host
	#	gui - The GUI for the script
	#	Registry - An object that represents the registry for the machine being updated
	#	RegistryCollection - A collection of registry entries that need to be applied
	#	xccdfPath - A path to an XCCDF file in a SCAP
	#	ovalPath - A path to an OVAL file in a SCAP
	#	profile - The profile in a SCAP to exectue
	#	userGpoPath - The path to a GPO registry.pol file to be applied for user settings
	#	machineGpoPath - The path to a GPO registry.pol file to be applied for machine settings
	#	userGpo - A domain level GPO to be applied to user settings
	#	machineGpo -  A domain level GPO to be applied to machine settings
	#	polItems - The selected policies to apply
	#	xccdfXml - The XML for the XCCDF file being processed
	#	ovalXml - The XML for the OVAL file being processed
	#	xccdfNs - The Namespace  for the XCCDF file being processed
	#	ovalNs - The Namespace for the OVAL file being processed
	###########################################################
	note -private gpoPol 
	note -private Verbose 
	
	note -private gui
	note -private HostObj @{}
	note -private mainProgressBar
		
	note -private Registry 
	note -private RegistryCollection 
	
	note -private xccdfPath 
	note -private ovalPath
	note -private profile = ""
	note -private userGpoPath
	note -private machineGpoPath
	note -private userGpo
	note -private machineGpo
	
	note -private polItems
	
	note -private xccdfXml = ""
	note -private ovalXml = ""
	note -private xccdfNs = ""
	note -private ovalNs = ""
	
	##########################################################
	# Method: Constructor
	# 	Creates a new object for the <applyPoliciesClass> Script
	#
	# Parameters:
	#	NA
	#
	# Scope:
	#	Public
	#
	# Dependencies:
	#	- <HostsClass>
	#	- <TJX.PolFileEditor.PolFile>
	#	- <registryClass>
	#	- <registryCollectionClass>
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
		if([System.Management.Automation.ActionPreference]::SilentlyContinue -ne $VerbosePreference){
			$private.verbose = $true
		}else{
			$private.verbose = $false
		}
		
		if($utilities.isBlank( (get-module | ? { $_.name -eq 'groupPolicy' }) ) -eq $false){
			$private.HostObj  = $HostsClass.New()
			$private.gpoPol = New-Object TJX.PolFileEditor.PolFile
					
			$private.Registry = $registryClass.new()
			$private.RegistryCollection = $registryCollectionClass.new()
					
			$private.xccdfPath = $xccdfPath
			$private.ovalPath = $ovalPath
			$private.userGpoPath = $userGpoPath
			$private.machineGpoPath = $machineGpoPath
			$private.profile = $profile
			$private.userGpo = $userGpo
			$private.machineGpo = $machineGpo
			$private.polItems = @()

						
			while(  ( ($private.polItems.count -eq 0 ) -band $utilities.isBlank($private.xccdfPath) -band $utilities.isBlank($private.ovalPath) -band $utilities.isBlank($private.userGpoPath) -band $utilities.isBlank($private.machineGpoPath) -band $utilities.isBlank($private.userGpo) -band $utilities.isBlank($private.machineGpo) ) ){
				$private.gui = $null
			
				$private.gui = $guiClass.New("ApplyPolicies.xml")
				$private.gui.generateForm() | out-null
				
				$private.gui.Controls.btnXccdf.add_Click({
					$private.gui.Controls.txtXccdf.Text = $private.gui.actInvokeFileBrowser(@{"XML Files (*.xml)" = "*.xml";})
					if( $utilities.isBlank($private.gui.Controls.txtXccdf.Text) -eq $false ){
						if( (test-path $private.gui.Controls.txtXccdf.Text.replace("xccdf","oval") ) -eq $true -and $private.gui.Controls.txtOval.Text -eq "" ){
							$private.gui.Controls.txtOval.Text = $private.gui.Controls.txtXccdf.Text.replace("xccdf","oval")
						}
					

						if( (test-path $private.gui.Controls.txtXccdf.Text.replace("xccdf","oval") ) -eq $true ){
							$private.gui.Controls.cboProfile.Items.clear()
							([xml] (gc $private.gui.Controls.txtXccdf.Text)).Benchmark.Profile | % {  $private.gui.Controls.cboProfile.Items.Add($_.id) }
						}
					}
				})
				
				$private.gui.Controls.btnOval.add_Click({ 
					$private.gui.Controls.txtOval.Text = $private.gui.actInvokeFileBrowser(@{"Xml Files (*.xml)" = "*.xml";}) 
					if( $utilities.isBlank($private.gui.Controls.txtOval.Text) -eq $false ){
					
						if( ( test-path $private.gui.Controls.txtOval.Text.replace("xccdf","oval") ) -eq $true -and $private.gui.Controls.txtXccdf.Text -eq "" ){
							$private.gui.Controls.txtXccdf.Text = $private.gui.Controls.txtOval.Text.replace("oval","xccdf")
						}
						
						if( (test-path $private.gui.Controls.txtXccdf.Text.replace("xccdf","oval") ) -eq $true ){
							$private.gui.Controls.cboProfile.Items.clear()
							([xml] (gc $private.gui.Controls.txtXccdf.Text)).Benchmark.Profile | % {  $private.gui.Controls.cboProfile.Items.Add($_.id) }
						}
					}
				})
				
				$private.gui.Controls.btnUserGpo.add_Click({ 
					$private.gui.Controls.txtUserGpo.Text = $private.gui.actInvokeFileBrowser(@{"Group Policy Registry Files (*.pol)" = "*.pol";}) 
				})
				
				$private.gui.Controls.btnMachineGpo.add_Click({ 
					$private.gui.Controls.txtMachineGpo.Text = $private.gui.actInvokeFileBrowser(@{"Group Policy Registry Files (*.pol)" = "*.pol";}) 
				})
				
				$private.gui.Controls.btnDelPol.add_Click({
					foreach($item in $private.gui.Controls.lstSelPol.Items){
						if ($item.Selected){
							$private.gui.Controls.lstSelPol.Items.Remove($item) | out-null
						}
					}
					
					$index=0
					foreach($item in $private.gui.Controls.lstSelPol.Items){
						$index++ | out-null
						$item.SubItems[0].text = $index
						
					}
					
					$private.gui.Controls.lstSelPol.FullRowSelect  = $true
				})
				
				$private.gui.Controls.btnAddPol.add_Click({
				
					#see if a scap is present
					if($utilities.isBlank( $private.gui.Controls.txtXccdf.Text) -eq $false -and $utilities.isBlank( $private.gui.Controls.txtOval.Text) -eq $false -and $utilities.isBlank( $private.gui.Controls.cboProfile.Text) -eq $false ){
						$item =  New-Object "System.Windows.Forms.ListviewItem"( $private.gui.Controls.lstSelPol.items.count )
						$item.SubItems[0].text = $private.gui.Controls.lstSelPol.items.count + 1 
						$item.SubItems.Add( "SCAP" ) | out-null
						$item.SubItems.Add( "$($private.gui.Controls.txtXccdf.Text);$($private.gui.Controls.txtOval.Text);$($private.gui.Controls.cboProfile.text)") | out-null
						$private.gui.Controls.lstSelPol.Items.Add( $item ) | out-null
					}
					
					foreach($field in @("cboDomainGpoUser","cboDomainGpoMachine","txtUserGpo","txtMachineGpo")){
						if($utilities.isBlank( $private.gui.Controls.$field.text   ) -eq $false ){
								$item =  New-Object "System.Windows.Forms.ListviewItem"( $private.gui.Controls.lstSelPol.items.count )
								$item.SubItems[0].text = $private.gui.Controls.lstSelPol.items.count + 1 
								switch($field){
									"cboDomainGpoUser" 		{$item.SubItems.Add( "User GPO" ) | out-null }
									"cboDomainGpoMachine" 	{$item.SubItems.Add( "Machine GPO" ) | out-null }
									"txtUserGpo" 			{$item.SubItems.Add( "User Reg" ) | out-null }
									"txtMachineGpo" 		{$item.SubItems.Add( "Machine Reg" ) | out-null}
								}
								$item.SubItems.Add( $private.gui.Controls.$field.text ) | out-null
								$private.gui.Controls.lstSelPol.Items.Add( $item ) | out-null
						}
					}
					
					
					foreach($field in @("txtUserGpo","txtMachineGpo","txtXccdf","txtOval")){
						$private.gui.Controls.$field.text = ""
					}
					foreach($field in @("cboDomainGpoUser","cboDomainGpoMachine","cboProfile")){
						$private.gui.Controls.$field.selectedIndex = -1
					}
					
					
					$private.gui.Controls.lstSelPol.FullRowSelect  = $true
					$private.gui.Controls.lstSelPol.AutoResizeColumns('ColumnContent') | out-null
					
				})
				
				
				$gpos = (get-gpo -all -ErrorAction SilentlyContinue | ? { $_.GpoStatus -like '*Enabled*' } | select DisplayName, Id | sort DisplayName )
				$private.gui.Controls.cboDomainGpoUser.Items.Add("") | out-null
				$private.gui.Controls.cboDomainGpoMachine.Items.Add("") | out-null
				foreach($gpo in $gpos){
					$private.gui.Controls.cboDomainGpoUser.Items.Add($gpo.DisplayName) | out-null
					$private.gui.Controls.cboDomainGpoMachine.Items.Add($gpo.DisplayName) | out-null
				}
				
				$private.gui.Controls.lstSelPol.AutoResizeColumns('ColumnContent') | out-null
				
				$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
				$private.gui.Form.ShowDialog()| Out-Null
				
				$private.xccdfPath = $private.gui.Controls.txtXccdf.text
				$private.ovalPath = $private.gui.Controls.txtOval.text
				$private.userGpoPath = $private.gui.Controls.txtUserGpo.text
				$private.machineGpoPath = $private.gui.Controls.txtMachineGpo.text
				$private.profile = $private.gui.Controls.cboProfile.text
				$private.userGpo = $private.gui.Controls.cboDomainGpoUser.text
				$private.machineGpo = $private.gui.Controls.cboDomainGpoMachine.text
				$private.polItems = $private.gui.Controls.lstSelPol.Items
				
			}
		}else{
			$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not import Group Policy Module.  Ensure it is installed on this system")
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
	#	Error Traps
	##########################################################
	method Execute{
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		$private.mainProgressBar.Activity("Parsing Selected SCAP Files").Status(("{0:N2}% complete" -f 0)).Percent(0).Render()
		$private.parseScap();
		$private.mainProgressBar.Activity("Parsing Selected User GPO Files").Status(("{0:N2}% complete" -f 5)).Percent(5).Render()
		$private.parseGpoPol($private.userGpoPath, "HKEY_CURRENT_USER");
		$private.mainProgressBar.Activity("Parsing Selected Machine GPO Files").Status(("{0:N2}% complete" -f 10)).Percent(10).Render()
		$private.parseGpoPol($private.machineGpoPath, "HKEY_LOCAL_MACHINE");
		$private.mainProgressBar.Activity("Parsing Selected User GPOs").Status(("{0:N2}% complete" -f 15)).Percent(15).Render()
		$private.parseGpo($private.userGpo, "HKEY_CURRENT_USER");
		$private.mainProgressBar.Activity("Parsing Selected Machine GPOs").Status(("{0:N2}% complete" -f 20)).Percent(20).Render()
		$private.parseGpo($private.MachineGpo, "HKEY_LOCAL_MACHINE");
		
		$private.mainProgressBar.Activity("Parsing Policy Collection").Status(("{0:N2}% complete" -f 25)).Percent(25).Render()
		foreach($item in $private.polItems){
			if($item -ne $null){
				switch( $item.subitems[1].text ){
					"SCAP" { $paths = ($item.subitems[2]).text.ToString().split(";"); $private.xccdfPath = $paths[0]; $private.ovalPath = $paths[1]; $private.profile = $paths[2]; $private.parseScap(); }
					"User GPO" { $private.userGpo = $item.subitems[2].text.ToString();  $private.parseGpo($private.userGpo, "HKEY_CURRENT_USER"); }
					"Machine GPO" { $private.MachineGpo = $item.subitems[2].text.ToString(); $private.parseGpo($private.MachineGpo, "HKEY_LOCAL_MACHINE");}
					"User Reg" { $private.userGpoPath = $item.subitems[2].text.ToString(); $private.parseGpoPol($private.userGpoPath, "HKEY_CURRENT_USER"); }
					"Machine Reg" { $private.machineGpoPath = $item.subitems[2].text.ToString(); $private.parseGpoPol($private.machineGpoPath, "HKEY_LOCAL_MACHINE"); }
				}
			}
		}
		
		# \\rdte\sysvol\rdte.nswc.navy.mil\Policies\{02512CD8-D0FB-4ED7-8060-05B80D0E67B0}\Machine\Registry.pol
		# C:\sandbox\bin\SCC4.0.1\Resources\Content\SCAP_Content\U_GoogleChrome24Windows_V1R1_STIG_Benchmark-xccdf.xml
		$private.mainProgressBar.Activity("Updating Systems").Status(("{0:N2}% complete" -f 50)).Percent(50).Render()
		$private.updateSystems()
		$private.mainProgressBar.Completed($true).Render() 
		$uiClass.errorLog()
	}
	
	##########################################################
	# Method: parseGpo
	# 	Will parse a GPO from the domain for user settings
	#
	# Parameters:
	#	gpo - the GPO (GUID or Name) to parse
	#	hive - The hive in the registry to be updated (HKEY_CURRENT_USER or HKEY_LOCAL_MACHINE)
	#
	# Scope:
	#	Private
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
	method -private parseGpo{
		param(
			$gpo, 
			$hive
		)		
		
		$domain = ([ADSI]"LDAP://RootDSE").Get("ldapServiceName").Split(":")[0]
		get-gpo -all -ErrorAction SilentlyContinue | ? { $_.GpoStatus -like '*Enabled*' } | ? { $_.DisplayName -eq $gpo -or $_.Id -eq $gpo} | select DisplayName, Id | sort DisplayName | %{
			$gpoId = $_.Id
			switch($hive){
				"HKEY_CURRENT_USER" {
					$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing User Domain GPO #yellow#$($gpo)#")
					gci "\\$($domain)\sysvol\*\Policies\{$($gpoId)}\User\Registry.pol" | %{ $private.parseGpoPol($_.FullName, "HKEY_CURRENT_USER") }
					gci "\\$($domain)\sysvol\*\Policies\{$($gpoId)}\User\Preferences\Registry\Registry.xml" | %{ $private.parseGpoXml($_.FullName, "HKEY_CURRENT_USER") }
					
				}
				"HKEY_LOCAL_MACHINE" {
					$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing Machine Domain GPO #yellow#$($gpo)#")
					gci "\\$($domain)\sysvol\*\Policies\{$($gpoId)}\Machine\Registry.pol" | %{ $private.parseGpoPol($_.FullName, "HKEY_LOCAL_MACHINE") }
					gci "\\$($domain)\sysvol\*\Policies\{$($gpoId)}\Machine\Preferences\Registry\Registry.xml" | %{ $private.parseGpoXml($_.FullName, "HKEY_LOCAL_MACHINE") }
				}
			}
		}
	}

	##########################################################
	# Method: parseGpoXml
	# 	Will parse a GPO File (registry.xml)
	#
	# Parameters:
	#	gpoPath - the path to the gpo file (registry.pol) to be parsed
	#	hive - The hive in the registry to be updated (HKEY_CURRENT_USER or HKEY_LOCAL_MACHINE)
	#
	# Scope:
	#	Private
	#
	# Dependencies:
	#	- <uiClass>
	# 	- <utilities>
	#	- <registryEntryClass>
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
	method -private parseGpoXml{
		param(
			$gpoPath = $null,
			$hive = "HKEY_LOCAL_MACHINE"
		)
		
		if( $utilities.isBlank($gpoPath) -eq $false -and (test-path $gpoPath) -eq $true){
			$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing GPO Preferences File #yellow#$($gpoPath)#")
			
			$gpoXml = [xml](gc $gpoPath)
			
			foreach($entry in ($gpoXml.RegistrySettings.registry)){
				
				if($entry -ne $null){
					if($private.verbose){
						$uiClass.writeColor("$($uiClass.STAT_OK) Consumed #yellow#$( $entry.properties.key )#\#green#$($entry.properties.name)# --> #green#$( $entry.properties.value )#")
					}
					
					$private.RegistryCollection.Add(
						$registryEntryClass.New(
							$hive,
							$entry.properties.key,
							$entry.properties.name,
							$entry.properties.type,
							$entry.properties.value
						)
					);
				}else{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could Not Parse GPO File Entry for #yellow#$($gpoPath)#")
				}
			}
			
		}
	}



	
	##########################################################
	# Method: parseGpoPol
	# 	Will parse a GPO File (registry.pol)
	#
	# Parameters:
	#	gpoPath - the path to the gpo file (registry.pol) to be parsed
	#	hive - The hive in the registry to be updated (HKEY_CURRENT_USER or HKEY_LOCAL_MACHINE)
	#
	# Scope:
	#	Private
	#
	# Dependencies:
	#	- <uiClass>
	# 	- <utilities>
	#	- <registryEntryClass>
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
	method -private parseGpoPol{
		param(
			$gpoPath = $null,
			$hive = "HKEY_LOCAL_MACHINE"
		)
		
		if( $utilities.isBlank($gpoPath) -eq $false -and (test-path $gpoPath) -eq $true){
			$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing GPO File #yellow#$($gpoPath)#")
			$private.gpoPol.LoadFile($gpoPath)
			foreach($entry in ( $private.gpoPol.Entries ) ){
				if($entry -ne $null){
					if($private.verbose){
						$uiClass.writeColor("$($uiClass.STAT_OK) Consumed #yellow#$( $entry.keyName )#\#green#$($entry.ValueName)# --> #green#$( $entry.stringValue )#")
					}
					
					$private.RegistryCollection.Add(
						$registryEntryClass.New(
							$hive,
							$entry.keyName,
							$entry.ValueName,
							$entry.type,
							$entry.StringValue
						)
					);
				}else{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could Not Parse GPO File Entry for #yellow#$($gpoPath)#")
				}
			}
		}
	}
	
	##########################################################
	# Method: parseScap
	# 	Will parse a SCAP (xccdf and oval files) for settings to apply
	#
	# Parameters:
	#
	# Scope:
	#	Private
	#
	# Dependencies:
	#	- <uiClass>
	# 	- <utilities>
	#	- <registryEntryClass>
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
	method -private parseScap{
		if($utilities.isBlank($private.profile) -eq $false -and $utilities.isBlank($private.xccdfPath) -eq $false -and $utilities.isBlank($private.ovalPath) -eq $false){
			if( (test-path $private.xccdfPath) -and (test-path $private.ovalPath) ){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #yellow#$($private.xccdfPath)#")
			
				[xml]$private.xccdfXml = (gc $private.xccdfPath)
				$private.xccdfNs = new-object Xml.XmlNamespaceManager $private.xccdfXml.NameTable
				$private.xccdfNs.AddNamespace("dsig", "http://www.w3.org/2000/09/xmldsig#" );
				$private.xccdfNs.AddNamespace("xhtml", "http://www.w3.org/1999/xhtml" );
				$private.xccdfNs.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance" );
				$private.xccdfNs.AddNamespace("cpe", "http://cpe.mitre.org/language/2.0" );
				$private.xccdfNs.AddNamespace("dc", "http://purl.org/dc/elements/1.1/" );
				$private.xccdfNs.AddNamespace("ns", "http://checklists.nist.gov/xccdf/1.1" );

				[xml]$private.ovalXml = (gc $private.ovalPath)
				$private.ovalNs = new-object Xml.XmlNamespaceManager $private.ovalXml.NameTable
				$private.ovalNs.AddNamespace("ns", "http://oval.mitre.org/XMLSchema/oval-definitions-5" );
				$private.ovalNs.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance" );
				$private.ovalNs.AddNamespace("win", "http://oval.mitre.org/XMLSchema/oval-definitions-5#windows" );
				$private.ovalNs.AddNamespace("win-def", "http://oval.mitre.org/XMLSchema/oval-definitions-5#windows" );

				foreach($rule in ($private.xccdfXml.selectNodes("/ns:Benchmark/ns:Profile[@id='$($private.profile)']/ns:select[@selected='true']/@idref", $private.xccdfNs))){
					foreach($group in ($private.xccdfXml.selectNodes("//ns:Group[@id=`'$($rule.'#text')`']/ns:Rule/ns:check/ns:check-content-ref/@name", $private.xccdfNs))){
						foreach($test in ($private.ovalXml.selectNodes("//ns:oval_definitions/ns:definitions/ns:definition[@id=`'$($group.'#text')`']/ns:criteria/ns:criterion/@test_ref", $private.ovalNs) )){
							$uiClass.writeColor("$($uiClass.STAT_OK) Consuming Test #yellow#$($test.'#text')#")
							$obj = ($private.ovalXml.selectNodes("//ns:oval_definitions/ns:tests/win:registry_test[@id=`'$($test.'#text')`']/win:object/@object_ref", $private.ovalNs) | select '#text').'#text'
							$state = ($private.ovalXml.selectNodes("//ns:oval_definitions/ns:tests/win:registry_test[@id=`'$($test.'#text')`']/win:state/@state_ref", $private.ovalNs)  | select '#text').'#text'
							
							$regObj = $private.ovalXml.selectNodes("//ns:oval_definitions/ns:objects/win:registry_object[@id=`'$($obj)`']", $private.ovalNs)
							if($regObj -ne $null){
								$regState = $private.ovalXml.selectNodes("//ns:oval_definitions/ns:states/win:registry_state[@id=`'$($state)`']", $private.ovalNs)
								if($regState -ne $null){
									 if( ( ($regState | select type ).type.var_ref ) -like '*:var:*' ){
										$typeVar = ($private.ovalXml.selectSingleNode("//*[@id=`'$( ( ($regState | select type ).type.var_ref ) )`']", $private.ovalNs) | select value).value
									 }else{
										$typeVar = $utilities.xmlText( ($regState | select Type ).type )
									 }
									 
									 if( ( ($regState | select Value ).Value.var_ref ) -like '*:var:*' ){
										$valueVar = ( ($private.ovalXml.selectSingleNode("//*[@id=`'$( ( ($regState | select Value ).Value.var_ref ) )`']", $private.ovalNs) | select value).value )
									 }else{
										$valueVar = $utilities.xmlText( ($regState | select Value ).Value )
									 }
									$entry = @{
										"hive" = ($utilities.xmlText( ( $regObj | select Hive ).hive ));
										"keyName" = ($utilities.xmlText( ( $regObj | select Key ).key ));
										"valueName" = ($utilities.xmlText( ( $regObj | select Name ).name ));
										"value" = ($valueVar);
										"type" = ($typeVar);
									}
									
									if($private.verbose){
										$uiClass.writeColor("$($uiClass.STAT_OK) Consumed #yellow#$( $entry.keyName )#\#green#$($entry.ValueName)# --> #green#$( $entry.value )#")
									}
										
									$private.RegistryCollection.Add(
									
										$registryEntryClass.New(
											$entry.hive,
											$entry.keyName,
											$entry.valueName,
											$entry.type,
											$entry.value
										)
									);
								}else{
									$uiClass.writeColor("$($uiClass.STAT_ERROR) Could Not Parse Registry State for test #yellow#$($test.'#text')#")
								}
							}else{
								$uiClass.writeColor("$($uiClass.STAT_ERROR) Could Not Parse Registry Object for test #yellow#$($test.'#text')#")
							}
						}
					}
				}
			}else{
				$uiClass.writeColor(
					( "$($uiClass.STAT_ERROR) Missing Scap Files/Data:`n`tXCCDF  : #yellow#{0}#`n`tOVAL   : #yellow#{1}#`n`tProfile: #yellow#{2}#" -f $private.xccdfPath,$private.ovalPath,$private.profile )
				)
			}
		}

	}
	
	##########################################################
	# Method: updateSystems
	# 	Will update each selected system with the settings 
	#	found while parsing the STIGs or GPOs
	#
	# Parameters:
	#
	# Scope:
	#	Private
	#
	# Dependencies:
	#	- <uiClass>
	# 	- <utilities>
	#	- <progressBarClass>
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
	method -private updateSystems{
		$hostProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
		
		$currentComputer = 0
		
		foreach($h in $private.HostObj.Hosts.keys){
			$currentComputer++
			$i = (100*($currentComputer / @(1,$private.HostObj.Hosts.count)[($private.HostObj.Hosts.count -gt 0)]))
			
			$hostProgressBar.Activity("$currentComputer / $($private.HostObj.Hosts.count): Processing system $h").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			$uiClass.writeColor("$($uiClass.STAT_WAIT) Updating system #green#$($h)#")
			
			$hostActivityProgressBar =  $progressBarClass.New( @{ "parentId" = 2; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 3 }).Render() 
			$hostActivityProgressBar.Activity("Processing Machine Settings on system $($h)").Status(("{0:N2}% complete" -f 15)).Percent(15).Render()
			
			$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($h.Trim())'"
			if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
				
				#local machine settings
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Updating Machine Settings for system #green#$($h)#")
				
				$private.Registry.Open($h,'LocalMachine')
				$private.RegistryCollection.Filter( @{ "hive" = "HKEY_LOCAL_MACHINE" } ) | %{
					if($private.verbose){
						$uiClass.writeColor("$($uiClass.STAT_OK) $($_.KeyName)\#yellow#$($_.valueName)#\#green#$($_.value)#")
					}
					$private.Registry.SetValue( $_.KeyName, $_.valueName, $_.Value,$_.type)
				}
				sleep 1
				$private.Registry.close()
				
				$hostActivityProgressBar.Activity("Searching for Profiles on system $($h)").Status(("{0:N2}% complete" -f 25)).Percent(25).Render()
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Analysing User Profiles for system #green#$($h)#")
				$hiveFiles = @()
				
				#registry user profile settings
				$private.Registry.Open($h, 'LocalMachine')
				$private.Registry.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList")
				
				$private.Registry.GetSubKeyNames() | ? { $_.length -gt 10 } | % {
					$private.Registry.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($_)") | out-null
					$profilePath = ($private.Registry.GetValue("ProfileImagePath")).replace(":\","`$\")
					
					if ( (test-path "\\$($h)\$($profilePath)\ntuser.dat") -eq $true ){
						$hiveFiles += "\\$($h)\$($profilePath)\ntuser.dat"
					}
				}
				sleep 1
				$private.Registry.close()
				
				



				
				$hives = @()
				New-PSDrive -PSProvider registry -Root HKEY_USERS -Name HKU
				remove-item "$($pwd)\temp\ntuser.dat*" -force
				#copy all profiles local
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Copying profiles to local machine")
				gci "\\$($h)\c`$\users\*\*" -filter "ntuser.dat" -errorAction silentlyContinue -force | % {
					if($utilities.IsFileLocked($_.fullname)){
						$uiClass.writeColor("$($uiClass.STAT_ERROR) User Profile #red#locked# for #yellow#$($_.fullname)#")
					}else{
						$guid = [guid]::newGuid().ToString()
						copy-item "$($_.fullname)" "$($pwd)\temp\$($guid).dat" -force
						
						$hives += @{
							"filepath" = $_.fullname;
							"guid" = $guid;
							"valid" = $true;
						}
					}
				}
				
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Mounting all profiles")
				#mount all profiles
				for($i=0; $i -lt $hives.count; $i++){
					reg load "hku\$($hives[$i].guid)" "$pwd\temp\$($hives[$i].guid).dat"
					sleep 2	
					if( (test-path "hku:\$($hives[$i].guid)") -ne $true){
						reg unload "hku\$($hives[$i].guid)"
						$uiClass.writeColor("$($uiClass.STAT_ERROR) Could Not Update User Profile for #yellow#$($hives[$i].filepath)#.  Likely due to #red#REG.EXE# permissions issues.")
						$hives[$i].valid = $false;
					}
				}
				
				#make sure all profiles can be updated
				for($i=0; $i -lt $hives.count; $i++){
					try{
						New-ItemProperty -path "HKU:\$($hives[$i].guid)\System" -Name "manualUpdate" -Value "$(get-date)" -PropertyType "String" -errorAction Stop -force
					}catch{
						$uiClass.writeColor("$($uiClass.STAT_ERROR) Could Not Update User Profile for #yellow#$($hives[$i].filepath)#.  Likely due to permissions issues.")
						$hives[$i].valid = $false;
					}
				}
				
				
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Updating Profiles")
				#make updates
				$polBar =  $progressBarClass.New( @{ "parentId" = 3; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 4 }).Render() 
				$totPol = $private.RegistryCollection.count()
				$pi = 0
				sleep 10
				$private.RegistryCollection.Filter( @{ "hive" = "HKEY_CURRENT_USER" } ) | %{
					$pi++
					
					$i = (100*($pi / $totPol))
					$polBar.Activity("$($pi) / $($totPol) : Applying Policies").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
					
					if($private.verbose){
						$uiClass.writeColor("$($uiClass.STAT_OK) $($_.KeyName)\#yellow#$($_.valueName)# --> #green#$($_.value)#")
					}
					
					foreach($hive in ($hives | ? { $_.valid -eq $true }) ){
						#make sure the key exists first
						if( (test-path "HKU:\$($hive.guid)\$($_.KeyName)" ) -eq $false){
							$item = New-Item "HKU:\$($hive.guid)\$($_.KeyName)" -Force
						}else{
							$item = get-Item "HKU:\$($hive.guid)\$($_.KeyName)" -Force
						}
						
						New-ItemProperty -path "HKU:\$($hive.guid)\$($_.KeyName)" -Name "$($_.valueName)" -Value "$($_.value)" -PropertyType "$($private.registry.getValueType($_.type))" -Force | Out-Null
						#remove handle to item...this is so the profile doesn't stay open
						remove-variable("item") -errorAction silentlyContinue
						[gc]::collect()
					}
				}				
				
				
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Dismounting Profiles")
				#give time to finish making changes to hive
				sleep 5
				0
				[gc]::Collect()

				#dismount profiles
				$hives | % {
					reg unload "hku\$($_.guid)"
					#wait for hive to close
					sleep 2
					0
					[gc]::Collect()
				}
				
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Copying profiles to #green#$($h)#")
				#copy back and make backup
				$hives | ?{ $_.valid -eq $true } | %{
					$ts = (get-date -format "yyyyMMdd-HHmmss")
					Move-item "$($_.filepath)" "$($_.filepath).$($ts).old" -force
					move-item "$pwd\temp\$($_.guid).dat" "$($_.filepath)"
				}
				
				if($force){
					$hives | ?{ $_.valid -eq $false } | %{
						$ts = (get-date -format "yyyyMMdd-HHmmss")
						Move-item "$($_.filepath)" "$($_.filepath).$($ts).old" -force
					}
				}
				
				
				remove-item "$($pwd)\temp\*" -force
				
				
			}else{
				$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not connect to #green#$($h)#")
			}
			
			$hostActivityProgressBar.Completed($true).Render() 
			0
			[gc]::Collect()
		}
		0
		[gc]::Collect()
		remove-psdrive -name HKU
		$hostProgressBar.Completed($true).Render() 
	}
}

##########################################################
# Script: Execution
# This is where the script determines if it should 
# auto execute
#
# (start code)
# if($manualExec -ne $true){
# 	$ApplyPoliciesClass.New().Execute() | out-null
# }
# (end code)
##########################################################
if($manualExec -ne $true){
	$ApplyPoliciesClass.New().Execute()  | out-null
}