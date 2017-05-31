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
#>
[CmdletBinding()]
param ()   

clear
$error.clear()

#make sure we are running from the right place
$oldPwd = $pwd
set-location (split-path $MyInvocation.MyCommand.Path)

. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

if(!(test-path "$pwd\bin\PolFileEditor.dll")){
	Add-Type -Language CSharpVersion3 -TypeDefinition ([System.IO.File]::ReadAllText("$pwd\types\PolFileEditor.cs")) -OutputAssembly "$pwd\bin\PolFileEditor.dll" -outputType Library
}
if(!("TJX.PolFileEditor.PolFile" -as [type])){
	Add-Type -path "$pwd\bin\PolFileEditor.dll"
}

Import-Module groupPolicy -errorAction SilentlyContinue

$imagePatcherController = new-PSClass imagePatcher{
	note -static PsScriptName "imagePatcher"
	note -static Description ( ($(((get-help .\imagePatcher.ps1).Description)) | select Text).Text)
	
	#this is the main gui component 
	note view
	
	#this is the dism library
	note dism
	
	#this is where all the tab functionality is contained
	note models @{}
	
	constructor{
		param()
		$this.dism = $dismClass.new()
		$this.view = $imagePatcherView.New($this)
		
		#construct model objects
		get-variable | ? { $_.name -like 'imagePatcherModel*' } | % {
			$this.models.add($($_.name.replace('imagePatcherModel','')), $(invoke-expression "`$$($_.name).new(`$this)"))
		}
		
		[gc]::collect()
		$this.view.render()
	}
	
	method Execute{
		param($par)
		
		set-location $oldPwd
		$uiclass.errorLog()
	}
}
$imagePatcherModelScapGpoSettings = new-PSClass imagePatcherScapGpoSettings{
	note -private controller
	note -static tabTitle 'ScapGpoSettings'
	
	note -private xccdfPath 
	note -private ovalPath
	note -private profile = ""
	note -private userGpoPath
	note -private machineGpoPath
	note -private userGpo
	note -private machineGpo
	
	note -private xccdfXml = ""
	note -private ovalXml = ""
	note -private xccdfNs = ""
	note -private ovalNs = ""
	
	note -private entries @()
			
	constructor{
		param($controller)
		$private.controller = $controller
		
		$tabControls = $guiClass.renderSubForm("$pwd\templates\tabScapGpoSettings.xml")
		$tabControls.keys | % {
			if($tabControls.$_){
				$private.controller.view.getTab("ScapGpoSettings").controls.add( $tabControls.$_ ) | out-null
			}
		}
		
		$private.controller.view.getControl('ScapGpoSettings','tab4btnXccdf').add_Click({
			$private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text = $private.gui.actInvokeFileBrowser(@{"XML Files (*.xml)" = "*.xml";})
			if( $utilities.isBlank($private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text) -eq $false ){
				if( (test-path $private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text.replace("xccdf","oval") ) -eq $true -and $private.controller.view.getControl('ScapGpoSettings','tab4txtOval').Text -eq "" ){
					$private.controller.view.getControl('ScapGpoSettings','tab4txtOval').Text = $private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text.replace("xccdf","oval")
				}
			
				if( (test-path $private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text.replace("xccdf","oval") ) -eq $true ){
					$private.controller.view.getControl('ScapGpoSettings','tab4cboProfile').Items.clear()
					([xml] (gc $private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text)).Benchmark.Profile | % {  
						$private.controller.view.getControl('ScapGpoSettings','tab4cboProfile').Items.Add($_.id) 
					}
				}
			}
		})
		
		$private.controller.view.getControl('ScapGpoSettings','tab4btnOval').add_Click({
			$private.controller.view.getControl('ScapGpoSettings','tab4txtOval').Text = $private.gui.actInvokeFileBrowser(@{"XML Files (*.xml)" = "*.xml";})
			if( $utilities.isBlank($private.controller.view.getControl('ScapGpoSettings','tab4txtOval').Text) -eq $false ){
				if( (test-path $private.controller.view.getControl('ScapGpoSettings','tab4txtOval').Text.replace("oval","xccdf") ) -eq $true -and $private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text -eq "" ){
					$private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text = $private.controller.view.getControl('ScapGpoSettings','tab4txtOval').Text.replace("oval","xccdf")
				}
			
				if( (test-path $private.controller.view.getControl('ScapGpoSettings','tab4txtOval').Text.replace("oval","xccdf") ) -eq $true ){
					$private.controller.view.getControl('ScapGpoSettings','tab4cboProfile').Items.clear()
					([xml] (gc $private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text)).Benchmark.Profile | % {  
						$private.controller.view.getControl('ScapGpoSettings','tab4cboProfile').Items.Add($_.id) 
					}
				}
			}
		})
		
		
		
		$private.controller.view.getControl('ScapGpoSettings','tab4btnUserGpo').add_Click({ 
			$private.controller.view.getControl('ScapGpoSettings','tab4txtUserGpo').Text = $private.controller.view.gui.actInvokeFolderBrowser() 
		})
		
		$private.controller.view.getControl('ScapGpoSettings','tab4btnMachineGpo').add_Click({ 
			$private.controller.view.getControl('ScapGpoSettings','tab4txtMachineGpo').Text = $private.controller.view.gui.actInvokeFolderBrowser() 
		})
				
		$gpos = (get-gpo -all -ErrorAction SilentlyContinue | ? { $_.GpoStatus -like '*Enabled*' } | select DisplayName, Id | sort DisplayName )
		$private.controller.view.getControl('ScapGpoSettings','tab4cboDomainGpoUser').Items.Add("") | out-null
		$private.controller.view.getControl('ScapGpoSettings','tab4cboDomainGpoMachine').Items.Add("") | out-null
		
		foreach($gpo in $gpos){
			$private.controller.view.getControl('ScapGpoSettings','tab4cboDomainGpoUser').Items.Add($gpo.DisplayName) | out-null
			$private.controller.view.getControl('ScapGpoSettings','tab4cboDomainGpoMachine').Items.Add($gpo.DisplayName) | out-null
		}
		
		$private.controller.view.getControl('ScapGpoSettings','tab4btnExec').add_Click({ 
			$private.controller.models.ScapGpoSettings.applyPolicies()
		})
		
		$private.controller.view.getControl('ScapGpoSettings','tab4btnAddPol').add_Click({
		
			#see if a scap is present
			if($utilities.isBlank( $private.controller.view.getControl('ScapGpoSettings','tab4txtOval').Text ) -eq $false -and $utilities.isBlank( $private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text ) -eq $false -and $utilities.isBlank( $private.controller.view.getControl('ScapGpoSettings','tab4cboProfile').Text ) -eq $false ){
				$item =  New-Object "System.Windows.Forms.ListviewItem"( $private.controller.view.getControl('ScapGpoSettings','tab4lstSelPol').items.count )
				$item.SubItems[0].text = $private.controller.view.getControl('ScapGpoSettings','tab4lstSelPol').items.count + 1 
				$item.SubItems.Add( "SCAP" ) | out-null
				$item.SubItems.Add( "$($private.controller.view.getControl('ScapGpoSettings','tab4txtXccdf').Text);$($private.controller.view.getControl('ScapGpoSettings','tab4txtOval').Text);$($private.controller.view.getControl('ScapGpoSettings','tab4cboProfile').Text)") | out-null
				$private.controller.view.getControl('ScapGpoSettings','tab4lstSelPol').Items.Add( $item ) | out-null
			}
			
			foreach($field in @("tab4cboDomainGpoUser","tab4cboDomainGpoMachine","tab4txtUserGpo","tab4txtMachineGpo")){
				if($utilities.isBlank( $private.controller.view.getControl('ScapGpoSettings',$field).text   ) -eq $false ){
						$item =  New-Object "System.Windows.Forms.ListviewItem"( $private.controller.view.getControl('ScapGpoSettings','tab4lstSelPol').items.count )
						$item.SubItems[0].text = $private.controller.view.getControl('ScapGpoSettings','tab4lstSelPol').items.count + 1 
						switch($field){
							"tab4cboDomainGpoUser" 		{$item.SubItems.Add( "User GPO" ) | out-null }
							"tab4cboDomainGpoMachine" 	{$item.SubItems.Add( "Machine GPO" ) | out-null }
							"tab4txtUserGpo" 			{$item.SubItems.Add( "User Pol" ) | out-null }
							"tab4txtMachineGpo" 		{$item.SubItems.Add( "Machine Pol" ) | out-null}
						}
						$item.SubItems.Add( $private.controller.view.getControl('ScapGpoSettings',$field).text ) | out-null
						$private.controller.view.getControl('ScapGpoSettings','tab4lstSelPol').items.Add( $item ) | out-null
				}
			}
			
			
			foreach($field in @("tab4txtXccdf","tab4txtOval","tab4txtUserGpo","tab4txtMachineGpo")){
				$private.controller.view.getControl('ScapGpoSettings',$field).text = ""
			}
			foreach($field in @("tab4cboProfile","tab4cboDomainGpoUser","tab4cboDomainGpoMachine")){
				$private.controller.view.getControl('ScapGpoSettings',$field).selectedIndex = -1
			}
			
			
			$private.controller.view.getControl('ScapGpoSettings','tab4lstSelPol').FullRowSelect  = $true
			$private.controller.view.getControl('ScapGpoSettings','tab4lstSelPol').AutoResizeColumns('ColumnContent') | out-null
			
		})
				
		[gc]::collect()
	}
	
	method parseScap{
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Parsing Selected Scap File #yellow#$($private.xccdfPath)#")
		$scap = $scapClass.new($private.xccdfPath, $private.ovalPath, $private.profile)
		$scap.ParseScap()
		
		foreach($e in $scap.entries){
			$private.entries += $e
		}
	}
	
	method parseGpo{
		param($gpo, $hive)
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Parsing Selected GPO #yellow#$($gpo)#")
		$gpo = $gpoClass.new($gpo, $hive)
		$gpo.parseGpo()
		
		foreach($e in $gpo.entries){
			$private.entries += $e
		}
	}
	
	
	method applyPolicies{
		#determine which settings need to be applied
		foreach($item in $private.controller.view.getControl('ScapGpoSettings','tab4lstSelPol').items){
			if($item -ne $null){
				switch( $item.subitems[1].text ){
					"SCAP" { $paths = ($item.subitems[2]).text.ToString().split(";"); $private.xccdfPath = $paths[0]; $private.ovalPath = $paths[1]; $private.profile = $paths[2]; $private.controller.models.ScapGpoSettings.parseScap(); }
					"User GPO" { $private.userGpo = $item.subitems[2].text.ToString();  $private.controller.models.ScapGpoSettings.parseGpo($private.userGpo, "HKEY_CURRENT_USER"); }
					"Machine GPO" { $private.MachineGpo = $item.subitems[2].text.ToString(); $private.controller.models.ScapGpoSettings.parseGpo($private.MachineGpo, "HKEY_LOCAL_MACHINE");}
					"User Pol" { $private.userGpoPath = $item.subitems[2].text.ToString(); $private.controller.models.ScapGpoSettings.parseGpo($private.userGpoPath, "HKEY_CURRENT_USER"); }
					"Machine Pol" { $private.machineGpoPath = $item.subitems[2].text.ToString(); $private.controller.models.ScapGpoSettings.parseGpo($private.machineGpoPath, "HKEY_LOCAL_MACHINE"); }
				}
			}
		}
		
		
		#now, go through and apply all the settings
		
		# first, mount all hives from the image
		$regPath = "$($private.controller.models.isowimcontrol.wimpath)\Windows\System32\config\"
		gci $regPath -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $false -and $utilities.isBlank($_.extension) -eq $true -and $_.name -notLike '*SECURITY*' } |  % {
			if((test-path "hklm:\$($private.controller.models.isowimcontrol.selectedIsoFileName)-$($_.name)" ) -eq $false){
				$uiclass.writeColor("$($uiclass.STAT_WAIT) Mounting Image #yellow#$($_.name)# HKLM Registry Hive")
				
				$params = @(
					"load",
					"hklm\$($private.controller.models.isowimcontrol.selectedIsoFileName)-$($_.name)",
					"$($_.fullname)"
				)
				& reg.exe $params
			}
		}
		$regPath = "$($private.controller.models.isowimcontrol.wimpath)\users\default\"
		gci $regPath -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $false -and$_.extension -eq '.DAT' } |  % {
			if((test-path "hklm:\$($private.controller.models.isowimcontrol.selectedIsoFileName)-$($_.name)" ) -eq $false){
				$uiclass.writeColor("$($uiclass.STAT_WAIT) Mounting Image #yellow#$($_.name)# HKCU Registry Hive")
				$params = @(
					"load",
					"hklm\$($private.controller.models.isowimcontrol.selectedIsoFileName)-$($_.name)",
					"$($_.fullname)"
				)
				& reg.exe $params
			}
		}

		#now that they are mounted, do stuff with them
		
		#see which 'controlset' is the current controlset
		$currentControl = get-itemProperty "hklm:\$($private.controller.models.isowimcontrol.selectedIsoFileName)-SYSTEM\Select" | select -expand current
		
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Applying Settings to Image")
		foreach($entry in ($private.entries) ){
			if($utilities.isBlank($entry.KeyName) -eq $false){
				if($cstsClass.verbose){
					$uiClass.writeColor("$($uiClass.STAT_OK) #blue#[$($entry.type)]# $($entry.KeyName)\#yellow#$($entry.valueName)# --> #green#$($entry.value)#")
				}
				
				if($entry.hive -eq 'HKEY_CURRENT_USER'){
					$keyPath = "hklm:\$($private.controller.models.isowimcontrol.selectedIsoFileName)-NTUSER.DAT\$($entry.KeyName)"
				}else{
					$keyPath = "hklm:\$($private.controller.models.isowimcontrol.selectedIsoFileName)-$($entry.keyName)" -creplace("\\CurrentControlSet\\","\ControlSet00$($currentControl)\")
				}
							
				if($entry.action -eq 'D'){
					if( (test-path $keyPath) -eq $true){
						remove-ItemProperty -Path $keyPath  -name $($entry.valuename)
					}
				}else{
					if( (test-path $keyPath) -eq $false){
						new-item -path $keyPath -force
					}
					#default value or another value
					if($utilities.isBlank($entry.valueName) -eq $false){
						try{
							set-itemProperty -path $keyPath -name $entry.valueName -value $entry.value -type $($registryClass.getValueType($entry.type)) -force
						}catch{
							write-host $keyPath
							write-host $entry.valueName
							write-host $entry.value
							write-host $entry.type
						}
					}else{
						set-itemProperty -path $keyPath -name '(Default)' -value $entry.value -type $($registryClass.getValueType($entry.type)) -force 
					}
				}
			}else{
				$uiclass.writeColor("$($uiclass.STAT_ERROR) Missing KeyName for:
#yellow#ACTION# : $($entry.action)
#green#HIVE# : $($entry.hive)
#yellow#KEY NAME# : $($entry.keyName)
#green#TYPE# : $($entry.type)
#yellow#VALUE NAME# : $($entry.valueName)
#green#VALUE# : $($entry.value)"
				)
			}
		}
		
		#unmount hives
		sleep 5
		[gc]::collect()
		$nodes = @()
		gci hklm:\ -erroraction silentlyContinue | ? { $_.name -like "*$($private.controller.models.isowimcontrol.selectedIsoFileName)*"  -and $_.name -notLike '*SECURITY*' } | select -expand Name | %{
			$nodes += $_
		}
		
		$nodes | % {
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Unmounting Image #yellow#$($_)# Registry Hive")
			[gc]::collect()
			reg.exe unload "$($_)"
		}
		
	}
}


