<#
.SYNOPSIS
	[Incomplete script!] This is a template for new scripts
.DESCRIPTION
	[Incomplete script!] This is a template for new scripts
.EXAMPLE
	C:\PS>.\template.ps1
	This will bring up the new script
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Nov 19, 2015
	
	
	
	
	
secpol <--> baseline.inf
auditpol <--> audits.csv


RSOP <--> ADM/admx/adml/inf/lgpo Folder Strcuture
GPO <--> adm/admx/adml/inf/lgpo Folder Structure
LGPO <--> adm/admx/adml/info/new Gpo
SCAP -> ADM/admx/adml/info/lgpo Folder Strcuture

RSOP -> Multiple separate GPOs (all settings are presented and the user can choose to send them to new GPOs.  like all windows settings to a win gpo, all office settings to an office gpo, etc etc etc)

***include registry.xml file under preferences
***include secedit under machine\microsoft
***include audit under machine\microsoft

Merge multiple domain GPOs to a single GPO
Split single GPO to multiple gpos


also allow .reg files



#>
[CmdletBinding()]
param ()   

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

$templateClass = new-PSClass template{
	note -static PsScriptName "policyManager"
	note -static Description ( ($(((get-help .\policyManager.ps1).Description)) | select Text).Text)
	
	note -private mainProgressBar
	note -private gui
	
	constructor{
		param()

		$private.gui = $null
		$private.gui = $guiClass.New("policyManager.xml")
		$private.gui.generateForm() | out-null;
		
		
		$rootNode = New-Object "$forms.TreeNode"
		$rootNode.text = "Selected Policies"
		$rootNode.Name = "Selected Policies"
		$rootNode.Tag = ""
		$private.gui.controls.treeSelPol.Nodes.Add($rootNode) | Out-Null
		
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
		
		$private.gui.Controls.btnRegFile.add_Click({ 
			$private.gui.Controls.txtRegFile.Text = $private.gui.actInvokeFileBrowser(@{"Registry File (*.reg)" = "*.reg";}) 
		})
		
		$private.gui.Controls.btnAddPol.add_Click({ 

			#add scap
			if($utilities.isBlank( $private.gui.Controls.txtXccdf.Text) -eq $false -and $utilities.isBlank( $private.gui.Controls.txtOval.Text) -eq $false -and $utilities.isBlank( $private.gui.Controls.cboProfile.Text) -eq $false ){
				$scap = $scapClass.new($private.gui.Controls.txtXccdf.Text,$private.gui.Controls.txtOval.Text,$private.gui.Controls.cboProfile.Text )
				$scap.ParseScap()
				$self.addPolicyNode("SCAP: $($scap.title)", $scap.entries)
			}
					
			#add domain user gpo settings
			if($utilities.isBlank( $private.gui.Controls.cboDomainGpoUser.text   ) -eq $false ){
				$gpo = $gpoClass.new($($private.gui.Controls.cboDomainGpoUser.text), "HKEY_CURRENT_USER" )
				$gpo.parseGpo() | out-null
				$self.addPolicyNode("User GPO: $($private.gui.Controls.cboDomainGpoUser.text)", $gpo.entries)
			}
			
			if($utilities.isBlank( $private.gui.Controls.cboDomainGpoMachine.text   ) -eq $false ){
				$gpo = $gpoClass.new($($private.gui.Controls.cboDomainGpoMachine.text), "HKEY_LOCAL_MACHINE" )
				$gpo.parseGpo() | out-null
				$self.addPolicyNode("Machine GPO: $($private.gui.Controls.cboDomainGpoMachine.text)", $gpo.entries)
			}
					
			if($utilities.isBlank( $private.gui.Controls.txtMachineGpo.text   ) -eq $false ){
				$gpo = $gpoClass.new($($private.gui.Controls.txtMachineGpo.text), "HKEY_LOCAL_MACHINE" )
				$gpo.parsePol( $private.gui.Controls.txtMachineGpo.text ) | out-null
				$self.addPolicyNode("Machine Pol: $($private.gui.Controls.txtMachineGpo.text)", $gpo.entries)
			}
			
			if($utilities.isBlank( $private.gui.Controls.txtUserGpo.text   ) -eq $false ){
				$gpo = $gpoClass.new($($private.gui.Controls.txtUserGpo.text), "HKEY_CURRENT_USER" )
				$gpo.parsePol( $private.gui.Controls.txtUserGpo.text ) | out-null
				$self.addPolicyNode("User Pol: $($private.gui.Controls.txtUserGpo.text)", $gpo.entries)
			}
			
			#txtRegFile
			if($utilities.isBlank( $private.gui.Controls.txtRegFile.text   ) -eq $false ){
				$regFile = $regFileClass.new($($private.gui.Controls.txtRegFile.text))
				$regFile.parseReg()
				$self.addPolicyNode("Registry File: $($private.gui.Controls.txtRegFile.text)", $regFile.entries)
			}
			
					
			foreach($field in @("txtUserGpo","txtMachineGpo","txtXccdf","txtOval","txtRegFile")){
				$private.gui.Controls.$field.text = ""
			}
			foreach($field in @("cboDomainGpoUser","cboDomainGpoMachine","cboProfile")){
				$private.gui.Controls.$field.selectedIndex = -1
			}

			$private.gui.controls.treeSelPol.Nodes[0].Expand()
		})
		
		$private.gui.Controls.btnSecPol.add_Click({ 
			$secPol = $secPolClass.new()
			$secPol.parseSecPol()
			$self.addPolicyNode("Local SecPol Policy (.inf):", $secPol.entries)
			$private.gui.controls.treeSelPol.Nodes[0].Expand()
		})
		
		$private.gui.Controls.btnAuditPol.add_Click({ 
			$newNode = New-Object "$forms.TreeNode"
			$newNode.text = "Local Audit Policy (.csv)"
			$newNode.Name = "Local Audit Policy (.csv)"
			$newNode.Tag = "Local Audit Policy (.csv)"
			
			$ts = (get-date -format "yyyy-MM-dd_HH_mm_ss")
			invoke-expression "auditpol /backup /file:'$($pwd)\temp\auditPol_$($ts).inf'" | out-null
			$auditItems = import-csv "$($pwd)\temp\auditPol_$($ts).inf"
			
			foreach($audit in $auditItems){
			
				if( ( $newNode.nodes.containsKey($audit.Subcategory) ) -eq $false){
					$subCatNode = New-Object "$forms.TreeNode"
					$subCatNode.text = $audit.Subcategory
					$subCatNode.Name = $audit.Subcategory
					$subCatNode.Tag = $audit.Subcategory
					$newNode.Nodes.Add($subCatNode) | Out-Null					
				}else{
					$subCatNode = $newNode.nodes.find($audit.Subcategory,$false) | select -first 1
				}
				
				#this is just csv data, export it as is
				$auditnode = New-Object "$forms.TreeNode"
				$auditnode.text = "$($audit.'Machine Name'),$($audit.'Policy Target'),$($audit.'Subcategory'),$($audit.'Subcategory GUID'),$($audit.'Inclusion Setting'),$($audit.'Exclusion Setting'),$($audit.'Setting Value')"
				$auditnode.Name = "$($audit.'Machine Name'),$($audit.'Policy Target'),$($audit.'Subcategory'),$($audit.'Subcategory GUID'),$($audit.'Inclusion Setting'),$($audit.'Exclusion Setting'),$($audit.'Setting Value')"
				$auditnode.Tag = "$($audit.'Machine Name'),$($audit.'Policy Target'),$($audit.'Subcategory'),$($audit.'Subcategory GUID'),$($audit.'Inclusion Setting'),$($audit.'Exclusion Setting'),$($audit.'Setting Value')"
				$subCatNode.Nodes.Add($auditnode) | Out-Null					
				
			}
			
			$private.gui.controls.treeSelPol.Nodes[0].Nodes.Add($newNode) | Out-Null
			$private.gui.controls.treeSelPol.Nodes[0].Expand()
		})
		
		$private.gui.Controls.btnRSOP.add_Click({ 
			$newNode = New-Object "$forms.TreeNode"
			$newNode.text = "Resultant Set of Policies (RSOP)"
			$newNode.Name = "Resultant Set of Policies (RSOP)"
			$newNode.Tag = "Resultant Set of Policies (RSOP)"
			
			$rsop = $rsopClass.new('c:\tsg\vresults.txt')
			$rsop.parse()
			
			foreach($key in ( $rsop.settings.keys | sort) ){
				switch($key){
					{@("accountPolicies","auditPolicies") -contains $key} {
						$rsopCatNode = New-Object "$forms.TreeNode"
						$rsopCatNode.text = $key
						$rsopCatNode.Name = $key
						$rsopCatNode.Tag = $key
				
						foreach($acctPolItem in ($rsop.settings.$key.Computer | sort) ){
							$acctPol = new-object "$forms.Treenode"
							$acctPol.text = "$($acctPolItem.Policy) --> $($acctPolItem.'Computer Setting')"
							$acctPol.Name = $acctPolItem.Policy
							$acctPol.Tag = $acctPolItem.'Computer Setting'
							$rsopCatNode.nodes.add($acctPol)
						}
						$newnode.nodes.add($rsopCatNode)
					}
					
					"secOpts" {
						$rsopCatNode = New-Object "$forms.TreeNode"
						$rsopCatNode.text = $key
						$rsopCatNode.Name = $key
						$rsopCatNode.Tag = $key
				
						foreach($secPolItem in ($rsop.settings.$key.Computer | sort) ){
							$secPolNode = new-object "$forms.Treenode"
							
							if($utilities.isBlank($secPolItem.ValueName) -eq $true){
								$secPolNode.text = "$($secPolItem.Policy) --> $($secPolItem.'Computer Setting')"
								$secPolNode.Name = $secPolItem.Policy
								$secPolNode.Tag = $secPolItem.'Computer Setting'
							}else{
								$secPolNode.text = "$($secPolItem.ValueName) --> $($secPolItem.'Computer Setting')"
								$secPolNode.Name = $secPolItem.ValueName
								$secPolNode.Tag = $secPolItem.'Computer Setting'														
							}
							
							$rsopCatNode.nodes.add($secPolNode)
						}
						$newnode.nodes.add($rsopCatNode)
					}
					
					"eventLogSettings" {
						$rsopCatNode = New-Object "$forms.TreeNode"
						$rsopCatNode.text = $key
						$rsopCatNode.Name = $key
						$rsopCatNode.Tag = $key
						foreach($logType in @('Application','Security','System')){
							$eventLogTypeNode = new-object "$forms.Treenode"
							$eventLogTypeNode.text = $logType
							$eventLogTypeNode.Name = $logType
							$eventLogTypeNode.Tag = $logType
								
							foreach($eventLogItem in ($rsop.settings.$key.Computer | ? { $_.'Log Name' -eq $logType}) ){
								
								$eventLogNode = new-object "$forms.Treenode"
								$eventLogNode.text = "$($eventLogItem.Policy) --> $($eventLogItem.'Computer Setting')"
								$eventLogNode.Name = $eventLogItem.Policy
								$eventLogNode.Tag = $eventLogItem.'Computer Setting'
								
								$eventLogTypeNode.nodes.add($eventLogNode)
							}
							$rsopCatNode.nodes.add($eventLogTypeNode)
						}
						$newnode.nodes.add($rsopCatNode)
					}
				}
				
				
				
				
				
				
				
				
				
				
				
			}
			
			
			
			
			$private.gui.controls.treeSelPol.Nodes[0].Nodes.Add($newNode) | Out-Null
			$private.gui.controls.treeSelPol.Nodes[0].Expand()
			$newNode.expand()
		})
		
		
		
		
		
		$gpos = (get-gpo -all -ErrorAction SilentlyContinue | ? { $_.GpoStatus -like '*Enabled*' } | select DisplayName, Id | sort DisplayName )
		$private.gui.Controls.cboDomainGpoUser.Items.Add("") | out-null
		$private.gui.Controls.cboDomainGpoMachine.Items.Add("") | out-null
		foreach($gpo in $gpos){
			$private.gui.Controls.cboDomainGpoUser.Items.Add($gpo.DisplayName) | out-null
			$private.gui.Controls.cboDomainGpoMachine.Items.Add($gpo.DisplayName) | out-null
		}
				
		
		$private.gui.Form.ShowDialog() | Out-Null	
	}
	
	method addPolicyNode{
		param($policyTitle, $entries)
		
		$newNode = New-Object "$forms.TreeNode"
		$newNode.text = $policyTitle
		$newNode.Name = $policyTitle
		$newNode.Tag = $policyTitle
		
		foreach($e in $entries){
			[System.Windows.Forms.Application]::DoEvents()  | out-null			
									
			#see if action exists
			switch($e.action){
				"U" {$action = "Update"}
				"D" {$action = "Delete"}
			}
			if( ( $newNode.nodes.containsKey($action) ) -eq $false){
				$actionNode = New-Object "$forms.TreeNode"
				$actionNode.text = $action
				$actionNode.Name = $action
				$actionNode.Tag = $action
				$newNode.Nodes.Add($actionNode) | Out-Null					
			}else{
				$actionNode = $newNode.nodes.find($action,$false) | select -first 1
			}
			
			#see if hive exists
			if( ( $actionNode.nodes.containsKey($e.hive) ) -eq $false){
				$hiveNode = New-Object "$forms.TreeNode"
				$hiveNode.text = $e.hive
				$hiveNode.Name = $e.hive
				$hiveNode.Tag = $e.hive
				$actionNode.Nodes.Add($hiveNode) | Out-Null					
			}else{
				$hiveNode = $actionNode.nodes.find($e.hive,$false) | select -first 1
			}
		
			#see if key exists (dont add registry options without keynames)
			if($utilities.isBlank( $e.keyName.ToString().Trim() ) -eq $false   ){
				
				if( ( $hiveNode.nodes.containsKey($e.keyName.toLower() ) ) -eq $false){
					$keyNode = New-Object "$forms.TreeNode"	
					$keyNode.text = $e.keyName.toLower()
					$keyNode.Name = $e.keyName.toLower()
					$keyNode.Tag = $e.keyName.toLower()
					$hiveNode.Nodes.Add($keyNode) | Out-Null					
				}else{
					$keyNode = $hiveNode.nodes.find($e.keyName.toLower(),$false) | select -first 1
				}
			
				#see if name exists
				if( $utilities.isBlank($e.valueName) -eq $false){
				
					if( ( $keyNode.nodes.containsKey($e.valueName) ) -eq $false){
						$valueNode = New-Object "$forms.TreeNode"
						$type = ""
						if($utilities.isBlank( $e.type) -eq $false){
							$type = "$($e.type.toString().ToUpper()):"
						}
						
						$valueNode.text = "$($e.valueName) --> $($type)$($e.value)"
						$valueNode.Name = "$($e.valueName) --> $($type)$($e.value)"
						$valueNode.Tag = "$($e.valueName) --> $($type)$($e.value)"
						$keynode.Nodes.Add($valueNode) | Out-Null
					}else{
						$valueNode = $hiveNode.nodes.find($e.valuename,$false) | select -first 1
					}
				}else{
				
					$keyNode.text += " --> $($e.value)"
				}
			}
			
		}
		$private.gui.controls.treeSelPol.Nodes[0].Nodes.Add($newNode) | Out-Null
		
	}
	
	method Execute{
		param($par)

		
		$uiClass.errorLog()
	}
}

$templateClass.New().Execute()  | out-null