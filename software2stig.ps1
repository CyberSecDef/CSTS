<#
.SYNOPSIS
	This is a script that will scan computers and determine which STIGs need to be executed
.DESCRIPTION
	This is a script that will scan computers and determine which STIGs need to be executed.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.EXAMPLE 
	C:\PS>.\software2stig.ps1 -computers "hostname1,hostname2" 
	This example will attempt to scan the computers entered into the command line
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Dec 30, 2014
#>
[CmdletBinding()]
param( $hostCsvPath = "", $computers = @(), $OU = "") 
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$SW2StigClass = new-PSClass Software2Stig{
	note -static PsScriptName "software2stig"
	note -static Description ( ($(((get-help .\software2stig.ps1).Description)) | select Text).Text)
	
	note -private mainProgressBar
	note -private HostObj @{}
	
	#internal keys (should be constants, but not available in PSClass)
	note -private UninstallKeys @(
		"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
		"SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
	)
	
	method Export{

		$export = $ExportClass.New()
		$export.addWorkSheet('soft2stig')
	
				
		#determine which stigs were executed
		$stigs = @()
		$private.HostObj.Hosts.keys | % {
			$stigs += $private.HostObj.Hosts.$_.Stigs
		}
		
		#add stig headers
		$r = 1
		$c = 2
		foreach($stig in ($stigs | Sort -unique)){
			$export.updateCell($r,$c,$stig)
			$c++
		}
		$r++
		
		#add host information
		$private.HostObj.Hosts.keys | sort -unique | % {
			$c=1
			$export.updateCell($r,$c,$_)

			foreach($stig in ($stigs | Sort -unique)){
				$c++
				if($private.HostObj.Hosts.$_.Stigs -contains $stig){
					$export.updateCell($r,$c,"X")
				}
			}
			$r++
		}
		
		$export.autofitAllColumns()
		$export.formatAllFirstRows('Header')
		
		$ts = (get-date -format "yyyyMMddHHmmss")
		$export.saveAs([System.IO.Path]::GetFullPath("$($pwd.ProviderPath)\results\$($SW2StigClass.PsScriptName)_$ts.xml"))
	}
	
	method Dump{
		$tmp = @()
		$private.HostObj.Hosts.keys | % {
			$tmp += $private.HostObj.Hosts.$_.Stigs
			$private.HostObj.Hosts.$_.Stigs | fl | out-string | write-host
			$private.HostObj.Hosts.$_.Software | fl | out-string | write-host
		}
		
		$tmp | Sort -unique | fl | out-string | write-host
	}
	
	method addStig{
		param ($remoteHost,$stig)
		if($private.HostObj.Hosts.$remoteHost.Stigs -eq $null){
			$private.HostObj.Hosts.$remoteHost.Stigs = @()
		}
		
		if($private.HostObj.Hosts.$remoteHost.Stigs -notcontains $stig){
			$private.HostObj.Hosts.$remoteHost.Stigs += $stig
		}
		
	}
	
	method addSoftware{
		param ($remoteHost,$software)
		
		if($private.HostObj.Hosts.$remoteHost.Software -eq $null){
			$private.HostObj.Hosts.$remoteHost.Software = @()
		}
		
		if($private.HostObj.Hosts.$remoteHost.Software -notcontains $software){
			$private.HostObj.Hosts.$remoteHost.Software += $software
		}
	}
	
	method scanIEVersion{
		param([string] $remoteHost)
		try{
			$remoteRegistry = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$remoteHost)  
			$remoteRegistryKey=$remoteRegistry.OpenSubKey("SOFTWARE\\Microsoft\\Internet Explorer")  
			$ieVer = 0
			$svcVer = $remoteRegistryKey.GetValue("SvcVersion")
			if($svcVer -ne $null -and $svcVer -ne ""){
				$ieVer = ( $svcVer ).Split(".")[0]
			}else{
				$ieVer = ( $remoteRegistryKey.GetValue("Version") ).Split(".")[0]
			}
			
			$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#Internet Explorer version $ieVer#" )
			
			$this.addSoftware($remoteHost, "Internet Explorer $ieVer");
			switch($ieVer){
				6 		{ $this.addStig($remoteHost, "Microsoft IE6");  }
				7 		{ $this.addStig($remoteHost, "Microsoft IE7");  }
				8 		{ $this.addStig($remoteHost, "Microsoft IE8");  }
				9 		{ $this.addStig($remoteHost, "Microsoft IE9");  }
				10 		{ $this.addStig($remoteHost, "Microsoft IE10");  }
				11 		{ $this.addStig($remoteHost, "Microsoft IE11");  }
			}
		}catch{
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not execute #yellow#scanIEVersion# on #green#$remoteHost#" )
		}
		
	}
		
	method scanWebServers{
		param([string] $remoteHost)
		
		try{
			$client = new-object System.Net.WebClient
			$task = $client.DownloadString("http://$remoteHost/") 
			$server = $client.ResponseHeaders.Get('Server')
			if($utilies.isBlank($server) -eq $false){
				if($server -like '*apache*' -and $server -like '*2.2*'){
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#Apache 2.2#" )
					$this.addSoftware($remoteHost,"Apache Web Server 2.2")
					$this.addStig($remoteHost, "APACHE 2.2")
				}elseif($server -like '*apache*' -and $server -like '*2.0*'){
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#Apache 2.0#" )
					$this.addSoftware($remoteHost,"Apache Web Server 2.0")
					$this.addStig($remoteHost, "Apache 2.0")
				}elseif($server -like '*IIS*' -and $server -like '*6*'){
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#IIS 6.x#" )
					$this.addSoftware($remoteHost,"IIS 6.x")
					$this.addStig($remoteHost, "IIS 6.0")
				}elseif($server -like '*IIS*' -and $server -like '*7*'){
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#IIS 7.x#" )
					$this.addSoftware($remoteHost,"IIS 7.x")
					$this.addStig($remoteHost, "IIS 7.0")
				}else{
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running a #green#Generic Web Server#" )
					$this.addSoftware($remoteHost,"Generic Web Server")
					$this.addStig($remoteHost, "web server STIG"); 
					$this.addStig($remoteHost, "Web Server Manual SRG");
				}
			}
		}catch{
			$uiClass.writeColor("$($uiClass.STAT_OK) #yellow#$($remoteHost)# is not running an #green#HTTP web server#" )
		}
			
		try{
			$task = $client.DownloadString("https://$remoteHost/") 
			$server = $client.ResponseHeaders.Get('Server')
			if($server -ne "" -and $server -ne $null){
				if($server -like '*apache*' -and $server -like '*2.2*'){
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#Apache 2.2#" )
					$this.addSoftware($remoteHost,"Apache Web Server 2.2")
					$this.addStig($remoteHost, "APACHE 2.2")
				}elseif($server -like '*apache*' -and $server -like '*2.0*'){
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#Apache 2.0#" )
					$this.addSoftware($remoteHost,"Apache Web Server 2.0")
					$this.addStig($remoteHost, "Apache 2.0")
				}elseif($server -like '*IIS*' -and $server -like '*6*'){
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#IIS 6.x#" )
					$this.addSoftware($remoteHost,"IIS 6.x")
					$this.addStig($remoteHost, "IIS 6.0")
				}elseif($server -like '*IIS*' -and $server -like '*7*'){
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#IIS 7.x#" )
					$this.addSoftware($remoteHost,"IIS 7.x")
					$this.addStig($remoteHost, "IIS 7.0")
				}else{
					$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running a #green#Generic Web Server#" )
					$this.addSoftware($remoteHost,"Generic Web Server")
					$this.addStig($remoteHost, "web server STIG"); 
					$this.addStig($remoteHost, "Web Server Manual SRG");
				}
			}
		}catch{
			$uiClass.writeColor("$($uiClass.STAT_OK) #yellow#$($remoteHost)# is not running an #green#HTTPS web server#" )
		}
	}
	
	method scanUninstallKeys{
		param([string] $remoteHost)
		
		try{
			$remoteRegistry = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$remoteHost)  
			foreach($key in $private.UninstallKeys){
				$remoteRegistryKey=$remoteRegistry.OpenSubKey($key)  
				if($remoteRegistryKey -ne $null){
					$remoteSubKeys = $remoteRegistryKey.GetSubKeyNames()
					
					$remoteSubKeys | % {
						$remoteSoftwareKey = $remoteRegistry.OpenSubKey("$key\\$_")
						$keyValue = $remoteSoftwareKey.GetValue("DisplayName")
						$keyVersion = $remoteSoftwareKey.GetValue("DisplayVersion")
						if( $keyValue -ne "" -and $keyValue -ne $null -and $keyValue -notlike '*security*' -and $keyValue -notlike '*update*' -and $keyValue -notlike '*driver*' -and $keyValue -notlike '*runtime*' -and $keyValue -notlike '*redistributable*' -and $keyValue -notlike '*framework*'-and $keyValue -notlike '*hotfix*'  -and $keyValue -notlike '*plugin*' -and $keyValue -notlike '*plug-in*' -and $keyValue -notlike '*debug*' -and $keyValue -notlike '*addin*' -and $keyValue -notlike '*add-in*' -and $keyValue -notlike '*library*'	){
							$this.addSoftware($remoteHost, $keyValue)
							
							if($keyValue -like 'McAfee VirusScan*'){
								if($keyVersion -ne "" -and $keyVersion -ne $null){
									if($keyVersion -like '8.8*'){
										$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#McAfee VirusScan 8.8#" )
										$this.addStig($remoteHost,"McAfee Virus Scan 8.8")
									}else{
										$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#McAfee VirusScan Pre-8.8#" )
										$this.addStig($remoteHost,"McAfee Antivirus")
									}
								}
								$this.addStig($remoteHost,"McAfee Virus Scan 8.8")
							}
							
							if($keyValue -like 'Symantec*' -and $keyValue -notlike '*encryption*' -and $keyValue -notlike '*ePo Plugin*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
								if($keyVersion -ne "" -and $keyVersion -ne $null){
									if($keyVersion -like '12.1*'){
											$this.addStig($remoteHost,"Symantec Endpoint Protection 12.1")
									}else{
											$this.addStig($remoteHost,"Symantec Antivirus")
									}
								}
							}
							
							if($keyValue -like 'Microsoft Visual Studio*' -or $keyValue -like 'Netbeans*' -or $keyValue -like 'Eclipse*'  ){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running a #green#Software Development IDE#" )
								$this.addStig($remoteHost,"Application Security and Development")
							}
							
							if($keyValue -like '*Java 7*' ){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$keyValue#" )
								$this.addStig($remoteHost,"JRE 7")
							}
							
							if($keyValue -like '*Java 6*' ){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$keyValue#" )
								$this.addStig($remoteHost,"JRE 6")
							}
							
							if($keyValue -like '*Java*' -and $keyValue -like '*development*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$keyValue#" )
								$this.addStig($remoteHost,"Application Security and Development")
							}
							
							if($keyValue -like '*.NET*' ){
								if($keyValue -like '*4*'){
									$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
									$this.addStig($remoteHost,"MS DotNet Framework 4")
								}else{
									$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
									$this.addStig($remoteHost,"MS DotNet Framework 1 through 3.5")
								}
							}
							
							if($keyValue -like 'Microsoft Office*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
								if($keyValue -like '*2003*'){
									$this.addStig($remoteHost, "Ms Office 2003")
								}
								if($keyValue -like '*2007*'){
									$this.addStig($remoteHost,"Ms Office 2007")
								}
								if($keyValue -like '*2010*'){
									$this.addStig($remoteHost,"Ms Office 2010")
								}
								if($keyValue -like '*2013*'){
									$this.addStig($remoteHost,"Ms Office 2013")
								}
							}
							
							if($keyValue -like 'Microsoft Sharepoint*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
								$this.addStig($remoteHost, "Sharepoint")
							}
							
							if($keyValue -like 'Tomcat*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
								$this.addStig($remoteHost, "Application Server SRG")
							}
							
							if($keyValue -like 'Virtual*' -or $keyvalue -like '*vmware*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
								$this.addStig($remoteHost, "Virtual Machine")
							}
							
							

							if($keyValue -like '*SQL Server*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
								if($keyValue -like '*SQL Server 2012*'){
									$this.addStig($remoteHost, "Sql 2012 DB")
								}elseif($keyValue -like '*SQL Server 2005*'){
									$this.addStig($remoteHost, "Sql 2005 DB")
								}else{
									$this.addStig($remoteHost, "Database SRG")
								}
							}						
							
							if($keyValue -like '*Chrome*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
								$this.addStig($remoteHost, "Google Chrome")
								
							}
							
							if($keyValue -like '*Firefox*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$($keyValue)#" )
								$this.addStig($remoteHost, "Mozilla Firefox")
								
							}
						}
					}
				}
			}
		}catch{
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not execute #yellow#scanUninstallKeys# on #green#$remoteHost#" )
		}
	}
	
	method scanOracleVersion{
		param([string] $remoteHost)
		
		try{
			$orclVer = -1
			
			$orclStat = get-wmiobject Win32_Service -ComputerName $remoteHost -Filter "name like 'Oracle%'"
			if($orclStat -ne "" -and $orclStat -ne $null){
				$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#Oracle#.  Scanning file system to determine version.  This may take a while..." )
				
				foreach($share in (gwmi win32_share -computername $remoteHost | ? { $_.Name -notlike 'IPC*' -and $_.Name -notlike 'ADMIN*' } ) ){
					try{
						cmd /c dir ""\\$remoteHost\$($share.Name)\oraclient*.dll"" /b /s  | % {
							if($_ -like '*11.2*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running a copy of #green#Oracle 11.2#" )
								$this.addStig($remoteHost, "Oracle DB 11.2g")
							}elseif($_ -like '*11g*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running a copy of #green#Oracle 11#" )
								$this.addStig($remoteHost, "Oracle DB 11g")
							}elseif($_ -like '*10*'){
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running a copy of #green#Oracle 10#" )
								$this.addStig($remoteHost, "Oracle 10")
								$this.addStig($remoteHost, "Oracle DB 10g")
							}else{
								$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running a copy of #green#Oracle#" )
								$this.addStig($remoteHost, "Oracle DB 11.2g")
								$this.addStig($remoteHost, "Oracle DB 11g")
								$this.addStig($remoteHost, "Oracle 10")
								$this.addStig($remoteHost, "Oracle DB 10g")
							}
						} 
					}catch{
						$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not scan filesystem on #green#$remoteHost#" )
					}
				}
				
			}
		}catch{
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not execute #yellow#scanOracleVersion# on #green#$remoteHost#" )
		}
	}
	
	method scanIISVersion{
		param([string] $remoteHost)
		
		try{
			$iisVer = -1
			#is IIS installed?
			$iisStat = get-wmiobject Win32_Service -ComputerName $remoteHost -Filter "name='W3SVC'"
			if($iisStat -ne "" -and $iisStat -ne $null){
				$iisVer = 0
				if(test-path "\\$remoteHost\c`$\windows\system32\inetsrv\InetMgr.exe"){
					$iisVer = ( [System.Diagnostics.FileVersionInfo]::GetVersionInfo("\\$remoteHost\c`$\windows\system32\inetsrv\InetMgr.exe").ProductVersion ).Split(".")[0]
				}
			}
			
			if($iisVer -ge 0){
				$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#Internet Information Services Version $iisVer#" )
				$this.addSoftware($remoteHost, "IIS $iisVer");
				switch($iisVer){
					6 		{ $this.addStig($remoteHost, "IIS 6.0"); }
					7 		{ $this.addStig($remoteHost, "IIS 7.0"); }
					default { $this.addStig($remoteHost, "web server STIG"); $this.addStig($remoteHost, "Web Server Manual SRG");}
				}
				
			}
		}catch{
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not execute #yellow#scanIISVersion# on #green#$remoteHost#" )
		}
	}
	
	method scanWindowsVersion{	
		param([string] $remoteHost)
		try{
			$winVer =  (gwmi win32_operatingSystem -computerName $remoteHost | select caption ).caption
			if($winVer -eq $null){$winVer = "UNKNOWN"}
			$uiClass.writeColor( "$($uiClass.STAT_OK) #yellow#$($remoteHost)# is running #green#$winVer#" )
			
			$this.addSoftware($remoteHost, $winVer);
			switch($true){
				($winVer -like 'Microsoft Windows 7*') { $this.addStig($remoteHost, "Windows 7");  }
				($winVer -like 'Microsoft Windows 8*') { $this.addStig($remoteHost, "Windows 8"); }
				($winVer -like '*2003*' -and $winVer -notlike '*R2*') { $this.addStig($remoteHost, "Windows 2003 MS");}
				($winVer -like '*2008*' -and $winVer -notlike '*R2*') { $this.addStig($remoteHost, "Windows 2008");}
				($winVer -like '*2008 R2*') { $this.addStig($remoteHost, "Windows 2008R2"); }
				($winVer -like '2012*') { $this.addStig($remoteHost, "Windows Server 2012"); }
				($winVer -like 'XP*') { $this.addStig($remoteHost, "Windows XP"); }
				($winVer -like 'Vista*') { $this.addStig($remoteHost, "Windows Vista"); }
				
			}
		}catch{
			$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not execute #yellow#scanWindowsVersion# on #green#$remoteHost#" )
		}
	}
	
	method scanDesktopApp{	
		param([string] $remoteHost)
		$this.addStig($remoteHost, "Desktop Application General Stig");
	}
	
	method scanHBSS{	
		param([string] $remoteHost)
		$this.addStig($remoteHost, "HBSS");
	}
		
	method Execute{
		if($private.HostObj.Hosts.count -gt 0){
			$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
			
			foreach($remoteHost in ( $private.HostObj.Hosts.GetEnumerator() | sort Name)){
				$currentComputer = $currentComputer + 1
				$i = (50*($currentComputer / $private.HostObj.Hosts.count))
			
				$private.mainProgressBar.Activity("$currentComputer / $($private.HostObj.Hosts.count): Processing system $($remoteHost.Name.Trim())").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
				
				try{
					$pingResult = Get-WmiObject -Class win32_pingstatus -Filter "address='$($remoteHost.Name.Trim())'"
					if( ($pingResult.StatusCode -eq 0 -or $pingResult.StatusCode -eq $null ) -and $utilities.isBlank($pingResult.IPV4Address) -eq $false ) {
						$uiClass.writeColor( "$($uiClass.STAT_OK) #green#Successfully# connected to #yellow#$($remoteHost.Name)# " )

						foreach($scanner in ($this | gm -MemberType ScriptMethod | ? {$_.Name -like 'scan*' } | sort Name | select Name ) ){
							try{
								invoke-expression "`$this.$($scanner.Name)('$($remoteHost.Name)')"
							}catch{
								$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not execute #yellow#$($scanner)# on #green#$($remoteHost.Name)#" )
							}
						}
					}else{
						$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not connect to #yellow#$($remoteHost.Name)#" )
					}
					$uiClass.writeColor("")
				}catch{
					$uiClass.writeColor( "$($uiClass.STAT_ERROR) Could not properly scan #yellow#$($remoteHost.Name)#" )
					$uiClass.writeColor( $_.Exception.Message )
				}
			}
			$private.mainProgressBar.Completed($true).Render() 
		}
		$this.Export()
		$uiClass.errorLog()
	}
	
	constructor{
		param()
		$private.HostObj = $HostsClass.New()
	}
	
}

$SW2StigClass.New().Execute() | out-null