$imagePatcherModelEditionInstallManagement = new-PSClass imagePatcherEditionInstallManagement{
	note -private controller
	note -static tabTitle 'EditionInstallManagement'
		
	constructor{
		param($controller)
		$private.controller = $controller
		
		$tabControls = $guiClass.renderSubForm("$pwd\templates\tabEditionInstallManagement.xml")
		$tabControls.keys | % {
			if($tabControls.$_){
				$private.controller.view.getTab("EditionInstallManagement").controls.add( $tabControls.$_ ) | out-null
			}
		}
		$private.controller.view.getControl('EditionInstallManagement','tab5btnSelectXml').add_Click({
			$private.controller.view.getControl('EditionInstallManagement','tab5txtUnattendSelection').text = $private.controller.view.gui.actInvokeFileBrowser(@{"XML Files (*.XML)" = "*.xml";}) 
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Selected Unattend XML File #yellow#$($private.controller.view.getControl('EditionInstallManagement','tab5txtUnattendSelection').text)#")
		})
		$private.controller.view.getControl('EditionInstallManagement','tab5BtnUnattend').add_Click({
			$private.controller.models.EditionInstallManagement.applyUnattendFile()
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Applying Unattend file #yellow#$($private.controller.view.getControl('EditionInstallManagement','tab5txtUnattendSelection').text)#")
		})
		$private.controller.view.getControl('EditionInstallManagement','tab5BtnProdKey').add_Click({
			$private.controller.models.EditionInstallManagement.setProdKey()
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Setting Product Key For Image to #green#$($private.controller.view.getControl('EditionInstallManagement','tab5txtProdKey').text)#")
		})
		[gc]::collect()
	}
	
	method applyUnattendFile{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.dism.wimPath = $private.controller.models.isowimcontrol.wimPath
			$private.controller.dism.applyUnattendFile( ($private.controller.view.getControl('EditionInstallManagement','tab5txtUnattendSelection').text) )
			$uiclass.writeColor("$($uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request /apply-unattend")
			while($private.controller.dism.job.state -eq 'Running'){
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
			}
			$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n`r`n$($private.controller.dism.getJobResults() -join "`r`n")`r`n")
			$private.controller.view.toggleSplash($false)
		}
	}
	
	method setProdKey{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.dism.wimPath = $private.controller.models.isowimcontrol.wimPath
			
			$private.controller.dism.setProdKey( ($private.controller.view.getControl('EditionInstallManagement','tab5txtProdKey').text) )
			$uiclass.writeColor("$($uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request /set-productKey")
			while($private.controller.dism.job.state -eq 'Running'){
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
			}
			$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n`r`n$($private.controller.dism.getJobResults() -join "`r`n")`r`n")
			$private.controller.view.toggleSplash($false)
		}
	}
}


