<#
.SYNOPSIS
	This script returns the pixel color information for a pixel under the mouse cursor.
.DESCRIPTION
	This script returns the pixel color information for a pixel under the mouse cursor.
.EXAMPLE
	.\pixelData.ps1 
	This starts the pixel data tool
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Version History:
        2015-11-18 - Inital Script Creation 
#>
[CmdletBinding()]
Param ( )

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$pixelDataClass = new-PSClass pixelData{
	note -static PsScriptName "pixelData"
	note -static Description ( ($(((get-help .\pixelData.ps1).Description)) | select Text).Text)
	
	note -private gui
	note -private grabber
		
	method Execute{
		$private.grabber = new-object cyberToolSuite.pixelDataObj
		while($private.gui.Form.Visible){
			$colors = $private.grabber.Get() 
			
			$private.gui.Controls.btnShowColor.BackColor = "#$('{0:x2}' -f $colors.R)$('{0:x2}' -f $colors.G)$('{0:x2}' -f $colors.B)".toUpper()
			
			$private.gui.Controls.lblHex.Text = "heX: 0x" + "$('{0:x2}' -f $colors.B)$('{0:x2}' -f $colors.G)$('{0:x2}' -f $colors.R)".toUpper()
			$private.gui.Controls.lblHtml.Text = "Html: #" + "$('{0:x2}' -f $colors.R)$('{0:x2}' -f $colors.G)$('{0:x2}' -f $colors.B)".toUpper()
			$private.gui.Controls.lblRGB.Text = "Rgb: " + "($($colors.R), $($colors.G), $($colors.B))"
			
			$black  = @(
				( 1 - ( $colors.R / 255 ) ),
				( 1 - ( $colors.G / 255 ) ),
				( 1 - ( $colors.B / 255 ) )
			) | sort | select -first 1
			
			if($black -eq 1){
				$black = .999
			}
						
			$cyan    = "{0:N0}" -f ( ( (1 - $( $colors.R / 255 ) - $black) / (1-$black) ) * 100 )
			$magenta = "{0:N0}" -f ( ( (1 - $( $colors.G / 255 ) - $black) / (1-$black) ) * 100 )
			$yellow  = "{0:N0}" -f ( ( (1 - $( $colors.B / 255 ) - $black) / (1-$black) ) * 100 )
			
			$newBlack = "{0:N0}" -f ($black * 100)
			$private.gui.Controls.lblCMYK.Text = "Cymk: " + "($($cyan),$($magenta),$($yellow),$($newBlack))"
			
			
			
			$max = @($colors.R, $colors.G, $colors.B) | sort -descending | select -first 1
			$min = @($colors.R, $colors.G, $colors.B) | sort | select -first 1

			if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
				$uiClass.writeColor("$($uiClass.STAT_OK) Cursor Pixel Color is #yellow#$($colors)# ")
			}
			
			$h = [System.Drawing.Color]::FromArgb($colors.R, $colors.G, $colors.B).GetHue()
			if($max -eq 0){
				$s = 0
			}else{
				$s = 1 - (1 * $min / $max);	
			}
			$s = $s *100
			$v = $max / 255 * 100;
		
			$private.gui.Controls.lblHSV.Text = "hSv: ($('{0:N0}' -f $h), $('{0:N0}' -f $s), $('{0:N0}' -f $v))"

			[System.Windows.Forms.Application]::DoEvents()  | out-null
			
		}
	}
	
	constructor{
		param()

		if(!(test-path "$pwd\bin\pixelData.dll")){
			Add-Type -Language CSharpVersion3 -TypeDefinition ([System.IO.File]::ReadAllText("$pwd\types\pixelData.cs")) -ReferencedAssemblies @("System.Drawing","WindowsBase","System.Windows.Forms") -ErrorAction Stop -OutputAssembly "$pwd\bin\pixelData.dll" -outputType Library
		}
		if (!("cyberToolSuite.pixelDataObj" -as [type])) {
			Add-Type -path "$pwd\bin\pixelData.dll"
		}
		
		$private.gui = $null
		$private.gui = $guiClass.New("pixelData.xml")
		$private.gui.generateForm();
		
		# $private.gui.Controls.btnShowColor.FlatStyle = [system.windows.forms.flatstyle]::Flat
		# $private.gui.Controls.btnShowColor.FlatAppearance.BorderSize = 0;
		
		add-type -an System.Windows.Forms

		$private.gui.controls.btnShowColor.add_keyDown( { 
			# $_ | fl | out-string | write-host} 
			if($_.Alt -eq $true -and $_.Control -eq $true){
				switch($_.KeyCode){
					'H' { [System.Windows.Forms.Clipboard]::SetText(($private.gui.Controls.lblHtml.Text -split '#')[1] ) }
					'X' { [System.Windows.Forms.Clipboard]::SetText(($private.gui.Controls.lblHex.Text -split ' ')[1] ) }
					'R' { [System.Windows.Forms.Clipboard]::SetText(($private.gui.Controls.lblRGB.Text -split ': ')[1] ) }
					'C' { [System.Windows.Forms.Clipboard]::SetText(($private.gui.Controls.lblCMYK.Text -split ': ')[1] ) }
					'S' { [System.Windows.Forms.Clipboard]::SetText(($private.gui.Controls.lblHSV.Text -split ': ')[1] ) }
				}
			}
		} )
		
		$private.gui.Form.TopMost= $true
		$private.gui.Form.Visible = $true
	}
}


if ([System.Threading.Thread]::CurrentThread.ApartmentState -eq [System.Threading.ApartmentState]::MTA){
    powershell.exe -Sta -File $MyInvocation.MyCommand.Path
    return
}else{
	$pixelDataClass.New().Execute() | out-null
}