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
Param( [string]$hostFilePath, [string]$hostMapFilePath, [string]$logoPath)
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

#TODO: GUI

$missingScansClass = new-PSClass missingScans{
	note -static PsScriptName "missingScansClass"
	note -static Description ( ($(((get-help .\missingScans.ps1).Description)) | select Text).Text)
	
	note -static confNotice "Confidential: The following report contains confidential information. Do not distribute, email, fax, or transfer via any electronic mechanism unless it has been approved by the recipient company's security policy. All copies and backups of this document should be saved on protected storage at all times. Do not share any of the information contained within this report with anyone unless they are authorized to view the information. Violating any of the previous instructions is grounds for termination."
	
	# Variable: mainProgressBar 
	# A Container for the main script progress bar
	note -private mainProgressBar
	
	note -private hostFilePath
	note -private hostMapFilePath
	note -private logoPath
	
	note -private hosts
	note -private hostMap
	
	note -private pdf
	 
	method -private makeHeader{
		
		$private.pdf = $pdfClass.new(
			"$($pwd)\results\missingScans_$(get-date -format 'yyyyMMddHHmmss').pdf",
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

		$private.pdf.add(( $private.pdf.createParagraph( "`nHosts with Missing Scans", "ALIGN_CENTER", $topSpacing, 20, ( $private.pdf.createFont("Verdana",36,"BOLD","Black",@(67,87,100)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$(get-date -format 'MMMM d, yyyy a\t HH:mm tt')", "ALIGN_LEFT", 200, 20, ( $private.pdf.createFont("Verdana",18,"NORMAL","Black",@(67,87,100)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$(((whoami).ToString().substring((whoami).indexOf('\')+1)))", "ALIGN_LEFT", 20, 10, ( $private.pdf.createFont("Verdana",18,"NORMAL","Black",@(67,87,100)) ) )  ).results) | out-null
		$private.pdf.add(( $private.pdf.createParagraph( "$($missingScansClass.confNotice)", "ALIGN_LEFT", 10, 20, ( $private.pdf.createFont("Verdana",10,"NORMAL","Black",@(93,107,120)) ) )  ).results) | out-null
		$private.pdf.doc.NewPage() | out-null
	}
	
	method execute{
		param()
	
		$vramAcasAudits = $private.vram | sort 'Nessus Id' -unique | select -expand 'Nessus Id'
				
		$packages = ($private.hostMap | select 'Package Id' -unique | sort 'Package ID' ) 
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		
		
		
		
		$private.makeHeader( )
		
		$t = New-Object iTextSharp.text.pdf.PDFPTable(5)
		$t.WidthPercentage = 100 
		$t.SetWidths(@(1, 2, 3, 2, 1)) | out-null
		$t.SpacingBefore = 5
		$t.SpacingAfter = 5
		$t.HorizontalAlignment = 0
		
		@("#", "IP","Host Name","Package", "Org Code") | % {
			$colHeader = New-Object iTextSharp.text.pdf.PDFPCell
			$colHeader.BackgroundColor = ( new-object iTextSharp.text.BaseColor( 0, 165, 181) )
			$colHeader.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
			
			$colHeader.addElement(( $private.pdf.createParagraph( "$($_)", "ALIGN_CENTER", 5, 5, ( $private.pdf.createFont("Verdana",12,"BOLD","White",@(255,255,255)) ) )  ).results) | out-null
			$t.AddCell( $colHeader ) | out-null
		}
			
		$i = 0
			
		foreach($hostIp in ($private.hosts | sort IP ) ){
			$i++
				
			$indexCell = New-Object iTextSharp.text.pdf.PDFPCell
			$indexCell.BackgroundColor = ( new-object iTextSharp.text.BaseColor( 0, 165, 181) );
			$indexCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
			$indexCell.addElement(( $private.pdf.createParagraph( "$($i)", "ALIGN_CENTER", 1, 1, ( $private.pdf.createFont("Verdana",12,"Normal","White",@(255,255,255)) ) )  ).results) | out-null
			$t.AddCell( $indexCell ) | out-null
			
			
			
			$ipCell = New-Object iTextSharp.text.pdf.PDFPCell
			$ipCell.BackgroundColor = [iTextSharp.text.BaseColor]::White;
			$ipCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
			$ipCell.addElement(( $private.pdf.createParagraph( "$($hostIp.IP)", "ALIGN_CENTER", 1, 1, ( $private.pdf.createFont("Verdana",8,"Normal","White",@(0,0,0)) ) )  ).results) | out-null
			$t.AddCell( $ipCell ) | out-null
			
			$hostNameCell = New-Object iTextSharp.text.pdf.PDFPCell
			$hostNameCell.BackgroundColor = [iTextSharp.text.BaseColor]::White;
			$hostNameCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
			
			try{
				$hostName = ([system.net.dns]::GetHostByAddress($hostIP.IP)).hostname
			}catch{
				$hostName = "Unknown"
			}
			
			$hostNameCell.addElement(( $private.pdf.createParagraph( "$($hostName)", "ALIGN_CENTER", 1, 1, ( $private.pdf.createFont("Verdana",8,"Normal","White",@(0,0,0)) ) )  ).results) | out-null
			$t.AddCell( $hostNameCell ) | out-null
			
			#get Package
			if($utilities.isBlank($private.hostMap) -eq $false){
				$packageData = ( $private.hostMap | ? { $_.'IPv4 Address' -eq ($hostIp.IP) } | select -first 1)
				
				$packageCell = New-Object iTextSharp.text.pdf.PDFPCell
				$packageCell.BackgroundColor = [iTextSharp.text.BaseColor]::White;
				$packageCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
				$packageCell.addElement(( $private.pdf.createParagraph( "$($packageData.'Package ID')", "ALIGN_CENTER", 1, 1, ( $private.pdf.createFont("Verdana",8,"Normal","White",@(0,0,0)) ) )  ).results) | out-null
				$t.AddCell( $packageCell ) | out-null
				
				$orgCell = New-Object iTextSharp.text.pdf.PDFPCell
				$orgCell.BackgroundColor = [iTextSharp.text.BaseColor]::White;
				$orgCell.HorizontalAlignment = [iTextSharp.text.Element]::ALIGN_CENTER;
				$orgCell.addElement(( $private.pdf.createParagraph( "$($packageData.'Org Code')", "ALIGN_CENTER", 1, 1, ( $private.pdf.createFont("Verdana",8,"Normal","White",@(0,0,0)) ) )  ).results) | out-null
				$t.AddCell( $orgCell ) | out-null
			
			}else{
				$t.AddCell( "" ) | out-null
				$t.AddCell( "" ) | out-null
			
			}
			
		}
		$private.pdf.Add($t) | out-null
		$private.pdf.Close()
		$private.mainProgressBar.Completed($true).Render()
	}
	
	
	constructor{
		param()
		
		$private.hostFilePath = $hostFilePath
		$private.hostMapFilePath = $hostMapFilePath
		
		$private.logoPath = $logoPath
		
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Parsing input files...")
		$private.hosts = import-csv "$($private.hostFilePath)"
		if($utilities.isBlank($private.hostMapFilePath) -eq $false){
			$private.hostMap = import-csv "$($private.hostMapFilePath)" | ? { $utilities.isBlank( $_.'IPv4 Address') -eq $false }
		}else{
			$private.hostMap = $null
		}
	}
}

$missingScansClass.New().execute() | out-null