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
param (	
	$hostCsvPath = "", 
	$computers = @(), 
	$OU = "", 
	[switch]$filter
)   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$netStatClass = new-PSClass netStat{
	note -static PsScriptName "netStatScanner"
	note -static Description ( ($(((get-help .\template.ps1).Description)) | select Text).Text)
	
	note -private mainProgressBar
	note -private gui
	note -private hostObj
	note -private export $ExportClass.New()
	note -private results @()
	
	constructor{
		param()
		$private.HostObj  = $HostsClass.New()
	}
	
	method Execute{
		param($par)
		$hostProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
		
		$sql = "select id, port, purpose from commonPort where port = :port"
		$properties = @('T/U','L.Add','L.Port','L.Purpose','R.Add','R.Port','R.Purpose','State','Name','PID','User','System')
		
		$currentComputer = 0
				
		foreach($comp in ($private.HostObj.Hosts.keys | sort)){
		
			$currentComputer++
			$i = (100*($currentComputer / @(1,$private.HostObj.Hosts.count)[($private.HostObj.Hosts.count -gt 0)]))
			
			$hostProgressBar.Activity("$currentComputer / $($private.HostObj.Hosts.count): Scanning system $comp").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			$uiClass.writeColor("$($uiClass.STAT_WAIT) Scanning system #green#$($comp)#")
			
			
			$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($comp.Trim())'"
			if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
				
				$processes = @{}
				gwmi win32_process -computerName $comp | % {
					if( (($_ | gm -memberType Method | select -expand Name ) -contains 'getOwner')  -eq $true ){
						if($_.handle -ne $null){
							try{
								$processes[ $_.handle ] = $_.getOwner().user
							}catch{
								write-host "$($_.handle) could not be resolved to a user"
							}
						}
					}
				}
				
				if( ((hostname) -eq $comp)){
					$netstat = invoke-command -scriptBlock { $d = & netstat -ano ; return $d } 
				}else{
					$netstat = invoke-command -scriptBlock { $d = & netstat -ano ; return $d } -computerName $comp
				}
				
				
				($netStat -split "`r`n") | Select-String -Pattern '\s+(TCP|UDP)' | ForEach-Object {
				
					$item = $_.line.split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
					
					if($item ){
					if($item[1] -notmatch '^\[::') {
					
						if (($la = $item[1] -as [ipaddress]).AddressFamily -eq 'InterNetworkV6') { 
						   $localAddress = $la.IPAddressToString 
						   $localPort = $item[1].split('\]:')[-1] 
						} else { 
							$localAddress = $item[1].split(':')[0] 
							$localPort = $item[1].split(':')[-1] 
						} 

						if (($ra = $item[2] -as [ipaddress]).AddressFamily -eq 'InterNetworkV6') { 
						   $remoteAddress = $ra.IPAddressToString 
						   $remotePort = $item[2].split('\]:')[-1] 
						} else { 
						   $remoteAddress = $item[2].split(':')[0] 
						   $remotePort = $item[2].split(':')[-1] 
						} 
						
						if( ($filter -eq $false) -or ( $filter -eq $true -and [int]$localPort -le 1024 ) ){
							$purpose = $dbClass.Get().query($sql, @{'port' = $localPort ;}).execAssoc();
							if( ($utilities.isBlank($purpose) -eq $false) ){
								$lpurpose = $purpose.purpose;
							}else{
								$lpurpose = "";
							}
						
							$purpose = $dbClass.Get().query($sql, @{'port' = $remotePort ;}).execAssoc();
							if( ($utilities.isBlank($purpose) -eq $false) ){
								$rpurpose = $purpose.purpose;
							}else{
								$rpurpose = "";
							}
							
							$r = New-Object PSObject -Property @{
								System = $comp
								PID = $item[-1] 
								Name = (Get-Process -Id $item[-1] -ErrorAction SilentlyContinue).Name 
								User = ($processes[ $($item[-1] ) ] )
								'T/U' = $item[0] 
								'L.Add' = $localAddress 
								'L.Port' = $localPort 
								'L.Purpose' = $lpurpose
								'R.Add' = $remoteAddress 
								'R.Port' = $remotePort
								'R.Purpose' = $rpurpose
								State = if($item[0] -eq 'tcp') {$item[3]} else {$null} 
							} | Select-Object -Property $properties
							
							$private.results += $r
						}
					}
					}
				}
			}else{
				$uiClass.writeColor("$($uiClass.STAT_ERR) System #green#$($comp)# is #red#offline#")
			}
		}
		
		$hostProgressBar.Completed($true).Render() 
		$private.exports()
		
		$uiClass.errorLog()
	}
	
	method -private exports{
	
		$private.export.addWorkSheet('Active Ports')
		$colHeaders = @("System","TCP/UDP","Local Address","Local Port","Local Purpose","Remote Address","Remote Port","Remote Purpose","State","Process ID","Process Name","Runas User")
		$sheetRow = 1
		$col = 1
		$colHeaders | %{ 
			$private.export.updateCell(1,$col,$_)
			$col = $col + 1
		}
		
		$private.results | %{
			$sheetRow++
			$private.export.addRow(
				$sheetRow,
				@(
					$_.system,
					$_.'T/U',
					$_.'L.Add',
					$_.'L.Port',
					$_.'L.Purpose',
					$_.'R.Add',
					$_.'R.Port',
					$_.'R.Purpose',
					$_.'State',
					$_.'PID',
					$_.'Name',
					$_.'User'
				)
				
			)
			
		}
		
		$private.export.autoFilterWorksheet()
		$private.export.autofitAllColumns()
		$private.export.formatAllFirstRows('Header')
		$ts = (get-date -format "yyyyMMddHHmmss")
		$private.export.saveAs([System.IO.Path]::GetFullPath("$($pwd.ProviderPath)\results\$($netStatClass.PsScriptName)_$ts.xml"))

	}
}

$netStatClass.New().Execute()  | out-null