$imagePatcherModelISOWimControl = new-PSClass imagePatcherISOWimControl{
	note -private controller
	note -static tabTitle 'ISOWimControl'
	
	property selectedIsoFileName -get {
		if($utilities.isBlank( $private.controller.view.getControl('ISOWimControl','tab0txtIsoSelection').text ) -eq $false){
			return  [io.path]::GetFileNameWithoutExtension( $private.controller.view.getControl('ISOWimControl','tab0txtIsoSelection').text )  
		}else{
			return $false
		}
	}
	
	property mounted -get { 
		return ($utilities.isBlank($this.selectedWimFileName) -eq $false -and $utilities.isBlank($this.selectedWimIndex) -eq $false -and $utilities.isBlank($private.controller.models.isowimcontrol.selectedIsoFileName) -eq $false)
	}
	
	property selectedWimIndex -get {
		return $private.controller.view.getControl('ISOWimControl','tab0cboAvailWimIndex').items[ $($private.controller.view.getControl('ISOWimControl','tab0cboAvailWimIndex').selectedIndex) ]
	}
	
	property selectedWimFileName -get{
		if($private.controller.models.isowimcontrol.selectedIsoFileName){
			return (gci "$($pwd)\wim\extracted\$($private.controller.models.isowimcontrol.selectedIsoFileName)\" -recurse -include "$( $private.controller.view.getControl('ISOWimControl','tab0cboAvailWim').items[$private.controller.view.getControl('ISOWimControl','tab0cboAvailWim').selectedIndex] )" | select -first 1 )
		}
	}
	property wimPath -get {
		if($this.mounted){
			return "$($pwd)\wim\offline\$($private.controller.models.isowimcontrol.selectedIsoFileName)\$([io.path]::GetFileNameWithoutExtension($($this.selectedWimFileName.fullName)))\$($this.selectedWimIndex)"
		}
	}
	
	constructor{
		param($controller)
		$private.controller = $controller
		
		$tabControls = $guiClass.renderSubForm("$pwd\templates\tabISOWimControl.xml")
		$tabControls.keys | % {
			if($tabControls.$_){
				$private.controller.view.getTab("ISOWimControl").controls.add( $tabControls.$_ ) | out-null
			}
		}
		
		#adding events are odd.  the event call populates the $this variable with the event, which doesn't link back to this PSClass.  
		#self is populated via the psclass library as an alternate variable for this
		#the scope of the event is actually in the scope of the primary controller, not this local scope
		#so adding the event requires bouncing back and forth to the different objects via the controller class
		#private.controller.view is the view object in the main imagePatcher class.
		#self.models.isowimcontrol is the isowimcontrol class in the models hash array within the main controller psclass object
		$private.controller.view.getControl('ISOWimControl','tab0btnSelectIso').add_Click({
			$private.controller.view.getControl('ISOWimControl','tab0txtIsoSelection').text = $private.controller.view.gui.actInvokeFileBrowser(@{"ISO Files (*.ISO)" = "*.iso";}) 
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Selected ISO #yellow#$($private.controller.view.getControl('ISOWimControl','tab0txtIsoSelection').text)#")
		})
		
		$private.controller.view.getControl('ISOWimControl','tab0btnExtractIso').add_Click({ 
			$private.controller.models.ISOWimControl.extractISO()
			$private.controller.models.ISOWimControl.searchWims()
		})
		
		$private.controller.view.getControl('ISOWimControl','tab0btnDiscardIso').add_Click({ 
			$private.controller.models.ISOWimControl.discardISO()
		})
		
		
		
		$private.controller.view.getControl('ISOWimControl','tab0cboAvailWim').add_SelectedIndexChanged({ 
			$private.controller.models.ISOWimControl.listWimInfo(); 
		})
		
		$private.controller.view.getControl('ISOWimControl','tab0btnMountWim').add_Click(	{ $private.controller.models.ISOWimControl.mountWim() })
		$private.controller.view.getControl('ISOWimControl','tab0btnDiscardWim').add_Click(	{ $private.controller.models.ISOWimControl.dismountWim($false) })
		$private.controller.view.getControl('ISOWimControl','tab0btnCommitWim').add_Click(	{ $private.controller.models.ISOWimControl.dismountWim($true) })
		$private.controller.view.getControl('ISOWimControl','tab0btncreateiso').add_Click(	{ $private.controller.models.ISOWimControl.createIso() })
		
		[gc]::collect()
	}
	
	method listWimInfo{
		if( $private.controller.view.getControl('ISOWimControl','tab0cboAvailWim').selectedIndex -ne -1){
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request /get-WimInfo")
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Executing DISM Request #yellow#/get-WimInfo#")
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Analysing WIM File #yellow#$($private.controller.models.isowimcontrol.selectedWimFileName.Name)#")
			
			$private.controller.dism.listWimInfo( ( $private.controller.models.isowimcontrol.selectedWimFileName.fullName ) )
			$uiclass.writeColor("$($uiclass.STAT_OK) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
			while($private.controller.dism.job.state -eq 'Running'){
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
			}
			
			$private.controller.view.toggleSplash($false)
			$content = $private.controller.dism.getJobResults()
			$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n$($content -join "`r`n")`r`n")
			
			$private.controller.view.getControl('ISOWimControl','tab0cboAvailWimIndex').items.clear()
			
			$content -split "`r`n" | ? { $_ -like 'Index*' } | % { ( $_ -split ':')[1].ToString().Trim() } | %{
				$private.controller.view.getControl('ISOWimControl','tab0cboAvailWimIndex').items.add( $_ )
			}
		}
		[gc]::collect()
	}
	
	method searchWims{
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Searching for #yellow#Wim# images")
		$private.controller.view.getControl('ISOWimControl','tab0cboAvailWim').items.clear()
		gci "$($pwd)\wim\extracted\$($private.controller.models.isowimcontrol.selectedIsoFileName)\" -recurse -include '*.wim' | % {
			$uiclass.writeColor("$($uiclass.STAT_OK) `tFound WIM File #yellow#$($_.name)#")
			$private.controller.view.getControl('ISOWimControl','tab0cboAvailWim').items.add( $_.name )
		}
		[gc]::collect()
	}
	
	method mountWim{
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Mounting #yellow#$($private.controller.models.isowimcontrol.selectedWimFileName.Name)#")
		$private.controller.view.toggleSplash($true,"Please Wait...","Mounting Wim")
		
		$mountOperation = $private.controller.dism.mountWim( $($private.controller.models.isowimcontrol.selectedWimFileName.fullName), $($private.controller.models.isowimcontrol.selectedWimIndex), $($private.controller.models.isowimcontrol.selectedIsoFileName) )
		$uiclass.writeColor("$($uiclass.STAT_OK) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
		if($mountOperation -ne $false){
			while($private.controller.dism.job.state -eq 'Running'){
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
			}
			$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n`r`n$($private.controller.dism.getJobResults() -join "`r`n")`r`n")
		}else{
			$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n`r`nWIM Image Already Mounted`r`n")
		}
		
		$private.controller.view.toggleSplash($false)
		[gc]::collect()
	}
	
	method dismountWim{
		param($commit)
		$private.controller.view.toggleSplash($true,"Please Wait...","Dismounting Wim")
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Dismounting WIM")
		$private.controller.dism.dismountWim( $commit )
		$uiclass.writeColor("$($uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
		while($private.controller.dism.job.state -eq 'Running'){
			[System.Windows.Forms.Application]::DoEvents()  | out-null			
		}
		$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n`r`n$($private.controller.dism.getJobResults() -join "`r`n")`r`n")
		
		#now get rid of the wim folder because dism will still think its mounted
		$private.controller.dism.cleanupWim()
		
		
		$private.controller.view.toggleSplash($false)
		[gc]::collect()
	}
	
	method extractISO{
		$private.controller.view.toggleSplash($true,"Please Wait...","Extracting ISO")
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Extracting #yellow#$($private.controller.view.getControl('ISOWimControl','tab0txtIsoSelection').text)#")
		$archiveClass.Get().extractIso( $private.controller.view.getControl('ISOWimControl','tab0txtIsoSelection').text, "$($pwd)\wim\extracted\$($private.controller.models.isowimcontrol.selectedIsoFileName)\" )
		while( $archiveClass.Get().job.state -eq 'Running' ){
			[System.Windows.Forms.Application]::DoEvents()  | out-null
		}
		$private.controller.view.toggleSplash($false)
		[gc]::collect()
	}
	
	method discardISO{
		$private.controller.view.toggleSplash($true,"Please Wait...","Discarding ISO")
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Discarding #yellow#$($private.controller.view.getControl('ISOWimControl','tab0txtIsoSelection').text)#")
		
		$discardIsoJobSB = {
			param($cwd)
			remove-item $($cwd) -recurse -force 
		}
			
		$job = start-job -scriptBlock $discardIsoJobSB -ArgumentList @("$($pwd)\wim\extracted\$($private.controller.models.isowimcontrol.selectedIsoFileName)\")
		while( $job.state -eq 'Running' ){
			[System.Windows.Forms.Application]::DoEvents()  | out-null
		}

		$private.controller.view.toggleSplash($false)
		[gc]::collect()
	}
	
	
	method createIso{
		$private.controller.view.toggleSplash($true,"Please Wait...","Creating ISO")
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Creating updated ISO")
		$selIso = "$($private.controller.models.isowimcontrol.selectedIsoFileName)"
		$isoJobSB = {
			param($cwd, $selIso )
			set-location $cwd
			. "$($cwd)\lib\PSClass.ps1"
			. "$($cwd)\lib\iso.ps1"
			
			$iso = $isoClass.New("$($cwd)\results\windows_patched-$((get-date -format 'yyyyMMddHHmmss')).iso", 'DVDPLUSR_DUALLAYER', "WinPatched", $true)
			$iso.makeIso()
			gci "$($cwd)\wim\extracted\$($selIso)" | %{
				$d = get-item $($_.fullName)
				$iso.addSource($d)
			}
			$bootPath = (gci "$($cwd)\wim\extracted\$($selIso)" -recurse -include "etfsboot.com" | select -expand fullname)
			$iso.finalize($bootPath)
		}
		
		$job = start-job -scriptBlock $isoJobSB -ArgumentList @($pwd,$selIso)
		while( $job.state -eq 'Running' ){
			[System.Windows.Forms.Application]::DoEvents()  | out-null
		}
		$private.controller.view.toggleSplash($false)
		[gc]::collect()
	}
}

$imagePatcherModelUpdates = new-PSClass imagePatcherUpdates{
	note -private controller
	note -static tabTitle 'UpdateManagement'
	
	constructor{
		param($controller)
		$private.controller = $controller
		
		$tabControls = $guiClass.renderSubForm("$pwd\templates\tabUpdateManagement.xml") 
		$tabControls.keys | % {
			$private.controller.view.getTab("UpdateManagement").controls.add( $($tabControls.$_) ) | out-null
		}

		$private.controller.view.getControl('UpdateManagement','tab2btnRefreshUpdates').add_Click( { $private.controller.view.refreshTree('UpdateManagement','tab2treeUpdates', @('Package_for_','Microsoft-Windows-','~.*')) } )
		$private.controller.view.getControl('UpdateManagement','tab2btnOpenFolderBrowser').add_Click({ $private.controller.view.getControl('UpdateManagement','tab2TxtUpdatesPath').text = $private.controller.view.gui.actInvokeFolderBrowser() } )
		$private.controller.view.getControl('UpdateManagement','tab2btnAddUpdate').add_Click({
			if( $utilities.isBlank( ($private.controller.view.getControl('UpdateManagement','tab2btnAddUpdate').text) ) -eq $false ){
				$private.controller.models.Updates.addUpdates()
			}
		})
		
		$private.controller.view.getControl('UpdateManagement','tab2btnRemoveUpdate').add_Click({
			$private.controller.models.Updates.removeUpdate()
			$private.controller.view.refreshTree('UpdateManagement','tab2treeUpdates',@('Package_for_','Microsoft-Windows-','~.*'))
		})
		
		$private.controller.view.getTab('UpdateManagement').add_Enter({
			$private.controller.view.refreshTree('UpdateManagement','tab2treeUpdates',@('Package_for_','Microsoft-Windows-','~.*'))	
		})
	}
	
	method addUpdates{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request Add-Package")
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Executing DISM Request #yellow#/Add-Package#")
			$private.controller.dism.wimPath =  $private.controller.models.isowimcontrol.wimPath
			$private.controller.dism.addUpdates( ($private.controller.view.getControl('UpdateManagement','tab2TxtUpdatesPath').text) )
			$uiclass.writeColor("$($uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
			while($private.controller.dism.job.state -eq 'Running'){
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
			}
			$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n`r`n$($private.controller.dism.getJobResults() -join "`r`n")`r`n")
			
			$private.controller.view.refreshTree('UpdateManagement','tab2treeUpdates',@('Package_for_','Microsoft-Windows-','~.*'))	
			$private.controller.view.toggleSplash($false)
		}
	}

	#tried this with recursion like the drivers function, but it was slower than mud.  nested loops took this from hours to seconds.
	method removeUpdate{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request remove-package")
			
			#make the treeview local to this method
			$updateTreeView = $private.controller.view.getControl('UpdateManagement','tab2treeUpdates')
			foreach($rootNode in ( $updateTreeView.Nodes[0])){
				foreach($typeNode in ($rootNode.nodes)){
					foreach($statusNode in $($typeNode.nodes)){
						foreach($updateNode in $($statusNode.nodes)){
							if($($updateNode.checked) -eq $true){
								$uiclass.writeColor("$($uiclass.STAT_WAIT) Removing Windows Update #yellow#$($updateNode.tag)#")
								$private.controller.dism.removeUpdate( $($updateNode.tag) )
								$uiclass.writeColor("$($uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
								while($private.controller.dism.job.state -eq 'Running'){
									[System.Windows.Forms.Application]::DoEvents()  | out-null			
								}
								$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n`r`n$($private.controller.dism.getJobResults() -join "`r`n")`r`n")
							}
						}
					}
				}
			}
		}
	}
}

$imagePatcherModelDrivers = new-PSClass imagePatcherDrivers{
	note -private controller
	note -static tabTitle 'DriverManagement'

	constructor{
		param($controller)
		$private.controller = $controller
		
		$tabControls = $guiClass.renderSubForm("$pwd\templates\tabDriverManagement.xml")
		$tabControls.keys | % {
			if($tabControls.$_){
				$private.controller.view.getTab("DriverManagement").controls.add( $tabControls.$_ ) | out-null
			}
		}
		
		$private.controller.view.getControl('DriverManagement','tab1btnRefreshDrivers').add_Click({ $private.controller.view.refreshTree('DriverManagement','tab1treeDrivers') })
		$private.controller.view.getControl('DriverManagement','tab1btnOpenFolderBrowser').add_Click({ $private.controller.view.getControl('DriverManagement','tab1TxtDriverPath').text = $private.controller.view.gui.actInvokeFolderBrowser()})
		$private.controller.view.getControl('DriverManagement','tab1btnAddDriver').add_Click({
			if( $utilities.isBlank( ($private.controller.view.getControl('DriverManagement','tab1TxtDriverPath').text) ) -eq $false ){
				$private.controller.models.Drivers.addDrivers()
				$private.controller.view.refreshTree('DriverManagement','tab1treeDrivers')
			}
		})
		$private.controller.view.getControl('DriverManagement','tab1btnRemoveDriver').add_Click({
			$private.controller.models.Drivers.removeDriver()
			$private.controller.view.refreshTree('DriverManagement','tab1treeDrivers')
		})

		#this will occur when the tab is displayed....used to run the auto functions on render
		$private.controller.view.getTab('DriverManagement').add_Enter({
			$private.controller.view.refreshTree('DriverManagement','tab1treeDrivers')	
		})
		[gc]::collect()
	}

	method addDrivers{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.dism.wimPath = $private.controller.models.isowimcontrol.wimPath
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Adding Drivers #yellow#$($private.controller.view.getControl('DriverManagement','tab1TxtDriverPath').text)# to Wim")
			$private.controller.dism.addDrivers( ($private.controller.view.getControl('DriverManagement','tab1TxtDriverPath').text) )
			$uiclass.writeColor("$($uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request /add-driver")
			while($private.controller.dism.job.state -eq 'Running'){
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
			}
			$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n`r`n$($private.controller.dism.getJobResults() -join "`r`n")`r`n")
		}
	}
	
	method removeDriverRecursion{
		param($node)
		if($node.checked -eq $true -and $node.nodes.count -eq 0){
			$private.controller.dism.wimPath = $private.controller.models.isowimcontrol.wimPath
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Removing Drivers #yellow#$($node.tag)# From WIM")
			$private.controller.dism.removeDriver( $($node.tag) )
			$uiclass.writeColor("$($uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
			while($private.controller.dism.job.state -eq 'Running'){
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
			}
			$uiclass.writeColor("$($uiclass.STAT_OK) RESULTS:`r`n`r`n$($private.controller.dism.getJobResults() -join "`r`n")`r`n")
		}
		foreach($tn in $node.Nodes){
			$private.controller.models.Drivers.removeDriverRecursion($tn);
		}
	}

	
	method removeDriver{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request /remove-driver")
			foreach($node in ( $private.controller.view.getControl('DriverManagement','tab1treeDrivers').Nodes[0]) ){
				$private.controller.models.Drivers.removeDriverRecursion($node)
			}
		}
	}
	
	
}

$imagePatcherModelFilesystem = new-PSClass imagePatcherFilesystem{
	note -private controller
	note -static tabTitle 'FileSystemUpdates'
	
	note imagePath
	note sortCol 0
	note sortAsc $true 
	
	constructor{
		param($controller)
		$private.controller = $controller
		
		if((test-path "$pwd\bin\iconTools.dll") -eq $false){
			Add-Type -Language CSharpVersion3 -TypeDefinition ([System.IO.File]::ReadAllText("$pwd\types\iconTools.cs")) -ReferencedAssemblies @("System.Drawing","WindowsBase","System.Windows.Forms")  -ErrorAction Stop -OutputAssembly "$pwd\bin\iconTools.dll" -outputType Library
		}
		
		if (!("csts.iconTools" -as [type])) {
			Add-Type -path "$pwd\bin\iconTools.dll"
		}
		
		
		$tabControls = $guiClass.renderSubForm("$pwd\templates\tabFileSystemUpdates.xml")
		$tabControls.keys | % {
			$private.controller.view.getTab("FilesystemUpdates").controls.add( $($tabControls.$_) ) | out-null
		}
		
		$private.controller.view.getControl('FileSystemUpdates','tab8btnRefreshFS').add_Click({ $private.controller.models.FileSystem.refreshFS() })
		
		
		$treeContext = new-object "$forms.ContextMenu"
		$menuItemArray = @(
			@{"weight" = 1; "Name" = "New Folder"},
			@{"weight" = 2; "Name" = "Rename Folder";},
			@{"weight" = 3; "Name" = "Delete Folder";},
			@{"weight" = 4; "Name" = "Copy Folder From Host";}
		)
		
		foreach($menuArrayItem in ($menuItemArray | sort { $_.Weight} ) ){
			$menuItem = new-object "$forms.MenuItem"
			$menuitem.text = $menuArrayItem.Name
			$menuitem.add_click( { $private.controller.models.FileSystem.fsTreeContextMenuClick("$($this.text)") }) | out-null
			$treeContext.menuItems.Add($menuItem) | out-null
		}
		$private.controller.view.getControl('FileSystemUpdates','tab8treeFS').ContextMenu = $treeContext;
		
		
		$listContext = new-object "$forms.ContextMenu"
		$menuItemArray = @(
			@{"weight" = 1; "Name" = "Add File"},
			@{"weight" = 2; "Name" = "Rename File";},
			@{"weight" = 3; "Name" = "Delete File";}
		)
		
		foreach($menuArrayItem in ($menuItemArray | sort { $_.Weight} ) ){
			$menuItem = new-object "$forms.MenuItem"
			$menuitem.text = $menuArrayItem.Name
			$menuitem.add_click( { $private.controller.models.FileSystem.fsListContextMenuClick("$($this.text)") }) | out-null
			$listContext.menuItems.Add($menuItem) | out-null
		}
		$private.controller.view.getControl('FileSystemUpdates','tab8listFS').ContextMenu = $listContext;
		
		$private.controller.view.getControl('FileSystemUpdates','tab8listFS').add_ColumnClick({ 
			if($private.controller.models.Filesystem.sortCol -eq $this.column){
				$private.controller.models.Filesystem.sortAsc = (-not $private.controller.models.Filesystem.sortAsc)
			}else{
				$private.controller.models.Filesystem.sortAsc = $true
			}
			$private.controller.models.Filesystem.sortCol = $this.column
			
			$private.controller.view.SortListView( 
				$private.controller.view.getControl('FileSystemUpdates','tab8listFS'),
				$private.controller.models.Filesystem.sortCol,
				$private.controller.models.Filesystem.sortAsc
			) 
		})
		
		
		
		$private.controller.view.getControl('FileSystemUpdates','tab8treeFS').add_AfterSelect({ $private.controller.models.FileSystem.loadFSNodes( $_ ); $private.controller.models.FileSystem.loadFSItems( $_ );})
		
		$private.controller.view.getTab('FileSystemUpdates').add_Enter({
			$private.controller.models.FileSystem.refreshFS()
		})
		
		
	}
	
	method refreshFS{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.view.toggleSplash($true,"Please Wait...","Searching for Filesystem Folders")
			$private.controller.view.getControl('FileSystemUpdates', 'tab8treeFS').Nodes.clear()
			$private.controller.view.getControl('FileSystemUpdates', 'tab8listFS').Items.clear()
			
			$rootNode = New-Object "$forms.TreeNode"
			$rootNode.text = "My Windows Image"
			$rootNode.Name = "My Windows Image"
			$rootNode.Tag = "$($private.controller.models.isowimcontrol.wimpath)"
			$private.controller.view.getControl('FileSystemUpdates','tab8treeFS').Nodes.Add($rootNode) | Out-Null
			
			gci "$($private.controller.models.isowimcontrol.wimpath)" -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $true} | % {
				$newNode = New-Object "$forms.TreeNode"
				$newNode.text = $_.name
				$newNode.Name = $_.name
				$newNode.Tag = $_.fullName
				$private.controller.view.getControl('FileSystemUpdates','tab8treeFS').Nodes[0].Nodes.Add($newNode) | Out-Null
			}
			
			$private.controller.view.getControl('FileSystemUpdates','tab8treeFS').Nodes[0].Expand() | out-null
			$private.controller.view.toggleSplash($false)
		}
	}
	
	method loadFSItems{
		$i = 0
		$private.controller.view.getControl('FileSystemUpdates','tab8listFS').Items.Clear();
		
		$sha1 = New-Object -TypeName System.Security.Cryptography.SHA1CryptoServiceProvider
		$photoList = new-object system.windows.forms.ImageList
		gci $private.controller.models.Filesystem.imagePath -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $false} | % {
			$photoList.Images.Add(
				[csts.iconTools]::ExtractAssociatedIcon($_.fullName)
			);
		}
		$private.controller.view.getControl('FileSystemUpdates','tab8listFS').SmallImageList = $photoList
		
		
		gci $private.controller.models.Filesystem.imagePath -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $false} | % {
		
			$item =  New-Object "$forms.ListviewItem"( "$($_.Name)".Trim() )
			
			if($i % 2 -eq 0){
				$item.BackColor = '#FFFFFF'
			}else{
				$item.BackColor = '#F9F9F9'
			}
			
			$item.tag = $_.fullName
			$item.imageIndex  = $i
			$item.subitems.add($_.extension.toString().replace('.','').ToUpper())
			$item.subitems.add( "$([math]::round( $_.length / 1KB, 2) ) K" )
			$item.subitems.add($_.CreationTimeUtc.ToString())
			$item.subitems.add($_.LastAccessTimeUtc.ToString())
			$item.subitems.add($_.LastWriteTimeUtc.ToString())
			$item.subitems.add("$($_.versioninfo.fileVersion)")
			if($_.length -lt 1mb){
				$item.subitems.add( [System.BitConverter]::ToString($sha1.ComputeHash( [System.IO.File]::ReadAllBytes( $($_.fullname) ))))
			}else{
				$item.subitems.add( "" )
			}
			
			$private.controller.view.getControl('FileSystemUpdates','tab8listFS').Items.Add($item);
			$i++
		}
		$private.controller.view.getControl('FileSystemUpdates','tab8listFS').FullRowSelect  = $true
		$private.controller.view.getControl('FileSystemUpdates','tab8listFS').AutoResizeColumns('ColumnContent') | out-null
		
	}
	
	method loadFSNodes{
		param($node)
		if($node.Node.text -ne 'My Windows Image'){
			#load directories
			$node.Node.Nodes.clear()
			$private.controller.models.Filesystem.imagePath = $node.node.tag
			gci $node.Node.tag -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $true} | % {
				$newNode = New-Object "$forms.TreeNode"
				$newNode.text = $_.name
				$newNode.Name = $_.name
				$newNode.Tag = $_.fullName
				$node.Node.Nodes.Add($newNode) | Out-Null
				$node.Node.expand()
			}

		}
	}
		
	method FSTreeContextMenuClick{
		param($contextMenuItem)
		switch($contextMenuItem){
			"New Folder" 			{$private.controller.models.FileSystem.addFSFolder()}
			"Rename Folder" 		{$private.controller.models.FileSystem.renFSFolder()}
			"Delete Folder" 		{$private.controller.models.FileSystem.delFSFolder()}
			"Copy Folder From Host" {$private.controller.models.FileSystem.copyFSFolder()}
		}
	}
	
	method FSListContextMenuClick{
		param($contextMenuItem)
		switch($contextMenuItem){
			"Add File" 		{$private.controller.models.FileSystem.addFSFile()}
			"Rename File" 	{$private.controller.models.FileSystem.renFSFile()}
			"Delete File" 	{$private.controller.models.FileSystem.delFSFile()}
		}
	}
	
	method delFSFile{
		$selItem = ($private.controller.view.getControl('FileSystemUpdates','tab8listFS').selectedItems | select -first 1)
		if($selItem.tag -ne $null){
			if( $private.controller.view.gui.confirm("Are you sure you want to delete '$($selItem.subitems[0].text)'")  -eq 1){
				$uiclass.writeColor("$(# $uiclass.STAT_OK) Deleting File #yellow#$($selitem.tag.replace("$($private.controller.models.isowimcontrol.wimpath)",''))#")
				remove-item -path "$($selItem.tag)" 
			}
		}
		
		$private.controller.models.FileSystem.loadFSItems( );
		
	}
	
	method renFSFile{
		$selItem = ($private.controller.view.getControl('FileSystemUpdates','tab8listFS').selectedItems | select -first 1)

		if($selItem.tag -ne $null){
			$newFile = $private.controller.view.gui.input("Enter new file name", "Rename File","$($selItem.subitems[0].text)")
			$uiclass.writeColor("$(# $uiclass.STAT_OK) Renaming File #yellow#$($selitem.tag.replace("$($private.controller.models.isowimcontrol.wimpath)",''))# to #green#$($newFile)#")
			rename-item -path "$($selItem.tag)" "$($newFile)"
		}
		
		$private.controller.models.FileSystem.loadFSItems( );
	}
	
	method addFSFile{
		$selNode = ($private.controller.view.getControl('FileSystemUpdates','tab8treeFS').selectedNode)
		if($selNode -ne $null){
			$file = $private.controller.view.gui.actInvokeFileBrowser() 
			$uiclass.writeColor("$(# $uiclass.STAT_OK) Adding File #green#$($file)# to Folder #yellow#$($selnode.tag.replace("$($private.controller.models.isowimcontrol.wimpath)",''))#")
			if( (test-path $file) -eq $true){
				copy-item $file $selNode.tag -force
			}
			
			$private.controller.models.FileSystem.loadFSItems( );
		}
	}
	
	method delFSFolder{
		$selNode = ($private.controller.view.getControl('FileSystemUpdates','tab8treeFS').selectedNode)
		$parent = $selNode.parent
		
		if($utilities.isBlank($selNode) -eq $false -and $utilities.isBlank($selNode.parent) -eq $false){
			
			if($private.controller.view.gui.confirm("Are you sure you want to delete '$($selNode.text)'") -eq 1){
				$uiclass.writeColor("$(# $uiclass.STAT_OK) Deleting Folder #yellow#$($selnode.tag.replace("$($private.controller.models.isowimcontrol.wimpath)",''))#")
				remove-item -path "$($private.controller.view.getControl('FileSystemUpdates','tab8treeFS').selectedNode.tag)" -force -recurse
				$parent.Nodes.clear()
				gci $parent.tag -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $true} | % {
					$newNode = New-Object "$forms.TreeNode"
					$newNode.text = $_.name
					$newNode.Name = $_.name
					$newNode.Tag = $_.fullName
					$parent.Nodes.Add($newNode) | Out-Null
					$parent.expand() | out-null
				}
				$private.controller.models.Filesystem.imagePath = $parent.tag
				$private.controller.models.FileSystem.loadFSItems( );
			}
		}
	}
	
	method renFSFolder{
		$selNode = ($private.controller.view.getControl('FileSystemUpdates','tab8treeFS').selectedNode)
		$parent = $selNode.parent
		
		if($utilities.isBlank($selNode) -eq $false -and $utilities.isBlank($selNode.parent) -eq $false){
			$newFolder = $private.controller.view.gui.input("Enter new folder name", "Rename Folder","$($selnode.node.text)")
			$uiclass.writeColor("$(# $uiclass.STAT_OK) Renaming Folder #yellow#$($selnode.tag.replace("$($private.controller.models.isowimcontrol.wimpath)",''))# to #green#$($newFolder)#")
			rename-item -path "$($private.controller.view.getControl('FileSystemUpdates','tab8treeFS').selectedNode.tag)" "$($newFolder)"
			$parent.Nodes.clear()
			gci $parent.tag -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $true} | % {
				$newNode = New-Object "$forms.TreeNode"
				$newNode.text = $_.name
				$newNode.Name = $_.name
				$newNode.Tag = $_.fullName
				$parent.Nodes.Add($newNode) | Out-Null
				$parent.expand() | out-null
			}
		}
		
		$private.controller.models.Filesystem.imagePath = $parent.tag
		$private.controller.models.FileSystem.loadFSItems( );
	}
	
	
	method addFSFolder{
		$selNode = ($private.controller.view.getControl('FileSystemUpdates','tab8treeFS').selectedNode)
		if($selNode -ne $null){
			$newFolder = $private.controller.view.gui.input("Enter new folder name", "New Folder","")
			
			$uiclass.writeColor("$(# $uiclass.STAT_OK) Adding Folder #green#$($newFolder)# to Directory #yellow#$($selnode.tag.replace("$($private.controller.models.isowimcontrol.wimpath)",''))#")
			
			new-item -type directory -path "$($private.controller.view.getControl('FileSystemUpdates','tab8treeFS').selectedNode.tag)\$($newFolder)"
			$selNode.Nodes.clear()
			gci $selNode.tag -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $true} | % {

				$newNode = New-Object "$forms.TreeNode"
				$newNode.text = $_.name
				$newNode.Name = $_.name
				$newNode.Tag = $_.fullName
				$selNode.Nodes.Add($newNode) | Out-Null
				$selNode.expand() | out-null
			}
		}
	}
	
	method copyFSFolder{
		$selNode = ($private.controller.view.getControl('FileSystemUpdates','tab8treeFS').selectedNode)
		if($selNode -ne $null){
		
		
			$sourceFolder = $private.controller.view.gui.actInvokeFolderBrowser()
		
			
			
			$uiclass.writeColor("$(# $uiclass.STAT_OK) Copying Folder #green#$($sourceFolder)# to Directory #yellow#$($selnode.tag.replace("$($private.controller.models.isowimcontrol.wimpath)",''))#")
			
			copy-item -literalPath $sourceFolder -destination "$($private.controller.view.getControl('FileSystemUpdates','tab8treeFS').selectedNode.tag)" -recurse -force
			
			
			
			
			$selNode.Nodes.clear()
			gci $selNode.tag -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $true} | % {

				$newNode = New-Object "$forms.TreeNode"
				$newNode.text = $_.name
				$newNode.Name = $_.name
				$newNode.Tag = $_.fullName
				$selNode.Nodes.Add($newNode) | Out-Null
				$selNode.expand() | out-null
			}
		}
	}
}

