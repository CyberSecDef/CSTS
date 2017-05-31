<#
.SYNOPSIS
	This is a script will merge multiple nessus scan files into one for upload into vram
.DESCRIPTION
	This is a script will merge multiple nessus scan files into one for upload into vram
.PARAMETER scanPath
	The path to a folder containing all the scan results
.PARAMETER targetSize
	The target size for the uncompressed xml file.  The resultant file is approximately 1/10 the size of this.
.PARAMETER recurse
	Whether or not to recurse into the subdirectories
.EXAMPLE
	C:\PS>.\mergeNessus.ps1 -scanPath ".\scans\"
	This example will merge all the nessus files in the scans directory
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   August 14, 2015
#>
[CmdletBinding()]
param (	$scanPath="", $targetSize="",[switch]$recurse )   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$mergeNessusClass = new-PSClass MergeNessus{
	note -static PsScriptName "mergeNessus"
	note -static Description ( ($(((get-help .\mergeNessus.ps1).Description)) | select Text).Text)

	note -private mainProgressBar
	note -private gui
	
	note -private scanPath
	note -private recurse
	note -private targetSize
	
	
	note -private plugins @()
	note -private xmlDoc
	note -private count 0
	note -private scanXml
	note -private IndividualPluginSelection @()
	note -private FamilyItem @()
	note -private PluginsPreferences @()
	note -private ServerPreferences @()
	
	constructor{
		param()
		
		$private.recurse = $recurse
		$private.scanPath = $scanPath
		$private.targetSize = $targetSize
		
		while( ($utilities.isBlank($private.scanPath) -eq $true) -or ($utilities.isBlank($private.targetSize) -eq $true) ){
			$private.gui = $null
		
			$private.gui = $guiClass.New("mergeNessus.xml")
			$private.gui.generateForm();
			
			$private.gui.Controls.btnOpenFolderBrowser.add_Click({ $private.gui.Controls.txtScanPath.Text = $private.gui.actInvokeFolderBrowser() })
			
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.scanPath = $private.gui.Controls.txtScanPath.Text 
			$private.targetSize = $private.gui.Controls.txtTargetSize.text
			
			if($private.gui.Controls.chkRecurse.checked){
				$private.recurse = $true
			}
		}
	}
	
	method -private createXml{
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Creating new XML Structure for a set of scans.")
		$private.plugins = @()
		$private.IndividualPluginSelection = @()
		$private.FamilyItem = @()
		$private.PluginsPreferences = @()
		$private.ServerPreferences = @()
		
		$private.count++
		
		[XML.XMLDocument]$private.xmlDoc = New-Object System.XML.XMLDocument
		
		[XML.XMLElement]$xmlRoot = $private.xmlDoc.CreateElement("NessusClientData_v2")
		$private.xmlDoc.appendChild($xmlRoot) | out-null
		[XML.XMLElement]$xmlPolicy=$xmlRoot.appendChild($private.xmlDoc.CreateElement("Policy"))

		[XML.XMLElement]$xmlPolName=$xmlPolicy.appendChild($private.xmlDoc.CreateElement("PolicyName"))
		$xmlPolName.innerText = "Merged .Nessus Scans"

		[XML.XMLElement]$xmlPreferences=$xmlPolicy.appendChild($private.xmlDoc.CreateElement("Preferences"))
		[XML.XMLElement]$xmlServerPreferences=$xmlPreferences.appendChild($private.xmlDoc.CreateElement("ServerPreferences"))
		
		[XML.XMLElement]$xmlPluginsPreferences=$xmlPreferences.appendChild($private.xmlDoc.CreateElement("PluginsPreferences"))

		[XML.XMLElement]$xmlFamilySelection=$xmlPolicy.appendChild($private.xmlDoc.CreateElement("FamilySelection"))
		[XML.XMLElement]$xmlIndividualPluginSelection=$xmlPolicy.appendChild($private.xmlDoc.CreateElement("IndividualPluginSelection"))

		[XML.XMLElement]$xmlReport=$xmlRoot.appendChild($private.xmlDoc.CreateElement("Report"))

		$xmlReport.setAttribute("name","Merged .Nessus Scans Report") | out-null
		$xmlReport.setAttribute("xmlns:cm","http://www.nessus.org/cm") | out-null
	}

	method -private saveXml{
		$uiClass.writeColor( "$($uiClass.STAT_OK) Saving XML Scan Files")
		[XML.XMLElement]$xmlPluginSet = $private.xmlDoc.selectSingleNode("/NessusClientData_v2/Policy/Preferences/ServerPreferences").appendChild($private.xmlDoc.CreateElement("preference"))
		
		[XML.XMLElement]$xmlPluginSetName=$xmlPluginSet.appendChild($private.xmlDoc.CreateElement("name"))
		$xmlPluginSetName.innerText="plugin_set"
		[XML.XMLElement]$xmlPluginSetValue=$xmlPluginSet.appendChild($private.xmlDoc.CreateElement("value"))
		$xmlPluginSetValue.innerText = (($private.plugins | sort -unique ) -join ";")

		
		$fileGuid = ([guid]::NewGuid()).Guid
		new-item "$($pwd.ProviderPath)\temp\$($fileGuid)\" -type directory | out-null
		$private.xmlDoc.Save("$($pwd.ProviderPath)\temp\$($fileGuid)\scans_$($private.count).xml")
		$utilities.zipFolder("$($pwd.ProviderPath)\temp\$($fileGuid)")
		remove-item "$($pwd.ProviderPath)\temp\$($fileGuid)" -recurse
		move-item "$($pwd.ProviderPath)\temp\$($fileGuid).zip" "$($pwd.ProviderPath)\results\"
		
		$uiclass.writeColor("$($uiclass.STAT_OK) Bundled scan archive #green#$($fileGuid).zip# is in the #yellow#results# folder")
	}
	
	method Execute{
	
		#house keeping.  This wont work if file extensions are hidden in explorer....because microsoft is dumb.
		$registry = $registryClass.New()
		$registry.open("localhost","LocalMachine")
		$Registry.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced") | out-null
		$currentSetting = $Registry.GetValue("HideFileExt")
		$Registry.SetValue( "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "HideFileExt", 0,"DWord")
		
		
	
		$private.createXml()
	
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
	
		$shell = new-object -com shell.application
		
		if($private.recurse){
			$scans = (gci $private.scanPath -filter "*.zip" -recurse )
		}else{
			$scans = (gci $private.scanPath -filter "*.zip" )
		}
		
		$currentScan = 0
		foreach($scan in $scans){
			$uiClass.writeColor( "$($uiClass.STAT_WAIT) Processing scan #yellow#$($scan.name)#")
			
			$currentScan++
			$i = (100 * ($currentScan / $scans.count))
			
			$private.mainProgressBar.Activity("$($currentScan) / $($scans.count): Processing scan $($scan.name)").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			$scanPBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
			
			$scanPBar.Activity("Extracting scan results from $($scan.name)").Status(("{0:N2}% complete" -f 10)).Percent(10).Render()
			$zip = $shell.NameSpace($scan.fullName)
			foreach($item in $zip.items()){
				$fileGuid = ([guid]::NewGuid()).Guid
				new-item "$($pwd.ProviderPath)\temp\$($fileGuid)\" -type directory | out-null
				$shell.Namespace("$($pwd.ProviderPath)\temp\$($fileGuid)\").copyhere($item)
				
				$private.scanXml = [xml](get-content "$($pwd.ProviderPath)\temp\$($fileGuid)\$($item.name)")
				remove-item "$($pwd.ProviderPath)\temp\$($fileGuid)" -recurse
			}
			
			$scanPBar.Activity("Extracting Server Preferences from scan").Status(("{0:N2}% complete" -f 25)).Percent(25).Render()
			foreach($existingNode in ( $private.scanXml.NessusClientData_v2.Policy.Preferences.ServerPreferences.preference | ? { $_.name -ne "plugin_set" } ) ) {
				if( $private.ServerPreferences -notContains $($existingNode.Name) ){
					$private.ServerPreferences += $existingNode.Name
					
					$sPref = $private.xmlDoc.CreateElement("preference")
					$sName = $private.xmlDoc.CreateElement("name")
					$sName.innerText = $existingNode.Name
					$sVal = $private.xmlDoc.CreateElement("value")
					$sval.innerText = $existingNode.value
					$sPref.appendChild($sName) | out-null
					$sPref.appendChild($sval) | out-null
					
					$private.xmlDoc.selectSingleNode("/NessusClientData_v2/Policy/Preferences/ServerPreferences").appendChild($spref) | out-null
				}
			}

			$scanPBar.Activity("Extracting Plugin Preferences from scan").Status(("{0:N2}% complete" -f 50)).Percent(50).Render()
			foreach($existingNode in ( $private.scanXml.NessusClientData_v2.Policy.Preferences.PluginsPreferences.item ) ) {
				if( $private.PluginsPreferences -notContains $($existingNode.pluginId) ){
					$private.PluginsPreferences += $existingNode.pluginId
					
					$sItem = $private.xmlDoc.CreateElement("item")
								
					$pluginName = $private.xmlDoc.CreateElement("pluginName")
					$pluginName.innerText = $existingNode.pluginName
					$pluginId = $private.xmlDoc.CreateElement("pluginId")
					$pluginId.innerText = $existingNode.pluginId	
					$fullName = $private.xmlDoc.CreateElement("fullName")
					$fullName.innerText = $existingNode.fullName
					$preferenceName = $private.xmlDoc.CreateElement("preferenceName")
					$preferenceName.innerText = $existingNode.preferenceName
					$preferenceType = $private.xmlDoc.CreateElement("preferenceType")
					$preferenceType.innerText = $existingNode.preferenceType
					$preferenceValues = $private.xmlDoc.CreateElement("preferenceValues")	
					$preferenceValues.innerText = $existingNode.preferenceValues
					$selectedValue = $private.xmlDoc.CreateElement("selectedValue")
					$selectedValue.innerText = $existingNode.selectedValue
					
					$sItem.appendChild($pluginName) | out-null
					$sItem.appendChild($pluginId) | out-null
					$sItem.appendChild($fullName) | out-null
					$sItem.appendChild($preferenceName) | out-null
					$sItem.appendChild($preferenceType) | out-null
					$sItem.appendChild($preferenceValues) | out-null
					$sItem.appendChild($selectedValue) | out-null
					
					$private.xmlDoc.selectSingleNode("/NessusClientData_v2/Policy/Preferences/PluginsPreferences").appendChild($sItem) | out-null
				}
			}
						
			$scanPBar.Activity("Extracting Family Selections from  scan").Status(("{0:N2}% complete" -f 75)).Percent(75).Render()
			foreach($existingNode in ( $private.scanXml.NessusClientData_v2.Policy.FamilySelection.FamilyItem ) ) {
				if( $private.FamilyItem -notContains $($existingNode.FamilyName) ){
					$private.FamilyItem += $existingNode.FamilyName
				
					$sFamItem = $private.xmlDoc.CreateElement("FamilyItem")
					
					$sFamName = $private.xmlDoc.CreateElement("FamilyName")
					$sFamName.innerText = $existingNode.FamilyName
					
					$sFamStatus = $private.xmlDoc.CreateElement("Status")
					$sFamStatus.innerText = $existingNode.Status
					
					$sFamItem.appendChild($sFamName) | out-null
					$sFamItem.appendChild($sFamStatus) | out-null
					
					$private.xmlDoc.selectSingleNode("/NessusClientData_v2/Policy/FamilySelection").appendChild($sFamItem) | out-null
				}
			}
				
			$scanPBar.Activity("Extracting Plugin Selections from scan").Status(("{0:N2}% complete" -f 85)).Percent(85).Render()
			foreach($existingNode in ( $private.scanXml.NessusClientData_v2.Policy.IndividualPluginSelection.PluginItem ) ) {
			
				if( $private.IndividualPluginSelection -notContains $($existingNode.PluginId) ){
					$private.IndividualPluginSelection += $existingNode.PluginId
				
					$sPluginItem = $private.xmlDoc.CreateElement("PluginItem")
					
					$sPluginId = $private.xmlDoc.CreateElement("PluginId")
					$sPluginId.innerText = $existingNode.PluginId
					
					$sPluginName = $private.xmlDoc.CreateElement("PluginName")
					$sPluginName.innerText = $existingNode.PluginName
					
					$sFamily = $private.xmlDoc.CreateElement("Family")
					$sFamily.innerText = $existingNode.Family
					
					$sStatus = $private.xmlDoc.CreateElement("Status")
					$sStatus.innerText = $existingNode.Status
					
					$sPluginItem.appendChild($sPluginId) | out-null
					$sPluginItem.appendChild($sPluginName) | out-null
					$sPluginItem.appendChild($sFamily) | out-null
					$sPluginItem.appendChild($sStatus) | out-null
					
					$private.xmlDoc.selectSingleNode("/NessusClientData_v2/Policy/IndividualPluginSelection").appendChild($sPluginItem) | out-null
				}
			}
			
			$private.plugins += ( ($private.scanXml.NessusClientData_v2.Policy.Preferences.ServerPreferences.preference | ? { $_.name -eq "plugin_set" } ).value -split ";" )

			$scanPBar.Activity("Extracting Host Reports from scan").Status(("{0:N2}% complete" -f 95)).Percent(95).Render()
			$hosts = ( $private.scanXml.NessusClientData_v2.Report.ReportHost )
			
			foreach($existingReport in $hosts ) {
				if($existingReport -ne $null){
					$private.xmlDoc.NessusClientData_v2.Report.AppendChild($private.xmlDoc.ImportNode(( $existingReport ), $true)) | out-null
				}
			}
				
			$uiClass.writeColor(( "$($uiClass.STAT_WAIT) Current File Size is #green#{0:0.##}# MB, Archive Target Size is #green#$($private.targetSize)MB#" -f ($private.xmlDoc.outerXml.length / 1MB) ) )
			if($private.xmlDoc.outerXml.length -ge ( [convert]::ToInt32($private.targetSize) * 1MB ) ){
				$private.saveXml()
				$private.createXml()
			}

			#garbage collection
			$private.plugins = ($private.plugins | sort -unique )
			
			$scanPBar.Completed($true).Render() 
		}
		
		$registry.SetValue( "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "HideFileExt", $currentSetting,"DWord")
		$registry.close()
		
		$private.mainProgressBar.Completed($true).Render() 
		$private.saveXml()
		$uiClass.errorLog()
	}
}

$mergeNessusClass.New().Execute()  | out-null