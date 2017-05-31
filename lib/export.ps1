# #########################################################################
# Class: ExportClass
# 	Creates an Excel document as the end product for a script
#
# See Also:
# 	<excelClass>
# #########################################################################
$ExportClass = new-PSClass Export{
	
	# Section: Private Members
	
	# Variable: xml
	# The internal XML Object
	note -private xml
	
	note -private activeSheet 
	note -private xmlNameSpaceMgr
	
	# Section: Public Members
	
	# Property: XML 
	# Returns the XML Object
	property XML -get {return $private.xml}
	
	# Property: workSheetCount
	# The number of worksheets in the export object
	property workSheetCount -get{ return $private.xml.worksheet.count}
	
	# Property: actuveSheet
	# The currently active worksheet
	property ActiveSheet -get {return $private.activeSheet }
	
	# #########################################################################
	# Method: Constructor
	# 	Constructs a new Export Class Object
	#
	# Returns:
	# 	New <ExportClass> Object
	#
	# See Also:
	# 	<TJX.PolFileEditor.PolFile.GetBinaryValue>
	# #########################################################################
	constructor{
		param()
		
		$private.xml = [xml]@"
<?xml version='1.0'?>
<?mso-application progid='Excel.Sheet'?>
<Workbook 
	xmlns="urn:schemas-microsoft-com:office:spreadsheet" 
	xmlns:o="urn:schemas-microsoft-com:office:office" 
	xmlns:x="urn:schemas-microsoft-com:office:excel" 
	xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
	xmlns:html="http://www.w3.org/TR/REC-html40"
	/> 
"@
	
		$private.xmlNameSpaceMgr = New-Object System.Xml.XmlNamespaceManager($private.xml.NameTable)
		$private.xmlNameSpaceMgr.AddNamespace("ns", $private.xml.Workbook.NamespaceURI) | out-null
		$private.xmlNameSpaceMgr.AddNamespace("", "urn:schemas-microsoft-com:office:spreadsheet") | out-null
		$private.xmlNameSpaceMgr.AddNamespace("o", "urn:schemas-microsoft-com:office:office") | out-null
		$private.xmlNameSpaceMgr.AddNamespace("x", "urn:schemas-microsoft-com:office:excel") | out-null
		$private.xmlNameSpaceMgr.AddNamespace("ss", "urn:schemas-microsoft-com:office:spreadsheet") | out-null
		$private.xmlNameSpaceMgr.AddNamespace("html", "http://www.w3.org/TR/REC-html40") | out-null
		
		$private.xml.PreserveWhitespace = $true
		
		$private.addStyles()
		$private.addDocProps()
	}

	method -private addDocProps{
		param()
		
		#document Properties
		$docProp = $private.xml.CreateElement('DocumentProperties', $private.xmlNameSpaceMgr.LookupNamespace("o"))
		$lastAuthor = $private.xml.CreateElement('LastAuthor', $private.xmlNameSpaceMgr.LookupNamespace("o"))
		
		if( (whoami) -ne $null){
			$lastauthor.innerText = (whoami).toString().SubString((whoami).indexOf('\')+1)
		}else{
			$lastauthor.innerText = ""
		}
		
		
		$lastSaved = $private.xml.CreateElement('LastSaved', $private.xmlNameSpaceMgr.LookupNamespace("o"))
		$lastSaved.innerText = (get-date -format yyyy-MM-ddTHH:mm:ssZ)
		$version = $private.xml.CreateElement('Version', $private.xmlNameSpaceMgr.LookupNamespace("o"))
		$version.innerText = "14.00"
		$docProp.appendChild($lastAuthor) | out-null
		$docProp.appendChild($lastSaved) | out-null
		$docProp.appendChild($version) | out-null
		$private.xml.Workbook.appendChild($docProp) | out-null
		
		#Office Document Settings
		$docSet = $private.xml.CreateElement('OfficeDocumentSettings', $private.xmlNameSpaceMgr.LookupNamespace("o"))
		$allowPng = $private.xml.CreateElement('AllowPNG', $private.xmlNameSpaceMgr.LookupNamespace("o"))
		$docSet.appendChild($allowPng) | out-null
		$private.xml.Workbook.appendChild($docSet) | out-null

	}
	
	method -private addStyles{
		param()
		
		#styles
		$styles = $private.xml.CreateElement('Styles', $private.xmlNameSpaceMgr.LookupNamespace(""))
		
		#default
		$style = $private.xml.CreateElement('Style', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$style.SetAttribute("ID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Default") | out-null
		$style.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Normal") | out-null
		$alignment = $private.xml.CreateElement('Alignment', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$alignment.SetAttribute("Vertical", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Bottom") | out-null
		$style.appendChild($alignment)  | out-null
		$font = $private.xml.CreateElement('Font', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$font.SetAttribute("FontName", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Calibri") | out-null
		$font.SetAttribute("Family", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Swiss") | out-null
		$font.SetAttribute("Size", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "10") | out-null
		$font.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#000000") | out-null
		$style.appendChild($font)  | out-null
		$style.appendChild( $private.xml.CreateElement('Borders', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('Interior', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('NumberFormat', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('Protection', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$styles.appendChild($style) | out-null
		
		#redText
		$style = $private.xml.CreateElement('Style', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$style.SetAttribute("ID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "RedText") | out-null
		$style.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "RedText") | out-null
		$alignment = $private.xml.CreateElement('Alignment', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$alignment.SetAttribute("Horizontal", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Center") | out-null
		$alignment.SetAttribute("Vertical", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Bottom") | out-null
		$style.appendChild($alignment)  | out-null
		$font = $private.xml.CreateElement('Font', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$font.SetAttribute("FontName", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Calibri") | out-null
		$font.SetAttribute("Family", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Swiss") | out-null
		$font.SetAttribute("Size", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "10") | out-null
		$font.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#FF0000") | out-null
		$font.SetAttribute("Bold", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
		$style.appendChild($font)  | out-null
		$style.appendChild( $private.xml.CreateElement('Borders', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('Interior', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('NumberFormat', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('Protection', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$styles.appendChild($style) | out-null
		
		
		#wrap
		$style = $private.xml.CreateElement('Style', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$style.SetAttribute("ID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Wrap") | out-null
		$style.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Wrap") | out-null
		$alignment = $private.xml.CreateElement('Alignment', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$alignment.SetAttribute("Vertical", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Bottom") | out-null
		$alignment.SetAttribute("WrapText", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
		$style.appendChild($alignment)  | out-null
		$font = $private.xml.CreateElement('Font', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$font.SetAttribute("FontName", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Calibri") | out-null
		$font.SetAttribute("Family", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Swiss") | out-null
		$font.SetAttribute("Size", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "10") | out-null
		$font.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#000000") | out-null
		$style.appendChild($font)  | out-null
		$style.appendChild( $private.xml.CreateElement('Borders', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('Interior', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('NumberFormat', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('Protection', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$styles.appendChild($style) | out-null
		
		
		#header
		$style = $private.xml.CreateElement('Style', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$style.SetAttribute("ID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Header") | out-null
		$style.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Header") | out-null
		$alignment = $private.xml.CreateElement('Alignment', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$alignment.SetAttribute("Vertical", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Bottom") | out-null
		$alignment.SetAttribute("Horizontal", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Center") | out-null
		$alignment.SetAttribute("WrapText", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
		$style.appendChild($alignment) | out-null
		$font = $private.xml.CreateElement('Font', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$font.SetAttribute("FontName", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Calibri") | out-null
		$font.SetAttribute("Family", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Swiss") | out-null
		$font.SetAttribute("Size", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "10") | out-null
		$font.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#000000") | out-null
		$font.SetAttribute("Bold", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
		$style.appendChild($font) | out-null
		$styles.appendChild($style) | out-null

		#Good
		$style = $private.xml.CreateElement('Style', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$style.SetAttribute("ID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Good") | out-null
		$style.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Good") | out-null
		$interior = $private.xml.CreateElement('Interior', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$interior.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#C6EFCE") | out-null
		$interior.SetAttribute("Pattern", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Solid") | out-null
		$style.appendChild($interior) | out-null
		$font = $private.xml.CreateElement('Font', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$font.SetAttribute("FontName", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Calibri") | out-null
		$font.SetAttribute("Family", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Swiss") | out-null
		$font.SetAttribute("Size", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "10") | out-null
		$font.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#006100") | out-null
		$font.SetAttribute("Bold", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "0") | out-null
		$style.appendChild($font) | out-null
		$styles.appendChild($style) | out-null
		
		#Bad
		$style = $private.xml.CreateElement('Style', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$style.SetAttribute("ID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Bad") | out-null
		$style.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Bad") | out-null
		$interior = $private.xml.CreateElement('Interior', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$interior.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#FFC7CE") | out-null
		$interior.SetAttribute("Pattern", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Solid") | out-null
		$style.appendChild($interior) | out-null
		$font = $private.xml.CreateElement('Font', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$font.SetAttribute("FontName", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Calibri") | out-null
		$font.SetAttribute("Family", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Swiss") | out-null
		$font.SetAttribute("Size", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "10") | out-null
		$font.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#9C0006") | out-null
		$font.SetAttribute("Bold", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "0") | out-null
		$style.appendChild($font) | out-null
		$styles.appendChild($style) | out-null
		
		#neutral
		$style = $private.xml.CreateElement('Style', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$style.SetAttribute("ID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Neutral") | out-null
		$style.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Neutral") | out-null
		$interior = $private.xml.CreateElement('Interior', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$interior.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#FFEB9C") | out-null
		$interior.SetAttribute("Pattern", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Solid") | out-null
		$style.appendChild($interior) | out-null
		$font = $private.xml.CreateElement('Font', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$font.SetAttribute("FontName", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Calibri") | out-null
		$font.SetAttribute("Family", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Swiss") | out-null
		$font.SetAttribute("Size", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "10") | out-null
		$font.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#9C6500") | out-null
		$font.SetAttribute("Bold", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "0") | out-null
		$style.appendChild($font) | out-null
		$styles.appendChild($style) | out-null
  
		#Orange
		$style = $private.xml.CreateElement('Style', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$style.SetAttribute("ID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Orange") | out-null
		$style.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Orange") | out-null
		$alignment = $private.xml.CreateElement('Alignment', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$alignment.SetAttribute("Vertical", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Bottom") | out-null
		$style.appendChild($alignment)  | out-null
		$font = $private.xml.CreateElement('Font', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$font.SetAttribute("FontName", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Calibri") | out-null
		$font.SetAttribute("Family", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Swiss") | out-null
		$font.SetAttribute("Size", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "10") | out-null
		$font.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#000000") | out-null
		$font.SetAttribute("Bold", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
		$interior = $private.xml.CreateElement('Interior', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$interior.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#FFC000") | out-null
		$interior.SetAttribute("Pattern", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Solid") | out-null
		
		$borders = $private.xml.CreateElement('Borders', $private.xmlNameSpaceMgr.LookupNamespace(""))
		foreach($position in @('Top','Bottom','Left','Right')){
			$border = $private.xml.CreateElement('Border', $private.xmlNameSpaceMgr.LookupNamespace(""))
			$border.SetAttribute("Position", $private.xmlNameSpaceMgr.LookupNamespace('ss'), $position) | out-null
			$border.SetAttribute("LineStyle", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Continuous") | out-null
			$border.SetAttribute("Weight", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
			$borders.appendChild($border) | out-null
		}
		$style.appendChild($borders)  | out-null
		$style.appendChild($interior)  | out-null
		$style.appendChild($font)  | out-null
		
		$style.appendChild( $private.xml.CreateElement('NumberFormat', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('Protection', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$styles.appendChild($style) | out-null
		
		
		
		#Gray
		$style = $private.xml.CreateElement('Style', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$style.SetAttribute("ID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Gray") | out-null
		$style.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Gray") | out-null
		$alignment = $private.xml.CreateElement('Alignment', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$alignment.SetAttribute("Vertical", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Bottom") | out-null
		$style.appendChild($alignment)  | out-null
		$font = $private.xml.CreateElement('Font', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$font.SetAttribute("FontName", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Calibri") | out-null
		$font.SetAttribute("Family", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Swiss") | out-null
		$font.SetAttribute("Size", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "10") | out-null
		$font.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#000000") | out-null
		$font.SetAttribute("Bold", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
		$interior = $private.xml.CreateElement('Interior', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$interior.SetAttribute("Color", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "#C0C0C0") | out-null
		$interior.SetAttribute("Pattern", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Solid") | out-null
		
		$borders = $private.xml.CreateElement('Borders', $private.xmlNameSpaceMgr.LookupNamespace(""))
		foreach($position in @('Top','Bottom','Left','Right')){
			$border = $private.xml.CreateElement('Border', $private.xmlNameSpaceMgr.LookupNamespace(""))
			$border.SetAttribute("Position", $private.xmlNameSpaceMgr.LookupNamespace('ss'), $position) | out-null
			$border.SetAttribute("LineStyle", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "Continuous") | out-null
			$border.SetAttribute("Weight", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
			$borders.appendChild($border) | out-null
		}
		$style.appendChild( $borders )  | out-null
		$style.appendChild($interior)  | out-null
		$style.appendChild($font)  | out-null
		
		$style.appendChild( $private.xml.CreateElement('NumberFormat', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$style.appendChild( $private.xml.CreateElement('Protection', $private.xmlNameSpaceMgr.LookupNamespace("")) )  | out-null
		$styles.appendChild($style) | out-null
  
		$private.xml.Workbook.appendChild($styles) | out-null
		
	}
	
	method renameSheet{
		param( $sheetIndex, $sheetName )
		
		$sheet = $private.xml.selectSinglenode("(/ns:Workbook/ns:Worksheet)[$($sheetIndex)]", $private.xmlNameSpaceMgr)
		if($sheet -ne $null){
			$sheet.setAttribute("Name",$sheetName)
		}
	}
	
	method selectSheet{
		param( $sheetName )
		
		if( $sheetName | isNumeric ){
			$private.activeSheet = $sheetName
		}else{
			$c = 0
			$private.xml.Workbook.Worksheet | % {
				$c++
				if ($_.name -eq $sheetName){
					$private.activeSheet = $c
				}
			}
		}
	}
	
	method addMatrix{
		param(
			[int] $row = 1,
			[int] $col = 1,
			$cells
		)
		
		$r = $row
		foreach($rows in $cells){
			$c = $col
			foreach($cell in $rows){
				$this.updateCell($r, $c, $cell)
				$c++
			}
			$r++
		}
	}
	
	method addRow{
		param(
			[int] $r = 1,
			$cells = @()
		)
		
		$c = 1
		$cells | % {
			$this.updateCell($r, $c, $_)
			$c++
		}
	}
	
	method formatAllFirstRows{
		param($style)
		$worksheetCount = ( $private.xml.selectnodes("/ns:Workbook/ns:Worksheet",$private.xmlNameSpaceMgr)).count
		for($w = 1; $w -le $workSheetCount; $w++){
			$this.selectSheet($w)
			$this.formatRow(1,$style)
		}
		
	}
	
	method formatRow{
		param(
			[int] $row = 1,
			$style
		)
		
		$columns = ( $private.xml.selectnodes("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[$row]/ns:Cell",$private.xmlNameSpaceMgr)).count
		for($c = 1; $c -le $columns; $c++){
			$this.formatCell($row,$c,$style)
		}

	}
	
	method formatCell{
		param(
			[int] $row = 1,
			[int] $col = 1,
			[export.excelStyle]$style
		)
		
		$cell = $private.xml.selectSinglenode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[$($row)]/ns:Cell[$($col)]", $private.xmlNameSpaceMgr)
		if($utilities.isBlank($cell) -eq $false){
			$cell.setAttribute("StyleID", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "$($style)") | out-null
		}
		
	}
	
	method updateCell{
		param(
			[int] $row = 1,
			[int] $col = 1,
			[string] $cellData = "",
			$style = $null
		)
		
		if($private.xml.Workbook.Worksheet -ne $null){
				$currentRows = ( $private.xml.selectnodes("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row",$private.xmlNameSpaceMgr)).count

				write-verbose "Current Rows: $($currentRows)"
				#does the requested row exist in the xml document
				for($r = $currentRows; $r -lt $row; $r++){
					$xmlRow = $private.xml.CreateElement('Row', $private.xmlNameSpaceMgr.LookupNamespace(""))
					$private.xml.selectSinglenode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table",$private.xmlNameSpaceMgr).appendChild($xmlRow) | out-null
				}
				
				#does the request cell exist in the xml document
				$currentCells = ( $private.xml.selectnodes("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[$row]/ns:Cell",$private.xmlNameSpaceMgr)).count
				write-verbose "Current Cells: $($currentCells)"
				for($c = $currentCells; $c -lt $col; $c++){
					$xmlCell = $private.xml.CreateElement('Cell', $private.xmlNameSpaceMgr.LookupNamespace(""))
					$private.xml.selectSinglenode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[$row]",$private.xmlNameSpaceMgr).appendChild($xmlCell) | out-null
				}
				
				#now...add the cell data
				
				$xmlData = $private.xml.CreateElement('Data', $private.xmlNameSpaceMgr.LookupNamespace(""))
				switch($true){
					{$cellData | isNumeric}		{$xmlData.SetAttribute("Type", $private.xmlNameSpaceMgr.LookupNamespace('ss'), 'Number') | out-null; }
					{$cellData | isInteger}		{$xmlData.SetAttribute("Type", $private.xmlNameSpaceMgr.LookupNamespace('ss'), 'Number') | out-null; }
					default						{$xmlData.SetAttribute("Type", $private.xmlNameSpaceMgr.LookupNamespace('ss'), 'String') | out-null; }
				}
				$xmlData.innerText = ($cellData -replace"[^\x00-\x7F]","");
				 
				write-verbose "Cell Data: $($cellData)"
				$private.xml.selectSinglenode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[$row]/ns:Cell[$col]",$private.xmlNameSpaceMgr).removeAll() | out-null
				$private.xml.selectSinglenode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[$row]/ns:Cell[$col]",$private.xmlNameSpaceMgr).appendChild($xmlData) | out-null
				
				if($utilities.isBlank($style) -eq $false){
					$this.formatCell($row,$col,($style)) | out-null;
				}
			
		}else{
			throw "Add a worksheet first"
		}
	}
	
	method mergeCells{
		param(
			[int]$row,
			[int]$col,
			[export.mergeType]$type,
			[int]$number
		)
		
		$cell = $private.xml.selectSinglenode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[$row]/ns:Cell[$col]",$private.xmlNameSpaceMgr)
		if($utilities.isBlank($cell) -eq $true){
			$this.updateCell($row,$col,"")
			$cell = $private.xml.selectSinglenode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[$row]/ns:Cell[$col]",$private.xmlNameSpaceMgr)
		}
		
		switch($type){
			$([export.mergeType]::Across) { $cell.SetAttribute("MergeAcross", $private.xmlNameSpaceMgr.LookupNamespace('ss'), $number) | out-null; }
			$([export.mergeType]::Down) { $cell.SetAttribute("MergeDown", $private.xmlNameSpaceMgr.LookupNamespace('ss'), $number) | out-null; }
		}
		
		
	}
	
	method dump {
		write-host ""
		write-host "----------------------------------------------------------------------"
		write-host "Namespaces"
		write-host "----------------------------------------------------------------------"
		foreach($prefix in ( $private.xmlNameSpaceMgr | sort) ){
			write-host "$($prefix) --> $($private.xmlNameSpaceMgr.LookupNamespace($prefix))"
		}
	
		$sw = New-Object system.io.stringwriter 
		$writer = New-Object system.xml.xmltextwriter($sw) 
		$writer.Formatting = [System.xml.formatting]::Indented 

		$private.xml.WriteContentTo( $writer ) 
		 
		write-host ""
		write-host "----------------------------------------------------------------------"
		write-host "XML"
		write-host "----------------------------------------------------------------------"
		write-host $sw.ToString() 
		write-host "----------------------------------------------------------------------"
		write-host ""
	}
	
	method autoFilterWorksheet{
		param( $row = 1 )
		
		$columns = ( $private.xml.selectnodes("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[$($row)]/ns:Cell",$private.xmlNameSpaceMgr)).count
	
		$worksheetNode = $private.xml.selectSinglenode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]",$private.xmlNameSpaceMgr)
		$autoFilter = $private.xml.CreateElement('AutoFilter', $private.xmlNameSpaceMgr.LookupNamespace("x"))
		$autoFilter.SetAttribute("Range", $private.xmlNameSpaceMgr.LookupNamespace('x'), "R$($row)C1:R$($row)C$($columns)") | out-null
		$worksheetNode.appendChild($autoFilter) | out-null
		
		$names = $private.xml.CreateElement('Names', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$namedRange = $private.xml.CreateElement('NamedRange', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$namedRange.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "_FilterDatabase") | out-null
		$namedRange.SetAttribute("RefersTo", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "=$($worksheetNode.Name)!R$($row)C1:R$($row)C$($columns)") | out-null
		$namedRange.SetAttribute("Hidden", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
		$names.appendChild($namedRange) | out-null
		($private.xml.selectSinglenode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]",$private.xmlNameSpaceMgr)).appendChild($names) | out-null
		
	}
	
	method autofitColumns{
		param()
		
		$columns = ( $private.xml.selectnodes("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row[1]/ns:Cell",$private.xmlNameSpaceMgr)).count
			
		$colWidths = @()
		for($c = 1; $c -le $columns; $c++){
			$maxLetters = 0
			$private.xml.selectnodes("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row/ns:Cell[$($c)]",$private.xmlNameSpaceMgr) | % {
				if( $_.innerText.toString().length -gt $maxLetters){
					$maxLetters = $_.innerText.toString().length
				}
			}	
			if( ( $maxLetters * 6.5) -lt 255){
				$colWidths += ($maxLetters * 6.5)
			}else{
				$colWidths += 255
			}
		}
		
		$colWidths | % {
			$col = $private.xml.CreateElement('Column', $private.xmlNameSpaceMgr.LookupNamespace(""))
			$col.SetAttribute("Width", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "$($_)") | out-null
			$col.SetAttribute("AutoFitWidth", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "1") | out-null
		
			$table = $private.xml.selectSingleNode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table",$private.xmlNameSpaceMgr)
			$row = $private.xml.selectSingleNode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row",$private.xmlNameSpaceMgr)
			$table.insertBefore($col,$row) | out-null
		}
	}
	
	method setColWidth{
		param([int]$c, $width)
		
		$col = $private.xml.CreateElement('Column', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$col.SetAttribute("Width", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "$($width)") | out-null
		$col.SetAttribute("AutoFitWidth", $private.xmlNameSpaceMgr.LookupNamespace('ss'), "0") | out-null
	
		$table = $private.xml.selectSingleNode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table",$private.xmlNameSpaceMgr)
		$row = $private.xml.selectSingleNode("/ns:Workbook/ns:Worksheet[$($private.activeSheet)]/ns:Table/ns:Row",$private.xmlNameSpaceMgr)
		$table.insertBefore($col,$row) | out-null
	}
	
	method autofitAllColumns{
		$worksheetCount = ( $private.xml.selectnodes("/ns:Workbook/ns:Worksheet",$private.xmlNameSpaceMgr)).count
		for($w = 1; $w -le $workSheetCount; $w++){
			$this.selectSheet($w)
			$this.autofitColumns()
		}
	}
	
	method saveAs{
		param( [string] $fileName )
		
		($private.xml.OuterXml) -replace "\\n","&#10;" | set-content $fileName
		# $private.xml.Save($fileName)
	}
	
<#
   Method: addWorkSheet
	Adds a worksheet to the export XML Object
	
   Parameters:
      sheetName - The name of the sheet to add
	  
   Returns:
      Null
	  
   See Also:
      <TJX.PolFileEditor.PolFile.GetBinaryValue>
#>
	method addWorkSheet{
		param( [string] $sheetName )
		
		$workSheet = $private.xml.CreateElement('Worksheet', $private.xmlNameSpaceMgr.LookupNamespace(""))
		$workSheet.SetAttribute("Name", $private.xmlNameSpaceMgr.LookupNamespace('ss'), $sheetName) | out-null
		$table = $private.xml.CreateElement('Table', $private.xmlNameSpaceMgr.LookupNamespace(""))
		
		$workSheet.appendChild($table) | out-null
		$private.xml.Workbook.appendChild($workSheet) | out-null

		$this.selectSheet($sheetName)
	}
}