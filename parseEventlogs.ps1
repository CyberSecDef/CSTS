<#
.SYNOPSIS
	This is a script that will parse through archived event logs, looking for important alerts
.DESCRIPTION
	This is a script that will parse through archived event logs, looking for important alerts
.PARAMETER computer
	The computer to pull the archive from
.PARAMETER archiveLocation
	The location the event logs are  stored
.PARAMETER start
	The start date to pull logs from
.PARAMETER stop
	The stop date to pull logs from
.PARAMETER details
	Output verbose details while executing
.EXAMPLE
	C:\PS>.\parseEventlogs.ps1 -archiveLocation "c:\logs\"
	This example will gather the important events from the logs in the c:\logs\ folder
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Apr 24, 2015
#>
[CmdletBinding()]
param( $computer, $archiveLocation, $start, $stop, [switch] $details ) 
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$ParseEventLogClass = new-PSClass ParseEventLog{
	note -static PsScriptName "parseEventlogs"
	note -static Description ( ($(((get-help .\parseEventlogs.ps1).Description)) | select Text).Text)
	
	note -private HostObj @{}
	note -private gui
	note -private archiveLocation
	note -private computer
	note -private start
	note -private stop
	
	note -private mainProgressBar
	note -private colHeaders @("Event Type", "Machine","Container","TimeCreated","LogName","Provider","User","Level","Id","Message")
	
	note -private export $ExportClass.New()
	note -private sheetRow 1
	
	method -private processLog{
		param($eventType, $filterHash)
		
		if($utilities.isBlank($private.archiveLocation) -eq $false){
			$filterHash.Path="$($private.archiveLocation)\*.*";
		}
		
		$filterHash.StartTime= ( [datetime]::ParseExact("$($private.start) 00:00:00", "MM-dd-yyyy HH:mm:ss", $null) );
		$filterHash.EndTime= ([datetime]::ParseExact("$($private.stop) 23:59:59", "MM-dd-yyyy HH:mm:ss", $null));

		try{
			if($utilities.isBlank($private.computer) -eq $false){
				$logs = get-winevent -computerName $($private.computer) -oldest -filterHashtable $filterHash 
			}else{
				$logs = get-winevent -oldest -filterHashtable $filterHash
			}
			if($logs){
				$parseBar = $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0;  "Id" = 2 }).Render()
				$li = 0;
				$logs | % {
					$li++
					$parseBar.Activity("$li / $($logs.count) : Analysing events in Log").Status("$($_.LogName)").Percent( $li / $($logs.count) * 100 ).Render()
					try{
						if($details -eq $true){
							$uiClass.writeColor("$($uiClass.STAT_OK) $($_.TimeCreated): #yellow#$($_.LevelDisplayName)# - #green#$($_.ProviderName)#")
						}
						
						$private.sheetRow++					
						
						$private.export.updateCell($private.sheetRow,1, "$($eventType)")
						$private.export.updateCell($private.sheetRow,2, "$($_.MachineName)")
						$private.export.updateCell($private.sheetRow,3, "$($_.ContainerLog)")
						$private.export.updateCell($private.sheetRow,4, "$($_.TimeCreated)")
						$private.export.updateCell($private.sheetRow,5, "$($_.LogName)")
						$private.export.updateCell($private.sheetRow,6, "$($_.ProviderName)")
						$private.export.updateCell($private.sheetRow,7, "$($_.UserId)")
						$private.export.updateCell($private.sheetRow,8, "$($_.LevelDisplayName)")
						$private.export.updateCell($private.sheetRow,9, "$($_.Id)")
						$private.export.updateCell($private.sheetRow,10, "$($_.Message)")
						$private.export.formatCell($private.sheetRow,10, [export.excelStyle]::Wrap)
					}catch{}
				}
				$parseBar.Completed($true).Render()
			
			}
		}catch{
			$uiClass.writeColor("$($uiClass.STAT_ERROR) Could not properly read #yellow#$($filterHash.ProviderName)#")
		}
	}
	
	method -private parsePrintingServices{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Printing Services#")
		$private.processLog( "Printing Services", @{Id=307;Level=4;Logname='Microsoft-Windows-PrintService/Operational';ProviderName="Microsoft-Windows-PrintService";} )
	}
	
	method -private parseExternalMediaDetection{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#External Media Detection#")
		$private.processLog("External Media Detection", @{Id=43;Level=4;Logname='Microsoft-Windows-USBUSBHUB3-Analytic';ProviderName="Microsoft-Windows-USBUSBHUB3";} )
		$private.processLog("External Media Detection", @{Id=@(400,410);Level=4;Logname='Microsoft-Windows-Kernel-PnP/Device Configuration';ProviderName="Microsoft-Windows-Kernel-PnP";} )
	}
	
	method -private parseMobileDeviceActivities{
		
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Mobile Device Activities#")
		$private.processLog("Mobile Device Activities", @{Id=@(10000,10001);Level=4;Logname='Microsoft-Windows-NetworkProfile/Operational';ProviderName="Microsoft-Windows-NetworkProfile";} )
		$private.processLog("Mobile Device Activities",  @{Id=@(8000,8011,8001,8003,11000,11001,11002,11004,11005,11010,11006,8002,12011,12012,12013);Level=@(2,4);Logname='Microsoft-Windows-WLANAutoConfig/Operational';ProviderName="Microsoft-Windows-WLANAutoConfig";} )
		
	}
	
	method -private parseGPOErrors{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Group Policy Errors#")
		$private.processLog("GPO Errors", @{Id=@(1125,1127,1129);Level=2;Logname='System';ProviderName="Microsoft-Windows-GroupPolicy";} )
	}
	
	method -private parseKernelDrivers{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Kernel Driver Signing#")
		$private.processLog("Kernel Drivers",  @{Id=@(5038,6281);Level=4;Logname='Security';ProviderName="Microsoft-Windows-Security-Auditing";} )
		$private.processLog("Kernel Drivers", @{Id=@(3001,3002,3003,3004,3010,3023);Logname='Microsoft-Windows-CodeIntegrity/Operational';ProviderName="Microsoft-Windows-CodeIntegrity";} )
		$private.processLog("Kernel Drivers", @{Id=@(219);Level=3;Logname='System';ProviderName="Microsoft-Windows-Kernel-PnP";} )
	}
	
	method -private parseAccountUsage{
		
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Account Usage#")
		$private.processLog("Account Usage", @{Id=@(4740,4728,4732,4756,4735,4624,4625,4648);Level=4;Logname='Security';ProviderName="Microsoft-Windows-Security-Auditing";} )
	}
	
	method -private parseSoftwareInstallation{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Software and Service Installation#")
		$private.processLog("Software Installation", @{Id=6;Level=4;Logname='System';ProviderName="Microsoft-Windows-FilterManager";} )
		$private.processLog("Software Installation", @{Id=7045;Level=4;Logname='System';ProviderName="Service Control Manager";} )
		$private.processLog("Software Installation", @{Id=@(1022,1033);Level=4;Logname='Application';ProviderName="MsiInstaller";} )
		$private.processLog("Software Installation", @{Id=@(903,904);Level=4;Logname='Microsoft-Windows-Application-Experience/Program-Inventory';ProviderName="Microsoft-Windows-Application-Experience";} )
		$private.processLog("Software Installation", @{Id=@(905,906);Level=4;Logname='Microsoft-Windows-Application-Experience/Program-Inventory';ProviderName="Microsoft-Windows-Application-Experience";} )
		$private.processLog("Software Installation", @{Id=@(907,908);Level=4;Logname='Microsoft-Windows-Application-Experience/Program-Inventory';ProviderName="Microsoft-Windows-Application-Experience";} )
		$private.processLog("Software Installation", @{Id=800;Level=4;Logname='Microsoft-Windows-Application-Experience/Program-Inventory';ProviderName="Microsoft-Windows-Application-Experience";} )
		$private.processLog("Software Installation", @{Id=2;Level=4;Logname='Setup';ProviderName="Microsoft-Windows-Servicing";} )
		$private.processLog("Software Installation", @{Id=19;Level=4;Logname='System';ProviderName="Microsoft-Windows-WindowsUpdateClient";} )
	}
	
	
	method -private parseClearingEventLogs{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Clearing Eventlog Events#")
		$private.processLog("Clearing Eventlogs", @{Id=104;Level=4;Logname='System';ProviderName="Microsoft-Windows-Eventlog";} )
		$private.processLog("Clearing Eventlogs", @{Id=1102;Level=4;Logname='Security';ProviderName="Microsoft-Windows-Eventlog";} )
	}
	
	method -private parseApplicationCrashes{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Application Crashes#")
		$private.processLog("Application Crashes", @{Id=1000;Level=2;Logname='Application';ProviderName="Application Error";} )
		$private.processLog("Application Crashes", @{Id=1002;Level=2;Logname='Application';ProviderName="Application Hang";} )
		$private.processLog("Application Crashes", @{Id=1001;Level=2;Logname='System';ProviderName="Microsoft-Windows-WERSystemErrorReporting";} )
		$private.processLog("Application Crashes", @{Id=1001;Level=4;Logname='Application';ProviderName="Windows Error Reporting";} )
		$private.processLog("Application Crashes", @{Id=@(1,2);Level=@(2,4);Logname='Application';ProviderName="EMET";} )
	}
	
	method -private parseSystemServiceFailure{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#System or Service Failures#")
		$private.processLog("System or Service Failures", @{Id=@(7022,7023,7024,7026,7031,7032,7034);Level=2;Logname='System';ProviderName="Service Control Manager";} )
	}
	
	method -private parseWindowsUpdateErors{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Windows Update Errors#")
		$private.processLog("Windows Update Errors", @{Id=@(20,24,25,31,34,35);Level=2;Logname='Microsoft-Windows-WindowsUpdateClient/Operational';ProviderName="Microsoft-Windows-WindowsUpdateClient";} )
		$private.processLog("Windows Update Errors", @{Id=1009;Level=4;Logname='Setup';ProviderName="Microsoft-Windows-Servicing";} )
	}
	
	method -private parseFirewallEvents{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Windows Firewall#")
		$private.processLog("Windows Firewall Events", @{Id=@(2004,2005,2006,2033);Level=4;Logname='Microsoft-Windows-Windows Firewall With Advanced Security/Firewall';ProviderName="Microsoft-Windows-Windows Firewall With Advanced Security";} )
		$private.processLog("Windows Firewall Events", @{Id=2009;Level=2;Logname='Microsoft-Windows-Windows Firewall With Advanced Security/Firewall';ProviderName="Microsoft-Windows-Windows Firewall With Advanced Security";} )
	}
	
	method -private parsePowerEvents{
		$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #green#$($private.archiveLocation)# for #yellow#Power Events#")
		$private.processLog("Windows Power Events", @{Id=@(1074,6008);Logname='System';} )
	}
	
	method Execute{
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
						
		$private.export.addWorkSheet('EventLogs')
						
		$parseMethods = $private | gm -MemberType ScriptMethod | ? { $_.name -like 'parse*' } | Sort
		$currentLog=0
		
		$col = 1
		$private.sheetRow = 1
		$private.colHeaders | %{ 
			$private.export.updateCell(1,$col,$_)
			$col = $col + 1
		}
		
		$parseMethods | % {
			$currentLog++
			$i = (100*($currentLog / $($parseMethods.count) ))
			
			$private.mainProgressBar.Activity("$currentLog / $($parseMethods.count) : Processing Event Type $($_.name)").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
		
			invoke-expression "`$private.$($_.Name)()"
		}
		
		$private.export.autoFilterWorksheet()
		$private.export.autofitAllColumns()
		$private.export.formatAllFirstRows('Header')
		
		$private.mainProgressBar.Completed($true).Render() 
		
		$ts = (get-date -format "yyyyMMddHHmmss")
		$private.export.saveAs([System.IO.Path]::GetFullPath("$($pwd.ProviderPath)\results\$($ParseEventLogClass.PsScriptName)_$ts.xml"))
		
		$uiClass.errorLog()
	}
	
	constructor{
		param($computer, $archiveLocation,$start,$stop)
		
		$private.computer = $computer
		$private.start = $start
		$private.stop = $stop
		$private.archiveLocation = $archiveLocation
			
		
		while( ( $utilities.isBlank($private.computer) -eq $true -and $utilities.isBlank($private.archiveLocation) -eq $true )  -or $utilities.isBlank($private.start) -eq $true -or $utilities.isBlank($private.stop) -eq $true ){
			$private.gui = $null
			$private.gui = $guiClass.New("parseEventlogs.xml")
			$private.gui.generateForm();
			
			$private.gui.Controls.btnOpenFolderBrowser.add_Click({ $private.gui.Controls.txtArchiveLocation.Text =  $private.gui.actInvokeFolderBrowser() })
			$private.gui.Controls.txtComputer.add_TextChanged({ $private.gui.Controls.txtArchiveLocation.Text =  "" })
			$private.gui.Controls.txtArchiveLocation.add_TextChanged({ $private.gui.Controls.txtComputer.Text =  "" })
			
			$private.gui.Controls.dtpStart.Value = [datetime]::Now.AddMonths(-1);

			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.computer = $private.gui.Controls.txtComputer.Text
			$private.archiveLocation = $private.gui.Controls.txtArchiveLocation.Text
			$private.start = $private.gui.Controls.dtpStart.Value.ToString("MM-dd-yyyy")
			$private.stop = $private.gui.Controls.dtpStop.Value.ToString("MM-dd-yyyy")
		}
	}
}

$ParseEventLogClass.New($computer, $archiveLocation,$start,$stop).Execute() | out-null