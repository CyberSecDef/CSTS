<#
.SYNOPSIS
	This is a script that will generate a report showing which hosts have open IAVMs per VRAM
.DESCRIPTION
	This is a script that will generate a report showing which hosts have open IAVMs per VRAM
.PARAMETER acasFilePath
	The path to a CSV export from ACAS of all open findings for the department
.PARAMETER vramFilePath
	The path to a CSV Export from VRAM showing all audits with their applicable ACAS Plugin Ids
.PARAMETER hostMapFilePath
	The path to a CSV Export from hostMap matching all hosts to their applicable packages.  The csv file must have the following columns (minus the quotes)
	'Hostname'
	'IPv4 Address'
	'MAC Address'
	'Package ID'
.EXAMPLE
	C:\PS>.\vram2AcasVulnClass.ps1 -acasFilePath "C:\scans\acasHosts.csv" -vramFilePath "C:\scans\vramAudits.csv" -hostMapFilePath "C:\scans\hostMapPackages.csv"
	This example will generate a report based off the specified csv files
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Nov 03, 2015
#>
[CmdletBinding()]
Param( [string]$acasFilePath, [string]$vramFilePath, [string]$hostMapFilePath, [string]$logoPath, [string]$repository )
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

#TODO: GUI

$vram2AcasVulnClass = new-PSClass vram2AcasVuln{
	note -static PsScriptName "vram2AcasVulnClass"
	note -static Description ( ($(((get-help .\scans2poam.ps1).Description)) | select Text).Text)
	
	note -static confNotice "Confidential: The following report contains confidential information. Do not distribute, email, fax, or transfer via any electronic mechanism unless it has been approved by the recipient company's security policy. All copies and backups of this document should be saved on protected storage at all times. Do not share any of the information contained within this report with anyone unless they are authorized to view the information. Violating any of the previous instructions is grounds for termination."
	# Variable: mainProgressBar 
	# A Container for the main script progress bar
	note -private mainProgressBar
	
	note -private repository 'Q Dept Vulnerabilties'
	note -private acasFilePath
	note -private vramFilePath
	note -private hostMapFilePath
	note -private logoPath
	
	note -private acas
	note -private vram
	note -private hostMap
	
	note -private pdf
	 
	method -private makeHeader{
		param(
			[string]$package = ""
		)
		
		$private.pdf = $pdfClass.new(
			"$($pwd)\results\vram2AcasVulnerabilities_$($package)_$(get-date -format 'yyyyMMddHHmmss').pdf",
			"$(((whoami).ToString().substring((whoami).indexOf('\')+1)))",
			40,40,40,40				
		) 
		$private.pdf.open() | out-null
		
		$topSpacing = 200
		if($utilities.isBlank($private.logoPath) -eq $false){
			[iTextSharp.text.Image]$img = [iTextSharp.text.Image]::GetInstance("$($private.logoPath)")
			$img.ScaleToFit(200, 200) | out-null
			$img.Alignment = [iTextSharp.text.Element]::ALIGN_CENTER
			$private.pdf.Add($img) | out-null
			$topSpacing = 0
		}

		$private.pdf.add(( $private.pdf.createParagraph( "`nVRAM and ACAS`n`nOpen Finding Cross-Mapping", "ALIGN_CENTER", $topSpacing, 20, ( $private.pdf.createFont("Verdana",36,"BOLD","Black",@(67,87,100)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$($package)", "ALIGN_LEFT", 80, 10, ( $private.pdf.createFont("Verdana",24,"BOLD","Black",@(0,165,181)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$(get-date -format 'MMMM d, yyyy a\t HH:mm')", "ALIGN_LEFT", 0, 20, ( $private.pdf.createFont("Verdana",18,"NORMAL","Black",@(67,87,100)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$(((whoami).ToString().substring((whoami).indexOf('\')+1)))", "ALIGN_LEFT", 20, 10, ( $private.pdf.createFont("Verdana",18,"NORMAL","Black",@(67,87,100)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$($vram2AcasVulnClass.confNotice)", "ALIGN_LEFT", 10, 20, ( $private.pdf.createFont("Verdana",10,"NORMAL","Black",@(93,107,120)) ) )  ).results) | out-null
		$private.pdf.doc.NewPage() | out-null
	}
	
	method execute{
		param()
	
		#add any vram audits in the iavm folder to the db
		$insertSql = "insert into iavm (iavm, acknowledge, mitigation, summary) values (:iavm, :acknowledge, :mitigation, :summary);"
		$selectSql = "select iavm from iavm where iavm = :iavm and acknowledge = :acknowledge and mitigation = :mitigation and summary = :summary;"

		$uiclass.writeColor("$($uiclass.STAT_WAIT) Consuming New IAVM Files")
		$iavmFiles = gci -include "*.xml" -path '.\iavm\' -recurse | ? { $_.name -match "[0-9]+-[AB]-[0-9]+.+\.xml" } 
		if($iavmFiles.count -gt 0){
			foreach($iavmFile in $iavmFiles){
				$iavm = [xml](get-content $iavmFile.fullname)
				$res = $dbclass.get().query($selectSql, @{ ":iavm" = $($iavm.iavmNotice.iavmNoticeNumber); ":acknowledge" = $($iavm.iavmNotice.acknowledgeDate); ":mitigation" = $($iavm.iavmNotice.poamMitigationDate); ":summary" = $($iavm.iavmNotice.executiveSummary) }).execAssoc(); 			
				if( $res.count  -eq 0 ){
					$dbclass.get().query($insertSql, @{ ":iavm" = $($iavm.iavmNotice.iavmNoticeNumber); ":acknowledge" = $($iavm.iavmNotice.acknowledgeDate); ":mitigation" = $($iavm.iavmNotice.poamMitigationDate); ":summary" = $($iavm.iavmNotice.executiveSummary) }).execNonQuery();
				}
				
				remove-item $iavmFile.fullname
			}
		}
		
		$vramAcasAudits = $private.vram | sort 'Nessus Id' -unique | select -expand 'Nessus Id'
				
		$packages = ($private.hostMap | select 'Package Id' -unique | sort 'Package ID' ) 
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		
		$currentPackage = 0
		
		foreach($package in $packages){
			$currentPackage++
			$i = (100*($currentPackage / $packages.count))
			$private.mainProgressBar.Activity("$currentPackage / $($packages.count) : Processing Package $($package.'Package ID')").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Processing Package $($package.'Package ID')")

			$packageHosts = $private.hostMap | ? { $_.'Package Id' -eq $package.'Package Id' } | ? { $utilities.isBlank($_.Hostname) -eq $false } |  Sort Hostname 
			
			if($packageHosts.count -gt 0 ){
				$validFinding = $false
				$hostProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
				$private.makeHeader( $($package.'Package Id') )
				
				$private.pdf.add(( $private.pdf.createParagraph( "Findings Grouped By Hostname:", "ALIGN_LEFT", 5, 5, ( $private.pdf.createFont("Verdana",18,"BOLD","Black",@(0,165,181)) ) )  ).results) | out-null
				$currentHost = 0
				
				foreach($hostName in $packageHosts ){
				
					$first = $true
					$currentHost++
					if($packageHosts.count -ne $null){
						$j = (100*($currentHost / $packageHosts.count))
					}else{
						$j = 100
					}
				
					$hostProgressBar.Activity("$currentHost / $($packageHosts.count) : Analysing findings for system $($hostName.hostname)").Status(("{0:N2}% complete" -f $j)).Percent($j).Render()

					$hostAcasFindings = ($private.acas | ? { $_.'DNS Name' -like "$($hostname.hostname)*" } | Select * -unique | Sort Plugin)
					$Dataset = @()

					foreach($acasFinding in $hostAcasFindings){
						if($vramAcasAudits -contains "$($acasFinding.plugin)"){
							$validFinding = $true
							if($first){
								$first = $false
								$uiclass.writeColor( "$($package.'Package ID') --> #green#$($hostName.hostname)#")
							}
							foreach($vramFinding in ( $private.vram | ? { $_.'Nessus ID' -eq "$($acasFinding.plugin)"} | Sort title ) ){
								
								#determine length of string to output using powershell unary function....similiar to ( test ? true response : false response)
								$l = @( (($vramFinding.title.toString().length) - 1), 83 )[ (($vramFinding.title.toString().length) - 1) -gt 83]
								$uiclass.writeColor( "    #yellow#$($vramFinding.'IAV ID')# : #green#$($acasFinding.plugin)# - $( $vramFinding.Title.ToString().substring(0,$l) )" )

								$iavmData = "$($vramFinding.'IAV ID') - ($($vramFinding.'Status')) "
								$iavmDb = $dbClass.get().query("select id, iavm, acknowledge, mitigation, summary from iavm where iavm = :iavm", @{ "iavm" = "$($vramFinding.'IAV ID')" }).execAssoc()
								if($iavmDb.count -gt 0){
									#powershell is dumb....see if this is an array or hash
									if($iavmDb.getType() -like '*hashtable*'){
										$iavmDbData = $iavmDb
									}else{
										$iavmDbData = $iavmDb[0]
									}	
									
									$iavmData += "`nAcknowledge: "
									if( $utilities.isBlank($iavmDbData.acknowledge) -eq $false ){
										$iavmData += $( ( [datetime]($iavmDbData.acknowledge)).toString('MM/dd/yyyy') )
									}
									$iavmData += "`nComply: "
									if( $utilities.isBlank( $($iavmDbData.mitigation) ) -eq $false ){
										$iavmData += $( ( [datetime]($iavmDbData.mitigation)).toString('MM/dd/yyyy') )
									}
									
								}else{
									$iavmFile = (gci ".\iavm\$($vramFinding.'IAV ID')*" | select -first 1).FullName
									if($utilities.isBlank($iavmFile) -eq $false -and (test-path $iavmFile) -eq $true){
										$iavm = [xml](get-content $iavmFile)
										$iavmData += "`nAcknowledge: $($iavm.iavmNotice.acknowledgeDate)`nComply: $($iavm.iavmNotice.poamMitigationDate)"
									}
								}
								 
								$Dataset += $iavmData
								$Dataset += "$($acasFinding.plugin)"
								$dataset += "$($acasFinding.Severity)"
								$Dataset += "$($acasFinding.Family): $($vramFinding.Title)"
							}
						}
					}
					
					if($Dataset.count -gt 0){
						
						$t = New-Object iTextSharp.text.pdf.PDFPTable(4)
						$t.WidthPercentage = 100 
						$t.SetWidths(@( 2, 1, 1, 6)) | out-null
						$t.SpacingBefore = 5
						$t.SpacingAfter = 5
						$t.HorizontalAlignment = 0
						$t.KeepTogether = $true
						
						$hostnameCell = New-Object iTextSharp.text.pdf.PDFPCell
						$hostnameCell.colspan = 4
						$hostnameCell.BackgroundColor = ( new-object iTextSharp.text.BaseColor( 0, 165, 181) );
						$hostnameCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
						
						$hostnameCell.addElement(( $private.pdf.createParagraph( "$($hostname.Hostname) / $($hostname.'IPv4 Address') - [$($hostname.'MAC Address')]", "ALIGN_CENTER", 5, 5, ( $private.pdf.createFont("Verdana",12,"BOLD","White",@(255,255,255)) ) )  ).results) | out-null
						
						$t.AddCell( $hostnameCell ) | out-null
						
						 @("IAVA","Plugin","Severity", "Title/Description") | % {
							$colHeader = New-Object iTextSharp.text.pdf.PDFPCell
							$colHeader.BackgroundColor = ( new-object iTextSharp.text.BaseColor( 0, 165, 181) )
							$colHeader.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
							
							$colHeader.addElement(( $private.pdf.createParagraph( "$($_)", "ALIGN_CENTER", 5, 5, ( $private.pdf.createFont("Verdana",12,"BOLD","White",@(255,255,255)) ) )  ).results) | out-null
							$t.AddCell( $colHeader ) | out-null
						}
											
						foreach($data in $Dataset){
							$cell = New-Object iTextSharp.text.pdf.PDFPCell
							$p = (( $private.pdf.createParagraph( "$($data)", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",8,"Normal","Black",@(0,0,0)) ) )  ).results)
							
							switch($data){
								"Critical" {$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(165,44,206) ); $p.Font.SetColor(250,250,250) }
								"High" {$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(211,31,32) ); $p.Font.SetColor(250,250,250) }
								"Medium" {$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(219,131,43) ); $p.Font.SetColor(250,250,250) }
								"Low" {$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(219,128,37) ); $p.Font.SetColor(0,0,0) }
								default {$cell.BackgroundColor = [iTextSharp.text.BaseColor]::White; $p.Font.SetColor(0,0,0) } 	
							}
							
							if($data.length -lt 15){
								$p.Alignment = ( [iTextSharp.text.Element]::ALIGN_CENTER );
								$p.Font.SetStyle('bold');
							}
							
							$p.SetLeading(0, 1) 

							$cell.addElement( $p ) | out-null
							$t.AddCell( $cell ) | out-null
						}
						$private.pdf.Add($t) | out-null
					}
				}
				
				$hostProgressBar.Completed($true).Render()
				
				$iavmProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 3 }).Render() 
				
				$private.pdf.doc.NewPage() | out-null
				$private.pdf.add(( $private.pdf.createParagraph( "Findings Grouped By IAVM:", "ALIGN_LEFT", 5, 5, ( $private.pdf.createFont("Verdana",18,"BOLD","Black",@(0,165,181)) ) )  ).results) | out-null
				
				$iavmProgressBar.Activity("Parsing hostMap Exports for Valid Hosts").Status(("{0:N2}% complete" -f 15)).Percent(25).Render()			
				$packageHosts = ($private.hostMap | ? { $_.'Package Id' -eq $package.'Package Id' } | ? { $utilities.isBlank($_.Hostname) -eq $false } | Sort Hostname | select -expand Hostname)
				
				$iavmProgressBar.Activity("Parsing Acas Audits for Valid Plugins").Status(("{0:N2}% complete" -f 30)).Percent(25).Render()
				$validAcas = ( $private.acas | ? {
					$indexOf = $_.'DNS Name'.indexOf(".");
					if($indexOf -gt -1){
						$domain = $_.'DNS Name'.substring($indexOf);
						return ( $packageHosts -contains ($_.'DNS Name').replace( $domain, '' ))
					}else{
						if( $packageHosts -contains $_.'DNS Name'){
							return $true
						}else{
							return $false
						}
					}
					
				} | Select * -unique | Sort Plugin )
				
				$iavmProgressBar.Activity("Cross Referencings ACAS Plugins with VRAM IAVMs").Status(("{0:N2}% complete" -f 45)).Percent(25).Render()
				
				$validPlugins = ($validAcas | select -expand Plugin -unique | sort )
				$validAudits = $private.vram | ? { $_.'Nessus ID' -ne ''}  | ? {$validPlugins -contains ($_.'Nessus ID') } | sort 'Nessus ID'
				$currentAudit = 0
				foreach($audit in $validAudits){
					$currentAudit++
					if($validAudits.count -ne $null){
						$j = 50 + (50*($currentAudit / $validAudits.count))
					}else{
						$j = 100
					}

					$iavmProgressBar.Activity("$currentAudit / $($validAudits.count) : Analysing findings for IAVM $($audit.'IAV ID') - $($audit.title)").Status(("{0:N2}% complete" -f $j)).Percent($j).Render()
				
					$currentAcas = $validAcas | ? { $_.plugin -eq $audit.'Nessus ID' } | sort 'DNS Name'
					if($utilities.isBlank( $($audit.'IAV ID') ) -eq $false ){
						$validFinding = $true
						
						$iavmFile = (gci ".\iavm\$($audit.'IAV ID')*" | select -first 1).FullName
						$iavmData = ""
						$iavmSummary = ""
						if($utilities.isBlank($iavmFile) -eq $false -and (test-path $iavmFile) -eq $true){
							$iavm = [xml](get-content $iavmFile)
							
							$iavmSummary = $($iavm.iavmNotice.executiveSummary)
							if($utilities.isBlank($iavm) -eq $false){
								$iavmData += "`nAcknowledge: $($iavm.iavmNotice.acknowledgeDate)`nComply: $($iavm.iavmNotice.poamMitigationDate)"
							}
						}
								
						$t = New-Object iTextSharp.text.pdf.PDFPTable(6)
						$t.KeepTogether = $true
						$t.WidthPercentage = 100 
						$t.SetWidths(@( 1, 1, 2, 2, 2, 2) ) | out-null
						$t.SpacingBefore = 5
						$t.SpacingAfter = 5
						$t.HorizontalAlignment = 0
							
						$iavaCell = New-Object iTextSharp.text.pdf.PDFPCell
						$iavaCell.colspan = 6
						$iavaCell.BackgroundColor = ( new-object iTextSharp.text.BaseColor( 0, 165, 181) );
						$iavaCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
						
						$iavaCell.addElement(( $private.pdf.createParagraph("$($audit.'IAV ID') ( $($audit.status) )`n$($audit.title)$($iavmData)", "ALIGN_LEFT", 5, 5, ( $private.pdf.createFont("Verdana",10,"BOLD","White",@(255,255,255)) ) )  ).results) | out-null
						
						$t.AddCell( $iavaCell ) | out-null

						if($utilities.isBlank($iavmSummary) -eq $false){
							$iavaSummCell = New-Object iTextSharp.text.pdf.PDFPCell
							$iavaSummCell.colspan = 6
							$iavaSummCell.BackgroundColor = ( new-object iTextSharp.text.BaseColor( 237,239,239 ) )
							$iavaSummCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_LEFT;
							$iavaSummCell.addElement(( $private.pdf.createParagraph("$($iavmSummary)", "ALIGN_LEFT", 5, 5, ( $private.pdf.createFont("Verdana",10,"Normal","Black",@(0,0,0)) ) )  ).results) | out-null
							$t.AddCell( $iavaSummCell ) | out-null
						}
						
						@("Plugin","Severity","Family", "Hostname", "IP Address","MAC Address") | % {

							$colHeader = New-Object iTextSharp.text.pdf.PDFPCell
							$colHeader.BackgroundColor = ( new-object iTextSharp.text.BaseColor( 0, 165, 181) )
							$colHeader.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;

							$p = New-Object iTextSharp.text.Paragraph
							$p.font = [iTextSharp.text.FontFactory]::GetFont("Verdana", 12, [iTextSharp.text.Font]::BOLD, [iTextSharp.text.BaseColor]::White)
							

							$colHeader.addElement(( $private.pdf.createParagraph("$($_)", "ALIGN_CENTER", 5, 5, ( $private.pdf.createFont("Verdana",12,"BOLD","White",@(255,255,255)) ) )  ).results) | out-null
							
							$t.AddCell( $colHeader ) | out-null
						}
						
						$dataset = @()
						foreach($acasHost in $currentAcas){
							$dataset += $($acasHost.plugin)
							$dataset += $($acasHost.severity) 
							$dataset += $($acasHost.family)
							$dataset += $($acasHost.'dns Name') 
							$dataset += $($acasHost.'ip address')
							$dataset += $($acasHost.'mac address')
						}
						
						if($Dataset.count -gt 0){
							foreach($data in $dataset){
								$cell = New-Object iTextSharp.text.pdf.PDFPCell
								
								$p = (( $private.pdf.createParagraph( "$($data)", "ALIGN_CENTER", 0, 0, ( $private.pdf.createFont("Verdana",8,"Normal","Black",@(0,0,0)) ) )  ).results)
								
								switch($data){
									"Critical" {$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(165,44,206) ); $p.Font.SetColor(250,250,250); $p.font.setStyle('bold'); }
									"High" {$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(211,31,32) ); $p.Font.SetColor(250,250,250); $p.font.setStyle('bold'); }
									"Medium" {$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(219,131,43) ); $p.Font.SetColor(250,250,250); $p.font.setStyle('bold'); }
									"Low" {$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(219,128,37) ); $p.Font.SetColor(0,0,0); $p.font.setStyle('bold'); }
									default {$cell.BackgroundColor = [iTextSharp.text.BaseColor]::White; $p.Font.SetColor(0,0,0); $p.font.setStyle('normal'); } 	
								}
								
								$p.SetLeading(0, 1) 
								$cell.addElement( $p ) | out-null
								$t.AddCell( $cell ) | out-null
							}
							$private.pdf.Add($t) | out-null
						}
					}
				}
				
				if($validFinding -eq $true){
					$private.pdf.Close()
				}else{
					$private.pdf.Close()
					remove-item $private.pdf.filename
				}
				$iavmProgressBar.Completed($true).Render()
			}
		}
		$private.mainProgressBar.Completed($true).Render()
	}
	
	
	constructor{
		param()
		
		$private.repository = $repository
		$private.acasFilePath = $acasFilePath
		$private.vramFilePath = $vramFilePath
		$private.hostMapFilePath = $hostMapFilePath
		$private.logoPath = $logoPath
		
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Parsing input files...")
		$private.vram    = import-csv "$($private.vramFilePath)"    | ? { $utilities.isBlank( $_.'Nessus ID') -eq $false }
		$private.acas    = import-csv "$($private.acasFilePath)"    | ? { $_.Severity -ne 'Info' } | ? { $_.Repository -like "*$($private.repository)*" } 
		$private.hostMap = import-csv "$($private.hostMapFilePath)" | ? { $utilities.isBlank( $_.'IPv4 Address') -eq $false }
		
	}
}

$vram2AcasVulnClass.New().execute() | out-null