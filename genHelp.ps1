<#
.SYNOPSIS
	This script generates a document with the help information for all the scripts in the suite.
.DESCRIPTION
	This script generates a document with the help information for all the scripts in the suite.
.EXAMPLE
	C:\PS>.\genHelp.ps1 
	This will create a readme.txt file in the docs folder of the suite and will create the html based api documentation
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Oct 26, 2015
#>
clear;
#generate naturaldocs
& "$pwd\bin\NaturalDocs\NaturalDocs.exe" -i "$pwd" -p "$pwd\docs\"  -o html "$pwd\docs\" -xi "$pwd\results" -xi "$pwd\stigs" -xi "$pwd\wim" -xi "$pwd\wsus"

#generate readme file in docs directory
$(@"
Project Purpose: 
This project is a tool suite written in PowerShell to help System Administrators and Information Assurance Officers with any DOD Information Assurance Certification and Accreditation Process (DIACAP) and Information Assurance (IA) related processes.  This suite is able to convert scan results into Plans of Actions and Milestones (POAMs), archive event logs, compare package hardware lists to actual hardware lists, check the status of Information Assurance Vulnerability Management items (IAVMs), execute Security Technical Implementation Guidelines (STIGs), convert benchmark STIGs to Group Policy Objects and many other IA related actions.

Major Technologies Employed: 
This tool suite is programmed in PowerShell, which is derived from the Dot Net Framework.  It can execute on any windows based system that has PowerShell V2 installed.  It utilizes a GNU Public License (GPL) library for many of its internal Object Oriented functions.

Related DoD Programs/Systems: 
There are no other Programs of record or identifiable systems that are related to this tool suite.

Participation Plans: 
Members of this project should have a deep developmental background utilizing Dot Net (preferably C#) and knowledge of the way PowerShell operates.  Members must also have knowledge of common System Administrator tasks.
 
The suite is available online at:
https://software.forge.mil/sf/projects/diacap_tools 

Go Home -> File Releases -> Cyber Security Tool Suite -> Latest version

The scripts come as a suite, so just unzip them anywhere you would like.  Once that is done, you'll need to let PowerShell know it can execute scripts.  You can do that by opening PowerShell as an admin, and running the following command:
 
PS C:\>set-executionpolicy unrestricted
 
It should prompt you for confirmation.  Just enter Y and hit enter.  Once that is done, you should have full access to the scripts.  Most of them can be run either via command line parameters are with the built in user interface.  There is also a setup.bat file in the root directory that will accomplish the same.  Most of the scripts require the PowerShell console to be run as an administrator and Microsoft Office needs to be installed for export purposes.
 
Below is a quick rundown of the scripts and what they do.  I'm assuming you unzipped to 'C:\Scripts' so that is the path you'll see.  Most of the scripts will accept the following command line parameters, or the GUI can be used if these are not provided.   Executing the script by just calling its name (.\scriptName.ps1) will use the GUI.
 
hostCsvPath - the path to a csv file that contains hostnames, if available.
computers - a comma separated string of hostnames
OU - a string specifying an Active Directory OU container for the hosts that need to be processed.
 
You can also execute
PS c:\> get-help .\scriptname.ps1 to view the internal documentation.
"@

ls "*.ps1*" | sort Name | % {
	"-------------------------------------------------------------------------------"
	$h = get-help -full $_ 
	".\$($_.Name)"
	(($h.Description) | select Text).Text
	""
	if($h.Parameters.Parameter.count -gt 1){
		"Parameters:"
		for($i = 0; $i -lt $h.Parameters.Parameter.count; $i++){
			"`t$($h.Parameters.Parameter[$i].Name) - $( ($h.Parameters.Parameter[$i].Description | select Text).Text)"
		}
	}elseif($h.Parameters.Parameter -ne $null){
		"Parameter:"
		"`t$($h.Parameters.Parameter.Name) - $( ($h.Parameters.Parameter.Description | select Text).Text)"	
	}
	
	""
	if( $h.Examples.example.count -gt 1){
		"Examples:"
		for($i = 0; $i -lt $h.Examples.example.count; $i++){
			"`t$($h.Examples.Example[$i].code)"
			"`t$(((($h.Examples.Example[$i]) ).remarks | ? { $_.Text -ne '' } | select Text).Text)"
			""
		}
	}elseif( $h.Examples.example -ne $null){
		"Example:"
		"`t$($h.Examples.Example.code)"
		"`t$(((($h.Examples.Example) ).remarks | ? { $_.Text -ne '' } | select Text).Text)"
		""
	}
}
) | set-content "$pwd\docs\README.txt"