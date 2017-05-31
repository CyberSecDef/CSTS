Add-Type -Path "$pwd\bin\iTextSharp\itextsharp.dll"
# #########################################################################
# Class: PdfClass
# 	Creates a PDF document as the end product for a script
#
# See Also:
# 	<excelClass>
# #########################################################################
$PdfClass = new-PSClass Pdf{
	
	# Section: Public Members
	
	# Variable: doc
	# The internal PDF Object
	note doc
	
	note filename "$($pwd)\results\$(get-date -format 'yyyyMMddHHmmss').pdf"
	note topMargin 20
	note bottomMargin 20
	note leftMargin 20 
	note rightMargin 20
	note author ""
	
	# Section: Public Members

	
	# #########################################################################
	# Method: Constructor
	# 	Constructs a new Pdf Class Object
	#
	# Returns:	
	# 	New <PdfClass> Object
	#
	# See Also:
	# 	<TJX.PolFileEditor.PolFile.GetBinaryValue>
	# #########################################################################
	constructor{
		param(
			$filename = $null,
			$author = "",
			$topMargin = 20,
			$bottomMargin = 20,
			$leftMargin = 20,
			$rightMargin = 20
		)
		$this.doc = New-Object iTextSharp.text.Document
		
		
		if($utilities.isBlank($filename) -eq $false){  $this.filename = $filename }
		if($utilities.isBlank($author) -eq $false){  $this.author = $author }
		if($utilities.isBlank($topMargin) -eq $false){  $this.topMargin = $topMargin }
		if($utilities.isBlank($bottomMargin) -eq $false){  $this.bottomMargin = $bottomMargin }
		if($utilities.isBlank($leftMargin) -eq $false){  $this.leftMargin = $leftMargin }
		if($utilities.isBlank($rightMargin) -eq $false){  $this.rightMargin = $rightMargin }
		
		$this.createPdf() | out-null
	}
	
	
	
	method createFont{
		param(
			[string]$family = "Verdana",
			[int]$size = 10,
			[string]$style = "Normal",
			[string]$BaseColor = "Black",
			[int[]]$color = @(0,0,0)
		)
		
		$font = [iTextSharp.text.FontFactory]::GetFont($family, $size, [iTextSharp.text.Font]::$Style, [iTextSharp.text.BaseColor]::$baseColor)
		$font.SetColor($color[0],$color[1],$color[2]);
		return $font
	}

	method createParagraph{
		param(
			$text = "",
			$alignment = "ALIGN_CENTER",
			[int]$spacingBefore = 20,
			[int]$spacingAfter = 20,
			$font = $this.createFont()
		)
		
		$p = New-Object iTextSharp.text.Paragraph
		$p.Alignment = ([iTextSharp.text.Element]::$alignment)
		$p.font = $font
		$p.SpacingBefore = $spacingBefore
		$p.SpacingAfter = $spacingAfter
		$p.add($text) | out-null
		return @{"results" = $p;}
	}
	
	# Add an image to the document, optionally scaled
	method addImage{
		param(
			[string]$File, 
			[int32]$Scale = 100
		)
		
		[iTextSharp.text.Image]$img = [iTextSharp.text.Image]::GetInstance($File)
		$img.ScalePercent($scale) | out-null
		$this.doc.Add($img) | out-null
	}

	# Add a table to the document with an array as the data, a number of columns, and optionally centered
	method addTable{
		param(
			[string[]]$Dataset, 
			[int32]$Cols = 3, 
			[bool]$Centered = $false,
			[int32]$width = 100
		)
		$font = [iTextSharp.text.FontFactory]::GetFont("Arial", 8)
		
		$t = New-Object iTextSharp.text.pdf.PDFPTable($Cols)
		$t.WidthPercentage = $width
		$t.SetWidths(@( 1, 1, 4));
		 
		$t.SpacingBefore = 5
		$t.SpacingAfter = 5
		if(!$Centered) { $t.HorizontalAlignment = 0 }
		foreach($data in $Dataset)
		{
			$cell = New-Object iTextSharp.text.pdf.PDFPCell;
			$phrase = new-object iTextSharp.text.Phrase($data,$font);
			$cell.addElement( $phrase );
			$t.AddCell($cell );
		}
		$this.doc.Add($t) | out-null
	}


	# Add a title to the document, optionally with a font name, size, color and centered
	method addTitle{
		param(
			[string]$Text, 
			[bool]$Centered, 
			[string]$FontName = "Arial", 
			[int32]$FontSize = 16, 
			[string]$Color = "BLACK"
		)
		
		$p = New-Object iTextSharp.text.Paragraph
		$p.Font = [iTextSharp.text.FontFactory]::GetFont($FontName, $FontSize, [iTextSharp.text.Font]::BOLD, [iTextSharp.text.BaseColor]::$Color)
		if($Centered) { $p.Alignment = [iTextSharp.text.Element]::ALIGN_CENTER }
		$p.SpacingBefore = 5
		$p.SpacingAfter = 5
		$p.Add($Text) | out-null
		$this.doc.Add($p) | out-null
	}


	# Add a text paragraph to the document, optionally with a font name, size and color
	method addText{
		param(
			[string]$Text, 
			[string]$FontName = "Arial", 
			[int32]$FontSize = 10, 
			[string]$Color = "BLACK"
		)
		
		$p = New-Object iTextSharp.text.Paragraph 
		$p.Font = [iTextSharp.text.FontFactory]::GetFont($FontName, $FontSize, [iTextSharp.text.Font]::NORMAL, [iTextSharp.text.BaseColor]::$Color)
		$p.SpacingBefore = 2
		$p.SpacingAfter = 2
		$p.Add($Text) | out-null
		$this.doc.Add($p) | out-null
	}

	# Set basic PDF settings for the document
	method createPdf{
		param()
		$this.doc.SetPageSize([iTextSharp.text.PageSize]::LETTER) | out-null
		$this.doc.SetMargins($this.LeftMargin, $this.RightMargin, $this.TopMargin, $this.BottomMargin) | out-null
		[iTextSharp.text.pdf.PdfWriter]::GetInstance($this.doc, [System.IO.File]::Create($this.filename)) | out-null
		$this.doc.AddAuthor($this.Author) | out-null
	}

	method add{
		param($elem)
		$this.doc.add($elem) | out-null
	}

	method open{
		param()
		$this.doc.open()
	}
	
	method close{
		param()
		$this.doc.close()
	
	}
}