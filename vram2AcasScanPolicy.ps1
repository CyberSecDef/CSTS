<#
.SYNOPSIS
	This script will create an ACAS Scan Policy for the audits that VRAM needs input from
.DESCRIPTION
	This script will create an ACAS Scan Policy for the audits that VRAM needs input from
.PARAMETER auditPath
	The path to the VRAM Audits (csv format)
.EXAMPLE
	C:\PS>.\vram2AcasScanPolicy.ps1 -auditPath "c:\audits.csv" 
	This example will clean the designated path
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Nov 2, 2015
#>
[CmdletBinding()]
param( $auditPath ) 
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$vram2AcasScanPolicyClass = new-PSClass vram2AcasScanPolicy{
	note -static PsScriptName "vram2AcasScanPolicy"
	note -static Description ( ($(((get-help .\vram2AcasScanPolicy.ps1).Description)) | select Text).Text)

	note -private mainProgressBar
	note -private auditPath
	note -private activeAudits
	note -private scanPolicy
	note -private ie
	
	note -private gui
	
	method Execute{
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		$uiClass.writeColor( "$($uiClass.STAT_OK) Parsing Active Plugins")
		
		$private.ie = new-object -com "InternetExplorer.Application"
		$private.activeAudits = Import-Csv "$($private.auditPath)"
		$private.scanPolicy = [xml](gc "$($pwd)/db/vramAcasSP.xml")

		$c = 0
		$d = 0

		$activeCount = $( ( $private.activeAudits | ? { $_.'Nessus ID' -ne '' } ).count)
		foreach($audit in ( $private.activeAudits | ? { $_.'Nessus ID' -ne '' } | sort 'Nessus ID')){
			$c++
			if($c % 100 -eq 0){
				$i = 100*($c / $activeCount)
				$private.mainProgressBar.Activity("$c / $activeCount : Analysing Plugin $($audit.'Nessus ID') ").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			}
			
			$source = "http://www.tenable.com/plugins/index.php?view=single&id=$($audit.'Nessus ID')"
			$present = $private.scanPolicy.selectNodes("/NessusClientData_v2/Policy/IndividualPluginSelection/PluginItem[./PluginId/text()='$($audit.'Nessus ID')']")
			
			if($present.count -eq 0){
				
				$private.ie.navigate( $source ) | out-null
				while($private.ie.document.readyState -ne 'complete'){
					sleep -milliseconds 100
				}
				
				$doc = $private.ie.Document
				if($doc -ne $null -and $doc -ne ''){
				
					$d++
					
					# $pluginName = ($doc.documentElement.getElementsByClassName('plugin-single') | select -first 1 ).children | ? { $_.tagName -eq 'H1' } | select -first 1 | select -expand innerText
					$pluginName = $($audit.'Title')
					$pluginFamily = (($doc.documentElement.getElementsByTagName('p') | ?  { $_.innerHtml -like '*strong*' } | ? { $_.innerHtml -like '*Family*' } | select -expand innerText ) -replace 'family:','') 
					
					$pluginId = $($audit.'Nessus ID')
					
					$pluginItem = $private.scanPolicy.createElement('PluginItem')

					$pluginIdNode = $private.scanPolicy.createElement('PluginId')
					$pluginIdNode.innerText = $audit.'Nessus ID'

					$pluginNameNode = $private.scanPolicy.createElement('PluginName')
					$pluginNameNode.innerText = $pluginName

					$pluginFamilyNode = $private.scanPolicy.createElement('Family')
					$pluginFamilyNode.innerText = $pluginFamily

					$pluginStatusNode = $private.scanPolicy.createElement('Status')
					$pluginStatusNode.innerText = "enabled"

					$pluginItem.appendChild($pluginIdNode) | out-null
					$pluginItem.appendChild($pluginNameNode) | out-null
					$pluginItem.appendChild($pluginFamilyNode) | out-null
					$pluginItem.appendChild($pluginStatusNode) | out-null

					$private.scanPolicy.NessusClientData_v2.Policy.IndividualPluginSelection.appendChild($pluginItem) | out-null
					
					#enable plugin family
					$p = $private.scanPolicy.selectSingleNode("/NessusClientData_v2/Policy/FamilySelection/FamilyItem[./FamilyName/text()='$($pluginFamily)']/Status")
					if($p -ne $null){
						$p.innerText = 'mixed'
					}
					
					$uiClass.writeColor( "$($uiClass.STAT_WAIT) Analysing Plugin #yellow#$($pluginId)# : $($pluginFamily) - #green#$($pluginName)#")
					
					if ( ($d % 50) -eq 0){
						$uiClass.writeColor("$($uiClass.STAT_WAIT) Saving Current Policy for in case of error...")
						$private.scanPolicy.save("$($pwd)/db/vramAcasSP.xml") | out-null
					}
				}
			}
		}

		$private.scanPolicy.PreserveWhitespace = $true
		$private.scanPolicy.save("$($pwd)/db/vramAcasSP.xml") | out-null
		copy-item "$($pwd)/db/vramAcasSP.xml" "$($pwd)/results/vramAcasSP.xml"

		$private.ie.quit()
		$private.mainProgressBar.Completed($true).Render() 

		$uiClass.errorLog()
	}

	constructor{
		param()
		$private.auditPath = $auditPath
		
		while($utilities.isBlank($private.auditPath) -eq $true){
			$private.gui = $null
			$private.gui = $guiClass.New("vram2AcasScanPolicy.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			
			$private.gui.Controls.btnOpenFileBrowser.add_Click({  $private.gui.Controls.txtAuditPath.Text = $private.gui.actInvokeFileBrowser(@{"CSV Files (*.csv)" = "*.csv";}) })
				
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.auditPath = $private.gui.Controls.txtAuditPath.Text
		}
	}
}

$vram2AcasScanPolicyClass.New().Execute() | out-null