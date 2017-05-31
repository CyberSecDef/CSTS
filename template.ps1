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
param (	)   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$templateClass = new-PSClass template{
	note -static PsScriptName "template"
	note -static Description ( ($(((get-help .\template.ps1).Description)) | select Text).Text)
	
	note -private mainProgressBar
	note -private gui
	
	method publicFunction{
		param($par)
		write-host "publicFunction called"
	}
	
	method -private privateFunction{
		param($par)
		write-host "privateFunction called"
	}
	
	constructor{
		param()
		
		$private.gui = $null
		
		$private.gui = $guiClass.New("template.xml")
		$private.gui.generateForm() | out-null;
		
		$private.gui.Form.ShowDialog() | Out-Null	
	}
	
	method Execute{
		param($par)
		
		$uiClass.errorLog()
	}
}

$templateClass.New().Execute()  | out-null