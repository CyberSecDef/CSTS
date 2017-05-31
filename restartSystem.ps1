<#
.SYNOPSIS
	This is a script will attempt to restart systems at a designated time
.DESCRIPTION
	This is a script will attempt to restart systems at a designated time
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.PARAMETER time
	The time to restart the system
.PARAMETER type
	The shutdown type to use (LogOff, Reboot, ForcedShutdown, etc).
.EXAMPLE    
	C:\PS>.\restratSystem.ps1 -computers "hostname1,hostname2" -type ForcedReboot
	This example will attempt to restart the computers entered into the command line
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Aug 06, 2015
#>
[CmdletBinding()]
param (	$hostCsvPath = "", $computers = @(), $OU = "", [datetime]$time, $type)

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }


$restartSystemClass = new-PSClass RestartSystem{
	note -static PsScriptName "restartSystem"
	note -static Description ( ($(((get-help .\restartSystem.ps1).Description)) | select Text).Text)
	
	note -private gui
	note -private HostObj @{}
	note -private macHosts @{}
	
	note -private time
	note -private type
	
	note -private tickerSymbol @('-','\','|','/')
	note -private startSpan
	note -static ShutdownType @{"LogOff"=0;"Shutdown"=1;"Reboot"=2;"ForcedLogOff"=4;"ForcedShutdown"=5;"ForcedReboot"=6;"PowerOff"=8;"ForcedPowerOff"=12;}
	
	
	constructor{
		param()
		$private.HostObj  = $HostsClass.New()
		
		$private.type = $type
		$private.time = $time
		
		while( ($utilities.isBlank($private.time) -eq $true) -or ($utilities.isBlank($private.type) -eq $true) ){
			$private.gui = $null
		
			$private.gui = $guiClass.New("restartHosts.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.time = $private.gui.Controls.dtpDate.Text + " " + $private.gui.Controls.dtpTime.Text
			
			$private.type = $private.gui.Controls.cboType.text
			
		}
		
		$private.startSpan = (new-timespan -start (get-date) -end $private.time).TotalSeconds
	}
	
	method Execute{
		
		if($restartSystemClass.ShutdownType.keys -notContains $private.type){
			$uiClass.writeColor("$($uiClass.STAT_ERROR) Invalid restart type ($type) specified")
			return
		}else{
		
			$waiting = $true
			$ticker = 0
			while($waiting -eq $true){
				$ticker++

				$timeSpan = (new-timespan -start (get-date) -end $private.time)
				if( $timeSpan.TotalMinutes  -lt 0){
					$waiting = $false
					
					foreach($remoteHost in ( $private.HostObj.Hosts.GetEnumerator() | sort Name)){
						$uiclass.writeColor( "$($uiClass.STAT_WAIT) Attempting to $($type) #green#$($remoteHost.Name.Trim())#")
						Try { 
							
							$sys = (gwmic -computerName $remoteHost.Name.Trim() -class Win32_OperatingSystem -namespace "root\cimv2" -timeout 15)
							$sys.Win32Shutdown( $($restartSystemClass.ShutdownType.$type) )
														
							$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($type)# of #green#$($remoteHost.Name.Trim())# successful." )
						}
						Catch { 
							$uiClass.writeColor( "$($uiClass.STAT_ERROR) #yellow#$($type)# of #green#($remoteHost.Name.Trim())# failed." )
						}
					}
				}else{
					$uiClass.clearLine()
					$uiClass.writeColor( ( "[   $($private.tickerSymbol[$($ticker % 4)])   ] #green#T Minus#: #yellow#{0:00}:{1:00}:{2:00}:{3:00}# " -f $timeSpan.days, $timeSpan.hours, $timeSpan.minutes, $timeSpan.seconds ), $true)
					
					$bar = ""
					for($i=0;$i -lt ((80 - [int](80*$ticker/$private.startSpan))); $i++){
						switch($true){
							{$timeSpan.totalSeconds -ge ( $private.startSpan * .1)}{$bar += "#green#]#" }
							{$timeSpan.totalSeconds -ge ( $private.startSpan * .05 ) -and $timeSpan.totalSeconds -lt ( $private.startSpan * .1 )}{$bar += "#yellow#]#" }
							{$timeSpan.totalSeconds -lt $private.startSpan * .05}{$bar += "#red#]#" }
						}
					}
					$uiClass.writeColor( $bar, $true)
					sleep -milliseconds 1000
				}
			}
		}
		$uiClass.errorLog()
	}
}

$restartSystemClass.New().Execute()  | out-null