<#
.SYNOPSIS
	This is a script will scan for systems that have active bluetooth or wifi adapters
.DESCRIPTION
	This is a script will scan for systems that have active bluetooth or wifi adapters
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.EXAMPLE 
	C:\PS>.\scan4wifiBluetooth.ps1 -computers "hostname1,hostname2" 
	This example will attempt to prevent sleep on the computers entered into the command line
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   July 6, 2015
#>
[CmdletBinding()]
param (	$hostCsvPath = "", $computers = @(), $OU = "" )   

#-ou "OU=Q20 Computers,OU=Computers,OU=Org - Q,DC=rdte,DC=nswc,DC=navy,DC=mil" 

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$scan4wifiBluetoothClass = new-PSClass scan4wifiBluetooth{
	note -static PsScriptName "scan4wifiBluetooth"
	note -static Description ( ($(((get-help .\scan4wifiBluetooth.ps1).Description)) | select Text).Text)
	
	note -private HostObj @{}

	note -private [UInt32] HKLM "0x80000002"
	note -private valueName "DisplayName"
	note -private softwareKeys @("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
	note -private updateKeys @("SOFTWARE\Wow6432Node\Microsoft\Updates","SOFTWARE\Microsoft\Updates")
	note -private startupKeys @("SOFTWARE\Microsoft\Windows\CurrentVersion\Run","SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run")

	note -private results @{}
	
	note -private mainProgressBar
	
	note -private export $ExportClass.New()
	note -private sheetRow 1
	note -private colHeaders @("Hostname","Finding Type","Finding")
	
	constructor{
		param()
		$private.HostObj  = $HostsClass.New($hostCsvPath, $computers, $OU)
		
	}
	
	method Export {
		param()
		
		$private.export.addWorkSheet('Wifi and BlueTooth')
		
		$col = 1
		$private.sheetRow = 1
		$private.colHeaders | %{ 
			$private.export.updateCell(1,$col, $_)
			$col = $col + 1
		}
		
		foreach($computer in ($private.results.keys | Sort )){
			$uiClass.writeColor("$($uiClass.STAT_OK) Exporting Installed BlueTooth or Wifi findings on #green#$($computer.Trim())#")
			 foreach($resultType in ($private.results.$( $computer.Trim() ).Keys | sort ) ){
				 
				foreach($item in $( $private.results.$( $computer.Trim() ).$($resultType) )){
					$uiClass.writeColor( "$($uiClass.STAT_WAIT)`t#yellow#$($resultType)# -> $($item)" )
					
					$private.sheetRow++					
					$private.export.updateCell($private.sheetRow,1, "$($computer.Trim())") | out-null
					$private.export.updateCell($private.sheetRow,2, "$($resultType.Trim())") | out-null
					$private.export.updateCell($private.sheetRow,3, "$($item.Trim())") | out-null
				}
			 }
		}
		
		$private.export.autoFilterWorksheet()
		$private.export.autofitAllColumns()
		$private.export.formatAllFirstRows('Header')
		
		$ts = (get-date -format "yyyyMMddHHmmss")
		$private.export.saveAs([System.IO.Path]::GetFullPath("$($pwd.ProviderPath)\results\$($scan4wifiBluetoothClass.PsScriptName)_$ts.xml")) | out-null
		
		$uiClass.errorLog()
	}
	
	method Execute{
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		$currentHost = 0
		foreach($computer in ( $private.HostObj.Hosts.GetEnumerator() | ? { $_.Name -ne "" -and $_.Name -ne $null } | sort Name)){
			$currentHost++
			$i = (100*($currentHost / $($private.HostObj.Hosts.count) ))
			
			$private.mainProgressBar.Activity("$currentHost / $($private.HostObj.Hosts.count) : Processing Host $($computer.name.trim())").Status(("{0:N2}% complete" -f $i)).Percent($i).Render() | out-null
		
			$pingResult = Get-WmiObject -Class win32_pingstatus -Filter "address='$($computer.Name.Trim())'"
			if( $pingResult.StatusCode -eq 0 -or $pingResult.StatusCode -eq $null ) {
				#add host to results object
				$private.results.add(
					$($computer.Name.Trim()), @{
						"software" = @();
						"updates" = @();
						"startup" = @();
						"network" = @();
						"hardware" = @();
						"services" = @();
					}
				)
			
				#collect inventory from host
				try{
					$uiClass.writeColor("$($uiClass.STAT_OK) Collecting inventory on #green#$($computer.name.Trim())#")
					$hardwareItems = $null;
					$serviceItems = $null;
					$networkItems = $null;
					$registry = $null;
					
					
					$hardwareItems = (gwmic -class win32_pnpentity -namespace "root\cimv2" -computerName $($computer.Name.Trim()) | ?  { $_.status -eq 'OK' -and ($_.caption -like '*bluetooth*'  -or $_.caption -like '*wifi*' -or $_.caption -like '*wireless*') } )
					$serviceItems = (gwmic -class win32_service -namespace "root\cimv2" -computerName $($computer.Name.Trim()) | ?  { $_.startmode -ne 'disabled' -and ( $_.caption -like '*bluetooth*'  -or $_.caption -like '*wifi*' -or $_.caption -like '*wireless*') } )
					$networkItems = (gwmic -class win32_NetworkProtocol -namespace "root\cimv2" -computerName $($computer.Name.Trim()) | ? { $_.Name -like '*bluetooth*'  -or $_.Name -like '*wifi*' -or $_.Name -like '*wireless*' } )
					#$networkItems2 = (gwmi cim_networkadapter -computerName $($computer.Name.Trim()) | ? { $_.Name -like '*bluetooth*'  -or $_.Name -like '*wifi*' -or $_.Name -like '*wireless*' } )
					$registry = [WMIClass] "\\$($computer.Name.Trim())\root\default:StdRegProv"
				}catch{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not collect inventory on #green#$($computer.name.Trim())#")
				}
				
				try{
					foreach($key in $private.softwareKeys){
						($registry.enumKey($private.HKLM, $key) | select sNames).sNames  | %{ $registry.GetStringValue($private.HKLM, "$($key)\$($_)", $valueName)  | ? {$_.sValue -like '*bluetooth*' -or $_.sValue -like '*wifi*' -or $_.sValue -like '*wireless*' } | % { $private.results.$($computer.Name.Trim()).software +=  $_.sValue } }
					}
				}catch{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not enumerate installed software on #green#$($computer.name.Trim())#")
				}
		
				try{
					foreach($key in $private.updateKeys){
						($registry.enumKey($private.HKLM, $key) | select sNames).sNames | %{ $registry.GetStringValue($private.HKLM, "$($key)\$($_)", $valueName)  | ? {$_.sValue -like '*bluetooth*'  -or $_.sValue -like '*wifi*' -or $_.sValue -like '*wireless*' } | % { $private.results.$($computer.Name.Trim()).updates +=  $_.sValue } }
					}
				}catch{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not enumerate installed updates on #green#$($computer.name.Trim())#")
				}
				
				try{
					foreach($key in $private.startupKeys){
						($registry.enumKey($private.HKLM, $key) | select sNames).sNames | %{ $registry.GetStringValue($private.HKLM, "$($key)\$($_)", $valueName)  | ? {$_.sValue -like '*bluetooth*'  -or $_.sValue -like '*wifi*' -or $_.sValue -like '*wireless*' } | % { $private.results.$($computer.Name.Trim()).startup +=  $_.sValue } }
					}
				}catch{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not enumerate installed startup programs on #green#$($computer.name.Trim())#")
				}

				try{
					foreach($objItem in $networkItems){
						if($objItem -ne $null){
							$private.results.$($computer.Name.Trim()).network += "$($objItem.Name) - $($objItem.Description)" 
						}
					}
				}catch{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not enumerate installed network adapters on #green#$($computer.name.Trim())#")
				}
				
				try{
					foreach($objItem in $hardwareItems){
						if($objItem -ne $null){
							$private.results.$($computer.Name.Trim()).hardware += "$($objItem.caption)" 
						}
					}
				}catch{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not enumerate installed hardware on #green#$($computer.name.Trim())#")
				}

				try{
					foreach($objItem in $serviceItems){
						if($objItem -ne $null){
							$private.results.$($computer.Name.Trim()).services += "$($objItem.caption)" 
						}
					}
				}catch{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not enumerate installed services on #green#$($computer.name.Trim())#")
				}
	
			}else{
				$private.results.add(
					$($computer.Name.Trim()), @{ "offline" = $computer.Name.Trim() }
				)
				
				$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not connect to  #green#$($computer.name.Trim())#")
			}
		}
		$private.mainProgressBar.Completed($true).Render()  | out-null
		$uiClass.errorLog()
	}
}

$scanData = $scan4wifiBluetoothClass.New()
$scanData.Execute()  
$scanData.Export()