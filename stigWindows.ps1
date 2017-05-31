<#
.SYNOPSIS
	This is a script that will apply the Non-GPO settings to STIG the asset.
.DESCRIPTION
	This is a script that will apply the Non-GPO settings to STIG the asset.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.PARAMETER skip
	STIG Steps that do not need to be completed
.PARAMETER test
	Only execute specified STIG Steps (opposite of skip)
.EXAMPLE
	C:\PS>.\stigWin7.ps1 -computers "hostname1,hostname2"
	This example will stig the computers entered into the command line
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Jan 12, 2015
#>
[CmdletBinding()]
param(
	$hostCsvPath = "",
	$computers = @(),
	$OU = "",
	$skip = @(),
	$test
)

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$stigWin7Class = new-PSClass stigWin7{
	note -static PsScriptName "stigWindows"
	note -static Description ( ($(((get-help .\stigWindows.ps1).Description)) | select Text).Text)

	note -private HostObj @{}
	note -private mainProgressBar
	note -private skip
	note -private methods @("localAccountTokenFilterPolicy", "v3363_RemoveComponents", "v32282_ActiveSetupPerms", "v2371_DisabledServicePerms", "v26545_AuditRegistryFailures", "userSharePerms", "localAuditorsAndAdmins", "sceregvl", "enPasFlt", "EventLogPerms", "regUpdates", "findCertFiles")
	
	note -private uninstallFeatures @("InboxGames", "SimpleTCP", "TelnetClient", "TelnetServer", "TFTP", "MediaCenter")

	method v3363_RemoveComponents{
		param($asset)
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) V-3363 - Removing Unnecessary Windows Features")

		#Enabled (1), Disabled (2), Absent (3), Unknown (4)
		$private.uninstallFeatures | % {
			$feature = gwmi -class Win32_OptionalFeature -filter "Name = '$_'" -computerName $asset
			if($feautre -ne $null){
				switch($feature.InstallState){
					1{	$uiClass.writeColor( "$($uiClass.STAT_ERROR) #green#$($feature.Name)# is #yellow#installed# and #red#enabled#." )
						$private.removeFeature($asset,$feature.Name)
						$uiClass.writeColor( "$($uiClass.STAT_OK) #green#$($feature.Name)# is now #yellow#installed# and #green#disabled#." )
					}
					2 		{ $uiClass.writeColor( "$($uiClass.STAT_OK) #green#$($feature.Name)# is #yellow#installed# and #yellow#disabled#. " ) }
					3 		{ $uiClass.writeColor( "$($uiClass.STAT_OK) #green#$($feature.Name)# is #green#not installed#. " ) }
					default {
						$uiClass.writeColor( "$($uiClass.STAT_WARN) #green#$($feature.Name)# has an #red#unknown status#." )
						$private.removeFeature($asset,$feature.Name)
						$uiClass.writeColor( "$($uiClass.STAT_OK) #green#$($feature.Name)# is now #yellow#installed# and #green#disabled#." )
					}
				}
			}
		}
	}

	method -private removeFeature{
		param($asset, $feature)

		$script = {
			$feature = $args[0]
			return invoke-expression "dism.exe /online /Disable-Feature /FeatureName:$feature /NoRestart"
		}
		return (invoke-command -computerName $asset -scriptBlock $script -Args $feature)
	}

	method v2371_DisabledServicePerms{
		param($asset)

		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) V-2371 - Checking Permissions For Disabled Services")

		$services = gwmi Win32_Service -Filter "StartMode='Disabled'" -computerName $asset
		foreach ($service in $services) {
			$uiClass.writeColor("$($uiClass.STAT_OK) Scanning Service #green#$($service.Name)#" )
			$sddl = ( sc.exe sdshow $($service.name) | ? { $_ } )
			try{
				foreach($access in ($sddl | convertFrom-sddl).Access){
					foreach($right in ($access.Rights.split(","))){
						if($access.IdentityReference -like '*INTERACTIVE*' -or 	$access.IdentityReference -like '*USERS*'){
							if( @("ReadData","ReadExtendedAttributes","ReadAttributes","ReadPermissions","Read","ReadAndExecute","ReadAndExecute","AppendData","WriteAttributes","WriteExtendedAttributes","ExecuteFiles") -notcontains $right ){
								$uiClass.writeColor("$($uiClass.STAT_ERROR) #green#$($service.Name)# for #yellow#$($access.IdentityReference)# is $($right)" )
								$private.updateServicePerms($asset,$service)
								$uiClass.writeColor("$($uiClass.STAT_OK) #green#$($service.Name)# Permissions Updated" )
							}
						}
					}
				}
			}catch{
				$uiClass.writeColor("$($uiClass.STAT_ERROR) #green#$($service.Name)# Security Descriptor Cannot Be Parsed." )
				$private.updateServicePerms($asset,$service)
				$uiClass.writeColor("$($uiClass.STAT_OK) #green#$($service.Name)# Permissions Updated" )
			}
		}
	}

	method -private updateServicePerms{
		param($asset, $service)

		$script = {
			$a = $args[0]
			$s = $args[1]
			invoke-expression "sc.exe sdset ""$($s.Name)"" ""D:AR(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCLCSWLOCRRC;;;IU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"""
		}

		invoke-command -computerName $asset -scriptBlock $script -args $asset,$service
	}

	method v32282_ActiveSetupPerms{
		param($asset)

		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) V-32282 - Checking Registry Permissions")
		$registryKeys = @(
			"HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components",
			"HKLM:\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components"
		)

		foreach($key in $registryKeys){
			$script = {
				$k = $args[0]
				return invoke-expression "(get-acl -Path '$k').Access"
			}

			(invoke-command -computerName $asset -scriptBlock $script -args $key) | ? { $_.IdentityReference -like '*Users*' -or $_.IdentityReference -like "$asset\*" } | % {
				$rights = $_

				switch($rights.RegistryRights){
					"ReadKey" { $uiClass.writeColor("$($uiClass.STAT_OK) #green#$($rights.IdentityReference)# -> #yellow#$($rights.RegistryRights)#" ) }
					"ReadPermissions" { $uiClass.writeColor("$($uiClass.STAT_OK) #green#$($rights.IdentityReference)# -> #yellow#$($rights.RegistryRights)#" ) }
					"GenericRead" { $uiClass.writeColor("$($uiClass.STAT_OK) #green#$($rights.IdentityReference)# -> #yellow#$($rights.RegistryRights)#" ) }
					"-2147483648" { $uiClass.writeColor("$($uiClass.STAT_OK) #green#$($rights.IdentityReference)# -> #yellow#$($rights.RegistryRights)#" ) }
					default{
						$uiClass.writeColor("$($uiClass.STAT_ERROR) #green#$($rights.IdentityReference)# -> #red#$($rights.RegistryRights)#" )
						$private.updateRegAcl($asset,$rights,$key)
						$uiClass.writeColor("$($uiClass.STAT_OK) #green#$($rights.IdentityReference)# -> #green#ReadKey#" )
					}
				}

			}
		}
	}

	method -private updateRegAcl{
		param($asset,$right,$key)

		$script = {
			$k = $args[0]
			$r = $args[1]
			$a = $args[2]
			$acls = invoke-expression "get-acl -Path '$k'"
			$users = @()

			#first, remove inheritance
			$acls.SetAccessRuleProtection($true,$true)
			$acls |Set-Acl

			#then remove all 'users' permissions
			foreach($acl in ( $acls.Access | ? { $_.IdentityReference -like "*Users*"} ) ){
				$users += $acl.IdentityReference
				$acls.RemoveAccessRule($acl)
				$acls | Set-Acl -Path "$k"
			}

			#now add readKey
			$acls = invoke-expression "get-acl -Path '$k'"
			foreach($user in $users){
				$acls.AddAccessRule( ( New-Object System.Security.AccessControl.RegistryAccessRule($user,"ReadKey","Allow") ) )
				$acls | Set-Acl -Path "$k"
			}

			$users = @()
			#finally make sure anyone local users only have read permissions
			$acls = invoke-expression "get-acl -Path '$k')"
			foreach($acl in ( $acls.Access | ? { $_.IdentityReference -like "$a\*"} )){
				$users += $acl.IdentityReference
				$acls.RemoveAccessRule($acl)
				$acls | Set-Acl -Path "$k"
			}

			foreach($user in $users){
				$acls.AddAccessRule( ( New-Object System.Security.AccessControl.RegistryAccessRule($user,"ReadKey","Allow") ) )
				$acls | Set-Acl -Path "$k"
			}
		}

		invoke-command -computerName $asset -scriptBlock $script -args $key,$right,$asset
	}

	method v26545_AuditRegistryFailures{
		param($asset)

		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) V-26545 - Checking Audits for Registry Failed Access Attempts")

		$hives = @("HKLM:\","HKCU:\")
		$drives = gdr -PSProvider 'FileSystem'

		foreach($hive in $hives){
			if( ( (Get-Acl -Path $hive -audit).Audit | ? { $_.AuditFlags -eq 'Failure' -and $_.IdentityReference -eq 'Everyone' }) -ne $null ){
				$uiClass.writeColor( "$($uiClass.STAT_OK) Registry Hive #yellow#$hive# Has #green#Auditing Enabled#")
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_WARN) Registry Hive #yellow#$hive# Does Not Have #red#Auditing Enabled#")
				$private.updateauditFailures($asset, $hive)

				if( ( (Get-Acl -Path $hive -audit).Audit | ? { $_.AuditFlags -eq 'Failure' -and $_.IdentityReference -eq 'Everyone'}) -ne $null ){
					$uiClass.writeColor( "$($uiClass.STAT_OK) Registry Hive #yellow#$hive# Now Has #green#Auditing Enabled#")
				}else{
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) Registry Hive #yellow#$hive# Could Not Have #red#Auditing Enabled#")
				}
			}
		}
	}

	method -private updateAuditFailures{
		param($asset,$key)

		if(@("HKLM:\","HKCU:\") -contains $key){
			$script = {
				$k = $args[0]
				$acl = Get-Acl -Path "$($k)" -Audit
				$rule = New-Object System.Security.AccessControl.RegistryAuditRule ("Everyone","fullcontrol", ( [System.Security.AccessControl.inheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.inheritanceFlags]::ObjectInherit ), ([System.Security.AccessControl.propagationFlags]::InheritOnly),"failure")
				$acl.AddAuditRule($rule)
				$acl |Set-Acl -Path $k
			}
			invoke-command -computerName $asset -scriptBlock $script -args $key
		}
	}

	method localAccountTokenFilterPolicy{
		param($asset)

		$key = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System")

		switch($key.LocalAccountTokenFilterPolicy){
			$null 	{ 	$uiClass.writeColor( "$($uiClass.STAT_ERROR) #yellow#localAccountTokenFilterPolicy# Missing on #green#$asset#");
						$private.updateLocalAccountTokenFilterPolicy($asset);
						if( (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").LocalAccountTokenFilterPolicy -eq 1){
							$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#localAccountTokenFilterPolicy# Added to #green#$asset#");
						}else{
							$uiClass.writeColor( "$($uiClass.STAT_ERROR) #yellow#localAccountTokenFilterPolicy# Could Not Be Added to #green#$asset#");
						}
					}
			0		{ 	$uiClass.writeColor( "$($uiClass.STAT_ERROR) #yellow#localAccountTokenFilterPolicy# Not Set Properly on #green#$asset#");
						$private.updateLocalAccountTokenFilterPolicy($asset);
						if( (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").LocalAccountTokenFilterPolicy -eq 1){
							$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#localAccountTokenFilterPolicy# Modified on #green#$asset#");
						}else{
							$uiClass.writeColor( "$($uiClass.STAT_ERROR) #yellow#localAccountTokenFilterPolicy# Could Not Be Modified on #green#$asset#");
						}
					}
			1		{ $uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#localAccountTokenFilterPolicy# Set on #green#$asset#"); }
		}
	}

	method -private updateLocalAccountTokenFilterPolicy{
		param($asset)
		$script = {
			New-ItemProperty -Path "hklm:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name 'LocalAccountTokenFilterPolicy' -PropertyType 'dWord' -Value 1 -Force
		}

		invoke-command -computerName $asset -scriptBlock $script
	}

	method userSharePerms{
		param($asset)

		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Confirming User Shares Do Not Have Permissions For 'Everyone'")

		$shares = gwmi -Query "Select * from win32_share where type=0" -computerName $asset
		if($shares.count -gt 0){
			foreach($share in $shares){
				$uiClass.writeColor( "$($uiClass.STAT_WAIT) Analysing User Share #yellow#$($share.Name)#")
				$acls = get-acl "\\$($asset)\$($share.Name)"
				$acls.Access | ? { $_.IdentityReference -eq 'Everyone' } | % {
					$uiClass.writeColor( "$($uiClass.STAT_OK) User Share #yellow#$($share.Name)# Has #red#Permissions for Everyone#")

					$private.updateUserSharePerms($asset, $share.Name)

					if( ( (Get-Acl -Path "\\$($asset)\$($share.Name)" ).Access | ? { $_.IdentityReference -eq 'Everyone' } ).Count  -gt 0 ){
						$uiClass.writeColor( "$($uiClass.STAT_OK) User Share #yellow#$($share.Name)# Had #green#Everyone Permissions# Removed")
					}else{
						$uiClass.writeColor( "$($uiClass.STAT_OK) User Share #yellow#$($share.Name)# Can't Have  #red#Everyone Permissions# Removed")
					}
				}
			}
		}
	}

	method -private updateUserSharePerms{
		param($asset, $share)

		$script = {
			$a = $args[0]
			$s = $args[1]
			invoke-expression "icacls '\\$a\$s\' /inheritance:d"
			invoke-expression "icacls '\\$a\$s\' /remove:g Everyone"
			invoke-expression "icacls '\\$a\$s\' /remove:g $a\Everyone"
		}

		invoke-command -computerName $asset -scriptBlock $script -args $asset,$share
	}

	method localAuditorsAndAdmins{
		param($asset)
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Confirming local Auditors group exists")
		
		$auditors = gwmi win32_Group -filter "Domain = '$asset' and Name = 'Auditors'" -computerName $asset
		if($auditors -eq $null){
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Local Group #yellow#Auditors# does #red#Not Exist#")
			$private.createAuditors($asset)
			
			$auditorsCheck = gwmi win32_Group -filter "Domain = '$asset' and Name = 'Auditors'" -computerName $asset
			if($auditorsCheck -ne $null){
				$uiClass.writeColor( "$($uiClass.STAT_OK) Local Group #yellow#Auditors# was #green#Created#")
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) Local Group #yellow#Auditors# could not  #red#Be Created#")
			}			
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_OK) Local Group #yellow#Auditors# already #green#Exists#")
		}
		
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Confirming local backup administrator exists")
		
		$localAdmin = "$($asset)_Admin"
		$localAdminExists = gwmi win32_UserAccount -filter "Name = '$localAdmin'" -computerName $asset
		if($localAdminExists -eq $null){
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Local Admin #yellow#$localAdmin# does #red#Not Exist#")
			$private.createLocalAdmin($asset)
			
			$localAdminCheck = gwmi win32_UserAccount -filter "Name = '$localAdmin'" -computerName $asset
			if($localAdminCheck -ne $null){
				$uiClass.writeColor( "$($uiClass.STAT_OK) Local Admin #yellow#$localAdmin# was #green#Created# with the password #yellow#l0c@lAdm1nPa55word!!#")
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) Local Admin #yellow#$localAdmin# could not  #red#Be Created#")
			}
			
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_OK) Local Admin #yellow#$localAdmin# already #green#Exists#")
		}
		
		
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Confirming BUILTIN\Administrator renamed")
		
		$localAdminAcct = @( ( [ADSI]"WinNT://$asset/Administrators" ).Invoke("Members")) | % { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) } | ? { $_ -eq 'Administrator' }
		#this means an account is called Administrator and it is in the administrators group.  This one will need to be renamed
		if($localAdminAcct -ne $null){
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Builtin #yellow#Administrator# account not #red#Renamed#")
			$private.renameBuiltinAdmin($asset)
			
			$localAdminCheck = @( ( [ADSI]"WinNT://$asset/Administrators" ).Invoke("Members")) | % { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) } | ? { $_ -eq 'Administrator' }
			if($localAdminCheck -eq $null){
				$uiClass.writeColor( "$($uiClass.STAT_OK) Builtin #yellow#Administrator# account was #green#Renamed#")
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) Builtin #yellow#Administrator# could not #red#Be Renamed#")
			}
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#Local Administrator# already #green#Renamed#")
		}
		
		#now see if there is a decoy admin account created
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Confirming Decoy Admin Account Exists")
		$localAdminAcct = @( ( [ADSI]"WinNT://$asset/Guests" ).Invoke("Members")) | % { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) } | ? { $_ -eq 'Administrator' }
		if($localAdminAcct -eq $null){
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Decoy #yellow#Administrator# account not #red#Created#")
			$private.createDecoyAdmin($asset)
			
			$localAdminCheck = @( ( [ADSI]"WinNT://$asset/Guests" ).Invoke("Members")) | % { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) } | ? { $_ -eq 'Administrator' }
			if($localAdminCheck -ne $null){
				$uiClass.writeColor( "$($uiClass.STAT_OK) Decoy #yellow#Administrator# account was #green#Created#")
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) Decoy #yellow#Administrator# account could not #red#Be Created#")
			}
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_OK) Decoy #yellow#Administrator# already #green#Exists#")
		}
		
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Confirming No Accounts Are Locked Out")
		$lockedOut = gwmi win32_UserAccount -filter "Lockout=True" -computerName $asset
		if($lockedOut -ne $null){
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Locked Out Accounts #red#Exist#")
			$private.unlockAccounts($asset)
			
			$lockedOutCheck = gwmi win32_UserAccount -filter "Lockout=True" -computerName $asset
			if($lockedOutCheck -eq $null){
				$uiClass.writeColor( "$($uiClass.STAT_OK) Locked Out Accounts #green#Unlocked#")
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not unlock #red#Locked Out# accounts")
			}
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_OK) No #yellow#Locked Out# accounts #green#Exist#")
		}
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Confirming All Accounts Can Change Their Passwords")
		$pwChange = gwmi win32_UserAccount -filter "PasswordChangeable=False" -computerName $asset
		if($pwChange -ne $null){
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Accounts with Non-Changeable Passwords Exist")
			$private.updatePWChangeable($asset)
			
			$pwChangeCheck = gwmi win32_UserAccount -filter "PasswordChangeable=false" -computerName $asset
			if($pwChangeCheck -eq $null){
				$uiClass.writeColor( "$($uiClass.STAT_OK) All Accounts can change passwords")
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could Not Update Password Changeable flag")
			}
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_OK) All Accounts can change passwords")
		}
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Confirming All Accounts Have Passwords That Expire")
		$pwChange = gwmi win32_UserAccount -filter "PasswordExpires=False" -computerName $asset
		if($pwChange -ne $null){
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Accounts with Non-Expiring Passwords Exist")
			$private.updatePWExpires($asset)
			
			$pwChangeCheck = gwmi win32_UserAccount -filter "PasswordExpires=false" -computerName $asset
			if($pwChangeCheck -eq $null){
				$uiClass.writeColor( "$($uiClass.STAT_OK) All Accounts have passwords that expire")
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could Not Update All Passwords To Expire")
			}
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_OK) All Accounts have passwords that expire")
		}
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Confirming All Accounts Require Passwords")
		$pwReq = gwmi win32_UserAccount -filter "PasswordRequired=False" -computerName $asset
		if($pwReq -ne $null){
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Accounts That Don't Require Passwords Exist")
			$private.updatePWRequired($asset)
			
			$pwReqCheck = gwmi win32_UserAccount -filter "PasswordRequired=false" -computerName $asset
			if($pwReqCheck -eq $null){
				$uiClass.writeColor( "$($uiClass.STAT_OK) All Accounts now require passwords")
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could Not Update All Accounts to Require Passwords")
			}
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_OK) All Accounts require passwords")
		}
		
	}

	method -private updatePWRequired{
		param($asset)
		
		$script = {
			$a = $args[0]
			(gwmi win32_UserAccount -filter "PasswordRequired=false" -computerName $a) | % {
				$_.PasswordRequired = $true
				$_.put()
			}
		}
		
		invoke-command -computerName $asset -scriptBlock $script -args $asset
	}
	
	method -private updatePWExpires{
		param($asset)
		
		$script = {
			$a = $args[0]
			(gwmi win32_UserAccount -filter "PasswordExpires=false" -computerName $a) | % {
				$_.PasswordExpires = $true
				$_.put()
			}
		}
		
		invoke-command -computerName $asset -scriptBlock $script -args $asset
	}
	
	method -private updatePWChangeable{
		param($asset)
		
		$script = {
			$a = $args[0]
			(gwmi win32_UserAccount -filter "PasswordChangeable=false" -computerName $a) | % {
				$_.PasswordChangeable = $true
				$_.put()
			}
		}
		
		invoke-command -computerName $asset -scriptBlock $script -args $asset
	}
	
	method -private unlockAccounts{
		param($asset)
		
		$script = {
			$a = $args[0]
			
			Foreach ($user in (([ADSI]"WinNT://$a").psbase.children | ? {$_.psbase.schemaClassName -match "user" -and $_.IsAccountLocked -eq $true})){
				$user.IsAccountLocked = $False
				$user.SetInfo()
			}
		}
		
		invoke-command -computerName $asset -scriptBlock $script -args $asset
	}
	
	method -private createDecoyAdmin{
		param($asset)
		
		$script = {
			$a = $args[0]
			
			$cn = [ADSI]"WinNT://$a"
			$user = $cn.Create("User","Administrator")
			$user.SetPassword("l0c@lAdm1nPa55word!!")
			$user.setinfo()
			$user.description = "Builtin Administrator"
			$user.SetInfo()
			$user.userFlags = 2 #2 is the flag for disabled accounts
			$user.SetInfo()
			
			$de = [ADSI]"WinNT://$a/Guests,group" 
			$de.psbase.Invoke("Add",([ADSI]"WinNT://Administrator").path)
			
			
		}
		
		invoke-command -computerName $asset -scriptBlock $script -args $asset
	}
	
	method -private renameBuiltinAdmin{
		param($asset)
		
		$script = {
			$a = $args[0]
			$admin=[adsi]"WinNT://$a/Administrator,user" 
			$admin.psbase.rename("xAdministrator")
		}

		invoke-command -computerName $asset -scriptBlock $script -args $asset
	}
	

	method -private createLocalAdmin{
		param($asset)
	
		$script = {
			$a = $args[0]
			
			$cn = [ADSI]"WinNT://$a"
			$user = $cn.Create("User","$($a)_Admin")
			$user.SetPassword("l0c@lAdm1nPa55word!!")
			$user.setinfo()
			$user.description = "Local Admin"
			$user.SetInfo()
			
			$de = [ADSI]"WinNT://$a/Auditors,group" 
			$de.psbase.Invoke("Add",([ADSI]"WinNT://$($a)_Admin").path)
			
			$de = [ADSI]"WinNT://$a/Administrators,group" 
			$de.psbase.Invoke("Add",([ADSI]"WinNT://$($a)_Admin").path)
		}
		
		invoke-command -computerName $asset -scriptBlock $script -args $asset
	}
	
	method -private createAuditors{
		param($asset)
		
		$script = {
			$a = $args[0]
			$cn = [ADSI]"WinNT://$a"
			$group = $cn.Create("Group","Auditors")
			$group.setInfo()
			$group.Description = "Local Auditors Group"
			$group.setInfo()			
			
			$currentAdmin = (whoami).replace("\","/")
			$de = [ADSI]"WinNT://$a/Auditors,group" 
			$de.psbase.Invoke("Add",([ADSI]"WinNT://$currentAdmin").path)

		}
		
		invoke-command -computerName $asset -scriptBlock $script -args $asset		
	}

	method enPasFlt{
		param($asset)
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Updating EnPasFlt.dll")

		if(test-path "\\$asset\c`$\windows\syswow64"){
			copy-item ".\bin\EnPasFltV2x64.dll" "\\$asset\c`$\windows\syswow64\EnPasFlt.dll"
		}else{
			copy-item ".\bin\EnPasFltV2x86.dll" "\\$asset\c`$\windows\system32\EnPasFlt.dll"
		}
			
		$script = {
			$a = $args[0]
			
			$rules = ( [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$a).OpenSubKey("System\CurrentControlSet\Control\Lsa",$true).GetValueNames() | ? { $_ -eq "Notification Packages" } )
			if($rules -eq $null){
				[string[]]$newArray = @("EnPasFlt")
				[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$a).OpenSubKey("System\CurrentControlSet\Control\Lsa",$true).SetValue('Notification Packages', $newarray,'MultiString')
			}else{
				[string[]]$newArray = ( [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine','msi').OpenSubKey("System\CurrentControlSet\Control\Lsa",$true).GetValue('Notification Packages') )
				if($newArray -notContains 'EnPasFlt'){
					$newArray += "EnPasFlt"
				}
				[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$a).OpenSubKey("System\CurrentControlSet\Control\Lsa",$true).SetValue('Notification Packages', $newarray,'MultiString')
			}
			
		}
		
		invoke-command -computerName $asset -scriptBlock $script -args $asset
		
	}
	
	method findCertFiles{
		param($asset)
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Searching for Certificates (.pfx and .p12)")
		
		$drives = gwmi win32_logicalDisk -filter "Drivetype=3" -computerName $asset
		$certFiles = @()
		foreach($device in ($drives | Select DeviceID) ){
			$drive = $device.deviceId.replace(":","")
			$uiClass.writeColor( "$($uiClass.STAT_OK) Scanning drive #yellow#$($drive):\#")
			$i = 0
			gci -path "\\$asset\$drive`$\"  -recurse -errorAction silentlyContinue | % {
				$i++
				if( @(".pfx",".p12") -contains $_.extension){
					$certFiles += $_.FullName
				}
				
				if($i % 1000 -eq 0){
					$uiClass.writeSameLine($_.FullName)
				}
				
			}
			
		}
		
		$uiClass.writeColor()
		
		$ct = $certFiles.count
		$uiClass.writeColor( "$($uiClass.STAT_OK) Scan results... found #yellow#$ct# files")
		$allChoice = $false
		foreach($file in $certFiles){
		
			if($allChoice){
				$uiClass.writeColor("$($uiClass.STAT_WARN) Deleting File $file")
				remote-item $file -force
			}else{			
				
				$title = "Delete File?"
				$message = "Do you want to delete $($file)?"
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Delete file $($file)"
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Retain file $($file)"
				$all = New-Object System.Management.Automation.Host.ChoiceDescription "&All", "Delete all files"
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $all)
				$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

				switch ($result){
					0 {
						$uiClass.writeColor("$($uiClass.STAT_WARN) Deleting File")
						remove-item $_ -force
					}
					1 {
						$uiClass.writeColor("$($uiClass.STAT_WARN) Retaining File")
					}
					2 {
						$uiClass.writeColor("$($uiClass.STAT_WARN) Deleting File")
						$allChoice = $true;
						remove-item $file -force
					}
				}
			}
		}
	}
	
	method sceregvl{
		param($asset)
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Updating sceregvl.inf")
		
		$ts = (get-date -format yyyyMMddHHmmss)
		
		$script = {
			$a = $args[0]
			invoke-expression "takeown /s $a /a /f c:\windows\inf\sceregvl.inf"
			
			$acls = invoke-expression "get-acl -Path 'c:\windows\inf\sceregvl.inf'"
			$acls.AddAccessRule( ( New-Object System.Security.AccessControl.FilesystemAccessRule("Builtin\Administrators","FullControl","Allow") ) )
			$acls | Set-Acl -Path "c:\windows\inf\sceregvl.inf"
		}
				
		if(test-path "\\$asset\c`$\windows\inf\sceregvl.inf"){
			invoke-command  -computerName $asset -scriptBlock $script -args $asset
			rename-item "\\$asset\c`$\windows\inf\sceregvl.inf" "\\$asset\c`$\windows\inf\sceregvl.$($ts).original"
		}
		copy-item ".\conf\sceregvl.inf" "\\$asset\c`$\windows\inf\"
		
		$script = {
			& regsvr32.exe scecli.dll
		}
		
		invoke-command -computerName $asset -scriptBlock $script
		
	}

	method regUpdates{
		param($asset)
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Updating Registry")

		$script = {
			$Key = Get-Item -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems\"
			if($key.GetValue("Optional",$null) -ne $null){
				remove-itemproperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" -name "Optional"
			}
			if($key.GetValue("Posix",$null) -ne $null){
				remove-itemproperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" -name "Posix"
			}
			$acls = get-acl -Path "HKLM:\System\CurrentControlSet\Control\SecurePipeServers\Winreg"
			
			$acls.SetAccessRuleProtection($true,$true)
			$acls | Set-Acl -Path "HKLM:\System\CurrentControlSet\Control\SecurePipeServers\Winreg"
			
			foreach($acl in ( $acls.Access | ? { @("BUILTIN\Backup Operators","NT AUTHORITY\LOCAL SERVICE","Builtin\Administrators") -notContains $_.IdentityReference } ) ) {
				$acls.RemoveAccessRule($acl)
				$acls | Set-Acl -Path "HKLM:\System\CurrentControlSet\Control\SecurePipeServers\Winreg"
			}
			
			$acls.AddAccessRule( ( New-Object System.Security.AccessControl.RegistryAccessRule("Builtin\Administrators","FullControl","Allow") ) )
			$acls | Set-Acl -Path "HKLM:\System\CurrentControlSet\Control\SecurePipeServers\Winreg"
			
			$acls.AddAccessRule( ( New-Object System.Security.AccessControl.RegistryAccessRule("NT AUTHORITY\LOCAL SERVICE","ReadKey","Allow") ) )
			$acls | Set-Acl -Path "HKLM:\System\CurrentControlSet\Control\SecurePipeServers\Winreg"
			
			$acls.AddAccessRule( ( New-Object System.Security.AccessControl.RegistryAccessRule("BUILTIN\Backup Operators","ReadKey","Allow") ) )
			$acls | Set-Acl -Path "HKLM:\System\CurrentControlSet\Control\SecurePipeServers\Winreg"
			
			
			@("Application","System","Security") | % {
				$key = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog")
				if($key.AutoBackupLogFiles -eq $null){
					New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\$($_)" -Name 'AutoBackupLogFiles' -PropertyType 'dWord' -Value 1 -Force
				}else{
					Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\$($_)" -Name 'AutoBackupLogFiles' -Value 1 -Force
				}
			}
			
			$key = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole")
			if($key.EnableDCOM -eq $null){
				New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name 'EnableDCOM' -PropertyType 'String' -Value "Y" -Force
			}else{
				Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name 'EnableDCOM' -Value "Y" -Force
			}
			
			if($key.LegacyAuthenticationLevel -eq $null){
				New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name 'LegacyAuthenticationLevel' -PropertyType 'dWord' -Value 2 -Force
			}else{
				Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name 'LegacyAuthenticationLevel' -Value 2 -Force
			}
			
			if($key.LegacyImpersonationLevel -eq $null){
				New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name 'LegacyImpersonationLevel' -PropertyType 'dWord' -Value 3 -Force
			}else{
				Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name 'LegacyImpersonationLevel' -Value 3 -Force
			}
			
		}
		
		invoke-command -computerName $asset -scriptBlock $script
	}
	
	method EventLogPerms{
		param($asset)
		
		$uiClass.writeColor()
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) Updating Event Log Permissions")
		
		foreach($log in @("Application","Security","System")){
			#evt or evtx fileS?
			if(test-path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evtx"){
				try{
					$acls = get-acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evtx"
					$acls.SetAccessRuleProtection($true,$true)
					$acls |Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evtx"
					$acls.AddAccessRule( ( New-Object System.Security.AccessControl.FilesystemAccessRule("Auditors","FullControl","Allow") ) )
					$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evtx"
					$acls.AddAccessRule( ( New-Object System.Security.AccessControl.FilesystemAccessRule("NT Service\EventLog","FullControl","Allow") ) )
					$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evtx"
					$acls.AddAccessRule( ( New-Object System.Security.AccessControl.FilesystemAccessRule("NT AUTHORITY\System","FullControl","Allow") ) )
					$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evtx"
					foreach($acl in ( $acls.Access | ? { @("$asset\Auditors","NT Service\EventLog","NT Authority\System") -notContains $_.IdentityReference } ) ) {
						$acls.RemoveAccessRule($acl)
						$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evtx"
					}
					$acls.AddAccessRule( ( New-Object System.Security.AccessControl.FilesystemAccessRule("Builtin\Administrators","ReadAndExecute","Allow") ) )
					$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evtx"
				}catch{
					$uiClass.writeColor( "$($uiClass.STAT_OK) $log Event Logs are properly restricted")
				}
			}else{
				try{
					$acls = get-acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evt"
					$acls.SetAccessRuleProtection($true,$true)
					$acls |Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evt"
					$acls.AddAccessRule( ( New-Object System.Security.AccessControl.FilesystemAccessRule("Auditors","FullControl","Allow") ) )
					$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evt"
					$acls.AddAccessRule( ( New-Object System.Security.AccessControl.FilesystemAccessRule("NT Service\EventLog","FullControl","Allow") ) )
					$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evt"
					$acls.AddAccessRule( ( New-Object System.Security.AccessControl.FilesystemAccessRule("NT AUTHORITY\System","FullControl","Allow") ) )
					$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evt"
					foreach($acl in ( $acls.Access | ? { @("$asset\Auditors","NT Service\EventLog","NT Authority\System") -notContains $_.IdentityReference } ) ) {
						$acls.RemoveAccessRule($acl)
						$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evt"
					}
					$acls.AddAccessRule( ( New-Object System.Security.AccessControl.FilesystemAccessRule("Builtin\Administrators","ReadAndExecute","Allow") ) )
					$acls | Set-Acl -Path "\\$asset\c`$\windows\System32\WinEvt\Logs\$log.evt"
				}catch{
					$uiClass.writeColor( "$($uiClass.STAT_OK) $log Event Logs are properly restricted")
				}
			}
		}
	}

	method execute{
		$currentComputer = 0

		if($private.HostObj.Count -gt 0){
			$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render()

			$private.HostObj.Hosts.keys | % {
				$assetName = $_
				$i = (100*($currentComputer / $private.HostObj.Hosts.count))
				$private.mainProgressBar.Activity("$currentComputer / $($private.HostObj.Hosts.count): Processing system $_").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()

				$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$assetName.Trim()'"

				$uiClass.writeColor()
				if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
					if($_.length -ge 1) {
						$uiClass.writeColor( "$($uiClass.STAT_OK) Processing $assetName" )
						switch($true){
							{$private.skip -notcontains 'localAccountTokenFilterPolicy'}	{ $this.localAccountTokenFilterPolicy($assetName) }
							{$private.skip -notcontains 'v3363_RemoveComponents'}			{ $this.v3363_RemoveComponents($assetName) }
							{$private.skip -notcontains 'v32282_ActiveSetupPerms'}			{ $this.v32282_ActiveSetupPerms($assetName) }
							{$private.skip -notcontains 'v2371_DisabledServicePerms'}		{ $this.v2371_DisabledServicePerms($assetName) }
							{$private.skip -notcontains 'v26545_AuditRegistryFailures'}		{ $this.v26545_AuditRegistryFailures($assetName) }
							{$private.skip -notcontains 'userSharePerms'}					{ $this.userSharePerms($assetName) }
							{$private.skip -notcontains 'localAuditorsAndAdmins'}			{ $this.localAuditorsAndAdmins($assetName) }
							{$private.skip -notcontains 'sceregvl'}							{ $this.sceregvl($assetName) }
							{$private.skip -notcontains 'enPasFlt'}							{ $this.enPasFlt($assetName) }
							{$private.skip -notcontains 'EventLogPerms'}					{ $this.EventLogPerms($assetName) }
							{$private.skip -notcontains 'regUpdates'}						{ $this.regUpdates($assetName) }
							{$private.skip -notcontains 'findCertFiles'}					{ $this.findCertFiles($assetName) }
						}
					}
				} else {
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) Skipping $_ .. not accessible" )
				}
				$currentComputer = $currentComputer + 1
			}
			$private.mainProgressBar.Completed($true).Render()
		}
		$uiClass.errorLog()
	}

	constructor{
		param()
		$private.HostObj = $HostsClass.New()
				
		if($skip.getType().Name -eq 'String'){
			$private.skip = $skip.split(",")
		}else{
			$private.skip = $skip
		}
		
		if($test -ne $null){
			$private.methods | % {
				if($test -notContains $_ ){
					$private.skip += $_
				}
			}
		}
		
	}

}

$stigWin7Class.New().Execute() | out-null