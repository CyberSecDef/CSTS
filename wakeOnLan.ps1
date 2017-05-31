<#  
.SYNOPSIS
	This is a script will attempt to wake up computers via network calls
.DESCRIPTION
	This is a script will attempt to wake up computers via network calls.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.EXAMPLE    
	C:\PS>.\wakeOnLan.ps1 -computers "hostname1,hostname2" 
	This example will attempt to wake up the computers entered into the command line
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Dec 30, 2014
#>
[CmdletBinding()]
param ( $hostCsvPath = "", $computers = @(), $OU = "")   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$WakeOnLanClass = new-PSClass WakeOnLan{
	note -static PsScriptName "WakeOnLan"
	note -static Description ( ($(((get-help .\WakeOnLan.ps1).Description)) | select Text).Text)
	
	note -private HostObj @{}
	note -private macHosts @{}
	
	constructor{
		param()
			$private.HostObj  = $HostsClass.New()
	}
	
	method Execute{
		$sqlSelect = "SELECT hostname, ip, mac FROM system where lower(hostname) = lower(:hostname)"

		$packetScript = {
			$MACAddr = ($args[0]).split(':') | %{ [byte]('0x' + $_)}
			$UDPclient = new-Object System.Net.Sockets.UdpClient
			$UDPclient.Connect(([System.Net.IPAddress]::Broadcast),4000)
			$packet = [byte[]](,0xFF * 6)
			$packet += $MacAddr * 16
			[void] $UDPclient.Send($packet, $packet.Length)
			
			return "Sent WOL Packet to $($args[0])"
		}
		
		foreach($remoteHost in ( $private.HostObj.Hosts.GetEnumerator() | ? { $_.Name -ne "" -and $_.Name -ne $null } | sort Name)){
			$sqlParms = @{ "hostname" = "$($remoteHost.Name.Trim())";}
			$sHosts = $dbclass.get().query($sqlSelect, $sqlParms ).execAssoc()
			
			foreach($sHost in $sHosts){
				$sHost | Add-Member -MemberType NoteProperty -Name ActiveIP ""

				if($utilities.isBlank($sHost.mac) -eq $false){
					$uiClass.writeColor( "$($uiClass.STAT_OK) Hostname: #green#$($sHost.Hostname)#" )
					
					try{
						$sHost.ActiveIP = ([System.Net.Dns]::GetHostAddresses($sHost.Hostname) | ? { $_.AddressFamily -eq 'InterNetwork' } )
						$uiClass.writeColor( "$($uiClass.STAT_WAIT)      IP:       #yellow#$($sHost.ActiveIP)#" )
					}catch{
						$uiClass.writeColor( "$($uiClass.STAT_ERROR)      IP Not Found")
					}

					$uiClass.writeColor( "$($uiClass.STAT_WAIT)      MAC:      #yellow#$($sHost.MAC)#")
				
					$MACStr = $sHost.MAC
					if($utilities.isBlank($sHost.MAC) -eq $false -and $utilities.isBlank($sHost.ActiveIP) -eq $false  ){
						
						$MACAddrParts = $MACStr.split(':') 

						if ($MACAddrParts.Length -ne 6){
							 throw 'MAC address must be format xx:xx:xx:xx:xx:xx'
						}

						#see if the machine is awake already
						$pingResult = (gwmi -class win32_pingstatus  -filter "address='$($sHost.Hostname.Trim())'")
						
						if( ($pingResult.StatusCode -eq 0 -or $pingResult.StatusCode -eq $null ) -and $utilities.isBlank($pingResult.IPV4Address) -eq $false ) {
							$uiClass.writeColor( "$($uiClass.STAT_OK)      Host #green#$($sHost.Hostname)# is already awake.")
						}else{
							$uiClass.WriteColor("$($uiClass.STAT_OK)      Sending Wake-On-Lan Packet from #green#localhost#")
							invoke-command -scriptBlock $packetScript -argumentList @($MACStr)
							
							#find other hosts on same vlan and use them to send packet as well.
							if($utilities.isBlank($sHost.ActiveIP) -eq $false){
								$ip = ([ipAddress]$sHost.ActiveIP).GetAddressBytes()[0..2] -join "."
								$range = 1..254
								$pingsSent = 0
								foreach($r in ($range | sort {get-random} ) ){
									$uiClass.WriteColor("$($uiClass.STAT_WAIT) Testing IP #green#$($ip).$($r)#")
									$slavePing = (gwmi -class win32_pingstatus  -filter "address='$($ip).$($r)'")
									if( ($slavePing.StatusCode -eq 0 -or $slavePing.StatusCode -eq $null ) -and $utilities.isBlank($slavePing.IPV4Address) -eq $false ) {
										$pingsSent++
										$uiClass.WriteColor("$($uiClass.STAT_OK)      IP #green#$($ip).$($r)# is alive")
										
										#attempt to have remote computer send wake on lan packet
										$slaveHost = (([System.Net.Dns]::gethostentry("$($ip).$($r)").HostName))
										$uiClass.WriteColor("$($uiClass.STAT_OK)      Sending Wake-On-Lan Packet from #green#$slaveHost#")
										$i = invoke-command -scriptBlock $packetScript -argumentList @($MACStr) -computerName $slaveHost
									}
									
									if($pingsSent -ge 5){
										break;
									}
								}
							}
							
							
							$uiClass.writeColor( "$($uiClass.STAT_OK) Wake-On-Lan magic packet sent to #yellow#$MACStr#")
						}
						
						$uiClass.writeColor()
					}else{
						$uiClass.writeColor( "$($uiClass.STAT_ERROR)      Invalid MAC or IP Address for #yellow#$($remoteHost.Name)# - #green#$($MACStr)#")
						$uiClass.writeColor()
					}
				}else{
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) MAC Address not found for #yellow#$($remoteHost.Name)#")
					$uiClass.writeColor()
				}
			}
		}
		$uiClass.errorLog()
	}
}

$WakeOnLanClass.New().Execute()