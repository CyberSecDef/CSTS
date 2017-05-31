<#
.SYNOPSIS
	This is a script that will manage the local admins on a machine
.DESCRIPTION
	This is a script that will manage the local admins on a machine
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.PARAMETER action
	Action to take on the accounts found (List, Delete, Disable, Enable)
.PARAMETER newAdmin
	Create a new administrator with the specified username
.PARAMETER newPass
	Create a new administrator with the specified password
INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Jun 3, 2015
#>
[CmdletBinding()]
param( $hostCsvPath = "", $computers = @(),	$OU = "", $action, $newAdmin, $newPass)

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$manageLocalAdminsClass = new-PSClass manageLocalAdmins{
	note -static PsScriptName "manageLocalAdmins"
	note -static Description ( ($(((get-help .\manageLocalAdmins.ps1).Description)) | select Text).Text)
	
	note -private HostObj @{}
	note -private mainProgressBar
	note -private gui
	
	note -private action
	note -private newAdmin
	note -private newPass
	
	
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
					
						$uiClass.writeColor("$($uiclass.STAT_OK) Action #green#$($private.action.ToUpper())# local admin users on #green#$($currentHostName)#"); 
					
						( gwmi  -Class Win32_Group  -Filter "LocalAccount='$true'"  -ComputerName $currentHostName  | ? { $_.Name -like 'Admin*' } ) | % {
							$_.GetRelated("Win32_Account","Win32_GroupUser","","", "PartComponent","GroupComponent",$FALSE,$NULL) | ? { 
								($_.Domain -eq $currentHostname -and $currentHostname.indexOf(".") -eq -1)  -or ($currentHostName.indexOf(".") -gt 0 -and $_.Domain -eq $currentHostName.substring(0, $currentHostName.indexOf(".") ) )
							} | % {
								$userName = $_.Name
								
								switch ( $private.action ) {
									"List" { 
										if( ($users.getLocalUser($currentHostname, $userName)).UserFlags.psBase.value -band 2 ){
											$uiClass.writeColor("$($uiclass.STAT_WAIT) #green#Found# #yellow#disabled# local admin user #yellow#$($userName)# on #green#$($currentHostName)#"); 
										}else{
											$uiClass.writeColor("$($uiclass.STAT_WAIT) #green#Found# #yellow#enabled# local admin user #yellow#$($userName)# on #green#$($currentHostName)#"); 
										}
									}
									"Delete" { 
										if( $private.newAdmin -eq $userName){
											$uiClass.writeColor("$($uiclass.STAT_WAIT) #red#Skipped# #yellow#Deleting# local admin user #yellow#$($userName)# on #green#$($currentHostName)# because of the specified new user"); 
										}else{
											if($users.removeLocalUser($currentHostname, $userName) -eq -1){
												$uiClass.writeColor("$($uiclass.STAT_WAIT) #red#Could Not Delete# local admin user #yellow#$($userName)# on #green#$($currentHostName)#"); 
											}else{
												$uiClass.writeColor("$($uiclass.STAT_WAIT) #red#Deleted# local admin user #yellow#$($userName)# on #green#$($currentHostName)#"); 
											}
										}
									}
									"Disable" { 
										if( $private.newAdmin -eq $userName){
											$uiClass.writeColor("$($uiclass.STAT_WAIT) #red#Skipped# #yellow#Disabling# local admin user #yellow#$($userName)# on #green#$($currentHostName)# because of the specified new user"); 
										}else{
											$uiClass.writeColor("$($uiclass.STAT_WAIT) #yellow#Disabled# local admin user #yellow#$($userName)# on #green#$($currentHostName)#");
											$users.disableLocalUser($currentHostname, $userName);
										}
									}
									"Enable" { 
										$uiClass.writeColor("$($uiclass.STAT_WAIT) #yellow#Enabled# local admin user #yellow#$($userName)# on #green#$($currentHostName)#");
										try{
											$users.enableLocalUser($currentHostname, $userName);
										}catch{
											$uiClass.writeColor("$($uiclass.STAT_ERROR) local admin user #yellow#$($userName)# on #green#$($currentHostName)# could not be enabled.");
										}
									}
									default { $uiClass.writeColor("$($uiclass.STAT_WAIT)  #green#Found# local admin user #yellow#$($userName)# on #green#$($currentHostName)#") }
								}
							}
						}

						if($utilities.isBlank($private.NewAdmin) -eq $false -and $utilities.isBlank($private.newPass) -eq $false){
						
							#see if the user already exists
							if($utilities.isBlank( $users.getLocalUser($currentHostName,$private.NewAdmin)  ) -eq $false){
								$users.resetLocalUserPassword($currentHostName,$private.NewAdmin,$private.NewPass)  
								$users.addLocalUserToGroup($currentHostName,$private.NewAdmin,"Administrators")  
								
								if($utilities.isBlank( $users.getLocalUser($currentHostName,$private.NewAdmin)  ) -eq $false){
									$uiClass.writeColor("$($uiclass.STAT_OK) #green#Updated# local admin user #yellow#$($private.NewAdmin)# on #green#$($currentHostName)#")
								}else{
									$uiClass.writeColor("$($uiclass.STAT_ERROR) #red#Could Not Update#  local admin user #yellow#$($private.NewAdmin)# on #green#$($currentHostName)#")
								}
							}else{
								$users.addLocalUser($currentHostName,$private.NewAdmin,$private.NewPass)  
								$users.addLocalUserToGroup($currentHostName,$private.NewAdmin,"Administrators")  
								
								if($utilities.isBlank( $users.getLocalUser($currentHostName,$private.NewAdmin)  ) -eq $false){
									$uiClass.writeColor("$($uiclass.STAT_OK) #green#Added# new local admin user #yellow#$($private.NewAdmin)# on #green#$($currentHostName)#")
								}else{
									$uiClass.writeColor("$($uiclass.STAT_ERROR) #red#Could Not Add# new local admin user #yellow#$($private.NewAdmin)# on #green#$($currentHostName)#")
								}
							}
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
		$private.HostObj = $HostsClass.New($hostCsvPath, $computers, $OU)

		$private.action = $action
		$private.newAdmin = $newAdmin
		$private.newPass  = $newPass
		
		while($utilities.isBlank($private.action) -eq $true){
			$private.gui = $null
			$private.gui = $guiClass.New("manageLocalAdmins.xml")
			$private.gui.generateForm();
			
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.action = $private.gui.Controls.cboAction.Text
			$private.newAdmin = $private.gui.Controls.txtNewAdmin.Text
			$private.newPass  = $private.gui.Controls.txtNewPass.Text
		}
	}
}

$manageLocalAdminsClass.New().Execute() | out-null