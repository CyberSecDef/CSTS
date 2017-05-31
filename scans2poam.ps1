<#
.SYNOPSIS
	This is a script will parse scan results and generate an excel POAM
.DESCRIPTION
	This is a script will parse scan results and generate an excel POAM.  It can accept StigViewer Checklists, ACAS .Nessus files and SCAP XCCDF files
.PARAMETER scanLocation
	The path to the scan results
.PARAMETER recurse
	Whether or not to recurse into the subdirectories for the scanLocation parameter
.EXAMPLE
	C:\PS>.\scans2poam.ps1 -ScanLocation "C:\scans\" -Recurse
	This example will scan the files in the path listed and save the poam
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Dec 30, 2014
#>
[CmdletBinding()]
Param( $ScanLocation, [switch] $recurse ) 
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$Scans2PoamClass = new-PSClass Scans2Poam{
	note -static PsScriptName "scans2poam"
	note -static Description ( ($(((get-help .\scans2poam.ps1).Description)) | select Text).Text)
	
	note -private gui
	
	note -private scanLocation
	note -private recurse
	note -private export $ExportClass.New()
	
	note -private currentScanFile
	
	note -private scans @{
		"scap" = @{}
		"acas" = @()
		"ckl" = @{}
	}
	
	note scanResults @()
	note poamArr @{}
	note mainProgressBar
	note -static parseExtensions @(".ckl",".xml",".nessus", ".zip")
	
	method export{
		
		$foundIAControls = @()
		$this.poamArr.Keys | % {
			if($utilities.isBlank($this.poamArr.$_.IA_Controls) -eq $false){
				$foundIAControls += $this.poamArr.$_.IA_Controls
			}
		}
		
		
		
		
		$this.mainProgressBar.Activity("Adding eMass POAM").Status("{0:N2}% complete" -f 70).Percent(70).Render()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Adding eMass POAM" )
		$this.addEmassPoam()
		
		$this.mainProgressBar.Activity("Adding RAR").Status("{0:N2}% complete" -f 80).Percent(85).Render()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Adding RAR" )
		$this.addRar()
		
		$this.addTestPlan()
		
		$ts = (get-date -format "yyyyMMddHHmmss")
		$private.export.saveAs([System.IO.Path]::GetFullPath("$($pwd.ProviderPath)\results\$($Scans2PoamClass.PsScriptName)_$ts.xml"))
		
	}

	method addResult{
		param( $h, $reportItem)
			
		#completed items are not a risk and should not be added
		if($reportItem.status -ne 'Completed'){
			#see if this report already exists in $poamArr
			if($utilities.isBlank("$($reportItem.VulnId)$($reportItem.RuleId)$($reportItem.PluginId)".trim()) -eq $false){
				$key = "$($reportItem.VulnId)-$($reportItem.RuleId)-$($reportItem.PluginId)"
			
				# if the vulnerability already exists, just add new hosts
				if($this.poamArr.ContainsKey( $key ) ){
					if($this.poamArr.$key.hosts -notcontains ("$h".ToLower()) ){
						$this.poamArr.$key.hosts += "$h".ToLower()
					}
					
					#see if the IA Controls need to be added to the record
					if($utilities.isBlank( $reportItem.IA_Controls) -eq $false){
						$this.poamArr.$key.IA_Controls = $reportItem.IA_Controls
					}
					
					#see if the comments need to be added to the record
					if($utilities.isBlank($reportItem.Comments) -eq $false){
						$this.poamArr.$key.Comments = "$($this.poamArr.$key.Comments)\n\n$($reportItem.Comments)"
					}
					
					if($this.poamArr.$key.sources -notcontains ( $reportItem.shortSource ) ){
						$this.poamArr.$key.sources += ( $reportItem.shortSource )
					}
					
				}else{
					$reportItem.sources = @()
					$reportItem.sources += $reportItem.shortSource
					$reportItem.hosts = @()
					$reportItem.hosts += "$h".ToLower()
					$this.poamArr.add( $key, $reportItem)
				}
			}
		}
		
	}
	
	method addTestPlan{
		$private.export.addWorkSheet('Test_Plan')
		$c = 1
		@(300,100,350,175,175) | %{
			$private.export.setColWidth($c,$_)
			$c++
		}
		

		$private.export.updateCell(1,1,"[SYSTEM NAME] Test Plan", ([export.excelStyle]::Neutral))
		$private.export.updateCell(1,3,"FOR OFFICIAL USE ONLY", [export.excelStyle]::RedText)
		
		$private.export.updateCell(2,1,"System Name:", [export.excelStyle]::Orange)
		$private.export.mergeCells(2,1,[export.mergeType]::Across,1)
		$private.export.updateCell(2,2,"MAC:", [export.excelStyle]::Orange)
		$private.export.updateCell(2,3,"Test Location (Specify Dev or Prod):", [export.excelStyle]::Orange)
		$private.export.updateCell(2,4,"CL:", [export.excelStyle]::Orange)

		$private.export.updateCell(3,1,"[INSERT SYSTEM NAME]",([export.excelStyle]::Neutral))
		$private.export.mergeCells(3,1,[export.mergeType]::Across,1)
		$private.export.updateCell(3,2,"[INSERT SYSTEM MAC LEVEL]",([export.excelStyle]::Neutral))
		$private.export.updateCell(3,3,"[INSERT SYSTEM LOCATION]",([export.excelStyle]::Neutral))
		$private.export.updateCell(3,4,"[INSERT SYSTEM CLEARANCE LEVEL]",([export.excelStyle]::Neutral))

		$private.export.updateCell(4,1,"ACAS Scan Date:", [export.excelStyle]::Gray)
		$private.export.updateCell(4,2,"Components Scanned/OS Version:", [export.excelStyle]::Gray)
		$private.export.mergeCells(4,2,[export.mergeType]::Across,1)
		$private.export.updateCell(4,3,"File Name:", [export.excelStyle]::Gray)
		$private.export.updateCell(4,4,"NESSUS SCAN Engine Version:", [export.excelStyle]::Gray)
		
		#only doing it this way because there is no sort unique for objects that works well.
		$tmpAcas = @()
		foreach($acasScan in ( $private.scans.acas | sort -property scanDate )){
			$tmpAcas += "$($acasScan.scanDate.toString('MM/dd/yyyy') )|$($acasScan.scanOs)|$($acasScan.scanFile)|$($acasScan.engine)"
		}
		
		$row = 5
		foreach($acasScan in ( $tmpAcas | sort -unique)){
			$scan = $acasScan.split("|")
			
			$private.export.updateCell($row,1,"$($scan[0])")
			$private.export.updateCell($row,2,"$($scan[1])")
			$private.export.mergeCells($row,2,[export.mergeType]::Across,1)
			$private.export.updateCell($row,3,"$($scan[2])")
			$private.export.updateCell($row,4,"$($scan[3])")
			
			$row++
		}
		
		$private.export.updateCell($row,1,"STIGs/SRRs/Checklists:", [export.excelStyle]::Gray)
		$private.export.updateCell($row,2,"Version:", [export.excelStyle]::Gray)
		$private.export.updateCell($row,3,"Components Tested:", [export.excelStyle]::Gray)
		$private.export.updateCell($row,4,"File Name:", [export.excelStyle]::Gray)
		$private.export.updateCell($row,5,"Date:", [export.excelStyle]::Gray)
		
		$row++
		
		#only doing it this way because there is no sort unique for objects that works well.
		$tmpScapCkl = @()
		foreach($scapTitle in ( $private.scans.scap.keys | sort )){
			foreach($scapVersion in ($private.scans.scap.$scapTitle.keys | Sort )){
				$tmpScapCkl += "$($scapTitle -replace 'Security Technical Implementation Guide','STIG') - SCAP Benchmark|$($scapVersion)|$($private.scans.scap.$scapTitle.$scapVersion.hosts -join '; ')| |$($private.scans.scap.$scapTitle.$scapVersion.date | sort | select @{Label='Start'; Expression = {$_.toString('MM/dd/yyyy') }} -first 1 | select -expand Start) - $($private.scans.scap.$scapTitle.$scapVersion.date | sort  -descending| select @{Label='Stop'; Expression = {$_.toString('MM/dd/yyyy') }} -first 1 | select -expand Stop)"
			}
		}
		
		foreach($cklTitle in ( $private.scans.ckl.keys | sort )){
			foreach($cklVersion in ($private.scans.ckl.$cklTitle.keys | Sort )){
				foreach($cklFile in ($private.scans.ckl.$cklTitle.$cklVersion.keys | Sort )){
					$tmpScapCkl += "$($cklTitle -replace 'Security Technical Implementation Guide','STIG') - STIG Checklist|$($cklVersion)|$( $private.scans.ckl.$cklTitle.$cklVersion.$cklFile.host )|$($cklFile)|$( $private.scans.ckl.$cklTitle.$cklVersion.$cklFile.date.toString('MM/dd/yyyy') )"
				}
			}
		}
		
		foreach($scapCkl in ( $tmpScapCkl | sort -unique)){
			$scan = $scapCkl.split("|")
			for($i = 0; $i -lt 5; $i++){
				$private.export.updateCell($row,($i+1),"$($scan[$i])")
				if($utilities.isBlank( ( $($scan[$i]).ToString().Trim() ) ) -eq $true -or $($scan[$i]).ToString().Trim() -eq "VR" ){
					$private.export.formatCell($row,($i+1),[export.excelStyle]::Neutral)
				}
			}
			$private.export.formatCell($row,3,[export.excelStyle]::Wrap)
			$row++
		}
		
		
		
		for($i = 1; $i -lt 6; $i++){
			$private.export.updateCell($row,$i," ", [export.excelStyle]::Gray )
		}
		$row++
		
		$private.export.updateCell($row,1,"[SYSTEM NAME] Test Plan", [export.excelStyle]::Neutral)
		$private.export.updateCell($row,3,"FOR OFFICIAL USE ONLY", [export.excelStyle]::RedText)
	}
	
	method addRar{
		param()
		
		$private.export.addWorkSheet('RAR')
				
		$c = 1
		@(85, 150, 180, 150, 180, 75, 85, 105, 210, 190, 150, 110, 80, 175, 175) | %{
			$private.export.setColWidth($c,$_)
			$c++
		}
			
		$private.export.updateCell(1,1,"System Name and Version:")
		$private.export.updateCell(2,1,"Date(s) of Testing:")
		$private.export.updateCell(3,1,"$(get-date)")
		$private.export.updateCell(3,1,"Date of Report:")
		$private.export.updateCell(3,3,"$(get-date)")
		$private.export.updateCell(4,1,"POC Information:")
		$private.export.updateCell(5,1,"Risk Assessment Method:")
		$private.export.updateCell(6,1,"Overall Severity Category:")
		
		$private.export.mergeCells(1,1,[export.mergeType]::Across,1)
		$private.export.mergeCells(2,1,[export.mergeType]::Across,1)
		$private.export.mergeCells(3,1,[export.mergeType]::Across,1)
		$private.export.mergeCells(4,1,[export.mergeType]::Across,1)
		$private.export.mergeCells(5,1,[export.mergeType]::Across,1)
		$private.export.mergeCells(6,1,[export.mergeType]::Across,1)
		
		$private.export.mergeCells(1,3,[export.mergeType]::Across,2)
		$private.export.mergeCells(2,3,[export.mergeType]::Across,2)
		$private.export.mergeCells(3,3,[export.mergeType]::Across,2)
		$private.export.mergeCells(4,3,[export.mergeType]::Across,2)
		$private.export.mergeCells(5,3,[export.mergeType]::Across,2)
		$private.export.mergeCells(6,3,[export.mergeType]::Across,2)

		#header stuff
		$colHeaders = @(
			"Identifier Applicable\nSecurity Control\n(1)",
			"Source of Discovery or\nTest Tool Name\n(2)",
			"Test ID or\nThreat IDs\n(3)",
			"Description of\nVulnerability/Weakness\n(4)",
			"Risk Statement\n(5)",
			"Raw Risk\n(CAT I, II, III)\n(6)",
			"Impact\n(7)",
			"Likelihood\n(8)",
			"Recommended\nCorrective Action\n(9)",
			"Mitigation\nDescription\n(10)",
			"Remediation\nDescription\n(11)",
			"Residual\nRisk/Risk Exposure\n(12)",
			"Status\n(13)",
			"Comment\n(14)",
			"Devices\nAffected\n(15)"
		)
		
		$col = 1
		$colHeaders | %{
			$private.export.updateCell(7,$col,$_)
			$private.export.formatCell(7,$col,[export.excelStyle]::Header)
			$col = $col + 1
		}
		
		
		$row = 8
		$column = 1
		$totalRows = $this.poamArr.Keys.count
		$currentRow = 1
		
		$rarProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "Adding RAR"; "Status" = "Please Wait..."; "PercentComplete" = 0; "Completed" = $false; "id" = 3 }).Render() 
		$this.poamArr.Keys | % {
			$i = (100*($currentRow / $totalRows))
			$rule = $this.poamArr.$_
			$rarProgressBar.Activity("$currentRow / $totalRows : $($rule.title) ").Status("{0:N2}% complete" -f $i).Percent($i).Render()	
			
			$hosts = $rule.hosts
			for($i = 0; $i -lt $hosts.count; $i++){
				if( ($hosts[$i] | isIp) -eq $true){
					try{
						$hosts[$i] = ([System.Net.Dns]::gethostentry($hosts[$i]) | select -expand Hostname).split('.')[0]
					}catch{
						$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not resolve $green#$($hosts[$i])# to a hostname.")
					}
				}
			}
			
			$colVals = @(
				"$($rule.IA_Controls)",
				"$( ( $rule.sources | sort ) -join '/' ): $($rule.Source)",
				"Group ID: $($rule.GrpId)\nVuln ID: $($rule.VulnId)\nRule ID: $($rule.RuleId)\nPlugin ID: $($rule.PluginId)",
				"$($rule.title)",
				"$($rule.description)",
				"$($rule.RawCat)",
				"$($rule.RawRisk)",
				"$($rule.Likelihood)",
				"$($rule.Mitigation)",
				"",
				"",
				"$($rule.RawCat)",
				"$($rule.Status)",
				"$($rule.Comments)",
				"$( ( ( $hosts | sort ) -join "", "" ) )"

			)
			
			$column = 1
			$colVals | % {
				[string] $colVal = [string]"$_"
				try{
					if("$($colVal)".length -ge 8192){
						$private.export.updateCell($row,$column, $colVal.substring(0,8192) )
					}else{
						$private.export.updateCell($row,$column, $colVal )
					}
					$private.export.formatCell($row,$column,[export.excelStyle]::Wrap)
				}catch{
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) Error writing Row $row, Column $column to the Excel RAR Worksheet.  Check for corrupt data:`n#yellow#$($colVal)#" )
				}
				$column ++
			}
			
			$currentRow++
			$row++
			$column = 1
		}

		$private.export.autoFilterWorksheet(7)
			
		$rarProgressBar.Completed($true).Render() 
	}

	method addEmassPoam{
		param()
		
		$private.export.addWorkSheet('eMass POAM')
				
		$c = 1
		@(35, 350, 100, 100, 100, 100, 100, 100, 100, 250, 100, 400) | %{
			$private.export.setColWidth($c,$_)
			$c++
		}
		
		$private.export.updateCell(2,1, "Date Exported:")
		$private.export.updateCell(3,1, "Exported By:")
		$private.export.updateCell(4,1, "Component Name:")
		$private.export.updateCell(5,1, "System/Project Name:")
		$private.export.updateCell(6,1, "DoD IT Registration No:")

		$private.export.updateCell(2,2, "$(get-date)")
		
		$private.export.updateCell(2,3, "IS Type:")
		$private.export.updateCell(4,3, "POC Name:")
		$private.export.updateCell(5,3, "POC Phone:")
		$private.export.updateCell(6,3, "POC E-Mail:")
		
		$private.export.updateCell(2,5, "OMB Project ID:")
		$private.export.updateCell(5,5, "Security Costs:")
		
		
		#col a merger
		$private.export.mergeCells(2,1,[export.mergeType]::Across,1)
		$private.export.mergeCells(3,1,[export.mergeType]::Across,1)
		$private.export.mergeCells(4,1,[export.mergeType]::Across,1)
		$private.export.mergeCells(5,1,[export.mergeType]::Across,1)
		$private.export.mergeCells(6,1,[export.mergeType]::Across,1)
		
		#col c merger
		$private.export.mergeCells(2,2,[export.mergeType]::Across,2)
		$private.export.mergeCells(3,2,[export.mergeType]::Across,2)
		$private.export.mergeCells(4,2,[export.mergeType]::Across,2)
		$private.export.mergeCells(5,2,[export.mergeType]::Across,2)
		$private.export.mergeCells(6,2,[export.mergeType]::Across,2)
		
		#col G merger
		$private.export.mergeCells(2,4,[export.mergeType]::Across,1)
		$private.export.mergeCells(3,4,[export.mergeType]::Across,1)		
		$private.export.mergeCells(4,4,[export.mergeType]::Across,1)		
		$private.export.mergeCells(5,4,[export.mergeType]::Across,1)
		$private.export.mergeCells(6,4,[export.mergeType]::Across,1)
		
		
		#col J merger
		$private.export.mergeCells(2,6,[export.mergeType]::Across,2)
		$private.export.mergeCells(3,6,[export.mergeType]::Across,2)
		$private.export.mergeCells(4,6,[export.mergeType]::Across,2)
		$private.export.mergeCells(5,6,[export.mergeType]::Across,2)
		$private.export.mergeCells(6,6,[export.mergeType]::Across,2)
				
		foreach($c in @(1,3,5)){
			for($r = 2; $r -lt 7; $r++){
				$private.export.formatCell($r,$c, [export.excelStyle]::Gray)
			}
		}
		
		$colHeaders = @("Control Vulnerability Description","Vulnerability\nSeverity Value","Security Control Number\n(NC/NA controls only)","Office/Org","Resources Required","Scheduled Completion\nDate","Milestones With \nCompletion Date","Milestone\nChanges","Source Identifying\nControl Vulnerability","Status","Comments")
		
		
		$col = 1
		$colHeaders | %{
			$private.export.updateCell(7,$col,$_)
			$private.export.formatCell(7,$col,[export.excelStyle]::Header)
			
			$col++
		}
		$private.export.mergeCells(7,1,[export.mergeType]::Across,1)
		
		$row = 8
		$column = 1
		$totalRows = $this.poamArr.Keys.count
		$currentRow = 1
		
		$eMassPoamProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "Adding eMass POAM"; "Status" = "Please Wait..."; "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
		$this.poamArr.Keys | % {
			$i = (100*($currentRow / $totalRows))
			$rule = $this.poamArr.$_
			$eMassPoamProgressBar.Activity("$currentRow / $totalRows : $($rule.title) ").Status("{0:N2}% complete" -f $i).Percent($i).Render()	
			
			if($rule.Comments.length -ge 8192){
				$rule.Comments= $rule.Comments.substring(0,8192)
			}
			$column = 1
			
			$private.export.updateCell($row,$column,$currentRow)
			
			$colVal = "Title: $($rule.title)\nDescription: $($rule.description)\n\nDevices Affected: $( ( ( $rule.hosts | sort ) -join "", "" ) )"

			$column = 2
			$private.export.updateCell($row,$column,$colVal)
			$private.export.formatCell($row,$column,[export.excelStyle]::Wrap)
			
			$column = 3
			$private.export.updateCell($row,$column,"$($rule.RawCat)")
						
			$column = 4
			$private.export.updateCell($row,$column,"$($rule.IA_Controls)")
			
			$column = 6
			$private.export.updateCell($row,$column,"$($rule.Responsibility)")
			
			$colVal = "$( ( $rule.sources | sort ) -join '/' ): $($rule.Source)\nGroup ID: $($rule.GrpId)\nVuln ID: $($rule.VulnId)\nRule ID: $($rule.RuleId)\nPlugin ID: $($rule.PluginId)"
			$column = 10	
			$private.export.updateCell($row,$column,$colVal)
			$private.export.formatCell($row,$column,[export.excelStyle]::Wrap)
			
			$colVal = "$($rule.Status)"
			$column = 11
			$private.export.updateCell($row,$column,$colVal)
			
			$colVal = "Raw Risk: CAT $($rule.RawCat)\nLikelihood: Low\nMitigation: $($rule.Mitigation)\n\nComments: $($rule.Comments)"

			$column = 12
			$private.export.updateCell($row,$column,$colVal)
			$private.export.formatCell($row,$column,[export.excelStyle]::Wrap)
		
			$currentRow++
			$row++
			$column = 1
		}

		$private.export.autoFilterWorksheet(7)
		
		$eMassPoamProgressBar.Completed($true).Render()
	}
	
	method parseNessusResult{
		param([xml] $xml)
	
		$hosts = Select-Xml "/NessusClientData_v2/Report/ReportHost" $xml
		if($utilities.isBlank($($hosts.length)) -eq $false){
			$uiClass.writeColor("            There are #yellow#$($hosts.length)# hosts in this nessus file")
		}else{
			$uiClass.writeColor("            There are #yellow#1# hosts in this nessus file")
		}
			
		foreach($h in $hosts){
			$uiClass.writeColor("$($uiClass.STAT_WAIT)     Gathering results for system: #green#$($h.Node.name)#")
			
			$uiClass.writeColor("$($uiClass.STAT_OK)     #green#$($h.Node.ReportItem.count)# findings")
		
			#get acas scan info
			
			$hostScanDate =  ([dateTime]::ParseExact( ($h.Node.SelectSingleNode("//HostProperties/tag[@name='HOST_START']").'#text').replace('  ',' '), 'ddd MMM d HH:mm:ss yyyy', $null) )
			$hostScanOs = ($h.Node.SelectSingleNode("//HostProperties/tag[@name='operating-system']").'#text') + ' ' + ($h.Node.SelectSingleNode("//HostProperties/tag[@name='os']").'#text')
			
			
			$hostScanEngine = "0.0"
			($h.Node.SelectSingleNode("//ReportItem[@pluginID='19506']/plugin_output").'#text') -split "`n"   | % {
				 if ( (($_ -split ":")[0]) -like 'Nessus version*'){
					$hostScanEngine =  ( [regex]::matches(  (($_ -split ":")[1]).Trim() , "(^[0-9\.]+)" ) | select -first 1 )
				}
			}
			
			$private.scans.acas += @{
				"scanDate" = $hostScanDate;
				"scanOs" = $hostScanOs;
				"scanFile" = [io.path]::GetFilename( $private.currentScanFile );
				"engine" = $hostScanEngine;
			}
			
			
			
			foreach($report in $h.Node.ReportItem){
				#create a report item
				$reportItem = @{}
				$reportItem.Title = $report.pluginName
				$reportItem.Description = $report.synopsis
				$reportItem.RawRisk = $report.risk_factor
				
				switch($report.risk_factor){
					"None" 		{$reportItem.RawCat = "IV"}
					"Low" 		{$reportItem.RawCat = "III"}
					"Medium" 	{$reportItem.RawCat = "II"}
					"High" 		{$reportItem.RawCat = "I"}
					"Critical" 	{$reportItem.RawCat = "I"}
					default 	{$reportItem.RawCat = "IV"}
				}
				
				switch($report.severity){
					"0" {$reportItem.Likelihood = "Info"}
					"1" {$reportItem.Likelihood = "Low"}
					"2" {$reportItem.Likelihood = "Medium"}
					"3" {$reportItem.Likelihood = "High"}
					"4" {$reportItem.Likelihood = "High"}
					default {$reportItem.Likelihood = "Info"}
				}
				
				$reportItem.Comments = $report.plugin_output
				$reportItem.Mitigation = $report.solution
				$reportItem.IA_Controls = ""
				
				$reportItem.Responsibility = ""
				$reportItem.Status = "Ongoing"
				$reportItem.Source = "Assured Compliance Assessment Solution:"
				
				$reportItem.ShortSource = "ACAS"
				$reportItem.PluginId = $report.pluginId
				$reportItem.RuleId = ""
				$reportItem.VulnId = ""
				$reportItem.GrpId = $report.pluginFamily
				
				$this.addResult($h.Node.name, $reportItem)
			}
		}
	}
	
	method parseXCCDFResult{
		param( 
			[xml] $xml
		)
	
		$xmlNs = @{}
		$xml.DocumentElement.Attributes | % { 
			if($_.Prefix -eq 'xmlns'){
				$name = ($_.Name).split(":")[1]
				$uri = $_.'#text'
				$xmlNs[$name] = $uri
			}
		}
		
		$h  = Select-Xml -Namespace $xmlNs -xpath "/cdf:Benchmark/cdf:TestResult/cdf:target" $xml
		$os = Select-Xml -Namespace $xmlNs -xpath "/cdf:Benchmark/cdf:TestResult/cdf:target-facts/cdf:fact[name='urn:scap:fact:asset:identifier:os_name']" $xml
		$osVer = Select-Xml -Namespace $xmlNs -xpath "/cdf:Benchmark/cdf:TestResult/cdf:target-facts/cdf:fact[name='urn:scap:fact:asset:identifier:os_version']" $xml
	
		$uiClass.writeColor("$($uiClass.STAT_WAIT)     Gathering results for system: #green#$($h)#")
		
		$title = (Select-Xml -Namespace $xmlNs -xpath "/cdf:Benchmark/cdf:title" $xml | select -expand Node | select innerXml).innerxml
		$version = (Select-Xml -Namespace $xmlNs -xpath "/cdf:Benchmark/cdf:version" $xml | select -expand Node | select innerXml).innerxml
		$release = ( ( [regex]::matches( (Select-Xml -Namespace $xmlNs -xpath "/cdf:Benchmark/cdf:plain-text[@id='release-info']" $xml), "Release: ([0-9.]+)") | select groups).groups[1] | select -expand value)
		$scanDate =  [datetime]::ParseExact(
			(Select-Xml -Namespace $xmlNs -xpath "/cdf:Benchmark/cdf:TestResult/@start-time" $xml ),
			'yyyy-MM-ddTHH:mm:ss',
			$null
		)
				
		#see if stigScapInfo key for this scap exists
		if($private.scans.scap.keys -notcontains $title){
			$private.scans.scap.$title = @{}
		}
		
		#see if this release is already in the stigScapInfo
		if($private.scans.scap.$title.keys -notcontains "V$($version)R$($release)"){
			$private.scans.scap.$title."V$($version)R$($release)" = @{}
			$private.scans.scap.$title."V$($version)R$($release)".hosts = @()
			$private.scans.scap.$title."V$($version)R$($release)".date = @()
		}
		
		$private.scans.scap.$title."V$($version)R$($release)".hosts += ( $h | select -expand Node | select innerXml).innerxml.toString().toLower()
		$private.scans.scap.$title."V$($version)R$($release)".date += $scanDate
		
		
		
		$vulns = Select-Xml -Namespace $xmlNs -xpath "/cdf:Benchmark/cdf:TestResult/cdf:rule-result" $xml
		if($utilities.isBlank($vulns) -eq $false){
			$uiClass.writeColor("$($uiClass.STAT_OK)     #green#$($vulns.count)# findings")
		}else{
			$uiClass.writeColor("$($uiClass.STAT_OK)     #green#0# findings")
		}
	
		for($i = 0; $i -lt $vulns.count; $i++){
			#from vulnerability result, get actual rule details
			$rule = Select-Xml -Namespace $xmlNs -xpath "//cdf:Rule[@id='$($vulns[$i].Node.idref)']" $xml
			
			# create a report item
			$reportItem = @{}
			
			$reportItem.Title = $rule.Node.title
			
			$reportItem.Description = $rule.Node.description
			$reportItem.RawRisk = $rule.Node.severity
			
			switch($rule.Node.severity){
				"low" 		{$reportItem.RawCat = "III"}
				"medium" 	{$reportItem.RawCat = "II"}
				"high" 		{$reportItem.RawCat = "I"}
				default 	{$reportItem.RawCat = "IV"}
			}
			
			$reportItem.Likelihood = "Low"
			$reportItem.Comments = ""
			$reportItem.Responsibility = ""
			
			$mitigation = $rule.Node.fixtext.'#text'
			$reportItem.Mitigation = "$mitigation
			
			FixId: $($rule.Node.fixtext.fixref)"
			
			$reportItem.IA_Controls = ""
			
			#see if i can figure out what IA Control to use
			
			if($utilities.isBlank( $reportItem.description ) -eq $false){
				try{
					$desc = [xml]( "<root>$($rule.Node.description)</root>" )
					$reportItem.IA_Controls = $desc.root.IAControls
				}catch{
					$uiClass.writeColor( "$($uiClass.STAT_ERROR)$green#$($rule.Title)# - Invalid Description Tag,  Can't Parse IA Controls")
				}
			}
			
			
			switch($vulns[$i].Node.result){
				"pass" {$reportItem.Status = "Completed"}
				"notselected" {$reportItem.Status = "Completed"}
				"fail" {$reportItem.Status = "Ongoing"}
				"error" {$reportItem.Status = "Error"}
				default {$reportItem.Status = "Ongoing"}
			}
					
			$source = (Select-Xml -Namespace $xmlNs -xpath "/cdf:Benchmark/cdf:title" $xml)
			$reportItem.Source = "$source"
					
			$reportItem.ShortSource = "SCAP"
			$reportItem.PluginId = ""
			$reportItem.RuleId = $vulns[$i].Node.idref
			$reportItem.VulnId = $rule.Node.ParentNode.id
			
			
			$reportItem.GrpId = $vulns[$i].Node.version
				
			if($reportItem.Status -ne 'Completed' -and "$h".trim() -ne ''){
				$this.addResult($h,$reportItem)
			}
		}
	}
	
	method parseCKLResult{
		param( [xml] $xml)
		
		#determine if this is an old or new version of the ckl
		$verCheck = select-xml "/CHECKLIST/STIGS/iSTIG" $xml
		
		$rmfMap = import-csv "$pwd\db\800-53_to_8500.2_mapping.csv"
			
		$cciXml = [xml](gc "$pwd\db\U_CCI_List.xml")
		$cciNs = new-object Xml.XmlNamespaceManager $cciXml.NameTable
		$cciNs.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance" );
		$cciNs.AddNamespace("ns", "http://iase.disa.mil/cci" );
			
		if( $utilities.isBlank( $verCheck ) -eq $false){
		
			$h = Select-Xml "/CHECKLIST/ASSET/HOST_NAME" $xml
			$uiClass.writeColor( "$($uiClass.STAT_WAIT)     Gathering results for system: #green#$($h)#" )
			$vulns = Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN" $xml
			$title = (select-xml "/CHECKLIST/STIGS/iSTIG/STIG_INFO/SI_DATA[./SID_NAME='title']/SID_DATA" $xml | select -expand Node | select innerXml).innerxml
			
			$version = ""
			$release = ""		
			$vrKey = "VR"
		
			$m = ([regex]::matches(  [io.path]::GetFilename( $private.currentScanFile ) , "V([0-9]+)R([0-9]+)" ) | select -expand groups)
			
			if($m.count -ge 1){
				$version = $m[1].value
				$release = $m[2].value
				$vrKey = "V$($version)R$($release)"
			}else{
				#its not in the filename, lets see if we have any matching stigs in the stig folder
				$cklRules = @()
				(select-xml "/CHECKLIST/STIGS/iSTIG/VULN/STIG_DATA[VULN_ATTRIBUTE='Rule_ID']/ATTRIBUTE_DATA" $xml )| %{
					$cklRules += $_.Node.'#text'
				}
			
				$ckls = ( gci .\stigs -recurse -include "*xccdf.xml" -exclude "*Benchmark*" | sort -descending )
				foreach($ckl in $ckls){
					
					$currentXml = ([xml](gc $ckl.fullname))
					
					$xccdfNs = new-object Xml.XmlNamespaceManager $currentXml.NameTable
					$xccdfNs.AddNamespace("dsig", "http://www.w3.org/2000/09/xmldsig#" );
					$xccdfNs.AddNamespace("xhtml", "http://www.w3.org/1999/xhtml" );
					$xccdfNs.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance" );
					$xccdfNs.AddNamespace("cpe", "http://cpe.mitre.org/language/2.0" );
					$xccdfNs.AddNamespace("dc", "http://purl.org/dc/elements/1.1/" );
					$xccdfNs.AddNamespace("ns", "http://checklists.nist.gov/xccdf/1.1" );
					
					if($title -eq $currentXml.Benchmark.title){
						$uiclass.writeColor("$($uiclass.STAT_WAIT) Attempting Version Match with #yellow#$($ckl.name)#")
						$stigRules = @()
						$currentXml.selectNodes('//ns:Benchmark/ns:Group/ns:Rule', $xccdfNs) | % { 
							$stigRules += $_.id 
						}
						
						$comparison = ( compare-object ($stigRules | sort) ($cklRules | sort ) )
						
						if($utilities.isBlank($comparison) -eq $true){
							$uiclass.writeColor("$($uiclass.STAT_OK) Match Found with #yellow#$($ckl.name)#")
							$version = ($currentXml.selectSingleNode("//ns:Benchmark/ns:version", $xccdfNs).'#text')
							$release = ( ( [regex]::matches( ($currentXml.selectSingleNode("//ns:Benchmark/ns:plain-text[@id='release-info']", $xccdfNs).'#text'), "Release: ([0-9.]+)") | select groups).groups[1] | select -expand value)
							$vrKey = "V$($version)R$($release)"
							$uiclass.writeColor("`t`tVersion: #green#$($version)#, Release: #green#$($release)#, VRKEY: #green#$($vrkey)#")
							break
						}
					}
				}
			}
			
			$scanDate =  (get-item "$($private.currentScanFile)" | select -expand LastWriteTime)
			
			#see if stigScapInfo key for this scap exists
			if($private.scans.ckl.keys -notcontains $title){
				$private.scans.ckl.$title = @{}
			}
			
			#see if this release is already in the stigScapInfo
			if($private.scans.ckl.$title.keys -notcontains $vrKey){
				$private.scans.ckl.$title.$vrKey = @{}
			}
			
			$private.scans.ckl.$title.$vrKey."$([io.path]::GetFilename( $private.currentScanFile ))" = @{}
			$private.scans.ckl.$title.$vrKey."$([io.path]::GetFilename( $private.currentScanFile ))".host = ( $h | select -expand Node | select innerXml).innerxml.toString().toLower()
			$private.scans.ckl.$title.$vrKey."$([io.path]::GetFilename( $private.currentScanFile );)".date = $scanDate
			
			for($i = 0; $i -lt $vulns.count; $i++){
				
				#create a report item
				$reportItem = @{}
				$reportItem.Title = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Rule_Title']/ATTRIBUTE_DATA" $xml)
				
				$reportItem.Description = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Vuln_Discuss']/ATTRIBUTE_DATA" $xml)
				$reportItem.RawRisk = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Severity']/ATTRIBUTE_DATA" $xml)
				
				$reportItem.Responsibility = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Responsibility']/ATTRIBUTE_DATA" $xml)
				
				$reportItem.Comments = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/COMMENTS" $xml)
				
				switch($reportItem.RawRisk){
					"low" 		{$reportItem.RawCat = "III"}
					"medium" 	{$reportItem.RawCat = "II"}
					"high" 		{$reportItem.RawCat = "I"}
					default 	{$reportItem.RawCat = "IV"}
				}
				$reportItem.Likelihood = "Low"
				$reportItem.Mitigation = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Fix_Text']/ATTRIBUTE_DATA" $xml)
				$reportItem.IA_Controls = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='IA_Controls']/ATTRIBUTE_DATA" $xml)
				
				#see if i can figure out what IA Control to use
				if($utilities.isBlank( $reportItem.IA_Controls.'#text' ) -eq $true){
					$cci = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='CCI_REF']/ATTRIBUTE_DATA" $xml | select -first 1)
					if($utilities.isBlank($cci) -eq $false){
						$cciNode  = $cciXml.selectSingleNode("//ns:cci_list/ns:cci_items/ns:cci_item[@id='$($cci)']", $cciNs)
						$rmfControl = $cciNode.references.reference | sort Version -descending | select -first 1 | select -expand index 
						
						$iaControl = ($rmfMap | ? { $_.'800-53' -eq "$($rmfControl -replace ' ','' -replace '\([a-z]\)','' )" } | select -expand '8500.2' )
						if($utilities.isBlank($iaControl)){
							$testRmf = $rmfControl -replace '\([a-z]\)','' -replace '\([0-9]+\)','' -replace ' [a-z]','' -replace ' ','' 
							$iaControl = ($rmfMap | ? { $_.'800-53' -eq $testRmf } | select -expand '8500.2' -first 1)
						}
						
						if($utilities.isblank($iaControl) -eq $false){
							$reportItem.IA_Controls = $iaControl
						}else{
							$reportItem.IA_Controls = ''
						}
					}
				}
				
				
				
				switch( Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STATUS" $xml ){
					"Open" 				{$reportItem.Status =  "Ongoing"}
					"NotAFinding" 		{$reportItem.Status =  "Completed"}
					"Not_Applicable" 	{$reportItem.Status =  "Completed"}
					default 			{$reportItem.Status =  "Ongoing"}
				}
				
				$source = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='STIGRef']/ATTRIBUTE_DATA" $xml)
				$reportItem.Source = "$source"
				
				$reportItem.ShortSource = "CKL"
				$reportItem.PluginId = ""
				$reportItem.RuleId = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Rule_ID']/ATTRIBUTE_DATA" $xml)
				$reportItem.VulnId = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Vuln_Num']/ATTRIBUTE_DATA" $xml)
				$reportItem.GrpId = (Select-Xml "/CHECKLIST/STIGS/iSTIG/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Group_Title']/ATTRIBUTE_DATA" $xml)
				if($utilities.isBlank("$($reportItem.RuleId)$($reportItem.vulnid)$($reportItem.grpId)".Trim() ) -eq $false  ){
					$this.addResult($h,$reportItem)
				}
			}
		
		}else{
			$h = Select-Xml "/CHECKLIST/ASSET/HOST_NAME" $xml
			$uiClass.writeColor( "$($uiClass.STAT_WAIT)     Gathering results for system: #green#$($h)#" )
			
			$vulns = Select-Xml "/CHECKLIST/VULN" $xml
			
			if($utilities.isBlank($vulns) -eq $false){
				$uiClass.writeColor("$($uiClass.STAT_OK)     #green#$($vulns.count)# findings")
			}else{
				$uiClass.writeColor("$($uiClass.STAT_OK)     #green#0# findings")
			}
			

			$version = ""
			$release = ""		
			$vrKey = "VR"

			$title = (Select-Xml "/CHECKLIST/STIG_INFO/STIG_TITLE" $xml | select -expand Node | select innerXml).innerxml
			$m = ([regex]::matches(  [io.path]::GetFilename( $private.currentScanFile ) , "V([0-9]+)R([0-9]+)" ) | select -expand groups)
			if($m.count -ge 1){
				$version = $m[1].value
				$release = $m[2].value
				$vrKey = "V$($version)R$($release)"
			}else{
			
				#its not in the filename, lets see if we have any matching stigs in the stig folder
				$cklRules = @()
				(Select-Xml "/CHECKLIST/VULN/STIG_DATA[VULN_ATTRIBUTE='Rule_ID']/ATTRIBUTE_DATA" $xml )| %{
					# $utilities.dump( ($_ | gm ) )
					$cklRules += $_.Node.'#text'
				}
			
				$ckls = ( gci .\stigs -recurse -include "*xccdf.xml" -exclude "*Benchmark*" | sort -descending )
				foreach($ckl in $ckls){
					
					$currentXml = ([xml](gc $ckl.fullname))
					
					$xccdfNs = new-object Xml.XmlNamespaceManager $currentXml.NameTable
					$xccdfNs.AddNamespace("dsig", "http://www.w3.org/2000/09/xmldsig#" );
					$xccdfNs.AddNamespace("xhtml", "http://www.w3.org/1999/xhtml" );
					$xccdfNs.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance" );
					$xccdfNs.AddNamespace("cpe", "http://cpe.mitre.org/language/2.0" );
					$xccdfNs.AddNamespace("dc", "http://purl.org/dc/elements/1.1/" );
					$xccdfNs.AddNamespace("ns", "http://checklists.nist.gov/xccdf/1.1" );
					
					if($title -eq $currentXml.Benchmark.title){
						$uiclass.writeColor("$($uiclass.STAT_WAIT) Attempting Version Match with #yellow#$($ckl.name)#")
						$stigRules = @()
						$currentXml.selectNodes('//ns:Benchmark/ns:Group/ns:Rule', $xccdfNs) | % { 
							$stigRules += $_.id 
						}
						
						$comparison = ( compare-object ($stigRules | sort) ($cklRules | sort ) )
						
						if($utilities.isBlank($comparison) -eq $true){
							$uiclass.writeColor("$($uiclass.STAT_OK) Match Found with #yellow#$($ckl.name)#")
							$version = ($currentXml.selectSingleNode("//ns:Benchmark/ns:version", $xccdfNs).'#text')
							$release = ( ( [regex]::matches( ($currentXml.selectSingleNode("//ns:Benchmark/ns:plain-text[@id='release-info']", $xccdfNs).'#text'), "Release: ([0-9.]+)") | select groups).groups[1] | select -expand value)
							$vrKey = "V$($version)R$($release)"
							$uiclass.writeColor("`t`tVersion: #green#$($version)#, Release: #green#$($release)#, VRKEY: #green#$($vrkey)#")
							break
						}
						
					}
					
				}
				
			}
			
			$scanDate =  (get-item "$($private.currentScanFile)" | select -expand LastWriteTime)
			
			#see if stigScapInfo key for this scap exists
			if($private.scans.ckl.keys -notcontains $title){
				$private.scans.ckl.$title = @{}
			}
			
			#see if this release is already in the stigScapInfo
			if($private.scans.ckl.$title.keys -notcontains $vrKey){
				$private.scans.ckl.$title.$vrKey = @{}
			}
			
			$private.scans.ckl.$title.$vrKey."$([io.path]::GetFilename( $private.currentScanFile ))" = @{}
			$private.scans.ckl.$title.$vrKey."$([io.path]::GetFilename( $private.currentScanFile ))".host = ( $h | select -expand Node | select innerXml).innerxml.toString().toLower()
			$private.scans.ckl.$title.$vrKey."$([io.path]::GetFilename( $private.currentScanFile );)".date = $scanDate
			
			
			
			
			for($i = 0; $i -lt $vulns.count; $i++){
				#create a report item
				$reportItem = @{}
				$reportItem.Title = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Rule_Title']/ATTRIBUTE_DATA" $xml)
				
				$reportItem.Description = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Vuln_Discuss']/ATTRIBUTE_DATA" $xml)
				$reportItem.RawRisk = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Severity']/ATTRIBUTE_DATA" $xml)
				
				$reportItem.Responsibility = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Responsibility']/ATTRIBUTE_DATA" $xml)
				
				$reportItem.Comments = (Select-Xml "/CHECKLIST/VULN[$i]/COMMENTS" $xml)
				
				switch($reportItem.RawRisk){
					"low" 		{$reportItem.RawCat = "III"}
					"medium" 	{$reportItem.RawCat = "II"}
					"high" 		{$reportItem.RawCat = "I"}
					default 	{$reportItem.RawCat = "IV"}
				}
				$reportItem.Likelihood = "Low"
				$reportItem.Mitigation = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Fix_Text']/ATTRIBUTE_DATA" $xml)
				$reportItem.IA_Controls = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='IA_Controls']/ATTRIBUTE_DATA" $xml)
				
				
				#see if i can figure out what IA Control to use
				if($utilities.isBlank( $reportItem.IA_Controls.'#text' ) -eq $true){
					$cci = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='CCI_REF']/ATTRIBUTE_DATA" $xml | select -first 1)
					if($utilities.isBlank($cci) -eq $false){
						$cciNode  = $cciXml.selectSingleNode("//ns:cci_list/ns:cci_items/ns:cci_item[@id='$($cci)']", $cciNs)
						$rmfControl = $cciNode.references.reference | sort Version -descending | select -first 1 | select -expand index 
						
						$iaControl = ($rmfMap | ? { $_.'800-53' -eq "$($rmfControl -replace ' ','' -replace '\([a-z]\)','' )" } | select -expand '8500.2' )
						if($utilities.isBlank($iaControl)){
							$testRmf = $rmfControl -replace '\([a-z]\)','' -replace '\([0-9]+\)','' -replace ' [a-z]','' -replace ' ','' 
							$iaControl = ($rmfMap | ? { $_.'800-53' -eq $testRmf } | select -expand '8500.2' -first 1)
						}
						
						if($utilities.isblank($iaControl) -eq $false){
							$reportItem.IA_Controls = $iaControl
						}else{
							$reportItem.IA_Controls = ''
						}
					}
				}
				
				
				switch( Select-Xml "/CHECKLIST/VULN[$i]/STATUS" $xml ){
					"Open" 				{$reportItem.Status =  "Ongoing"}
					"NotAFinding" 		{$reportItem.Status =  "Completed"}
					"Not_Applicable" 	{$reportItem.Status =  "Completed"}
					default 			{$reportItem.Status =  "Ongoing"}
				}
				
				$source = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='STIGRef']/ATTRIBUTE_DATA" $xml)
				$reportItem.Source = "$source"
				
				$reportItem.ShortSource = "CKL"
				$reportItem.PluginId = ""
				$reportItem.RuleId = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Rule_ID']/ATTRIBUTE_DATA" $xml)
				$reportItem.VulnId = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Vuln_Num']/ATTRIBUTE_DATA" $xml)
				$reportItem.GrpId = (Select-Xml "/CHECKLIST/VULN[$i]/STIG_DATA[VULN_ATTRIBUTE='Group_Title']/ATTRIBUTE_DATA" $xml)
				if($utilities.isBlank("$($reportItem.RuleId)$($reportItem.vulnid)$($reportItem.grpId)".Trim() ) -eq $false  ){
					$this.addResult($h,$reportItem)
				}
			}
		
		}
	}
	
	method parseScanResult{
		param(
			[string] $scanPath
		)
		
		$file = gci $scanPath
		$gss = $uiClass.getShortString("$($file.Name.ToString())" ,60)
		
		switch($file.extension){
			".xml" 		{ [xml]$scanData = Get-Content $scanPath }
			".nessus" 	{ [xml]$scanData = Get-Content $scanPath }
			".ckl" 		{ [xml]$scanData = Get-Content $scanPath }
			default 	{ $scanData = $null }
		}
		
		#see which type of result this is
		if($scanData.Benchmark -ne $null){
			$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing XCCDF file: #yellow#$gss#")
			$this.parseXCCDFResult($scanData)
		}elseif($scanData.CHECKLIST -ne $null){
			$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing .ckl file: #yellow#$gss#")
			$this.parseCKLResult($scanData)
		}elseif($scanData.NessusClientData_v2 -ne $null){
			$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing .Nessus file: #yellow#$gss#")
			$this.parseNessusResult($scanData)
		}else{
			 if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
				$uiClass.writeColor("$($uiClass.STAT_WARN) #yellow#$($gss)# is an unknown file type.  Skipping...")
			}
		}
	}
	
	method findScanResults{
		param(
			[string] $scanPath
		)
		
		$t = @()
		#these are ordered by reverse write time.  so the latest is processed first.  Any updates will only add host names and comments.  
		#not perfect, but you shouldn't be processing multiple sets of scans at the same time.
		if($private.recurse){
			gci $scanPath -recurse | ? { !$_.PSIsContainer } | ? { $Scans2PoamClass.parseExtensions -contains $_.extension } | Sort-Object LastWriteTime -Descending | %{ 
				if($t -notcontains $_.name ){ 
					$this.scanResults  += $_.FullName; 
					$t += $_.name 
				}
			}
		}else{
			gci $scanPath |  where { !$_.PSIsContainer } | where { $Scans2PoamClass.parseExtensions -contains $_.extension } | Sort-Object  LastWriteTime -Descending | %{ 
				if($t -notcontains $_.name){ 
					$this.scanResults  += $_.FullName; 
					$t += $_.name 
				} 
			}
		}
	}
	
	method Execute{
		$this.findScanResults($private.scanLocation)
		$startP = 10 
		$currentScan = 1
		$totalScans = $this.ScanResults.count
		$this.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "$currentScan / $totalScans : Parsing file $_"; "Status" = ("{0:N2}% complete" -f $i); "PercentComplete" = $i; "Completed" = $false; "id" = 1 }).Render() 
		
		$this.scanResults | % {
			$i = 10 + (40*($currentScan / $totalScans))
			
			$this.mainProgressBar.Activity("$currentScan / $totalScans : Parsing file $_").Status("{0:N2}% complete" -f $i).Percent($i).Render()
			
			$private.currentScanFile = $_
			
			
			if($_ -like '*.zip'){
				
				$TempDir = [System.Guid]::NewGuid().ToString()
				New-Item -Type Directory -force  "$($pwd)\temp\$($tempDir)" 
				#unzip file here
				
				$shellApplication = new-object -com shell.application
				$zipPackage = $shellApplication.NameSpace($_)
				$destinationFolder = $shellApplication.NameSpace("$($pwd)\temp\$($tempDir)")
				$destinationFolder.CopyHere($zipPackage.Items())
				
				gci "$($pwd)\temp\$($tempDir)" -recurse | %{
					$this.parseScanResult($_.FullName)
				}

				Remove-Item "$($pwd)\temp\$($TempDir)\*.*" -Force
				Remove-Item "$($pwd)\temp\$($TempDir)"

			}else{
				$this.parseScanResult($_)
			}
			$currentScan++
		}
		
		$this.mainProgressBar.Activity("Exporting to Excel").Status("{0:N2}% complete" -f 66).Percent(66).Render()
		$this.export()
	}
	
	constructor{
		param(
			$scanLocation,
			$recurse
		)
		$private.scanLocation = $scanLocation
		$private.recurse = $recurse
		
		while($private.scanLocation -eq $null -or $private.scanLocation -eq ""){
			$private.gui = $null
			$private.gui = $guiClass.New("scans2poam.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnOpenFolderBrowser.add_Click({ $private.gui.Controls.txtScanLocation.Text = $private.gui.actInvokeFolderBrowser() })
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.scanLocation = $private.gui.Controls.txtScanLocation.Text
			
			if($private.gui.Controls.chkRecurse.checked){
				$private.recurse = $true
			}
		}
	}
}

$Scans2PoamClass.New($scanLocation, $recurse).Execute() | out-null