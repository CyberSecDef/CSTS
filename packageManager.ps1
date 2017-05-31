<#
.SYNOPSIS
	[Incomplete script!] This script helps manage DIACAP Package Evidence Submission.
.DESCRIPTION
	[Incomplete script!] This script helps manage DIACAP Package Evidence Submission.
.EXAMPLE
	C:\PS>.\packageManager.ps1
	This will bring up the packageManager manager console.
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Sep 14, 2015
#>
[CmdletBinding()]
param (	)

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$packageManagerClass = new-PSClass packageManager{
	note -static PsScriptName "packageManager"
	note -static Description ( ($(((get-help .\packageManager.ps1).Description)) | select Text).Text)

	note -private mainProgressBar
	note -private gui

	note -private package
	note -private xml
	note -private findings

	#main form methods
	(gci .\modules\packageManager\ ) | % { . "$($_.FullName)" }
	
}

$packageManagerClass.New().Execute()  | out-null