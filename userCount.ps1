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
	[string]$ou = "LDAP://",
	[string]$cOu = "",
	[string]$uOu = ""
)   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$userCountClass = new-PSClass userCount{
	note -static PsScriptName "userCount"
	note -static Description ( ($(((get-help .\userCount.ps1).Description)) | select Text).Text)
	
	note mainProgressBar
	note -private startTime (get-date)
	note -private exporter $ExportClass.New()
	
	note -private cOu ""
	note -private uOu ""
	
	note -private domainusers @()
	note -private exceptionUsers @()
	note -private disabledUsers @()
	note -private offlineSystems @()
	note -private localSystems @()

	note -private domain "$( ([ADSI]'LDAP://RootDSE').Get('rootDomainNamingContext') )"
	note -private adRoot ""
	note -private objUserSearch ""
	
	constructor{
		param()
		
		if($uOu -ne '' -and $cOu -ne ''){
			$private.cou = $cou
			$private.uou = $uou
		}else{
			$private.cou = $ou
			$private.uou = $ou
		}
		
		$private.adRoot = ([adsi]$private.cou)
		$private.objUserSearch = New-Object System.DirectoryServices.DirectorySearcher($private.adRoot)
	}

	method -private getLocalUsers{
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Parsing Local Users" )
		
		$localPBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 : Parsing Local Users"; "Status" = ("{0:N2}% complete" -f 0); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
	
		#local admin groups
		$ds = New-Object DirectoryServices.DirectorySearcher
		$ds.Filter = "ObjectCategory=Computer"
		$ds.SearchRoot = $private.cou
		$systems = $ds.FindAll()

		$totalSys = $systems.count
		$currentSys = 1
		foreach($system in ( $systems | sort Path) ){
			$hostName = $($system.properties.item('cn'))
			$uiClass.writeColor( "$($uiClass.STAT_OK) Connecting to Host #green#$($hostName)#" )
		
			$i = (100*($currentSys / $totalSys))
			$runtime = [string]::format("{0:N2} sec(s)", ($(get-date) - $private.startTime).totalSeconds)
			$timePer = [string]::format("{0:N2} sec(s)",( (($(get-date) - $private.startTime).totalSeconds)/$currentSys) )
			$eta = [string]::format("{0:N2} sec(s)",( (($(get-date) - $private.startTime).totalSeconds)/$currentSys)*$totalSys - ($(get-date) - $private.startTime).totalSeconds )
			
			$localPBar.Activity("$currentSys / $totalSys : $($hostName) ").Status("{0:N2}% complete; Time Per Host $timePer, Total RunTime $runtime; ETA $eta" -f $i).Percent($i).Render()	
			
			$ou = ((($system.properties.item('adspath') -replace 'LDAP://','' -split ',') | ? { $_ -like 'OU=*' } | % { $_ -replace 'OU=','' }))
			[array]::Reverse($ou)
					
			$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($hostName.Trim())'"
			if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
				try{
					([adsi]"WinNT://$hostName,computer").psbase.children | ? { $_.psbase.schemaClassName -eq 'group'} | % {
						$groupName = $($_.path.substring( $_.path.lastIndexOf('/')+1))
						$Group = [ADSI]"$($_.path),group"
						[Array]$MemberNames = @($Group.psbase.Invoke("Members")) | % {  $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) } | Sort
						if($MemberNames-ne $null){
							$private.localSystems += New-Object PSObject -Property @{
								OU = $ou -join '\'
								Host = $hostName.ToLower()
								Group = $groupName
								Members = ($MemberNames -join ";")
							}
						}
					}
				}catch{
					$private.offlineSystems += new-object PSObject -Property @{
						OU = $ou -join '\'
						Host = $hostName.ToLower()
					}
				
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) `tError Parsing Host #green#$($hostName)#" )
				}
			}else{
				$private.offlineSystems += new-object PSObject -Property @{
					OU = $ou -join '\';
					Host = $hostName.ToLower()
				}
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) `tHost #green#$($hostName)# is #yellow#Offline#" )
			}
			$currentSys++
		}
		$localPBar.Completed($true).Render() 
	}
	
	method -private getADUsers{
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Parsing Domain Users" )
		
		$private.objUserSearch.filter = "(&(objectCategory=person)(objectClass=user))"
		$private.domainusers = $private.objUserSearch.findall() | select *, @{e={[string]$adspath=$_.properties.adspath;$account=[ADSI]$adspath;$account.psbase.invokeget('AccountDisabled')};n='Disabled'} | sort Path

		$private.objUserSearch.filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=262144)))"
		$private.objUserSearch.findall() | % {
			$private.exceptionUsers += $_.properties.item('cn')
		}

		$private.objUserSearch.filter = "(&(objectCategory=person)(objectClass=user)((userAccountControl:1.2.840.113556.1.4.803:=2)))"
		$private.objUserSearch.findall() | % {
			$private.disabledUsers += $_.properties.item('cn')
		}
	}
	
	method -private exportADUsers{
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Exporting Domain Users" )
		
		$list = @()
		foreach($domainUser in $private.domainusers){
			$userName = $($domainUser.properties.item('cn'))
			if( (([ADSISEARCHER]"samaccountname=$($userName)").Findone().Properties.memberof -replace '^CN=([^,]+).+$','$1' | ? { $_ -like '*admin*'}) -ne $null ){
				$adminPriv = 'X'
			}else{
				$adminPriv = ''
			}

			$list += (New-Object PSObject -Property @{
				UserName = $userName;
				AdminPriv = $adminPriv;
				Exception = @('','X')[$private.exceptionUsers -contains $userName];
				Disabled = @('','X')[$private.disabledUsers -contains $userName];
			})
		}

		# $list | select Username, AdminPriv, Exception, Disabled | ft | out-string | write-host
		
		$private.exporter.addWorkSheet('Domain Accounts')
		$colHeaders = @("Username","Admin Privileges","Exception List","Disabled")
		$col = 1
		$colHeaders | %{
			$private.exporter.updateCell(1,$col,$_)
			$private.exporter.formatCell(1,$col,[export.excelStyle]::Header)
			$col = $col + 1
		}
		
		$row = 2
		$list | % {
			$private.exporter.addRow($row, @($_.userName, $_.AdminPriv, $_.Exception, $_.Disabled) )
			$row++
		}
		$private.exporter.autoFilterWorksheet(1)
		$private.exporter.autofitColumns()
	
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Exporting Domain User Summary" )
		
		$private.exporter.addWorkSheet('Domain Account Summary')
		$colHeaders = @("Statistic","Count")
		$col = 1
		$colHeaders | %{
			$private.exporter.updateCell(1,$col,$_)
			$private.exporter.formatCell(1,$col,[export.excelStyle]::Header)
			$col = $col + 1
		}
		
		$private.exporter.addRow(2, @("Domain Users in B:", $list.count ) )
		$private.exporter.addRow(3, @("Domain Users in B with Exceptions:", $(($list | ? { $_.Exception -eq 'X' }).count) ) )
		$private.exporter.addRow(4, @("Domain Users in B that are not disabled:", $(($list | ? { $_.Disabled -ne 'X' }).count) ) )
		$private.exporter.addRow(5, @("Domain Users in B that are disabled:", $(($list | ? { $_.Disabled -eq 'X' }).count) ) )
		$private.exporter.addRow(6, @("Domain Users in B that are not disabled and on the exceptions list:", $(($list | ? { $_.Disabled -ne 'X' -and $_.Exception -eq 'X' }).count) ) )
		$private.exporter.addRow(7, @("Domain Users in B that are disabled on the exceptions list:", $(($list | ? { $_.Disabled -eq 'X' -and $_.Exception -eq 'X' }).count) ) )
		$private.exporter.addRow(8, @("Domain Users in B that are privileged:", $(($list | ? { $_.AdminPriv -eq 'X' }).count) ) )
		$private.exporter.addRow(9, @("Domain Users in B that are privileged on exceptions list:", $(($list | ? { $_.AdminPriv -eq 'X' -and $_.Exception -eq 'X' }).count) ) )
		
		$private.exporter.autoFilterWorksheet(1)
		$private.exporter.autofitColumns()
	}
	
	method -private exportLocalUsers{
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Exporting Local Users" )
		
		$private.exporter.addWorkSheet('Local Accounts')
		$colHeaders = @("OU","Host","Group","Members")
		$col = 1
		$colHeaders | %{
			$private.exporter.updateCell(1,$col,$_)
			$private.exporter.formatCell(1,$col,[export.excelStyle]::Header)
			$col = $col + 1
		}
		
		$row = 2
		foreach($system in ( $private.localSystems | sort OU, Host) ){
			foreach($member in ($system.Members -split ';')){
				$private.exporter.addRow($row, @($system.ou, $system.Host, $system.Group, $member) )
				$row++
			}
		}
		$private.exporter.autoFilterWorksheet(1)
		$private.exporter.autofitColumns()
	}
	
	method -private exportOfflineSystems{
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Exporting Offline Systems" )
		
		$private.exporter.addWorkSheet('Offline Systems')
		$colHeaders = @("OU","Hostname")
		$col = 1
		$colHeaders | %{
			$private.exporter.updateCell(1,$col,$_)
			$private.exporter.formatCell(1,$col,[export.excelStyle]::Header)
			$col = $col + 1
		}
		
		$row = 2
		$private.offlineSystems | sort OU,Host | % {
			$private.exporter.addRow($row, @($_.OU, $_.Host) )
			$row++
		}
		$private.exporter.autoFilterWorksheet(1)
		$private.exporter.autofitColumns()
	}
	
	method -private export{
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Exporting Results" )
		$private.exportADUsers()
		$private.exportLocalUsers()
		$private.exportOfflineSystems()
		
		$ts = (get-date -format "yyyyMMddHHmmss")
		$private.exporter.saveAs([System.IO.Path]::GetFullPath("$($pwd.ProviderPath)\results\$($userCountClass.PsScriptName)_$ts.xml"))
	}
	
	method Execute{
		param()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Executing Scan" )
		$this.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "1 / 3 : Parsing Active Directory Users"; "Status" = ("{0:N2}% complete" -f 10); "PercentComplete" = 10; "Completed" = $false; "id" = 1 }).Render() 
		$private.getADUsers()
		$this.mainProgressBar.Activity("Parsing Local Users").Status("{0:N2}% complete" -f 50).Percent(50).Render()
		$private.getLocalUsers()
		$this.mainProgressBar.Activity("Exporting Results").Status("{0:N2}% complete" -f 75).Percent(75).Render()
		$private.export()

		$uiClass.errorLog()
	}
}

$userCountClass.New().Execute() | out-null