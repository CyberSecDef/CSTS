<# 
.SYNOPSIS
	This is a script will attempt to fix issues with dot net and certificate issues which prevent windows udpate from installing updates.  
.DESCRIPTION
	This is a script will attempt to fix issues with dot net and certificate issues which prevent windows udpate from installing updates.
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.PARAMETER stig
	Whether to set the computer to a STIG approved setting or a known good setting
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   May 01, 2015
#>
[CmdletBinding()]
param (	$hostCsvPath = "", $computers = @(), $OU = "", [switch] $stig )   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$fixDotNetClass = new-PSClass FixDotNet{
	note -static PsScriptName "fixDowNet"
	note -static Description ( ($(((get-help .\fixDotnet.ps1).Description)) | select Text).Text)
	
	note -private HostObj @{}
	note -private macHosts @{}
	note -private stig
	
	note -private ScriptBlock {
		param( $stig )
		
		set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\" -Name AcceptTrustedPublisherCerts -value "1" -type dword
		foreach($user in (gci -path "Registry::HKEY_USERS" | ? { $_.Name -notlike '*classes*' } ) ) {
			$oldState = Get-ItemProperty -Path "Registry::$($user.name)\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing\" -Name State
			set-ItemProperty -Path "Registry::$($user.name)\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing\" -Name oldState -value "$($oldState.state)" -type dword
			set-ItemProperty -Path "Registry::$($user.name)\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing\" -Name stigState -value "65536" -type dword
			set-ItemProperty -Path "Registry::$($user.name)\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing\" -Name dotNetState -value "141385"  -type dword
			
			if($stig){
				set-ItemProperty -Path "Registry::$($user.name)\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing\" -Name State -value "65536" -type dword
			}else{
				set-ItemProperty -Path "Registry::$($user.name)\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing\" -Name State -value "141385"  -type dword
			}
		}
		
		[reflection.assembly]::LoadWithPartialName("System.Security")
		foreach($certFile in (gci "C:\temp\*.p7b" ) ){
			$data = [System.IO.File]::ReadAllBytes($certFile.FullName)
			$cms = new-object system.security.cryptography.pkcs.signedcms
			$cms.Decode($data) | out-null
			foreach($certObj in $cms.Certificates) {
				$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certObj
				$store = New-Object System.Security.Cryptography.X509Certificates.X509Store "TrustedPublisher", "LocalMachine"
				$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite) | out-null
				$store.Add($cert) | out-null
				$store.Close() | out-null
			}
			Write-Verbose "Successfully added '$certfile' to 'cert:\LocalMachine\TrustedPublisher'."
		}
		
		remove-item "c:\temp\*.p7b"
	}
	
	constructor{
		param()
		$private.HostObj  = $HostsClass.New($hostCsvPath, $computers, $OU)
		$private.stig = $stig
	}
	
	method Execute{
		foreach($remoteHost in ( $private.HostObj.Hosts.GetEnumerator() | ? { $_.Name -ne "" -and $_.Name -ne $null } | sort Name)){
			
			$pingResult = Get-WmiObject -Class win32_pingstatus -Filter "address='$($remoteHost.Name.Trim())'"
		
			if( ($pingResult.StatusCode -eq 0 -or $pingResult.StatusCode -eq $null ) -and $utilities.isBlank($pingResult.IPV4Address) -eq $false ) {
			
				$uiclass.writeColor( "$($uiclass.STAT_OK) Analyzing #green#$($remoteHost.Name)")
				
				if( (test-path "\\$($remoteHost.Name)\c`$\temp\") -eq $false){
					$uiclass.writeColor( "$($uiclass.STAT_ERROR) #green#\\$($remoteHost.Name)\c`$\temp\# does not exist.  Creating it now.")
					new-item -type Directory -path "\\$($remoteHost.Name)\c`$\temp\"
				}else{
					$uiclass.writeColor( "$($uiclass.STAT_OK) #green#\\$($remoteHost.Name)\c`$\temp\# exists")
				}
				
				$uiclass.writeColor( "$($uiclass.STAT_OK) Deploying current certificates")
				copy-item "$pwd\conf\*.p7b" "\\$($remoteHost.Name)\c`$\temp\"
				sleep -seconds 5
				
				invoke-command -computerName $remoteHost.Name -scriptBlock $private.ScriptBlock -Args $private.stig
				
				sleep -seconds 5
				$uiclass.writeColor( "$($uiclass.STAT_OK) Removing temporary certificate locations.")
				remove-item "\\$($remoteHost.Name)\c`$\temp\*.p7b"
			}else{
				$uiclass.writeColor( "$($uiclass.STAT_ERROR) Could not connect to #green#$($remoteHost.Name)#")
			}
		}
		$uiClass.errorLog()
	}
}

$fixDotNetClass.New().Execute()  | out-null