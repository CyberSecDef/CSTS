<#  
.SYNOPSIS
	This script will search for and display accounts that have not been logged in for a selected number of days.  
.DESCRIPTION
	This script will search for and display accounts that have not been logged in for a selected number of days.  This script searches for both local and active directory accounts
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.PARAMETER age
	The age that determines an account is dormant
.PARAMETER userOU
	An Organization Unit in Active Driectory to pull users from
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Oct 20, 2015
#>
[CmdletBinding()]
param( $hostCsvPath = "", $computers = @(), $OU = "", [int] $age, $userOU = "" ) 
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$findDormantAccountsClass = new-PSClass findDormantAccounts{
	note -static PsScriptName "findDormantAccounts"
	note -static Description ( ($(((get-help .\findDormantAccounts.ps1).Description)) | select Text).Text)
	
	note -private HostObj @{}

	note -private gui
	note -private age 30
	note -private userOu ""
	
	note -private dormantUser 
	note -private dormantUsers @()
	
	note -private mainProgressBar
	
	method -private getLocalAccounts{
		param($computerName)
		$localUsers = ([ADSI]"WinNT://$computerName").Children | ? {$_.SchemaClassName -eq 'user'} | ? { $_.properties.lastlogin -lt ( ( ([System.DateTime]::Now).ToUniversalTime() ).AddDays(-1 * $private.Age) ) } | select `
			@{e={$_.name};n='DisplayName'},`
			@{e={$_.name};n='Username'},`
			@{e={$_.properties.lastlogin};n='LastLogon'},`
			@{e={if($_.properties.userFlags.ToString() -band 2){$true}else{$false} };n='Disabled'},`
			@{e={$_.path};n='Path'}, `
			@{e={'Local'};n='AccountType'}
			
		$uiClass.writeColor( "$($uiClass.STAT_OK) Found #yellow#$($localUsers.count)# dormant accounts on #green#$($computerName)#" )
		
		foreach($localUser in $localUsers){
			$uiClass.writeColor( "$($uiClass.STAT_OK)`t #yellow#$($localUser.Username)#" )
			
			$u = $private.dormantUser.PsObject.Copy()
			foreach($key in (($localUser | gm  -memberType 'NoteProperty' | select -expand Name ) ) ){
				 $u.$($key) = $localUser.$($key)
			}
						
			$private.dormantUsers += $u 
		}
	}
	
	method -private getDomainAccounts{
		param()
		
		$prefix = "LDAP://"		
		$domain = "$( ([ADSI]'LDAP://RootDSE').Get('rootDomainNamingContext') )"
		if($utilities.isBlank($private.userOU) -eq $false){
			$query = "$($prefix)$($private.userOu.replace('LDAP://',''))"
		}else{
			$query = "$($prefix)$($domain)"
		}
		
		$currentDate = [System.DateTime]::Now
		$currentDateUtc = $currentDate.ToUniversalTime()
		$lltstamplimit = $currentDateUtc.AddDays(-1 * $private.Age)
		$lltIntLimit = $lltstampLimit.ToFileTime()
		$adobjroot = [adsi]$query
		$objstalesearcher = New-Object System.DirectoryServices.DirectorySearcher($adobjroot)
		$objstalesearcher.filter = "(&(objectCategory=person)(objectClass=user)(lastLogonTimeStamp<=" + $lltIntLimit + "))"

		$domainusers = $objstalesearcher.findall() | select `
			@{e={$_.properties.cn};n='DisplayName'}, `
			@{e={$_.properties.samaccountname};n='Username'}, `
			@{e={[datetime]::FromFileTimeUtc([int64]$_.properties.lastlogontimestamp[0])};n='LastLogon'}, `
			@{e={[string]$adspath=$_.properties.adspath;$account=[ADSI]$adspath;$account.psbase.invokeget('AccountDisabled')};n='Disabled'}, `
			@{e={$_.properties.distinguishedname};n='Path'}, `
			@{e={'Domain'};n='AccountType'}`
		
		if($utilities.isBlank($private.userOU) -eq $false){
			$uiClass.writeColor( "$($uiClass.STAT_OK) Found #yellow#$($domainusers.count)# dormant domain accounts in #green#$($private.userOu)#" )
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_OK) Found #yellow#$($domainusers.count)# dormant domain accounts on #green#$($domain)#")
		}

		foreach($domainUser in $domainusers){
			$uiClass.writeColor( "$($uiClass.STAT_OK)`t #yellow#$($domainUser.Username)#" )
			$u = $private.dormantUser.PsObject.Copy()
			foreach($key in (($domainUser | gm  -memberType 'NoteProperty' | select -expand Name ) ) ){
				 $u.$($key) = $domainUser.$($key)
			}
			$private.dormantUsers += $u 
		}
	}
	
	method -private Export{
		
		$exportProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 				
		$exportProgressBar.Activity("Exporting Results").Status(("{0:N2}% complete" -f 0)).Percent(0).Render()
		
		$colHeaders = @{}
		$sheets = @{}
		
		$export = $ExportClass.New()
		
		# Select AccountType, DisplayName, Username, LastLogon, Disabled, Path
		$colHeaders.add("DormantAccounts",@("AccountType","DisplayName","Username","LastLogon","Disabled","Path"))
				
		$export.addWorkSheet('Dormant Accounts')
		
		
		$col = 1
		$colHeaders.DormantAccounts | %{
			$export.updateCell(1,$col,$_)
			$col = $col + 1
		}
	
		$row = 2
		$currentAccount = 0
		foreach($dormantUser in $private.dormantUsers){
			$i = (100*($currentAccount / @(1,$private.dormantUsers.count)[($private.dormantUsers.count -gt 0)]))
			$exportProgressBar.Activity("$currentAccount / $($private.dormantUsers.count): Processing Account $($dormantUser.Username)").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			
			$col = 1
			foreach($colHeader in ( $colHeaders.DormantAccounts ) ){
				$export.updateCell($row,$col,$dormantUser.$($colHeader))
				$col++
			}
			$row++
			$currentAccount++
		}
		$exportProgressBar.Completed($true).Render() 
			
		$export.autoFilterWorksheet()
		$export.autofitAllColumns()
		$export.formatAllFirstRows('Header')
		
		$ts = (get-date -format "yyyyMMddHHmmss")
		$export.saveAs([System.IO.Path]::GetFullPath("$($pwd.ProviderPath)\results\$($findDormantAccountsClass.PsScriptName)_$ts.xml"))
	}
		
	method Execute{
		$currentComputer = 0

		#get local accounts from submitted systems
		if($private.HostObj.Count -gt 0){
			$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
			
			$private.HostObj.Hosts.keys | % {
				$i = (50*($currentComputer / $private.HostObj.Hosts.count))
				$private.mainProgressBar.Activity("$currentComputer / $($private.HostObj.Hosts.count): Processing system $_").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
				$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($_.Trim())'"
				if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
					if($_.length -ge 1) { 
						$uiClass.writeColor( "$($uiClass.STAT_WAIT) Processing #green#$_#" )
						$private.getLocalAccounts($_)
					}
				} else { 	
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) Skipping #green#$_#... not accessible" )
				}
				
				$currentComputer = $currentComputer + 1
			} 
			
			#get dormant Domain Accounts
			$uiClass.writeColor( "$($uiClass.STAT_WAIT) Analyzing Domain Accounts" )
			$private.mainProgressBar.Activity("Getting Dormant Domain Accounts").Status(("{0:N2}% complete" -f 75)).Percent(75).Render()
			$private.getDomainAccounts()
			
			$uiClass.writeColor( "$($uiClass.STAT_WAIT) Exporting Results..." )
			$private.mainProgressBar.Activity("Exporting Results").Status(("{0:N2}% complete" -f 95)).Percent(95).Render()
			$private.export()
			$private.mainProgressBar.Completed($true).Render() 
		}
		$uiClass.errorLog()
	}
	
	constructor{
		param()
		
		 
		
		$private.HostObj = $HostsClass.New()
		if($utilities.isBlank($age) -eq $false){ $private.age = $age }
		if($utilities.isBlank($userOu) -eq $false){ 
			$private.userOu = $userOu 
		}else{
			$root = new-object directoryservices.directoryentry "$($prefix)$($domain)"
			$selector = new-object directoryservices.directorysearcher
			$selector.searchroot = $root
			$ous = $selector.findall() | ? {$_.path -match 'LDAP://OU=*' } | select -expandProperty Path | sort
			
			$private.gui = $null
			$private.gui = $guiClass.New("findDormantAccounts.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			
			$private.gui.Controls.cboUserOu.Items.Add("") | out-null
			$ous | % { 
				$private.gui.Controls.cboUserOu.Items.Add($_) | out-null
			}
			$private.gui.Form.ShowDialog()| Out-Null
			$private.userOu = $private.gui.Controls.cboUserOu.text
		}
		$private.dormantUser = new-object -TypeName PSObject | Select AccountType, DisplayName, Username, LastLogon, Disabled, Path
	}
}

$dormantAccounts = $findDormantAccountsClass.New().Execute() | out-null