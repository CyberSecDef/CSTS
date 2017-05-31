$HostsClass = new-PSClass Hosts{
	note -private hostGui
	note -private Hosts @{}
	
	note -private hostCsvPath
	note -private computers
	note -private OU
			
	property Hosts -get { return $private.Hosts	}
	property Count -get { return $private.Hosts.Count }
	
	method -private updateMac{
		$runningJobs = get-job | ? { $_.State -ne 'Completed' } | ? { $_.Name -eq 'updateMac' }
		
		if($runningJobs.count -eq 0 -or $runningJobs -eq $null){
			$uiclass.writeColor("$($uiclass.STAT_WAIT) Updating Mac Address Database")
			$j = start-job -name updateMac -argumentList $private.Hosts,$pwd -scriptBlock { 
				$macHosts = import-csv "$($args[1])\conf\hostMac.csv"
				foreach($h in $args[0].GetEnumerator() ){
					$pingResult = Get-WmiObject -Class win32_pingstatus -Filter "address='$($h.name.Trim())'"
					if( ($pingResult.StatusCode -eq 0 -or $pingResult.StatusCode -eq $null ) -and $utilities.isBlank($pingResult.IPV4Address) -eq $false ) {
						$macs = Get-WmiObject win32_networkadapterconfiguration -computerName $($h.name) | ? { $_.macaddress -ne "" -and $_.macaddress -ne $null } | select description, macaddress
						foreach($mac in $macs){
							if( ($macHosts | ? { $_.Hostname -eq $($h.name) } | ? { $_.MAC -eq $mac.macaddress } ) -eq $null){
								$newMacRow = New-Object PsObject -Property @{ Hostname = "$($h.name)" ; IP = ''; MAC = "$($mac.macaddress)" }
								$macHosts += $newMacRow
							}
						}
					}
				}
				$macHosts | export-csv "$($args[1])\conf\hostMac.csv" -NoTypeInformation
			}
		}
	}
	
	method -private ParseCSV{
		if($private.hostCsvPath -ne "" -and $private.hostCsvPath -ne $null){
			if(test-path $private.hostCsvPath){
				$csvHosts = import-csv "$($private.hostCsvPath)"
				foreach($c in $csvHosts){
					if($c.Hostname -ne "" -and $c.Hostname -ne $null){
						if($private.Hosts.Keys -notcontains $c.HostName.Trim()){
							$private.Hosts.Add($c.Hostname.Trim(), @{} )
						}
					}
				}
			}
		}
	}
	
	method -private ParseComputers{
		foreach($c in $private.computers.split(",")){
			if($c -ne "" -and $c -ne $null){
				if($private.Hosts.Keys -notContains $c.Trim()){
					$private.Hosts.Add($c.Trim(), @{} )
				}
			}
		}
	}
	
	method -private ParseOu{
		$ds = New-Object DirectoryServices.DirectorySearcher
		$ds.Filter = "ObjectCategory=Computer"
		$ds.SearchRoot = "LDAP://$($private.OU)"

		
		$ds.FindAll() | % {
			$adHost = [string]($_.Properties['dnshostname'])
			
			
			if(($adHost.indexOf(".")) -ne -1){
				if(($adHost.indexOf(".")) -gt 0){
					$adHost = $adHost.substring(0,$adHost.indexOf("."))
				}
			}
		
			$adHost = $adHost.trim()
			
			if($utilities.isBlank($adHost) -eq $false){
				if( $adHost -ne $null -and $private.Hosts.keys -notcontains $adHost ){
					$private.Hosts.Add( $adHost, @{"Software" = @(); "Stigs" = @()} )
				}
			}
		}
	}

	method -private GetHosts{
		if($private.hostCsvPath -ne "" -and $private.hostCsvPath -ne $null){
			$private.ParseCSV()
		}
		if($private.computers -ne "" -and $private.computers -ne $null){
			$private.ParseComputers()
		}
		if($private.OU -ne "" -and $private.OU -ne $null){
			$private.ParseOu()
		}
		
		$private.updateMac()
	}
		
	constructor{
		param( )
		if( $utilities.isBlank($hostCsvPath) -eq $true -and ( $utilities.isBlank($computers) -eq $true -or $computers.count -eq 0) -and $utilities.isBlank($OU) -eq $true){
			$private.hostGui = $null
			$private.hostGui = $HostGuiClass.New() 
			$private.hostCsvPath = $private.hostGui.HostCsvPath
			$private.computers = $private.hostGui.Computers
			$private.OU = $private.hostGui.OU.replace("LDAP://","")
		}else{
			$private.hostCsvPath = $hostCsvPath
			$private.computers = $computers
			$private.OU = $OU
		}
		$private.GetHosts()
	}
}