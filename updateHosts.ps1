<# 
.SYNOPSIS
	This is a script that will execute updates on a list of hosts
.DESCRIPTION
	This is a script that will execute updates on a list of hosts
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.PARAMETER cmd
	A command to execute on the remote hosts
.PARAMETER winrm
	Enabled Windows Remoting on the remote host
.PARAMETER audit
	Fix Audit settings on remote host
.PARAMETER gpupdate
	Force remote system to process a gupdate -force
.PARAMETER acas
	Try to update the host to get ACAS Credentialed scans working
.PARAMETER office
	Renamed user profiles to 'profile.old' in an effort to correct the MS Office SCAP Benchmarks
.PARAMETER win10
	Prevent the windows 10 upgrade from being enabled on the remote host
.PARAMETER hideKB
	Prevent a windows KB from being installed
.PARAMETER showKB
	Allow a previously hidden windows KB to be installed
.PARAMETER kb
	The KB referenced in the show and hide parameters
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Fen 25, 2015
#>
[CmdletBinding()]
param( $hostCsvPath = "", $computers = @(),	$OU = "", 
$cmd = "",
[switch] $winrm,
[switch] $audit,
[switch] $gpupdate,
[switch] $acas,
[switch] $office,
[switch] $win10,
[switch] $hideKB,
[switch] $showKB,
$kb = ""

)

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$updateHostsClass = new-PSClass updateHosts{
	note -static PsScriptName "updateHosts"
	note -static Description ( ($(((get-help .\updateHosts.ps1).Description)) | select Text).Text)
	
	note -private HostObj @{}
	note -private mainProgressBar
	note -private gui
	
	note -private cmd ""
	note -private gpupdate $false
	note -private winrm $false
	note -private audit $false
	note -private acas $false
	note -private office $false
	note -private win10 $false
	note -private hideKb $false
	note -private showKb $false
	note -private switchParms @("gpupdate","winrm","acas","office","win10", "hidekb","showKb", "audit")
	
	method -private  RecurseCopyKey{
		param($sourceKey, $destinationKey)
		foreach ($valueName in $sourceKey.GetValueNames() ){        
			$objValue = $sourceKey.GetValue($valueName);
			$valKind = $sourceKey.GetValueKind($valueName);
			$destinationKey.SetValue($valueName, $objValue, $valKind);
		}

		foreach ($sourceSubKeyName in $sourceKey.GetSubKeyNames())	{
			$sourceSubKey = $sourceKey.OpenSubKey($sourceSubKeyName);
			$destSubKey = $destinationKey.CreateSubKey($sourceSubKeyName);
			$private.RecurseCopyKey($sourceSubKey,$destSubKey)
		}
	}

	method -private  CopyKey{
		param($parentKey, $keyNameToCopy, $newKeyName)
		$destinationKey = $parentKey.CreateSubKey($newKeyName);
		$sourceKey = $parentKey.OpenSubKey($keyNameToCopy);
		$private.RecurseCopyKey($sourceKey,$destinationKey)
		return $null
	}
			
	method -private  RenameSubKey{
		param($parentKey,  $subKeyName, $newSubKeyName)
		$private.CopyKey($parentKey,$subKeyName,$newSubKeyName)
		$parentKey.DeleteSubKeyTree($subKeyName);
	}

	method -private actOffice{
		param($computerName)
		
		$pingResult = Get-WmiObject -Class win32_pingstatus -Filter "address='$($computerName.Trim())'"
		$uiClass.writeColor( "$($uiClass.STAT_WAIT) #yellow#Connecting# to #green#$($computerName)#" )
		if( $pingResult.StatusCode -eq 0 -or $pingResult.StatusCode -eq $null ) {
			foreach($agedProfile in 
				(gwmi win32_userprofile -computerName $computerName | 
					? { $_.SID.length -gt 10 } | 
					? { $_.LocalPath -like '*\users\*' } | 
					select @{LABEL="last used";EXPRESSION={$_.ConvertToDateTime($_.lastusetime)}},  LocalPath,  SID 
				)
			) {
				$ntuser = ( gci -force ($agedProfile.localPath -replace "c:\\","\\$($computerName)\c`$\") -filter "ntuser.dat"  | select -first 1) 
				if($utilities.isBlank($ntuser) -eq $false){
					$uiClass.writeColor( "$($uiClass.STAT_WAIT) #yellow#Renaming# $($ntuser.fullname) to $($ntuser.fullname).$(get-date -format 'yyyyMMdd-hhmmss').old" )
					move-item "$($ntuser.fullname)" "$($ntuser.fullname).$(get-date -format 'yyyyMMdd-hhmmss').old"
				}
			}

			$uiClass.writeColor( "$($uiclass.STAT_WAIT) Renaming #yellow#Profile# in #green#Registry#" )
			$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $computerName ) 
			$regKey = $reg.OpenSubKey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList",$true) 
			foreach($regProfile in ( $regKey.GetSubKeyNames() | ?{ $_.length -gt 10 } | ? { $_ -notlike '*.old*' } ) ){
				$profileKey = $reg.OpenSubKey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\$($regProfile)",$true) 
				$private.renameSubKey($regKey,$regProfile,"$($regProfile).$(get-date -format 'yyyyMMdd-hhmmss').old")
			}
			$uiClass.writeColor( )
			
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) #yellow#Connection# to #green#$($computerName)# failed" )
		}
		$uiClass.writeColor( )
	}
	
	method -private actAcas{
		param($computerName)
		$pingResult = gwmi -Class win32_pingstatus -Filter "address='$($computerName.Trim())'"
		if( ($pingResult.StatusCode -eq 0 -or $pingResult.StatusCode -eq $null ) ) {
			$uiclass.writeColor( "$($uiClass.STAT_OK) Updating #green#$computerName#")
		
			#make sure we have access to the machine
			if( (test-path "\\$computerName\c`$" ) -eq $true){
				#ensure the remote host accepts powershell management requests
				$private.actWinrm($computerName)
				
				$uiclass.writeColor("$($uiclass.STAT_WAIT) Updating #yellow#Registry# to generate admin shares on #green#$($computerName)#")
				#set registry key to handle admin share
				$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $computerName ) 
				$regKey= $reg.OpenSubKey("SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters",$true) 
				$regKey.SetValue("AutoShareServer",1,[Microsoft.Win32.RegistryValueKind]::DWord)

				#restart services to get admin share out there again		
				$uiclass.writeColor("$($uiclass.STAT_WAIT) Attempting to delete ADMIN`$ Share" )
				$adminShare = ( gwmi win32_share -filter "Name='ADMIN$'" -computerName $computerName).Delete() 
				if($adminShare.ReturnValue -eq 0){
					$uiclass.writeColor( "$($uiClass.STAT_OK) ADMIN`$ share deleted")
				}else{
					$uiclass.writeColor( "$($uiClass.STAT_ERROR) Could not delete ADMIN`$ share")
				}
				
				$uiclass.writeColor("$($uiclass.STAT_WAIT) Attempting to delete IPC`$ Share" )
				$adminShare = ( gwmi win32_share -filter "Name='IPC`$'" -computerName $computerName).Delete() 
				if($adminShare.ReturnValue -eq 0){
					$uiclass.writeColor( "$($uiClass.STAT_OK) IPC`$ share deleted")
				}else{
					$uiclass.writeColor( "$($uiClass.STAT_ERROR) Could not delete IPC`$ share")
				}
				
				$uiclass.writeColor( "$($uiClass.STAT_OK) Stopping #yellow#Computer Browser and Server# Services on #green#$computerName#")
				
				stop-service -inputobject $(get-service -ComputerName $computerName -Name "Computer Browser") -force
				stop-service -inputobject $(get-service -ComputerName $computerName -Name "Server") -force
				sleep -seconds 10
				
				$uiclass.writeColor( "$($uiClass.STAT_OK) Starting #yellow#Computer Browser and Server# Services on #green#$computerName#")
				start-service -inputobject $(get-service -ComputerName $computerName -Name "Server")
				start-service -inputobject $(get-service -ComputerName $computerName -Name "Computer Browser")
				sleep -seconds 10

				$uiclass.writeColor( "$($uiClass.STAT_OK) Updating #yellow#Firewall Configurations# on #green#$computerName#")
				stop-service -inputobject $(get-service -ComputerName $computerName -Name "Windows Firewall") -force
				sleep -seconds 10
				
				#enable get firewall service, set to manual start
				set-service -inputobject $(get-service -ComputerName $computerName -Name "Windows Firewall") -StartupType manual
				start-service -inputobject $(get-service -ComputerName $computerName -Name "Windows Firewall")
				sleep -seconds 10

				#send command to remote system to turn off the firewall, even though the service must be running
				invoke-command -computername $computerName -scriptBlock {NetSh Advfirewall set allprofiles state off}
			}else{
				$uiClass.writeColor( "$($uiClass.STAT_ERROR) No Administrative Privileges on  #green#$($computerName) #" )
			}
		}else{
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Skipping $($computerName) .. not accessible" )
		}
		$uiClass.writeColor()
	}
	
	method -private actGpupdate{
		param($computerName)
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Updating #yellow#Group Policies# on #green#$($computerName.trim())#")
		$uiClass.writeColor(
			(& .\bin\PsExec.exe \\$($computerName.trim()) cmd /c 'gpupdate /force' | out-string)
		)
		$uiClass.writeColor("$($uiClass.STAT_OK) Completed Updating #yellow#Group Policies# on #green#$($computerName.trim())#")
		sleep -seconds 5
	}
	
	method -private actWinrm{
		param($computerName)
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Enabling #yellow#WinRm# on #green#$($computerName.trim())#")
		$uiClass.writeColor( 
			(& .\bin\PsExec.exe \\$($computerName.trim()) /s cmd /c 'winrm quickconfig -quiet' | out-string) 
		)
		$uiClass.writeColor("$($uiClass.STAT_OK) Finished Enabling #yellow#WinRm# on #green#$($computerName.trim())#")
		sleep -seconds 5
	}
	
	method -private uninstallKB{
		param($computerName, $kb)
		
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Scanning #green#$($computerName.trim())# for installed hotfix #yellow#$KB#")
		
		try{
			$installedHotfixes = (get-hotfix  -ComputerName $computername -errorAction silentlyContinue  | ? { $_.HotFixId -eq $kb } | select hotfixid).HotFixId
			if($utilities.isBlank($installedHotfixes) -eq $false ) {
				$hotfixID = $installedHotfixes.Replace("KB","")
				$uiClass.writeColor( "$($uiclass.STAT_OK) Found the hotfix #yellow#KB$($HotfixID)#" )
				
				$UninstallString = "cmd.exe /c wusa.exe /uninstall /KB:$hotfixID /quiet /norestart"
				$uiClass.writeColor( "$($uiclass.STAT_WAIT) Uninstalling the hotfix. #yellow#$($uninstallstring)#")
				([WMICLASS]"\\$computername\ROOT\CIMV2:win32_process").Create($UninstallString) | out-null            
				while (@(Get-Process wusa -computername $computername -ErrorAction SilentlyContinue).Count -ne 0) {
					Start-Sleep 3
					$uiClass.writeColor(  "$($uiClass.STAT_WAIT) Waiting for update removal to finish ..." )
				}
				$uiClass.writeColor(  "$($uiClass.STAT_OK) Completed the uninstallation of #yellow#KB$hotfixID#" )
			} else {            
				$uiClass.writeColor(  "$($uiClass.STAT_WAIT) Hotfix #yellow#$($kb)# not installed on #green#$($computerName)#" )
				return
			}   
		}catch{
			$uiClass.writeColor(  "$($uiClass.STAT_ERROR) Could not uninstall $kb" )
		}
	}
	
	method -private toggleKb{
		param($computerName, $kb, $disable)

		try{
			$dirGuid = ( [guid]::NewGuid() ).Guid
			if( (test-path "\\$($computerName)\c`$\$($dirGuid)") -eq $false){
				$uiClass.writeColor( "$($uiclass.STAT_WAIT) Creating remote script folder #yellow#c:\$($dirGuid)# on #green#$computerName#" )
				mkdir "\\$($computerName)\c`$\$($dirGuid)"
			}
			
			if($disable -eq $true){
				$hide = 'True'
			}else{
				$hide = 'False'
			}
		
		$kbToHideVBS = @"
wscript.echo "Creating Update Session"
set updateSession = createObject("Microsoft.Update.Session")
wscript.echo "Creating Searcher"
set updateSearcher = updateSession.CreateupdateSearcher()
wscript.echo "Setting Server to Microsoft Update"
updateSearcher.ServerSelection = 2
wscript.echo "Executing search"
Set searchResult = updateSearcher.Search("IsHidden=0 or IsHidden=1")
For i = 0 To searchResult.Updates.Count-1
	set update = searchResult.Updates.Item(i)
	if instr(1, update.Title, "$($kb)", vbTextCompare) <> 0 then
		update.IsHidden = $($hide)
		wscript.echo "Disabling $($kb)"
	end if
Next
"@
			$uiClass.writeColor( "$($uiclass.STAT_WAIT) Deploying update script #yellow#hide$($kb).vbs# on #green#$computerName#" )
			set-content -path "\\$($computeRName)\c`$\$($dirGuid)\hide$($kb).vbs"  -value $kbToHideVBS

			$uiClass.writeColor( "$($uiclass.STAT_WAIT) Executing update script #yellow#hide$($kb).vbs# on #green#$computerName#" )
			write-host (& .\bin\psexec.exe \\$($computerName) -s c:\windows\system32\cscript.exe "c:\$($dirGuid)\hide$($kb).vbs" | out-string )
			
			$uiClass.writeColor( "$($uiclass.STAT_WAIT) Removing remote script folder #yellow#c:\$($dirGuid)# on #green#$computerName#" )
			Remove-Item "\\$($computeRName)\c`$\$($dirGuid)\" -Force -Recurse
		}catch{
			$uiClass.writeColor(  "$($uiClass.STAT_ERROR) Could not toggle $kb" )
		}
	}
	
	method -private findKb{
		param($computerName, $kb, $uid = $null)
		
		try{
			$objSession =  [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session","$($computerName)"))
			$objSearcher = $objSession.CreateUpdateSearcher()
			$objSearcher.ServerSelection = 2

			$uiClass.writeColor( "$($uiclass.STAT_WAIT) Scanning for install status of #yellow#$kb# on #green#$computerName#" )
			
			if($uid -eq $null){
				$search = "IsHidden=1 or IsHidden=0"
			}else{
				$search = "(IsHidden=1 and UpdateID='$($uid)') or (IsHidden=0 and UpdateID='$($uid)')"
			}
			
			$objResults = $objSearcher.Search($search)

			Foreach($Update in $objResults.Updates){
				If($Update.KBArticleIDs -eq ($kb -replace "kb","" ) ){
					if($Update.IsHidden -eq 'True'){
						$uiClass.writeColor( "$($uiclass.STAT_OK) #yellow#$($update.KBArticleIDs)# is hidden on #green#$computerName#" )
					}else{
						$uiClass.writeColor( "$($uiclass.STAT_ERROR) #yellow#$($update.KBArticleIDs)# is not hidden on #green#$computerName#" )
					}
				}
			}
		}catch{
			$uiClass.writeColor(  "$($uiClass.STAT_ERROR) Could not find $kb" )
		}
	}
	
	
	method -private actHideKb{	
		param($computerName)
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Preventing install of #yellow#$($KB)# on #green#$($computerName.trim())#")
		$private.uninstallKB($computerName, $kb)
		$private.toggleKb($computerName, $kb, $true)
		$private.findKb($computerName, $kb)
		
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Prevented install of #yellow#$($KB)# on #green#$($computerName.trim())#")
	}
	
	method -private actShowKb{	
		param($computerName)
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Allowing install of #yellow#$($KB)# on #green#$($computerName.trim())#")
		$private.toggleKb($computerName, $kb, $false)
		$private.findKb($computerName, $kb)
		
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Allowed install of #yellow#$($KB)# on #green#$($computerName.trim())#")
	}
	
	method -private actWin10{
		param($computerName)
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Preventing #yellow#Windows 10# upgrade on #green#$($computerName.trim())#")
		
		$private.uninstallKB($computerName, "3035583")
		$private.toggleKb($computerName, "3035583", $true)
		$private.findKb($computerName, "3035583", "4af2dec5-6d6a-4b8c-892d-2b8aa4179c04")
		$uiClass.writeColor("$($uiClass.STAT_OK) Finished Preventing #yellow#Windows 10# upgrade on #green#$($computerName.trim())#")
		$uiClass.writeColor("")
	}
	
	method -private actAudit{
		param($computerName)
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Update #yellow#Audit Privileges# on #green#$($computerName.trim())#")
		
		$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $computerName ) 
		
		
		$regKey = $reg.OpenSubKey("SYSTEM\\CurrentControlSet\\Control\\LSA",$true) 
		$regKey.SetValue("fullprivilegeauditing", ([byte[]]("0x00")),[Microsoft.Win32.RegistryValueKind]::Binary)
		
		$regKey = $reg.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System")  
		$regKey.SetValue("LocalAccountTokenFilterPolicy", 0,[Microsoft.Win32.RegistryValueKind]::DWord)
		
		([ADSI]"WinNT://$computerName/Auditors,group").psbase.Invoke("Add",([ADSI]"WinNT://$($env:userDomain)/$($env:userName)").path)
		
		$auditFile = gwmi -query "select * from CIM_DataFile where name = 'C:\\windows\\security\\audit\\audit.csv'" -computerName $computerName
		$auditFile.Delete()
		invoke-command -computerName $computeRName -scriptBlock { & gpupdate /force }
		
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Finished updating #yellow#Audit Privileges# on #green#$($computerName.trim())#")
	}
	
	method Execute{
		$currentComputer = 0

		if($private.HostObj.Count -gt 0){
		
			$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
			
			$private.HostObj.Hosts.keys | % {
				$currentComputer = $currentComputer + 1
				$currentHostName = $_
				$i = (100*($currentComputer / $private.HostObj.Hosts.count))
			
				$private.mainProgressBar.Activity("$currentComputer / $($private.HostObj.Hosts.count): Processing system $_").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			
				$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($_.Trim())'"
				try{
					$uiClass.writeColor( "$($uiClass.STAT_OK) Processing #green#$($_)#" )
					$stat = (gwmi -class win32_pingstatus  -filter "address='$($currentHostName.Trim())'")
					
					if( ($stat.StatusCode -eq 0 -or $stat.StatusCode -eq $null ) -and $utilities.isBlank($stat.IPV4Address) -eq $false ) {
					
						$private.switchParms | % {
							if($private.$($_) -eq $true){
								invoke-expression "`$private.act$($_)('$($currentHostName.trim())')"
							}
						}
						
						if($private.cmd -ne ""){
							$uiClass.writeColor("$($uiClass.STAT_WAIT) Executing Command #yellow#$($private.cmd)# on #green#$($_.trim())#")
							$uiClass.writeColor(
								(& .\bin\PsExec.exe \\$($_.trim()) /s cmd /c "$($private.cmd)" | out-string)
							)
							sleep -seconds 5
						}
						
					}else{
						$uiClass.writeColor( "$($uiClass.STAT_ERROR) #green#$($_)# is offline." )
					}
				} catch { 
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) Skipping $_ .. not accessible" )
				}
			} 
			$private.mainProgressBar.Completed($true).Render() 
		}
		$uiClass.errorLog()
	}
	
	constructor{
		param()
		$private.HostObj = $HostsClass.New()
				
		if( ($cmd -eq "" -or $cmd -eq $null) -and  -not ( $private.switchParms | % { invoke-expression "`$$($_)" } | ? { $_ -eq $true } )  ){
			$private.gui = $null
		
			$private.gui = $guiClass.New("updateHosts.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.cmd = $private.gui.Controls.txtCmd.Text
			$private.switchParms | % { $private.$($_) = $private.gui.Controls.$($_).checked }
						
			if( $private.gui.Controls.disUpdate.checked -eq $true ){
				if( $utilities.isBlank($private.gui.Controls.txtKB.Text) -ne $true ){
					if($private.gui.Controls.cboToggle.Text -eq "Enabled" ){
						$private.showKB = $true
						$private.hideKb = $false
						$kb = $private.gui.Controls.txtKB.Text
					}else{
						$private.hideKb = $true
						$private.showKB = $false
						$kb = $private.gui.Controls.txtKB.Text
					}
				}
			}
		}else{
			$private.cmd = $cmd
			$private.switchParms | % { $private.$($_) = invoke-expression "`$$($_)" }
		}
	}
}

$updateHostsClass.New().Execute() | out-null