$imagePatcherModelRegistry = new-PSClass imagePatcherRegistry{
	note -private controller
	note -static tabTitle 'RegistryUpdates'
	
	note registryKey
	note registryName
	
	note sortCol 0
	note sortAsc $true
	
	constructor{
		param($controller)
		$private.controller = $controller
		
		$tabControls = $guiClass.renderSubForm("$pwd\templates\tabRegistryUpdates.xml")
		$tabControls.keys | % {
			$private.controller.view.getTab("RegistryUpdates").controls.add( $($tabControls.$_) ) | out-null
		}
		
		$private.controller.view.getControl('RegistryUpdates','tab7btnRefreshReg').add_Click({ $private.controller.models.Registry.addRegistryRootNodes() })
		$private.controller.view.getControl('RegistryUpdates','tab7btnRegUnmount').add_Click({ $private.controller.models.Registry.unmountRegistry() })
		$private.controller.view.getTab("RegistryUpdates").add_leave( { $private.controller.models.Registry.unmountRegistry() } )
		
		$private.controller.view.getControl('RegistryUpdates','tab7treeReg').add_AfterSelect({
			$private.controller.models.Registry.registryKey = $_.node.tag;
			$private.controller.models.Registry.loadRegTreeNodes($_.node)
		})
		
		$private.controller.view.getControl('RegistryUpdates','tab7listReg').add_ItemSelectionChanged({
			if($_.item){
				$private.controller.models.Registry.registryName = $($_.item.subitems[1].text)
			}
		})
		
		#Node tree Context Menu
		$treeContext = new-object "$forms.ContextMenu"
		$menuItemArray = @(
			@{"weight" = 1; "Name" = "New Key"},
			@{"weight" = 2; "Name" = "Rename Key";},
			@{"weight" = 3; "Name" = "Delete Key";}
		)
		
		foreach($menuArrayItem in ($menuItemArray | sort { $_.Weight} ) ){
			$menuItem = new-object "$forms.MenuItem"
			$menuitem.text = $menuArrayItem.Name
			$menuitem.add_click( { $private.controller.models.Registry.regTreeContextMenuClick("$($this.text)") }) | out-null
			$treeContext.menuItems.Add($menuItem) | out-null
		}
		$private.controller.view.getControl('RegistryUpdates','tab7treeReg').ContextMenu = $treeContext;
		
		
		#Node List Context Menu
		$context = new-object "$forms.ContextMenu"
		$menuItemArray = @(
			@{"weight" = 1; "Name" = "New Value"; "Value" = @(
					@{"weight" = 1;"Name" = "String"; "Value" = $null;},
					@{"weight" = 2;"Name" = "Binary"; "Value" = $null;},
					@{"weight" = 3;"Name" = "DWord"; "Value" = $null;},
					@{"weight" = 4;"Name" = "QWord"; "Value" = $null;}
				)
			},
			@{"weight" = 2; "Name" = "Rename Item"; "Value" = $null},
			@{"weight" = 3; "Name" = "Edit Item"; "Value" = $null},
			@{"weight" = 4; "Name" = "Delete Item"; "Value" = $null}
		)
		
		foreach($menuArrayItem in ($menuItemArray | sort { $_.Weight} ) ){
			$menuItem = new-object "$forms.MenuItem"
			$menuitem.text = $menuArrayItem.Name
			
			if($menuArrayItem.Value -eq $null){
				$menuitem.add_click( { $private.controller.models.Registry.regListContextMenuClick("$($this.text)") }) | out-null
			}else{
				foreach($subMenuArrayItem in ($menuArrayItem.Value | sort { $_.weight } ) ){
					if($subMenuArrayItem.Value -eq $null){
						$subMenuItem = new-object "$forms.MenuItem"
						$subMenuItem.text = $subMenuArrayItem.Name
						$subMenuItem.add_click( { $private.controller.models.Registry.regListContextMenuClick("$($this.text)") }) | out-null
					}
					$menuItem.menuItems.add($subMenuItem) | out-null
				}
			}
			$context.menuItems.Add($menuItem) | out-null
		}
		$private.controller.view.getControl('RegistryUpdates','tab7listReg').ContextMenu = $context;
		
		$private.controller.view.getControl('RegistryUpdates','tab7listReg').add_ColumnClick({ 
			if($private.controller.models.Registry.sortCol -eq $this.column){
				$private.controller.models.Registry.sortAsc = (-not $private.controller.models.Registry.sortAsc)
			}else{
				$private.controller.models.Registry.sortAsc = $true
			}
			$private.controller.models.Registry.sortCol = $this.column
			
			$private.controller.view.SortListView( 
				$private.controller.view.getControl('RegistryUpdates','tab7listReg'),
				$private.controller.models.Registry.sortCol,
				$private.controller.models.Registry.sortAsc
			) 
		})
		
		
			
			
			
		
		#this will occur when the tab is displayed....used to run the auto functions on render
		$private.controller.view.getTab('RegistryUpdates').add_Enter({
			$private.controller.models.Registry.addRegistryRootNodes()
		})
		[gc]::collect()
	}
	
	method regTreeContextMenuClick{
		param($contextMenuItem)
		switch($contextMenuItem){
			"New Key" 		{$private.controller.models.Registry.addRegKey()}
			"Rename Key" 	{$private.controller.models.Registry.renRegKey()}
			"Delete Key" 	{$private.controller.models.Registry.delRegKey()}
		}
	}
	
	method regListContextMenuClick{
		param($contextMenuItem)
		switch($contextMenuItem){
			{'String','Binary','DWord','QWord' -contains $_ } {
				$private.controller.models.Registry.addRegVal( $($private.controller.view.gui.Input('Enter the Registry Item Name','Add Registry Item')),[imagePatcher.registryTypes]::$contextMenuItem);
			}
			"Rename Item" 	{ $private.controller.models.Registry.renRegVal( 	$($private.controller.view.gui.Input("Enter the new Registry Item Name",'Rename Registry Item')))}
			"Edit Item" 	{ $private.controller.models.Registry.editRegVal(  	$($private.controller.view.gui.Input('Enter the Registry Item Value','Edit Registry Item')) );}
			"Delete Item" 	{
				if( 
					$(
						$private.controller.view.gui.Confirm("Are you sure you want to delete '$($private.controller.models.Registry.registryName)'")
					)
				){ 
					$private.controller.models.Registry.delRegVal(); 
				}
			}
		}
		$private.controller.models.Registry.loadRegListNodes()
	}
	
	method addRegVal{
		param($regName, $propType)
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Editing Registry Node #yellow#$($private.controller.models.Registry.registryKey.replace("$($private.controller.models.isowimcontrol.selectedIsoFileName)-",''))#")
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Adding Value #yellow#$($regName)#")
		new-itemProperty -path $($private.controller.models.Registry.registryKey) -name $regName -value $null -propertyType $propType
	}
	
	method editRegVal{
		param($regVal)
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Editing Registry Node #yellow#$($private.controller.models.Registry.registryKey.replace("$($private.controller.models.isowimcontrol.selectedIsoFileName)-",''))#")
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Setting Value #yellow#$($private.controller.models.Registry.registryName)# to #green#$($regVal)#")
		set-itemProperty -path $($private.controller.models.Registry.registryKey) -name $($private.controller.models.Registry.registryName) -value $regVal
	}
	
	method delRegVal{
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Deleting Value #yellow#$($private.controller.models.Registry.registryName)#")
		remove-itemProperty -path $($private.controller.models.Registry.registryKey) -name $private.controller.models.Registry.registryName
	}
	
	method renRegVal{
		param($newRegName)
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Editing Registry Node #yellow#$($private.controller.models.Registry.registryKey.replace("$($private.controller.models.isowimcontrol.selectedIsoFileName)-",''))#")
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Renaming Value #yellow#$($private.controller.models.Registry.registryName)# to #green#$($newRegName)#")
		rename-itemProperty -path $($private.controller.models.Registry.registryKey) -name $private.controller.models.Registry.registryName -newName $newRegName
	}
	
	method addRegistryRootNodes{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.view.getControl('RegistryUpdates', 'tab7listReg').items.clear()
			$private.controller.view.getControl('RegistryUpdates', 'tab7treeReg').Nodes.clear()
			#text,name,teg
			$rootNode = $private.controller.view.quickNode('My Windows Image Registry')
			$hklmNode = $private.controller.view.quickNode('HKLM')
			$hkcuNode = $private.controller.view.quickNode('HKCU')
			$rootNode.nodes.add($hklmNode)
			$rootNode.nodes.add($hkcuNode)
			$rootNode.expand()
			$private.controller.view.getControl('RegistryUpdates','tab7treeReg').Nodes.Add($rootNode) | Out-Null
		}
	}
	
	method addRegKey{
		$keyName = $private.controller.view.gui.Input("Enter a Registry Key Name", "New Registry Key", "") 
		
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Adding Registry Node #green#$($keyName)# to Registry Node #yellow#$($private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode.tag.replace("$($private.controller.models.isowimcontrol.selectedIsoFileName)-",''))#")
		
		new-item -path $($private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode.tag) -name $keyName 
		$private.controller.models.Registry.loadRegTreeNodes($private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode)
	}
	
	method renRegKey{
		$keyName = $private.controller.view.gui.Input("Enter a new Registry Key Name", "Rename Registry Key", "") 
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Renaming Registry Node from #yellow#$($private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode.tag.replace("$($private.controller.models.isowimcontrol.selectedIsoFileName)-",''))# to #green#$($keyName)#")
		rename-item -path $($private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode.tag) -newName $keyName 
		
		$private.controller.models.Registry.loadRegTreeNodes($private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode.parent)
		
	}
	
	method delRegKey{
		if ( $private.controller.view.gui.Confirm("Are you sure you want to delete '$($private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode.Text)'") -eq 1){
			$parentKey = $private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode.parent
			$uiclass.writeColor("$(# $uiclass.STAT_OK) Deleting Registry Node #yellow#$($private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode.tag.replace("$($private.controller.models.isowimcontrol.selectedIsoFileName)-",''))#")
			remove-item -path $($private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode.tag)
			$private.controller.models.Registry.loadRegTreeNodes( $parentKey )
		}
	}
	
	method refresh{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$uiclass.writeColor("$(# $uiclass.STAT_OK) Refreshing Registry Hives")
			
			$private.controller.view.toggleSplash($true,"Please Wait...","Searching for Registry Hives")
			[System.Windows.Forms.Application]::DoEvents()  | out-null
	
			$regPath = "$($private.controller.models.isowimcontrol.wimpath)\Windows\System32\config\"
			gci $regPath -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $false -and $utilities.isBlank($_.extension) -eq $true } |  % {
				[System.Windows.Forms.Application]::DoEvents()  | out-null
				$newNode = New-Object "$forms.TreeNode"
				$newNode.text = $_.name
				$newNode.Name = "HIVE:$($_.name)"
				$newNode.Tag = $_.fullname
				$private.controller.view.getControl('RegistryUpdates','tab7treeReg').Nodes[0].nodes['HKLM'].nodes.Add($newNode) | Out-Null
				# $hklmNode.Nodes.Add($newNode) | Out-Null
			}
			
			$regPath = "$($private.controller.models.isowimcontrol.wimpath)\users\default\"
			gci $regPath -force -errorAction silentlyContinue | ? { $_.PSIsContainer -eq $false -and$_.extension -eq '.DAT' } |  % {
				[System.Windows.Forms.Application]::DoEvents()  | out-null
				$newNode = New-Object "$forms.TreeNode"
				$newNode.text = $_.name
				$newNode.Name = "HIVE:$($_.name)"
				$newNode.Tag = $_.fullname
				$private.controller.view.getControl('RegistryUpdates','tab7treeReg').Nodes[0].nodes['HKCU'].nodes.Add($newNode) | Out-Null
				# $hkcuNode.Nodes.Add($newNode) | Out-Null
			}
			
			$private.controller.view.getControl('RegistryUpdates','tab7treeReg').Nodes[0].nodes['HKLM'].expand()
			$private.controller.view.getControl('RegistryUpdates','tab7treeReg').Nodes[0].nodes['HKCU'].expand()
			$private.controller.view.toggleSplash($false)
		}
	}
	
	method unmountRegistry{
		$uiclass.writeColor("$(# $uiclass.STAT_OK) Unmounting Registry Hives")
		#done in two steps so that the loop isn't locking the nodes open.  REG.EXE needs to file handles to be closed.
		$nodes = @()
		gci hklm:\ -erroraction silentlyContinue | ? { $_.name -like "*$($private.controller.models.isowimcontrol.selectedIsoFileName)*"} | select -expand Name | %{
			$nodes += $_
		}
		
		$nodes | % {
			[gc]::collect()
			reg.exe unload "$($_)"
		}
		$private.controller.models.Registry.addRegistryRootNodes()
	}
	
	method mountRegistry{
		param($text,$tag)
		if((test-path "hklm:\$($private.controller.models.isowimcontrol.selectedIsoFileName)-$($node.Text)" ) -eq $false){
			invoke-expression "reg.exe load 'hklm\$($private.controller.models.isowimcontrol.selectedIsoFileName)-$($text)' '$($tag)'"
		}
				
		
	}
	
	#this handles actual nodes and can be called programmatically
	method loadRegTreeNodes{
		param($node)
		
		if($node.text -ne $node.name){
			$node.nodes.clear()
			#see if the clicked node is a hive.  if so, load it
			if( $($node.name) -like "HIVE:*"){
				$private.controller.models.Registry.mountRegistry($node.text, $node.tag)
				foreach($regNode in (gci "hklm:\$($private.controller.models.isowimcontrol.selectedIsoFileName)-$($node.Text)" -errorAction silentlyContinue)){
					$newNode = New-Object "$forms.TreeNode"
					$newNode.text = $regNode.Name.replace("HKEY_LOCAL_MACHINE\$($private.controller.models.isowimcontrol.selectedIsoFileName)-$($node.Text)\",'')
					$newNode.Name = "KEY:$($regNode.name)"
					$newNode.Tag = $regNode.name.replace('HKEY_LOCAL_MACHINE\','hklm:\')
					$node.Nodes.Add($newNode) | Out-Null
				}
			}else{
				#get subnodes
				foreach($regNode in (gci "$($node.tag)" -errorAction silentlyContinue)){
					$newNode = New-Object "$forms.TreeNode"
					$newNode.text = $($regNode.name.substring($regNode.name.lastIndexOf("\")+1))
					$newNode.Name = "KEY:$($regNode.name)"
					$newNode.Tag = "$($node.tag)\$($regNode.name.substring($regNode.name.lastIndexOf("\")+1))"
					$node.Nodes.Add($newNode) | Out-Null
				}
			}
			
			$private.controller.models.Registry.loadRegListNodes($node)
			$node.expand()
		}else{
			#these are the hklm and hkcu nodes
			$private.controller.models.Registry.refresh()
		}
	}
	
	method loadRegListNodes{
		param($node = $null)
		if($node -eq $null){
			$node = $private.controller.view.getControl('RegistryUpdates','tab7treeReg').selectedNode
		}
		
		#get Values
		$private.controller.view.getControl('RegistryUpdates','tab7listReg').Items.Clear()
		$i=0

		if($node.tag.substring(0,4) -eq 'hklm' -or $node.tag.substring(0,4) -eq 'hkcu'){
			$key = Get-Item "$($node.tag)\"
			if($utilities.isBlank($key) -eq $false){
				$Property = @{Name = 'Property'; Expression = {$_}}
				$Value = @{Name = 'Value'; Expression = { if( $($_) -eq '(default)'){ $key.GetValue('') }else{ $key.GetValue($_) } } }
				$ValueType = @{Name = 'ValueType'; Expression = { if( $($_) -eq '(default)'){ $key.GetValueKind('') }else{ $key.GetValueKind($_) } } }
				
				$key.Property | sort | select $Property, $Value, $ValueType | % {
					$i++
					$item =  New-Object "$forms.ListviewItem"( $i )
					if($i % 2 -eq 0){
						$item.BackColor = '#FFFFFF'
					}else{
						$item.BackColor = '#F9F9F9'
					}
			
			
					$item.tag = $_
					$item.SubItems.Add( "$($_.Property)".Trim() ) | out-null
					$item.SubItems.Add( "$($_.ValueType)".Trim() ) | out-null
					$text = $_.value
					switch("$($_.ValueType)".Trim()){
						"DWord" { $item.SubItems.Add( "0x$( '{0:x8}' -f $text) ($($text))" ) | out-null }
						"QWord" { $item.SubItems.Add( "0x$( '{0:x16}' -f $text) ($($text))" ) | out-null }
						"Binary" { $item.SubItems.Add( "$($text)".Trim() ) | out-null }
						"String" { $item.SubItems.Add( "$($text)".Trim() ) | out-null }
					}
					
					$private.controller.view.getControl('RegistryUpdates','tab7listReg').Items.Add($item);
				}
			}
			if( $private.controller.view.getControl('RegistryUpdates','tab7listReg').Items.count -eq 0){
				$item =  New-Object "$forms.ListviewItem"( $i )
				$item.tag = $_
				$item.SubItems.Add( "(Default)" ) | out-null
				$item.SubItems.Add( "REG_SZ" ) | out-null
				$item.SubItems.Add( "(value not set)" ) | out-null
				
				$private.controller.view.getControl('RegistryUpdates','tab7listReg').Items.Add($item);
			}
		
		}
		$private.controller.view.getControl('RegistryUpdates','tab7listReg').FullRowSelect  = $true
		$private.controller.view.getControl('RegistryUpdates','tab7listReg').AutoResizeColumns('ColumnContent') | out-null
		
	}

}

$imagePatcherModelFeatures = new-PSClass imagePatcherFeatures{
	note -private controller
	note -static tabTitle 'FeatureUpdates'
	
	note registryKey
	
	note features @("CorporationHelpCustomization", "IIS-HostableWebCore", "IIS-WebServerRole", "IIS-WebServerRole\IIS-FTPServer", "IIS-WebServerRole\IIS-FTPServer\IIS-FTPExtensibility", "IIS-WebServerRole\IIS-FTPServer\IIS-FTPSvc", "IIS-WebServerRole\IIS-FTPServer\IIS-FTPSvc\IIS-FTPExtensibility", "IIS-WebServerRole\IIS-WebServer", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-ASP", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-ASPNET", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-CGI", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-ISAPIExtensions", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-ISAPIExtensions\IIS-ASP", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-ISAPIExtensions\IIS-ASPNET", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-ISAPIExtensions\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-ISAPIFilter", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-ISAPIFilter\IIS-ASPNET", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-NetFxExtensibility", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-NetFxExtensibility\IIS-ASPNET", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-NetFxExtensibility\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-NetFxExtensibility\WCF-HTTP-Activation", "IIS-WebServerRole\IIS-WebServer\IIS-ApplicationDevelopment\IIS-ServerSideIncludes", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-DefaultDocument", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-DefaultDocument\IIS-ASPNET", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-DefaultDocument\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-DirectoryBrowsing", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-DirectoryBrowsing\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-HttpErrors", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-HttpErrors\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-HttpRedirect", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-HttpRedirect\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-StaticContent", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-StaticContent\IIS-WebDAV", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-StaticContent\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-CommonHttpFeatures\IIS-WebDAV", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-CustomLogging", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-HttpLogging", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-HttpLogging\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-HttpTracing", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-HttpTracing\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-LoggingLibraries", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-LoggingLibraries\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-ODBCLogging", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-RequestMonitor", "IIS-WebServerRole\IIS-WebServer\IIS-HealthAndDiagnostics\IIS-RequestMonitor\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-Performance", "IIS-WebServerRole\IIS-WebServer\IIS-Performance\IIS-HttpCompressionDynamic", "IIS-WebServerRole\IIS-WebServer\IIS-Performance\IIS-HttpCompressionStatic", "IIS-WebServerRole\IIS-WebServer\IIS-Performance\IIS-HttpCompressionStatic\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-Security", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-BasicAuthentication", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-ClientCertificateMappingAuthentication", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-DigestAuthentication", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-IISCertificateMappingAuthentication", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-IPSecurity", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-RequestFiltering", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-RequestFiltering\IIS-ASP", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-RequestFiltering\IIS-NetFxExtensibility", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-RequestFiltering\IIS-NetFxExtensibility\IIS-ASPNET", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-RequestFiltering\IIS-NetFxExtensibility\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-RequestFiltering\IIS-NetFxExtensibility\WCF-HTTP-Activation", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-URLAuthorization", "IIS-WebServerRole\IIS-WebServer\IIS-Security\IIS-WindowsAuthentication", "IIS-WebServerRole\IIS-WebServerManagementTools", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-IIS6ManagementCompatibility", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-IIS6ManagementCompatibility\IIS-LegacyScripts", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-IIS6ManagementCompatibility\IIS-LegacySnapIn", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-IIS6ManagementCompatibility\IIS-Metabase", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-IIS6ManagementCompatibility\IIS-Metabase\IIS-LegacyScripts", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-IIS6ManagementCompatibility\IIS-Metabase\IIS-LegacySnapIn", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-IIS6ManagementCompatibility\IIS-Metabase\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-IIS6ManagementCompatibility\IIS-WMICompatibility", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-IIS6ManagementCompatibility\IIS-WMICompatibility\IIS-LegacyScripts", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-ManagementConsole", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-ManagementConsole\MSMQ-HTTP", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-ManagementScriptingTools", "IIS-WebServerRole\IIS-WebServerManagementTools\IIS-ManagementService", "InboxGames", "InboxGames\Chess", "InboxGames\FreeCell", "InboxGames\Hearts", "InboxGames\Internet Games", "InboxGames\Internet Games\Internet Backgammon", "InboxGames\Internet Games\Internet Checkers", "InboxGames\Internet Games\Internet Spades", "InboxGames\Minesweeper", "InboxGames\More Games", "InboxGames\PurblePlace", "InboxGames\Shanghai", "InboxGames\Solitaire", "InboxGames\SpiderSolitaire", "Indexing-Service-Package", "Internet-Explorer-Optional-<architecture>, where<architecture> can be x86, amd64, or ia64.", "Example: Internet-Explorer-Optional-amd64", "MediaPlayback", "MediaPlayback\MediaCenter", "MediaPlayback\OpticalMediaDisc", "MediaPlayback\WindowsMediaPlayer", "MediaPlayback\WindowsMediaPlayer\MediaCenter", "MSMQ-Container", "MSMQ-Container\MSMQ-DCOMProxy", "MSMQ-Container\MSMQ-Server", "MSMQ-Container\MSMQ-Server\MSMQ-ADIntegration", "MSMQ-Container\MSMQ-Server\MSMQ-HTTP", "MSMQ-Container\MSMQ-Server\MSMQ-Multicast", "MSMQ-Container\MSMQ-Server\MSMQ-Triggers", "MSRDC-Infrastructure", "NetFx3", "NetFx3\WCF-HTTP-Activation", "NetFx3\WCF-NonHTTP-Activation", "OEMHelpCustomization", "Printing-Foundation-Features", "Printing-Foundation-Features\ FaxServicesClientPackage", "Printing-Foundation-Features\Printing-Foundation-InternetPrinting-Client", "Printing-Foundation-Features\Printing-Foundation-LPDPrintService", "Printing-Foundation-Features\Printing-Foundation-LPRPortMonitor", "Printing-Foundation-Features\ScanManagementConsole", "Printing-XPSServices-Features", "RasCMAK", "RasRip", "SearchEngine-Client-Package", "ServicesForNFS-ClientOnly", "ServicesForNFS-ClientOnly\ClientForNFS-Infrastructure", "ServicesForNFS-ClientOnly\NFS-Administration", "SimpleTCP", "SNMP", "SNMP\WMISnmpProvider", "SUA", "TabletPCOC", "TelnetClient", "TelnetServer", "TFTP", "TIFFIFilter", "WAS-WindowsActivationService", "WAS-WindowsActivationService\WAS-ConfigurationAPI", "WAS-WindowsActivationService\WAS-ConfigurationAPI\WCF-HTTP-Activation", "WAS-WindowsActivationService\WAS-ConfigurationAPI\WCF-NonHTTP-Activation", "WAS-WindowsActivationService\WAS-NetFxEnvironment", "WAS-WindowsActivationService\WAS-NetFxEnvironment\WCF-HTTP-Activation", "WAS-WindowsActivationService\WAS-NetFxEnvironment\WCF-NonHTTP-Activation", "WAS-WindowsActivationService\WAS-ProcessModel", "WCF-NonHTTP-Activation", "WAS-WindowsActivationService\WAS-ProcessModel", "WAS-WindowsActivationService\WAS-ProcessModel\WCF-HTTP-Activation", "WAS-WindowsActivationService\WAS-ProcessModel\WCF-NonHTTP-Activation", "WindowsGadgetPlatform", "Xps-Foundation-Xps-Viewer")
	
	constructor{
		param($controller)
		$private.controller = $controller
		
		$tabControls = $guiClass.renderSubForm("$pwd\templates\tabFeatureManagement.xml")
		$tabControls.keys | % {
			if($tabControls.$_){
				$private.controller.view.getTab("FeatureManagement").controls.add( $tabControls.$_ ) | out-null
			}
		}
				
		$private.controller.view.getControl('FeatureManagement','tab3btnRefreshFeatures').add_Click( { $private.controller.models.Features.refreshFeatures() } )
		$private.controller.view.getControl('FeatureManagement','tab3btnUpdateFeatures').add_Click( { $private.controller.models.Features.updateFeatures() } )
		
		#this will occur when the tab is displayed....used to run the auto functions on render
		$private.controller.view.getTab('FeatureManagement').add_Enter({
			$private.controller.models.Features.refreshFeatures()
		})
		[gc]::collect()
	}
	
	method refreshFeatures{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request /get-features")
			
			$uiclass.writeColor("$(# $uiclass.STAT_WAIT) Executing DISM Request #yellow#/get-features#")
			$private.controller.dism.wimPath = $private.controller.models.isowimcontrol.wimpath
			$private.controller.dism.getFeatures()
			$uiclass.writeColor("$(# $uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
			while($private.controller.dism.job.state -eq 'Running'){
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
			}
			
			$uiclass.writeColor("$(# $uiclass.STAT_WAIT) Parsing DISM Results")
			$private.controller.view.toggleSplash($true,"Please Wait...","Parsing DISM Results")
			
			$results = ($private.controller.dism.parseResults( 'Features' ) ).results
				
			$private.controller.view.getControl('FeatureManagement','tab3treeFeatures').Nodes.clear()
			$private.controller.view.getControl('FeatureManagement','tab3treeFeatures').add_AfterCheck({  $private.controller.view.checkAll( $($_.Node) ) })	
			
			$rootNode = New-Object "$forms.TreeNode"
			$rootNode.text = "Features"
			$rootNode.Name = "Features"
			$rootNode.Tag = "root"
			
			$private.controller.view.getControl('FeatureManagement','tab3treeFeatures').Nodes.Add($rootNode) | Out-Null
			$private.controller.view.getControl('FeatureManagement','tab3treeFeatures').nodes[0].Expand() | out-null
			
			foreach($res in $results){
				[System.Windows.Forms.Application]::DoEvents()  | out-null
				$tag = $res.'Feature Name'
				$path = $($private.controller.models.features.features | ? { $_ -like "*$($res.'Feature Name')" } | select -first 1)
				$private.controller.models.Features.addFeatureNode($private.controller.view.getControl('FeatureManagement','tab3treeFeatures').nodes[0].nodes, $path, $res.state)
			}	
			$private.controller.view.getControl('FeatureManagement','tab3treeFeatures').nodes[0].Expand() | Out-Null
			
			$private.controller.view.toggleSplash($false)
		}
	}
	
	method addFeatureNode{
		param($nodeList, $path, $state)
		
		$folder = '';

		$p = $path.IndexOf('\');
		if( $p -eq -1 ){
			$folder = $path;
			$path = "";
		}else{
			$folder = $path.Substring(0,$p);
			$path = $path.Substring($p+1,$path.Length-($p+1));
		}
		$node = $null;

		foreach ($item in $nodeList){
			if($item.Text -eq $folder){
				$node = $item;
			}
		}

		if ($node -eq $null){
			$node = New-Object "$forms.TreeNode"
			$node.name = $folder
			$node.tag = $path
			$node.text = $folder
			if($state -eq 'Enabled'){
				$node.checked = $true
			}
			$nodeList.Add($node);
		}

		if ($path -ne ''){
			$private.controller.models.Features.addFeatureNode($node.Nodes, $path, $state);
		}
	}
	
	method execFeatureUpdate{
		param($node)
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.dism.wimPath = $private.controller.models.isowimcontrol.wimpath
			$node.Nodes | %{
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
				$uiclass.writeColor("$(# $uiclass.STAT_WAIT) Setting Feature #yellow#$($_.text)# to #green#$($_.checked)#")
				$private.controller.dism.updateFeature( $($_.text), $($_.checked))
				$uiclass.writeColor("$(# $uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
				while($private.controller.dism.job.state -eq 'Running'){
					[System.Windows.Forms.Application]::DoEvents()  | out-null			
				}
				$uiclass.writeColor("$(# $uiclass.STAT_OK) RESULTS:`r`n`r`n$($private.controller.dism.getJobResults() -join "`r`n")`r`n")
				$private.controller.models.Features.execFeatureUpdate($_)
			}
		}
	}
	
	#using recursion because there are multiple levels in the treeview
	method updateFeatures{
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request updateFeature")
			foreach($node in ( $private.controller.view.getControl('FeatureManagement','tab3treeFeatures').Nodes[0]) ){
				$private.controller.models.Features.execFeatureUpdate($node)
			}
			$private.controller.view.toggleSplash($false)
		}
	}
	
}

$imagePatcherView = new-PSClass imagePatcherView{
	note -private gui #main gui object
	note -private controller #in case i need to reach back to the controller for data
	property gui -get {return $private.gui}
	constructor{
		param($controller)
		$private.controller = $controller
		
		$private.gui = $null
		$private.gui = $guiClass.New("imagePatcher.xml")
		$private.gui.generateForm() | out-null;
		$this.toggleSplash($false) | out-null
		[gc]::collect()
	}

	method render{
		$private.gui.Form.ShowDialog() | Out-Null
	}
	
	method getTab{
		param(
			[string]$tab = ""
		)
		return ($private.gui.Controls.tabControl.tabPages | ? { ($_.Text.ToString() -replace '[^a-zA-Z0-9]','') -eq "$($tab)"} | select -first 1 )
	}
	
	method getControl{
		param(
			[string]$tab = '',
			[string]$control = ''
		)
		return ( $this.getTab($tab).controls | ? { $_.Name -eq $($control) } | select -first 1 )
	}
	
	method checkAll{
		param($selectedNode)
		foreach($node in $selectedNode.Nodes){
			$node.checked = $selectedNode.checked
			$this.checkAll($node);
		}
	}
	
	method toggleSplash{
		param(
			[bool]$show = $false,
			[string]$msg = "Loading... Please Wait.",
			[string]$msg2 = ""
		)
		
		$private.gui.controls.splashTxt.Parent = $private.gui.controls.splash
		$private.gui.controls.splashTxt.BackColor = 'Transparent'
		$private.gui.controls.splashTxt.Text = $msg
		
		$private.gui.controls.splashTxt2.Parent = $private.gui.controls.splash
		$private.gui.controls.splashTxt2.BackColor = 'Transparent'
		$private.gui.controls.splashTxt2.Text = $msg2
		
		if($show){
			$private.gui.controls.splash.BringToFront()
			$private.gui.controls.splashTxt.BringToFront()
			$private.gui.controls.splashTxt2.BringToFront()
			[System.Windows.Forms.Application]::DoEvents()  | out-null
		}else{
			$private.gui.controls.splash.SendToBack()
			$private.gui.controls.splashTxt.SendToBack()
			$private.gui.controls.splashTxt2.SendToBack()
			[System.Windows.Forms.Application]::DoEvents()  | out-null
		}
		[gc]::collect()
	}
	
	method quickNode{
		param(
			$text = "",
			$name = "",
			$tag = ""
		)
		
		if($tag -eq ''){ $tag = $text}
		if($name -eq ''){ $name = $text}
		
		$newNode = new-object "System.Windows.Forms.TreeNode"
		$newNode.Name = $name
		$newNode.Text = $text
		$newNode.Tag = $tag
		return $newNode
		
	}
	
	method sortListView{
		param($ListView, $Column, $sortAsc)
		$Numeric = $true 

		$ListItems = @(@(@())) # three-dimensional array; column 1 indexes the other columns, column 2 is the value to be sorted on, and column 3 is the System.Windows.Forms.ListViewItem object
		foreach($ListItem in $ListView.Items){
			if($Numeric -ne $false){
				try{
					$Test = [Double]$ListItem.SubItems[[int]$Column].Text
				}catch{
					$Numeric = $false # a non-numeric item was found, so sort will occur as a string
				}
			}
			$ListItems += ,@($ListItem.SubItems[[int]$Column].Text,$ListItem)
		}

		# create the expression that will be evaluated for sorting
		$EvalExpression = {
			if($Numeric){ 
				return [Double]$_[0] 
			}else{ 
				return [String]$_[0] 
			}
		}

		# all information is gathered; perform the sort
		$ListItems = $ListItems | Sort-Object -Property @{Expression=$EvalExpression; Ascending=$sortAsc}

		## the list is sorted; display it in the listview
		$ListView.BeginUpdate()
		$ListView.Items.Clear()
		foreach($ListItem in $ListItems){
			$ListView.Items.Add($ListItem[1])
		}
		$ListView.EndUpdate()
		
	}
	
	
	method refreshTree{
		param([string]$tab = '', [string]$tree = '', $replacements = @())
		
		if($private.controller.models.isowimcontrol.mounted -eq $true -and $utilities.isBlank($private.controller.models.isowimcontrol.wimpath) -eq $false){
			$private.controller.dism.wimPath = $private.controller.models.isowimcontrol.wimPath
			
			$action = "get$($private.controller.view.getControl($tab, $tree).Text)" # <-- Magic :)
			invoke-expression "`$private.controller.dism.$action()"
			
			$private.controller.view.toggleSplash($true,"Please Wait...","Executing DISM Request $action")
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Executing DISM Request #yellow#$($action)#")
			$uiclass.writeColor("$($uiclass.STAT_WAIT) COMMAND:`r`n`r`n$($private.controller.dism.argumentList)`r`n")
			while($private.controller.dism.job.state -eq 'Running'){
				[System.Windows.Forms.Application]::DoEvents()  | out-null			
			}
			
			$private.controller.view.toggleSplash($true,"Please Wait...","Parsing DISM Results")
			
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Parsing DISM Results")
			$results = ($private.controller.dism.parseResults( ($private.controller.view.getControl($tab, $tree).Text) ) ).results
		
			$private.controller.view.getControl($tab, $tree).Nodes.clear()
			$private.controller.view.getControl($tab, $tree).add_AfterCheck({ $private.controller.view.checkAll( $($_.Node) ) })	
			
			$rootNode = New-Object "$forms.TreeNode"
			$rootNode.text = $private.controller.view.getControl($tab, $tree).Text
			$rootNode.Name = $private.controller.view.getControl($tab, $tree).Text
			$rootNode.Tag = "root"
			
			$private.controller.view.getControl($tab, $tree).Nodes.Add($rootNode) | Out-Null
			$rootNode.Expand() | out-null
			$private.controller.view.gui.form.Refresh() | out-null
			
			foreach($res in $results){
				[System.Windows.Forms.Application]::DoEvents()  | out-null
				if($utilities.isBlank($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ) ) -eq $true){
					$res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ) = 'UNKNOWN'
				}
				
				#see if the Class Name already Exists
				if ( ( $private.controller.view.getControl($tab, $tree).nodes[0].nodes.containsKey( "CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ))" ) ) -eq $false){
					$newNode = new-object "System.Windows.Forms.TreeNode"
					$newNode.Name = "CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ))"
					$newNode.Text = $($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ))
					$newNode.Tag = $($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ))
					$private.controller.view.getControl($tab, $tree).nodes[0].Nodes.Add($newNode) | Out-Null
				}
				
				#if no providers exist, definitely add
				if( ($private.controller.view.getControl($tab, $tree).nodes[0].Nodes["CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ))"].nodes).count -eq 0){
					$newNode = new-object "System.Windows.Forms.TreeNode"
					$newNode.Name = "CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ));PROVIDER:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 1 ] ))"
					$newNode.Text = $($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 1 ] ))
					$newNode.Tag = $($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 1 ] ))
					$private.controller.view.getControl($tab, $tree).nodes[0].Nodes["CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ))"].nodes.add($newNode)
				}else{
					#see if this is the first provided for this name
					if( ($private.controller.view.getControl($tab, $tree).nodes[0].Nodes["CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ))"].nodes["CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ));PROVIDER:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 1 ] ))"]) -eq $null){
						$newNode = new-object "System.Windows.Forms.TreeNode"
						$newNode.Name = "CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ));PROVIDER:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 1 ] ))"
						
						$newNode.Tag = $($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 1 ] ))
						$private.controller.view.getControl($tab, $tree).nodes[0].Nodes["CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ))"].nodes.add($newNode)
					}
				}
				
				#add the new node
				$newNode = new-object "System.Windows.Forms.TreeNode"
				$newNode.Name = "CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ));PROVIDER:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 1 ] ));NODENAME:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 2 ] ))"
								
				if( $($replacements.count) -eq 0){
					$newNode.Text = $($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 3 ] ))
				}else{
					$t = $($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 3 ] ))
					$replacements | % {
						$t = $t -replace $_,''
				
					}
					$newNode.Text = $t; 
				}
						
				$newNode.Tag = $($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 4 ] ))
				
				$private.controller.view.getControl($tab, $tree).nodes[0].Nodes["CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ))"].nodes["CLASS:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 0 ] ));PROVIDER:$($res.$( $dismClass.dismNodeLevels.($private.controller.view.getControl($tab, $tree).Text)[ 1 ] ))"].nodes.add($newNode)
			}
			$private.controller.view.getControl($tab,$tree).nodes[0].Expand() | Out-Null
			$private.controller.view.toggleSplash($false)
		}
	}
}

$imagePatcherController.New().Execute()  | out-null