<#
.SYNOPSIS
	This is a script will attempt to change the power scheme on a remote computer and prevent sleep.
.DESCRIPTION
	This is a script will attempt to change the power scheme on a remote computer and prevent sleep.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.EXAMPLE 
	C:\PS>.\preventSleep.ps1 -computers "hostname1,hostname2" 
	This example will attempt to prevent sleep on the computers entered into the command line
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Jan 09, 2015
#>
[CmdletBinding()]
param (	$hostCsvPath = "", $computers = @(), $OU = "" )   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$preventSleepClass = new-PSClass PreventSleep{
	note -static PsScriptName "preventSleep"
	note -static Description ( ($(((get-help .\preventSleep.ps1).Description)) | select Text).Text)
	
	note -private HostObj @{}
	note -private macHosts @{}
	
	constructor{
		param()
		$private.HostObj  = $HostsClass.New()
	}
	
	method Execute{
		foreach($remoteHost in ( $private.HostObj.Hosts.GetEnumerator() | ? { $_.Name -ne "" -and $_.Name -ne $null } | sort Name)){
			try{
				([wmiclass]"\\$($remoteHost.Name)\root\cimv2:win32_Process").create('cmd /c powercfg.exe -change -standby-timeout-ac 0')  | out-null
				([wmiclass]"\\$($remoteHost.Name)\root\cimv2:win32_Process").create('cmd /c powercfg.exe -change -hibernate-timeout-ac 0')  | out-null
				$uiClass.writeColor( "$($uiClass.STAT_OK) Standby values updated on #yellow#$($remoteHost.Name)#") | out-null
			}catch{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not connect to #yellow#$($remoteHost.Name)#") | out-null
			}
		}
		$uiClass.errorLog()
	}
}

$preventSleepClass.New().Execute()  | out-null