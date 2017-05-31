<#
.SYNOPSIS
	This is a script that will analyze a list of hosts and ensure all services with spaces are properly quoted
.DESCRIPTION
	This is a script that will analyze a list of hosts and ensure all services with spaces are properly quoted
.PARAMETER hosts
	A comma separated list of hosts specified in the CA Plan
.PARAMETER hostCsvPath
	The path to a csv file with hosts listed
.PARAMETER computers
	A parameter of comman separated host names
.PARAMETER OU
	An ou to pull hosts from 
.PARAMETER test
	Whether to only test run, or to actually execute
.EXAMPLE
	C:\PS>.\serviceQuotes.ps1 -computers "host1,host2,host3"
	This example will udpate the hosts found in the hosts parameter
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder.  Resulting export is in the results folder
.NOTES
	Author: Robert Weber
	Date:   Feb 3, 2015
#>
#OU=Q50 Computers,OU=Computers,OU=Org - Q,DC=rdte,DC=nswc,DC=navy,DC=mil
[CmdletBinding()]
param( $hostCsvPath = "", $computers = @(), $OU = "", [switch] $test )

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$serviceQuotesClass = new-PSClass serviceQuotes{
	note -static PsScriptName "serviceQuotes"
	note -static Description ( ($(((get-help .\serviceQuotes.ps1).Description)) | select Text).Text)
	
	note mainProgressBar
	
	note -private HostObj @{}
	note -private test
		
	method Execute{
		if($private.HostObj.Hosts.count -gt 0){
			
			$this.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / $( $private.HostObj.Hosts.count )"; "Status" = ("{0:N2}% complete" -f 0); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		
			$i = 0
			foreach($remoteHost in ( $private.HostObj.Hosts.GetEnumerator() | sort Name)){
				$i++
				$this.mainProgressBar.Activity("$i / $( $private.HostObj.Hosts.count ) : Analyzing host $($remoteHost.name)").Status("{0:N2}% complete" -f (100*$i/$( $private.HostObj.Hosts.count ) )).Percent( (100*$i/$( $private.HostObj.Hosts.count ) ) ).Render()
				
				try{
					$uiClass.writeColor("$($uiclass.STAT_OK) Updating #green#$($remoteHost.name)#")
				
					$gwmi = ( gwmi win32_service -computerName $($remoteHost.name) | ? { $_.pathname -notlike '"*' } )
					
					$serviceProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / $( $gwmi.count )"; "Status" = ("{0:N2}% complete" -f 0); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
					$s=0
					foreach($service in $gwmi){
						$s++
						
						$serviceProgressBar.Activity("$s / $( $gwmi.count ) : Analyzing service $($service.name)").Status("{0:N2}% complete" -f (100*$s/$( $gwmi.count ) )).Percent( (100*$s/$( $gwmi.count ) ) ).Render()

						if( $service.pathName.indexOf(" -") -eq -1 -and $service.pathName.indexOf(" /") -eq -1 -and $service.pathName.indexOf("=") -eq -1){
							if($service.pathName.indexOf(" ") -ne -1){
								$replacement = """$($service.pathname.trim())"""
								$uiClass.writeColor("$($uiClass.STAT_OK)      Service: #green#$($service.Name)#")
								$uiClass.writeColor("$($uiClass.STAT_OK)      Old: #yellow#$($service.pathname)#")
								$uiClass.writeColor("$($uiClass.STAT_OK)      New: #yellow#$($replacement)#")
								if($private.test -eq $null -or $private.test -eq $false){
									$service.Change($null,$replacement) | out-null
								}
								$uiClass.writeColor("")
							}
						}else{

							if( $service.pathname -like "* /*"){
								$executable = (($service.pathname.split("/"))[0]).Trim()
								$replacement = $service.pathname.replace( $executable, """$executable""")
								if($executable -like '* *'){
									$uiClass.writeColor("$($uiClass.STAT_OK)      Service: #green#$($service.Name)#")
									$uiClass.writeColor("$($uiClass.STAT_OK)      Old: #yellow#$($service.pathname)#")
									$uiClass.writeColor("$($uiClass.STAT_OK)      New: #yellow#$($replacement)#")
									if($private.test -eq $null -or $private.test -eq $false){
										$service.Change($null,$replacement) | out-null
									}
								}
							}elseif( $service.pathname -like '* -*'){
								$executable = (($service.pathname.split("-"))[0]).Trim()
								$replacement = $service.pathname.replace( $executable, """$executable""")
								if($executable -like '* *'){
									$uiClass.writeColor("$($uiClass.STAT_OK)      Service: #green#$($service.Name)#")
									$uiClass.writeColor("$($uiClass.STAT_OK)      Old: #yellow#$($service.pathname)#")
									$uiClass.writeColor("$($uiClass.STAT_OK)      New: #yellow#$($replacement)#")
									if($private.test -eq $null -or $private.test -eq $false){
										$service.Change($null,$replacement) | out-null
									}
									$uiClass.writeColor("")
								}
							}elseif( $service.pathname -like '*=*'){
								$executable = ($service.pathname -replace "([a-zA-Z0-9_]+=[a-zA-Z0-9_]+)","" ).trim()								
								$replacement = $service.pathname.replace( $executable, """$executable""")
								if($executable -like '* *'){
									$uiClass.writeColor("$($uiClass.STAT_OK)      Service: #green#$($service.Name)#")
									$uiClass.writeColor("$($uiClass.STAT_OK)      Old: #yellow#$($service.pathname)#")
									$uiClass.writeColor("$($uiClass.STAT_OK)      New: #yellow#$($replacement)#")
									if($private.test -eq $null -or $private.test -eq $false){
										$service.Change($null,$replacement) | out-null
									}
									$uiClass.writeColor("")
								}
							}
						}
						
					}
					$serviceProgressBar.Completed($true).Render() 
				}catch{
					$uiClass.writeColor("$($uiclass.STAT_ERROR) Could not connect to #green#$($remoteHost.name)#")
				}
			}
		}
	}
	
	constructor{
		param()
		$private.HostObj = $HostsClass.New()
		if($test -ne "" -and $test -ne $false){
			$private.test = $test
		}else{
			$private.test = $false
		}
	}
}

$serviceQuotesClass.New().Execute() | out-null