<#
.SYNOPSIS
	This is a script that will scan computers and determine the status of an IAVM (KB HotFix)
.DESCRIPTION
	This is a script that will scan computers and determine the status of an IAVM (KB HotFix).  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters
.PARAMETER hostCsvPath
	The path the a CSV File containing hosts
.PARAMETER computers
	A comma separated list of hostnames
.PARAMETER OU
	An Organizational Unit in Active Directory to pull host names from
.PARAMETER IAVM
	The KB###### to be scanned for
.EXAMPLE   
	C:\PS>.\iavmStatus.ps1 -computers "ws184894-q03,ws179702-q20" -IAVM "KB982018,KB2979570"
	This example will attempt to scan the computers entered into the command line for the two hotfixes
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Dec 30, 2014
	Misc: 	ou -limit 5000 | where { "$_" -like '*Org - Q*' -and $_ -like '*OU=Computers*' }

#>
[CmdletBinding()]
param( $hostCsvPath = "",$computers = @(),$OU = "", $IAVM)

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$IavmStatusClass = new-PSClass IavmStatus{
	note -static PsScriptName "iavmStatus"
	note -static Description ( ($(((get-help .\iavmStatus.ps1).Description)) | select Text).Text)
	
	note -private HostObj
	
	note results @{}
	
	note mainProgressBar

	note -private gui
	note -private iavm
	
	method getComputerHotfixes{
		$currentComputer = 0

		$this.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "Please Wait..."; "Status" = "Please Wait..." ; "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render()
		
		ForEach($computer in ( $private.HostObj.Hosts.GetEnumerator() | sort Name) ) {
			
			$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($computer.Name.Trim())'"
			$compHost = "$($($computer.Name))".split(".")[0]
			try{
				$hotfixes = Get-HotFix -ComputerName $computer.Name
			}catch{
				$hotfixes = @{}
			}
			if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
				$uiClass.writeColor( "$($uiClass.STAT_OK) Connecting to #yellow#$compHost#...")
				foreach($v in $private.IAVM.split(",")){
					if($computer.Name.length -ge 1) {
						if($hotfixes.count -gt 0){
							$presence = ( $hotfixes | % { if ($_.HotFixId -eq $v){ $true } } )
							if( $presence -eq $true){
								$this.results.$v.installed += $computer.Name
								$uiClass.writeColor( "$($uiClass.STAT_OK) Processed #yellow#$compHost#... Hotfix #gray#$v# #green#Installed#" )
							}else{
								$this.results.$v.missing += $computer.Name
								$uiClass.writeColor( "$($uiClass.STAT_ERROR)  Processed #yellow#$compHost#... Hotfix #gray#$v# #yellow#Missing#")
							}
						}else{
							$this.results.$v.untested += $computer.Name
							$uiClass.writeColor( "$($uiClass.STAT_WARN) Could not retrieve hotfixes from #yellow#$compHost#" )
						}
					}
				}
			} else { 
				$this.results.$v.offline += $computer.Name
				$uiClass.writeColor( "$($uiClass.STAT_WARN) Skipping #yellow#$compHost#... #red#Not accessible#")
			}
			$currentComputer = $currentComputer + 1
			$i = (100*($currentComputer / $private.HostObj.Count))
					 
			$this.mainProgressBar.Activity("$currentComputer / $($private.HostObj.Count): Processing system $($computer.Name) ").Status(("{0:N2}% complete" -f $i)).Percent($i).Render()
			
		} 
		$this.mainProgressBar.Completed($true).Render()
		$uiClass.writeColor()
	} 

	method Export{
	
		$export = $ExportClass.New()
		
		$currentIndex = 1
		foreach($v in $this.results.keys){
			$export.addWorkSheet($v)
			
			$export.updateCell(1,1,"Installed")
			$export.updateCell(2,1,"Missing")
			$export.updateCell(3,1,"Untested")
			$export.updateCell(4,1,"Offline")
			
			$export.updateCell(1,2,"$($this.results.$v.Installed.count)")
			$export.updateCell(2,2,"$($this.results.$v.Missing.count)")
			$export.updateCell(3,2,"$($this.results.$v.Untested.count)")
			$export.updateCell(4,2,"$($this.results.$v.Offline.count)")
								
			$export.updateCell(6,1,"Installed")
			$export.updateCell(6,2,"Missing")
			$export.updateCell(6,3,"Untested")
			$export.updateCell(6,4,"Offline")
		
			$currentRow = 7
			$this.results.$v.Installed | % { $export.updateCell($currentRow,1,$_); $currentRow++ }
			
			$currentRow = 7
			$this.results.$v.Missing | % { $export.updateCell($currentRow,2,$_); $currentRow++ }
			
			$currentRow = 7
			$this.results.$v.Untested | % { $export.updateCell($currentRow,3,$_); $currentRow++ }
			
			$currentRow = 7
			$this.results.$v.Offline | % { $export.updateCell($currentRow,4,$_); $currentRow++ }
		
			$export.autofitAllColumns()
			$export.formatRow(6,'Header')

			$currentIndex++
		}
		
		$ts = (get-date -format "yyyyMMddHHmmss")
		$export.saveAs([System.IO.Path]::GetFullPath("$($pwd.ProviderPath)\results\$($IavmStatusClass.PsScriptName)_$ts.xml"))
	}
	
	method dump{
		$uiClass.writeColor("")
		foreach($v in $this.results.keys){
			$uiClass.writeColor( "-----------------------------------------------" )
			$uiClass.writeColor( "$v --> $($this.results.$v.installed.count) Installed, $($this.results.$v.missing.count) Missing, $($this.results.$v.offline.count) Offline")
			$uiClass.writeColor("#green#Installed On#")
			$this.results.$v.Installed | % { $uiClass.writeColor( $_ )}
			$uiClass.writeColor(" ")

			$uiClass.writeColor( "#red#Missing On#")
			$this.results.$v.Missing | % { $uiClass.writeColor( $_ ) }
			$uiClass.writeColor(" ")
			
			$uiClass.writeColor("#yellow#Offline On#")
			$this.results.$v.Offline | % { $uiClass.writeColor($_ ) }
			$uiClass.writeColor(" ")
			
			$uiClass.writeColor( "#magenta#Untested On#" )
			$this.results.$v.Untested | % { $uiClass.writeColor( $_ ) }
			$uiClass.writeColor(" ")
		}
		
	}

	method Execute{
		
		$private.IAVM.split(",") | % {
			$this.results.$_ = @{}
			$this.results.$_.Installed = @()
			$this.results.$_.Missing = @()
			$this.results.$_.Untested = @()
			$this.results.$_.Offline = @()
		}
		
		$this.getComputerHotfixes()
		$this.Export()
		$this.Dump()
		
		$uiClass.errorLog()
	}
	
	constructor{
		param()
		$private.HostObj = $HostsClass.New()
		
		$private.iavm = $IAVM
		
		while($private.iavm -eq $null -or $private.iavm -eq ""){
			$private.gui = $null
			$private.gui = $guiClass.New("iavmStatus.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.iavm = $private.gui.Controls.txtIavm.Text
		}
	}
}

$IavmStatusClass.New().Execute() | out-null