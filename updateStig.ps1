<#
.SYNOPSIS
	This script copies all user input data from one STIG file to another.  
.DESCRIPTION
	This Script is designed to make updating to a new STIG Checklist 
    version faster and easier.  It will move the asset data and all comments,
    finding details, status, severity override and justifications from the
    oldFile to the newFile.  The Script assumes that the vulnerability ids
    are consistent from file to file.  It does not perform any checking for
    STIG items which may have been updated between versions and that will
    still need to be performed manually.  
    Before running this script, the DISA STIG Viewer must be used to save a
    new .ckl file with the new version of the STIG.

    WARNING: It is highly recommended that you use a copy of the old file.  
    this script has no sanity checking and will happily copy nothing back into 
    the old file from the new file if they are listed backwards in the command.
.PARAMETER oldFile
    The original Stig Checklist file (.ckl) which contains the comments, etc.
.PARAMETER newFile
    The new, empty Stig file (.ckl) which is to receive the comments, etc.
.EXAMPLE
	.\CopyToNewSTIG.ps1 -oldFile C:\Users\john.laska\Desktop\uRDTE_Application_Security_and_Development_STIG_V3R9.ckl -newFile C:\Users\john.laska\Desktop\uRDTE_Application_Security_and_Development_STIG_V3R10.ckl
	This would copy all of the data from the file for V3R9 to the file for V3R10
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: John Laska / Robert Weber
	Version History:
        2015-05-22 - Inital Script Creation 
        2015-08-12 - Changed Node matching to use Rule_Id rather than Vuln_Id as the latter was not unique in all STIGs
		2015-08-17 - Incorporated into Cyber Security Tool Suite
#>
[CmdletBinding()]
Param (
    [ValidateScript({ Test-Path -Path $_ })] [string]$oldFile,
    [ValidateScript({ Test-Path -Path $_ })] [string]$newFile
)

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$updateStigClass = new-PSClass updateStig{
	note -static PsScriptName "updateStig"
	note -static Description ( ($(((get-help .\updateStig.ps1).Description)) | select Text).Text)
	
	note -private mainProgressBar
	note -private gui
	
	note -private oldFile 
	note -private newFile
			
	method Execute{
		$oldXml = New-Object System.Xml.XmlDataDocument
		$newXml = New-Object System.Xml.XmlDataDocument
		$oldXml.PreserveWhitespace = $true
		$newXml.PreserveWhitespace = $true
		$oldXml.Load($private.oldFile)
		$newXml.Load($private.newFile)
		
		foreach($vuln in ($oldXml.selectNodes('//VULN'))){
			#first check for matching rules
			$newNode = $newXml.SelectSingleNode(("//VULN[./STIG_DATA/VULN_ATTRIBUTE='Rule_ID' and ./STIG_DATA/ATTRIBUTE_DATA='{0}']" -f ($vuln.STIG_DATA | ?{$_.VULN_ATTRIBUTE -eq "Rule_Id" }).Attribute_Data))
			#if no matching rule, search for matching vuln
			if($utilities.isBlank($newNode)){
				$newNode = $newXml.SelectSingleNode(("//VULN[./STIG_DATA/VULN_ATTRIBUTE='Vuln_Num' and ./STIG_DATA/ATTRIBUTE_DATA='{0}']" -f ($vuln.STIG_DATA | ?{$_.VULN_ATTRIBUTE -eq "Vuln_Num" }).Attribute_Data))
			}
			
			if($newNode -notlike $null) {
				$newNode.STATUS = "$($vuln.STATUS)"
				$newNode.FINDING_DETAILS = "$($vuln.FINDING_DETAILS)"
				$newNode.COMMENTS = "$($vuln.COMMENTS)"
				$newNode.SEVERITY_OVERRIDE = "$($vuln.SEVERITY_OVERRIDE)"
				$newNode.SEVERITY_JUSTIFICATION = "$($vuln.SEVERITY_JUSTIFICATION)"
				$uiClass.writeColor("$($uiClass.STAT_OK) Node found for Vuln_Num #yellow#$(($vuln.STIG_DATA | ? { $_.VULN_ATTRIBUTE -eq 'Vuln_Num'} ).ATTRIBUTE_DATA)#, Rule Id #green#$(($vuln.STIG_DATA | ? { $_.VULN_ATTRIBUTE -eq 'Rule_ID'} ).ATTRIBUTE_DATA)#")
			} else {
				$uiClass.writeColor("$($uiClass.STAT_WARN) Node not found for Vuln_Num #yellow#$(($vuln.STIG_DATA | ? { $_.VULN_ATTRIBUTE -eq 'Vuln_Num'} ).ATTRIBUTE_DATA)#, Rule Id #green#$(($vuln.STIG_DATA | ? { $_.VULN_ATTRIBUTE -eq 'Rule_ID'} ).ATTRIBUTE_DATA)#")
			}
		}
		
		$newXml.CHECKLIST.ASSET.ASSET_TYPE = "$($oldXml.CHECKLIST.ASSET.ASSET_TYPE)"
		$newXml.CHECKLIST.ASSET.HOST_NAME = $oldXml.CHECKLIST.ASSET.HOST_NAME.ToString()
		$newXml.CHECKLIST.ASSET.HOST_IP = $oldXml.CHECKLIST.ASSET.HOST_IP.ToString()
		$newXml.CHECKLIST.ASSET.HOST_MAC = $oldXml.CHECKLIST.ASSET.HOST_MAC.ToString()

		$newXml.Save($private.newFile)
		
		$uiClass.errorLog()
	}
	
	constructor{
		param()
		
		$private.oldFile = $oldFile
		$private.newFile = $newFile
		
		while( ($utilities.isBlank($private.oldFile) -eq $true) -or ($utilities.isBlank($private.newFile) -eq $true) ){
			$private.gui = $null
		
			$private.gui = $guiClass.New("updateStig.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			
			
			$private.gui.Controls.btnOldFile.add_Click({ $private.gui.Controls.txtOldFile.Text = $private.gui.actInvokeFileBrowser() })
			$private.gui.Controls.btnNewFile.add_Click({ $private.gui.Controls.txtNewFile.Text = $private.gui.actInvokeFileBrowser() })
			
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.oldFile = $private.gui.Controls.txtOldFile.Text
			$private.newFile = $private.gui.Controls.txtNewFile.Text
		}
	}
}

$updateStigClass.New().Execute() | out-null