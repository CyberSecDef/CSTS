<#
.SYNOPSIS
	This is a script that will generate a report based on the current SCAP Scans
.DESCRIPTION
	This is a script that will generate a report based on the current SCAP Scans
.EXAMPLE
	C:\PS>.\scap2report.ps1 -acasFilePath "C:\scans\acasHosts.csv" -vramFilePath "C:\scans\vramAudits.csv" -hostMapFilePath "C:\scans\hostMapPackages.csv"
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
Param( 
	$ipaPath = 'C:\tsg\ipa_hosts_20161107.csv',
	$scapPath = 'C:\sandbox\scc_4.1.1\Results\SCAP',
	[switch] $reset,
	[switch] $skip,
	[switch] $out,
	$first = $null,
	$selPackage = $null
)
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$scap2report = new-PSClass vram2AcasVuln{
	note -static PsScriptName "scap2report"
	note -static Description ( ($(((get-help .\scans2poam.ps1).Description)) | select Text).Text)
	
	note -static confNotice "Confidential: The following report contains confidential information. Do not distribute, email, fax, or transfer via any electronic mechanism unless it has been approved by the recipient company's security policy. All copies and backups of this document should be saved on protected storage at all times. Do not share any of the information contained within this report with anyone unless they are authorized to view the information. Violating any of the previous instructions is grounds for termination."
	
	note -static scanDetailTableOptions @{
		WidthPercentage = 100;
		SpacingBefore = 5;
		SpacingAfter = 5;
		HorizontalAlignment = 0;
		KeepTogether = $true;
	}
	
	note -static headerBackground ( new-object iTextSharp.text.BaseColor( 0, 165, 181) )
	
	note -static dbPath "$($pwd)\db\scap_results.xml"
	
	# Variable: mainProgressBar 
	# A Container for the main script progress bar
	note -private mainProgressBar
		
		
	note -private ipaPath
	note -private ipa
	note -private scapPath
	note -private scanData (new-object system.collections.arraylist)
	
	note -private reset
	note -private skip
	note -private out
	note -private first
	note -private selPackage
	
	note -private pdf
	 
	method pdfMakeHeader{
		param(
			$packageData
		)
		
		$topSpacing = 200
		$private.pdf.add(( $private.pdf.createParagraph( "`nSCAP Scan Summary", "ALIGN_CENTER", $topSpacing, 20, ( $private.pdf.createFont("Verdana",36,"BOLD","Black",@(67,87,100)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$($packageData.packageName)", "ALIGN_LEFT", 80, 10, ( $private.pdf.createFont("Verdana",24,"BOLD","Black",@(0,165,181)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$(get-date -format 'MMMM d, yyyy a\t HH:mm')", "ALIGN_LEFT", 0, 20, ( $private.pdf.createFont("Verdana",18,"NORMAL","Black",@(67,87,100)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$(((whoami).ToString().substring((whoami).indexOf('\')+1)))", "ALIGN_LEFT", 20, 10, ( $private.pdf.createFont("Verdana",18,"NORMAL","Black",@(67,87,100)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$($scap2report.confNotice)", "ALIGN_LEFT", 10, 20, ( $private.pdf.createFont("Verdana",10,"NORMAL","Black",@(93,107,120)) ) )  ).results) | out-null
		$private.pdf.doc.NewPage() | out-null
	}
	
	method pdfOpen{
		param(
			$packageData
		)
		
		$private.pdf = $pdfClass.new(
			"$($pwd)\results\scap2report_$($packageData.packageName)_$(get-date -format 'yyyyMMddHHmmss').pdf",
			"$(((whoami).ToString().substring((whoami).indexOf('\')+1)))",
			40,40,40,40				
		) 
		$private.pdf.open() | out-null
	}
	
	method pdfClose{
		param()
		$private.pdf.Close()
	}
	
	method updateScanData{
		param()
		
		$existing = (ls -recurse "C:\sandbox\scc_4.1.1\Results\SCAP" -filter "*xccdf*.xml" )
		$scanPBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
		$dataFiles = @()
		
		
		#remove any scans that no longer exist from the database
		$i = 0
		$t = $private.scanData.count
		
		foreach($scan in ($private.scanData)){
			$i++
			$scanPBar.Activity("Confirming Scans Still Valid").Status(("$($i) / $($t) : {0:N2}% Complete - Removing Stale Scans" -f ( $i/$t*50  ) )).Percent($i/$t*50).Render()			
			
			$dataFiles += $scan.filename
			if( ( $existing | select -expand Name) -notcontains $($scan.filename) ){
				write-host "Removing $($scan.filename)"
				$private.scanData.remove($i)
			}
		} 
		
		#add any scans that exist but aren't in the database
		$i = 0
		$t = $existing.count
		foreach($scan in $existing){
			$i++
			$scanPBar.Activity("Confirming Scans Still Valid").Status(("$($i) / $($t) : {0:N2}% Complete - Adding Missing Stans" -f ( $i/$t*50 + 50 ) )).Percent($i/$t*50 + 50).Render()			
			if( $dataFiles -notcontains $($scan) ){
				write-host "Adding $($scan)"
				$this.addScan($scan)
				
			}
		} 
		
		$private.scanData | export-clixml $scap2report.dbPath
		$scanPBar.Completed($true).Render()
	}
	
	method addScan{
		param(
			$scan
		)
		
		$xccdf = [xml](gc $scan.fullname)
		$scanInfo = @{
			"obe"			= $false;
			"package"       = ($private.ipa | ?  { $_.hostname -eq $xccdf.Benchmark.TestResult.target } | select -expand 'package id');
			"filename"      = $($scan.name).trim()
			"scapId"        = $xccdf.Benchmark.id;
			"title"         = $xccdf.Benchmark.title -replace "Security Technical Implementation Guide","" -replace "stig","";
			"version"       = $xccdf.Benchmark.version;
			"releaseinfo"   = ( $xccdf.Benchmark.'plain-text' | ? { $_.id -eq 'release-info' } | select -expand '#text' );
			"release"       = ( ( [regex]::matches( ( $xccdf.Benchmark.'plain-text' | ? { $_.id -eq 'release-info' } | select -expand '#text' ) , "Release: ([0-9.]+)") | select groups).groups[1] | select -expand value);
			"hostname"      = $xccdf.Benchmark.TestResult.target;
			"ip"            = $xccdf.Benchmark.TestResult.'target-address';
			"mac"			= ($xccdf.Benchmark.TestResult.'target-facts'.fact | ? { $_.name -eq 'urn:scap:fact:asset:identifier:mac'}) | select -expand '#text';
			"time"          = $xccdf.Benchmark.TestResult.'start-time';
			"identity"      = $xccdf.Benchmark.TestResult.identity.'#text';
			"authenticated" = $xccdf.Benchmark.TestResult.identity.authenticated;
			"privileged"    = $xccdf.Benchmark.TestResult.identity.privileged;
			"profile"       = $xccdf.Benchmark.TestResult.profile.idref;
			"score"         = ( $xccdf.Benchmark.TestResult.score | ? { $_.system -eq 'urn:xccdf:scoring:spawar-original'} ).'#text';
			"pass"          = ( ( $xccdf.Benchmark.TestResult.'rule-result' | ? { $_.result -eq 'pass'}  ).count ) + 0;
			"fail"          = ( ( $xccdf.Benchmark.TestResult.'rule-result' | ? { $_.result -eq 'fail'}  ).count ) + 0;
			"error"         = ( ( $xccdf.Benchmark.TestResult.'rule-result' | ? { $_.result -eq 'error'} ).count ) + 0;
			"total"         = ( $xccdf.Benchmark.TestResult.'rule-result' ).count;
		}
		
		#see if there are any previous scaps [datetime]::ParseExact('2016-12-01T16:55:51','yyyy-MM-ddTHH:mm:ss',$null)
		$scanInfo | ? { $_.hostname -eq $xccdf.Benchmark.TestResult.target -and $_.id -eq $xccdf.Benchmark.id -and [datetime]::ParseExact( $_.time ,'yyyy-MM-ddTHH:mm:ss',$null) -lt [datetime]::ParseExact( $xccdf.Benchmark.TestResult.'start-time' ,'yyyy-MM-ddTHH:mm:ss',$null) } | %{
			$_.obe = $true
		}
		$private.scanData.add($scanInfo )
	}
	
	method parseScans{
		param($obj)
		$package = $obj.packageName
		#add scan info
		$scanPBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
		
		# select first argument or all of them
		$packageScans = $private.scanData | ? { "$($_.package)".trim() -eq "$($package)".trim() } | select -first ( @(($private.scandata.count + 1), $first)[ $first -ne $null] )
		
		$i = 0
		$t = $packageScans.count
		foreach($scan in $packageScans ) {
			$i++
			$scanPBar.Activity("Parsing SCAP Data").Status(("$($i) / $($t) : {0:N2}% Complete - Parsing Scans" -f ( $i/$t*100  ) )).Percent($i/$t*100).Render()	| out-null
			$scanId = [guid]::NewGuid().guid
			$scanNode = @{}
			$scanNode.id = $scanId
			foreach($key in $scan.keys ){
				$scanNode.$key = $scan.$key
				
			}
			$obj.scans += $scanNode

			#get Scan data
			[xml]$scapData = [xml]( (gc (ls "$($scapPath)\" -recurse -filter $scan.filename | select -first 1 -expand fullname) -readCount 0 )  )
			$xccdfNs = new-object Xml.XmlNamespaceManager $scapData.NameTable
			$xccdfNs.AddNamespace("cdf", "http://checklists.nist.gov/xccdf/1.1" ) | out-null
			$xccdfNs.AddNamespace("dsig", "http://www.w3.org/2000/09/xmldsig#" )	| out-null
			$xccdfNs.AddNamespace("xhtml", "http://www.w3.org/1999/xhtml" )	| out-null
			$xccdfNs.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance" )	| out-null
			$xccdfNs.AddNamespace("cpe", "http://cpe.mitre.org/language/2.0" )	| out-null
			$xccdfNs.AddNamespace("dc", "http://purl.org/dc/elements/1.1/" )	| out-null
			$xccdfNs.AddNamespace("ns", "http://checklists.nist.gov/xccdf/1.1" )	| out-null
			
			$scapData.Benchmark.TestResult.'rule-result' | ? { $_.result -ne 'pass' } | % {
				#requirements data per scan
				$ruleData = $scapData.selectSingleNode("/cdf:Benchmark/cdf:Group[./cdf:Rule/@id = '$($rule)']", $xccdfNs)
				$rule = $_.idref
				$vuln = $ruleData.id
				
				$reqNode = @{}
				$reqId = [guid]::NewGuid().guid
				$reqNode.id = $reqId 
				$reqNode.rule = $rule
				$reqNode.severity = $_.severity
				$reqNode.check = $_.check.'check-content-ref'.name

				$reqNode.vuln = $vuln 
				$reqNode.family = $ruleData.title;
				$reqNode.version = $ruleData.rule.version;
				$reqNode.title = $ruleData.rule.title;
				$reqNode.description = ([xml]("<root>$($ruleData.rule.description)</root>")).selectSingleNode('/root/VulnDiscussion').'#text';
		
				if( ($obj.requirements | ? { $_.rule -eq $rule -and $_.vuln -eq $vuln}) -eq $null ){
					$obj.requirements += $reqNode
				}

				#results data per requirement
				$scanHost = (($scapData.Benchmark.TestResult.'target-facts'.fact | ? { $_.name -eq 'urn:scap:fact:asset:identifier:host_name' }).'#text')
				$resultsNode = @{}
				$resultsNode.id = [guid]::NewGuid().guid
				$resultsNode.scanId = $scanId
				$resultsNode.reqId = $reqId
				$resultsNode.hostId =  ($obj.hosts | ? { $_.hostname -eq $scanHost } ).id
				$resultsNode.hostName =  $scanHost
				$resultsNode.pass =  $_.result
				$obj.results += $resultsNode
							}
		}
		$scanPBar.Completed($true).Render()	| out-null
		return $obj
	}
	
	method addHosts{
		param($package)
		$hosts = @()
		$private.ipa | ? { $_.'package id'.trim() -eq $package.trim() } | ? { $_.hostname -ne $null -and $_.hostname -ne '' } | sort hostname | % {
			$hosts += @{
				id       = [guid]::NewGuid().guid;
				package  = $_.'package id';
				hostname = $_.'hostname';
				ip       = $_.'ipv4 address';
				mac      = $_.'mac address';
			}
		}
		return $hosts
	}
	
	method pdfScanDetails{
		param($packageData)
		
		$private.pdf.add(( $private.pdf.createParagraph( "Scan Details", "ALIGN_LEFT", 5, 5, ( $private.pdf.createFont("Verdana",18,"BOLD","Black",@(0,165,181)) ) )  ).results) | out-null
		
		foreach($packageHost in ($packageData.hosts)){
			
			$t = New-Object iTextSharp.text.pdf.PDFPTable(4)
			$scap2report.scanDetailTableOptions.keys | % {
				$t.$($_) = $scap2report.scanDetailTableOptions.$($_)
			}
			$t.SetWidths(@( 1, 1, 1, 1)) | out-null
			
			@('Package','Hostname','IP Address','MAC Address') | % {
				$headerCell = New-Object iTextSharp.text.pdf.PDFPCell
				$headerCell.BackgroundColor = $scap2report.headerBackground
				$headerCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
				$headerCell.addElement(( $private.pdf.createParagraph( "$($_)", "ALIGN_CENTER", 5, 5, ( $private.pdf.createFont("Verdana",12,"BOLD","White",@(255,255,255)) ) )  ).results) | out-null
				$t.AddCell( $headerCell ) | out-null
			}
			
			@( $packageData.packageName, $packageHost.hostname, $packageHost.ip, $packageHost.mac) | % {
				$cell = New-Object iTextSharp.text.pdf.PDFPCell
				$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(238,238,238) );
				
				$p = (( $private.pdf.createParagraph( "$($_)", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",8,"Normal","Black",@(0,0,0)) ) )  ).results)
				$p.Font.SetColor(0,0,0)
				$p.Alignment = ( [iTextSharp.text.Element]::ALIGN_LEFT );
				$p.SetLeading(0, 1);
				$cell.addElement( $p ) | out-null
				$t.AddCell( $cell ) | out-null
			}
			$t.AddCell( $cell ) | out-null
			$private.pdf.Add($t) | out-null
			
			$p = (( $private.pdf.createParagraph( "SCAP Scans Executed", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",12, "BOLD" ,"Black",@(0,0,0)) ) )  ).results)
			$p.SetLeading(0, 1) 
			$private.pdf.Add($p) | out-null
			
			$packageData.scans | ? { $_.hostname -eq $packageHost.hostname -and $_.obe -eq $false } | sort { $_.title } | % {
				$p = (( $private.pdf.createParagraph( $_.title, "ALIGN_LEFT", 10, 0, ( $private.pdf.createFont("Verdana",10, "BOLD" ,"Black",@(0,0,0)) ) )  ).results)
				$p.SetLeading(0, 1) 
				$private.pdf.Add($p) | out-null
				
				$p = (( $private.pdf.createParagraph( "Executed: $($_.time); OBE: $($_.obe); Version/Release: V$($_.version)R$($_.release); Profile: $($_.profile); ", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",10, "NORMAL" ,"Black",@(0,0,0)) ) )  ).results)
				$p.SetLeading(0, 1) 
				$private.pdf.Add($p) | out-null
				
				$p = (( $private.pdf.createParagraph( "Identity: $($_.identity); Authenticated: $($_.authenticated); Privileged: $($_.privileged); ", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",10, "NORMAL" ,"Black",@(0,0,0)) ) )  ).results)
				$p.SetLeading(0, 1) 
				$private.pdf.Add($p) | out-null
				
				$p = (( $private.pdf.createParagraph( "Score: $($_.score)%; Pass: $($_.pass); Fail: $($_.fail); Error: $($_.error);", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",10, "NORMAL" ,"Black",@(0,0,0)) ) )  ).results)
				$p.SetLeading(0, 1) 
				$private.pdf.Add($p) | out-null

				$p = (( $private.pdf.createParagraph( "Filename: $($_.filename);", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",10, "NORMAL" ,"Black",@(0,0,0)) ) )  ).results)
				$p.SetLeading(0, 1) 
				$private.pdf.Add($p) | out-null
			}
			
			$p = (( $private.pdf.createParagraph( " ", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",10, "NORMAL" ,"Black",@(0,0,0)) ) )  ).results)
			$p.SetLeading(0, 1) 
			$private.pdf.Add($p) | out-null
		}
	}
	
	method pdfVulnSummary{
		param($packageData)
		
		$private.pdf.doc.NewPage() | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "Vulnerability Summary", "ALIGN_LEFT", 5, 5, ( $private.pdf.createFont("Verdana",18,"BOLD","Black",@(0,165,181)) ) )  ).results) | out-null
		
		$packageData.results | ? { $_.pass -eq 'fail' } | % { $utils.hashToObj($_) } | % { $req = $_.reqId; ($packageData.requirements | ? { $_.id -eq $req }).vuln;} | sort -unique | % {
			$vuln = $_;
			$requirement = $packageData.requirements | ? { $_.vuln -eq $vuln }
			$requirement | % {
				$req = $_;
				
				$t = New-Object iTextSharp.text.pdf.PDFPTable(4)
				$scap2report.scanDetailTableOptions.keys | % {
					$t.$($_) = $scap2report.scanDetailTableOptions.$($_)
				}
				$t.SetWidths(@( 1, 1, 1, 1)) | out-null
				
				@('Vuln / Rule / Version','Title','Family','Severity') | % {
					$headerCell = New-Object iTextSharp.text.pdf.PDFPCell
					$headerCell.BackgroundColor = $scap2report.headerBackground
					$headerCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
					$headerCell.addElement(( $private.pdf.createParagraph( "$($_)", "ALIGN_CENTER", 5, 5, ( $private.pdf.createFont("Verdana",12,"BOLD","White",@(255,255,255)) ) )  ).results) | out-null
					$t.AddCell( $headerCell ) | out-null
				}
				
				@( "$($_.vuln) / $($_.rule) / $($_.version)", "$($_.title)","$($_.family)","$($_.severity)" ) | % {
					$cell = New-Object iTextSharp.text.pdf.PDFPCell
					$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(238,238,238) );
					
					$p = (( $private.pdf.createParagraph( "$($_)", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",8,"Normal","Black",@(0,0,0)) ) )  ).results)
					$p.Font.SetColor(0,0,0)
					$p.Alignment = ( [iTextSharp.text.Element]::ALIGN_LEFT );
					$p.SetLeading(0, 1);
					$cell.addElement( $p ) | out-null
					$t.AddCell( $cell ) | out-null
				}
				
				$cell = New-Object iTextSharp.text.pdf.PDFPCell
				$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(255,255,255) );
				$cell.colspan = 4;
				
				$p = (( $private.pdf.createParagraph( "Description:", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",10,"Bold","Black",@(0,0,0)) ) )  ).results)
				$p.Font.SetColor(0,0,0)
				$p.Alignment = ( [iTextSharp.text.Element]::ALIGN_LEFT );
				$p.SetLeading(0, 1);
				$cell.addElement( $p ) | out-null
				
				$p = (( $private.pdf.createParagraph( "$($_.description)", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",8,"Normal","Black",@(0,0,0)) ) )  ).results)
				$p.Font.SetColor(0,0,0)
				$p.Alignment = ( [iTextSharp.text.Element]::ALIGN_LEFT );
				$p.SetLeading(0, 1);
				$cell.addElement( $p ) | out-null
				$t.AddCell( $cell ) | out-null
				
				$cell = New-Object iTextSharp.text.pdf.PDFPCell
				$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(238,238,238) );
				$cell.colspan = 4;
				
				$p = (( $private.pdf.createParagraph( "Hosts:", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",10,"Bold","Black",@(0,0,0)) ) )  ).results)
				$p.Font.SetColor(0,0,0)
				$p.Alignment = ( [iTextSharp.text.Element]::ALIGN_LEFT );
				$p.SetLeading(0, 1);
				$cell.addElement( $p ) | out-null
								
				$packageData.results | ? { $_.reqId -eq $req.id -and $_.pass -ne 'pass' } | % { $utils.hashToObj($_) } | select -expand hostId | sort -unique | % {
					$hostInfo = $_
					$packageData.hosts | ? { $_.id -eq $hostInfo } | %{
						$p = (( $private.pdf.createParagraph( "IP: $($_.ip) - MAC Address: $($_.mac) - Hostname: $($_.hostname)", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",8,"Normal","Black",@(0,0,0)) ) )  ).results)
						$p.Font.SetColor(0,0,0)
						$p.Alignment = ( [iTextSharp.text.Element]::ALIGN_LEFT );
						$p.SetLeading(0, 1);
						$cell.addElement( $p ) | out-null
					}
				}
				
				$t.AddCell( $cell ) | out-null	
				$private.pdf.Add($t) | out-null
			}
		}
		
	}
	
	method pdfNoAccess{
		param($packageData)
		
		$private.pdf.doc.NewPage() | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "Scans with No Access", "ALIGN_LEFT", 5, 5, ( $private.pdf.createFont("Verdana",18,"BOLD","Black",@(0,165,181)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "Authentication Failure - Local Checks Not Run = Local security checks have been disabled for this host because either the credentials supplied in the scan policy did not allow the SCAP Compliance Checker to log into it or some other problem occurred.", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",10,"Normal","Black",@(64,64,64)) ) )  ).results) | out-null
		
		$badScans = $packageData.scans | ? { $_.obe -eq $false -and $_.privileged -eq $false } | sort -unique { $_.hostname } 
		if($badScans.count -gt 0){
			$t = New-Object iTextSharp.text.pdf.PDFPTable(4)
			$scap2report.scanDetailTableOptions.keys | % {
				$t.$($_) = $scap2report.scanDetailTableOptions.$($_)
			}
			$t.SetWidths(@( 1, 1, 1, 1)) | out-null
			
			@('Package','Hostname','IP Address','MAC Address') | % {
				$headerCell = New-Object iTextSharp.text.pdf.PDFPCell
				$headerCell.BackgroundColor = $scap2report.headerBackground
				$headerCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
				$headerCell.addElement(( $private.pdf.createParagraph( "$($_)", "ALIGN_CENTER", 5, 5, ( $private.pdf.createFont("Verdana",12,"BOLD","White",@(255,255,255)) ) )  ).results) | out-null
				$t.AddCell( $headerCell ) | out-null
			}
			
			foreach($badScan in $badScans){
				@( $packageData.packageName, $badScans.hostname, $badScans.ip, $badScans.mac) | % {
					$cell = New-Object iTextSharp.text.pdf.PDFPCell
					$cell.BackgroundColor = ( new-object iTextSharp.text.BaseColor(238,238,238) );
					
					$p = (( $private.pdf.createParagraph( "$($_)", "ALIGN_LEFT", 0, 0, ( $private.pdf.createFont("Verdana",8,"Normal","Black",@(0,0,0)) ) )  ).results)
					$p.Font.SetColor(0,0,0)
					$p.Alignment = ( [iTextSharp.text.Element]::ALIGN_LEFT );
					$p.SetLeading(0, 1);
					$cell.addElement( $p ) | out-null
					$t.AddCell( $cell ) | out-null
				}
			}
			
			$private.pdf.Add($t) | out-null
		}
	}
	
	method pdfSeveritySummary{
		param($packageData)
		
		$private.pdf.doc.NewPage() | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "Severity Summary", "ALIGN_LEFT", 5, 5, ( $private.pdf.createFont("Verdana",18,"BOLD","Black",@(0,165,181)) ) )  ).results) | out-null
		
		$t = New-Object iTextSharp.text.pdf.PDFPTable(2)
		$scap2report.scanDetailTableOptions.keys | % { $t.$($_) = $scap2report.scanDetailTableOptions.$($_) }
		$t.SetWidths(@( 1, 1)) | out-null
		
		@('Severity','Count') | % {
			$headerCell = New-Object iTextSharp.text.pdf.PDFPCell
			$headerCell.BackgroundColor = $scap2report.headerBackground
			$headerCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
			$headerCell.addElement(( $private.pdf.createParagraph( "$($_)", "ALIGN_CENTER", 5, 5, ( $private.pdf.createFont("Verdana",12,"BOLD","White",@(255,255,255)) ) )  ).results) | out-null
			$t.AddCell( $headerCell ) | out-null
		}
		
		#high
		
		
		$private.pdf.Add($t) | out-null
		
	}
	
	method execute{
		param()
		
		if(!$private.skip){
			$this.updateScanData()
		}
		
		foreach($package in  ($private.ipa | ? { $private.selPackage -eq $null -or $private.selPackage -eq $_.'package id'  } | select -expand 'package id' | sort -unique  ) ){
			if((($private.scanData | ? { "$($_.package)".trim() -eq "$($package)".trim()} ) | sort {$_.hostname } -unique) -ne $null){
						
				#build a package object
				$packageData = @{
					"packageName"  = $package;
					"hosts"        = $this.addHosts($package);
					"scans"        = @();
					"results"      = @();
					"requirements" = @();
				}
				
				$packageData = ( $this.parseScans($packageData) )
				
				
				$this.pdfOpen( $packageData )
				$this.pdfMakeHeader( $packageData )
				
				$this.pdfScanDetails( $packageData )
				$this.pdfNoAccess( $packageData )
				$this.pdfVulnSummary( $packageData )
				$this.pdfSeveritySummary( $packageData )

				$this.pdfClose()
			}
		}
	}
	
	constructor{
		param()
	
		$private.ipaPath = $ipaPath
		$private.scapPath = $scapPath
		$private.reset = $reset
		$private.skip = $skip
		$private.out = $out
		$private.first = $first
		$private.selPackage = $selPackage
		
		if( (test-path $scap2report.dbPath) ){
			$private.scanData = [system.collections.arraylist](import-clixml $scap2report.dbPath)
		}else{
			$private.scanData = (new-object system.collections.arraylist)
		}
		if($private.reset){
			$private.scanData = (new-object system.collections.arraylist)
		}
		
		if( (test-path $private.ipaPath)){
			$private.ipa = Import-Csv $private.ipaPath
		}else{
			$private.ipa = @()
		}
		
	}
}

$scap2report.New().execute() | out-null