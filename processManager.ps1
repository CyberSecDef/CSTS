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
param (	)   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }


$processManager = new-PSClass processManager{
	note -static PsScriptName "processManager"
	note -static Description ( ($(((get-help .\processManager.ps1).Description)) | select Text).Text)
	note -static minWidths @(125,125,50,50,50,75,75,75,100,100,100)
	
	note -private mainProgressBar
	note -private gui
	
	note -private job
	note -private sortColumn 0
	note -private sortDir $false
	note -private firstRun $true
	
	note cpuLoad
	note OSMem
	note PhysMem
	note ProcessCount
	note bandwidthUtilization
	note diskUtilization
	
	constructor{
		param()
		$private.gui = $null
		
		$private.gui = $guiClass.New("processManager.xml")
		$private.gui.generateForm() | out-null;
		
		
		$private.gui.Controls.lstActiveProcess.add_click({$private.itemClicked()})| out-null
		$private.gui.Controls.lstActiveProcess.AutoGenerateColumns = $false
		$private.gui.Controls.lstActiveProcess.selectionMode = 'FullRowSelect'
		$private.gui.Controls.lstActiveProcess.AllowUserToAddRows  = $false
		$private.gui.Controls.lstActiveProcess.multiselect = $false
		$private.gui.Controls.lstActiveProcess.AutoSizeColumnsMode = 'AllCells'
		$private.gui.Controls.lstActiveProcess.add_MouseClick( {$private.lstActiveProcess_OnMouseClick()}  ) | out-null
		
		$private.gui.Controls.lstDependencies.add_ColumnClick( {$private.SortListView()}  ) | out-null
		$private.gui.Controls.toolMain.autoSize = $false
		
		$context = new-object "System.windows.forms.ContextMenu"
		$menuItemArray = @(
			@{"weight" = 1; "Name" = "Set Priority"; "Value" = @(
					@{"weight" = 1;"Name" = "Realtime (24)"; "Value" = $null;},
					@{"weight" = 2;"Name" = "High (13)"; "Value" = $null;},
					@{"weight" = 3;"Name" = "Above Normal (10)"; "Value" = $null;},
					@{"weight" = 4;"Name" = "Normal (8)"; "Value" = $null;},
					@{"weight" = 4;"Name" = "Below Normal (6)"; "Value" = $null;},
					@{"weight" = 4;"Name" = "Idle (4)"; "Value" = $null;}
				)
			},
			@{"weight" = 2; "Name" = "Kill Process(es)"; "Value" = $null},
			@{"weight" = 3; "Name" = "Edit Item"; "Value" = $null},
			@{"weight" = 4; "Name" = "Delete Item"; "Value" = $null}
		)
		
		foreach($menuArrayItem in ($menuItemArray | sort { $_.Weight} ) ){
			$menuItem = new-object "System.windows.forms.MenuItem"
			$menuitem.text = $menuArrayItem.Name
			
			if($menuArrayItem.Value -eq $null){
				$menuitem.add_click( { $private.processListContextMenuClick("$($this.text)") }) | out-null
			}else{
				foreach($subMenuArrayItem in ($menuArrayItem.Value | sort { $_.weight } ) ){
					if($subMenuArrayItem.Value -eq $null){
						$subMenuItem = new-object "System.windows.forms.MenuItem"
						$subMenuItem.text = $subMenuArrayItem.Name
						$subMenuItem.add_click( { $private.processListContextMenuClick("$($this.text)") }) | out-null
					}
					$menuItem.menuItems.add($subMenuItem) | out-null
				}
			}
			$context.menuItems.Add($menuItem) | out-null
		}
		$private.gui.Controls.lstActiveProcess.ContextMenu = $context;
		
		
		$private.gui.Form.TopMost= $true
		$private.gui.Form.Visible = $true
	}
	
	method -private SortListView{
		
		$Numeric = $true # determine how to sort
		if($private.sortColumn -eq $_.Column){
			$private.sortDir = -not $private.sortDir
		}else{
			$private.sortDir = $true
		}
		
		$private.sortColumn = $_.Column
		
		$ListItems = @(@(@())) # three-dimensional array; column 1 indexes the other columns, column 2 is the value to be sorted on, and column 3 is the System.Windows.Forms.ListViewItem object
		foreach($ListItem in $private.gui.Controls.lstDependencies.Items){
			if($Numeric -ne $false){
				try{
					if($ListItem.SubItems[[int]$_.Column].Text | isNumeric){
						$Test = [Double]$ListItem.SubItems[[int]$_.Column].Text
					}else{
						$Numeric = $false # a non-numeric item was found, so sort will occur as a string
					}
				}catch{
					$Numeric = $false 
				}
			}
			$ListItems += ,@($ListItem.SubItems[[int]$_.Column].Text,$ListItem)
		}

		$EvalExpression = {
			if($Numeric){ 
				return [Double]$_[0] 
			}else{ 
				return [String]$_[0] 
			}
		}
 
		$ListItems = $ListItems | Sort-Object -Property @{Expression=$EvalExpression; Ascending=$($private.sortDir)}
		
		$private.gui.Controls.lstDependencies.BeginUpdate()
		$private.gui.Controls.lstDependencies.Items.Clear()
		foreach($ListItem in $ListItems){
			$private.gui.Controls.lstDependencies.Items.Add($ListItem[1])
		}
		#renumber
		$i=0
		$private.gui.Controls.lstDependencies.Items | % {
			$i++
			$_.subitems[0].Text = $i
		}
		$private.gui.Controls.lstDependencies.EndUpdate()
	}
	
	method -private lstActiveProcess_OnMouseClick{
#right click is show context
		if($_.button -eq 'Right'){
			$private.gui.Controls.lstActiveProcess.ContextMenu.Show( $private.gui.Controls.lstActiveProcess, (new-object "system.drawing.Point"($_.X, $_.Y) ) )
		}else{
			$selRow = $private.gui.Controls.lstActiveProcess.SelectedRows[0].Index
			$selPid = $private.gui.Controls.lstActiveProcess.Rows[$selRow].Cells[4].Value
			
			$private.gui.Controls.lstDependencies.items.clear()
			
			$i = 0
			get-process -id $selPid | select -expand modules | sort ModuleName | select modulename, description, company, filename, size, ProductVersion | % {
			
				$i++
				$item =  New-Object "$forms.ListviewItem"( $i )
				$item.tag = $i
				
				$item.SubItems.Add( "$($_.modulename)".Trim() ) | out-null
				$item.SubItems.Add( "$($_.description)".Trim() ) | out-null
				$item.SubItems.Add( "$($_.company)".Trim() ) | out-null
				$item.SubItems.Add( "$($_.filename)".Trim() ) | out-null
				$item.SubItems.Add( "$($_.size)".Trim() ) | out-null
				$item.SubItems.Add( "$($_.ProductVersion)".Trim() ) | out-null

				$private.gui.Controls.lstDependencies.Items.Add($item) | out-null
			}
			
			$private.gui.Controls.lstDependencies.FullRowSelect  = $true
			$private.gui.Controls.lstDependencies.AutoResizeColumns('ColumnContent') | out-null
		
		}
	}
	
	method -private itemClicked{
		
	}
	
	method killProcesses{
	
		for($r = 0; $r -lt $private.gui.Controls.lstActiveProcess.Rows.count; $r++){
			if( ((($private.gui.Controls.lstActiveProcess.Rows[$r].cells['select']) -as [system.windows.forms.DataGridViewCheckBoxCell]).EditingCellFormattedValue -eq $true)){
				write-host "Killing $($private.gui.Controls.lstActiveProcess.Rows[$r].cells[2].value) ( $($private.gui.Controls.lstActiveProcess.Rows[$r].cells[4].value) )"
				invoke-expression "taskkill /f /im $($($private.gui.Controls.lstActiveProcess.Rows[$r].cells[4].value))"
			}
		}
		
		
	}
	
	method -private processListContextMenuClick{
		param($contextText)
		write-host "Clicked $contextText"
		switch($contextText){
			"Kill Process(es)" {$this.killProcesses()}
		}
	}
	
	
	method Execute{
		param($par)
		
		while($private.gui.Form.Visible){
			[System.Windows.Forms.Application]::DoEvents()  | out-null
			$this.getMetrics()

			$private.gui.Controls.stbMain.Items['stbLabelProcesses'].text = "Processes: $($this.ProcessCount)"
			$private.gui.Controls.stbMain.Items['stbLabelCpu'].text = "CPU Usage: $( $this.cpuLoad ) %"
			$private.gui.Controls.stbMain.Items['stbLabelCommit'].text = "Commit Charge: $( [math]::Round( ($this.OSMem.CommittedBytes / $this.OSMem.CommitLimit * 100) , 2 ) ) %"
			$private.gui.Controls.stbMain.Items['stbLabelMem'].text = "Physical RAM Usage: $( [math]::Round(  ( ( $this.PhysMem.TotalVisibleMemorySize - $this.PhysMem.FreePhysicalMemory) / $this.PhysMem.TotalVisibleMemorySize * 100 ) , 2 ) ) %"

			$private.gui.Controls.stbMain.Items['stbLabelNet'].text = "Network Utilization: $( [math]::Round( $this.bandwidthUtilization, 2 ) ) %"
			$private.gui.Controls.stbMain.Items['stbLabelDisk'].text = "Disk Utilization:   $( [math]::Round( 100 - $this.diskUtilization, 2 ) ) %"
			$this.updateCpuGraph()				
			$this.updateCommitGraph()
			$this.updateRamGraph()
			$this.updateNetGraph()
			$this.updateDiskGraph()
				
			$this.updateProcessNodes( ( $this.getProcesses() ) )
			
			[System.Windows.Forms.Application]::DoEvents()  | out-null
		}
		
		$uiClass.errorLog()
	}
	method getMetrics{
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		$this.cpuLoad = Get-WmiObject win32_processor |  Measure-Object -property LoadPercentage -Average | Select -expand Average
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		$this.OSMem = gwmi win32_perfFormattedData_PerfOs_Memory
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		$this.PhysMem = gwmi -Class win32_operatingsystem
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		
		$colInterfaces = Get-WmiObject -class Win32_PerfFormattedData_Tcpip_NetworkInterface |select BytesTotalPersec, CurrentBandwidth,PacketsPersec|where {$_.PacketsPersec -gt 0}
		$count = 0
		foreach ($interface in $colInterfaces) {
			$bitsPerSec = $interface.BytesTotalPersec * 8
			$totalBits = $interface.CurrentBandwidth

			# Exclude Nulls (any WMI failures)
			if ($totalBits -gt 0) {
				$count++
				$tempBand = (( $bitsPerSec / $totalBits) ) 
				
			}
		}
		if($count -gt 0){
			$this.bandwidthUtilization = $tempBand / $count
		}
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		
		#disk utilization
		$this.diskUtilization = Get-Counter "\PhysicalDisk(_total)\% Idle Time" |Select-Object -expandProperty CounterSamples | group InstanceName | select -expand Group | select -expand cookedValue
		
		[System.Windows.Forms.Application]::DoEvents()  | out-null
	}
	
	method updateNetGraph{
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		$img = $private.gui.Controls.pboxNet.Image
		$nb = new-object system.drawing.Bitmap(128,32);
		
		$whiteBrush = new-object Drawing.SolidBrush white
		$mypen = new-object Drawing.Pen orange
		$myPen.color = 'orange'
		$myPen.width = 1
		
		$rect = new-object system.drawing.Rectangle(0, 0, 127, 31);
		
		$g = [system.drawing.Graphics]::FromImage($nb);
		$g.FillRectangle($whiteBrush, $rect);
		$g.DrawImage($img, -1, 0);
		$g.drawLine($myPen, 127, $( [int](32 - ( $this.bandwidthUtilization * 32 ) ) ), 127, 31)
		
		
		$private.gui.Controls.pboxNet.Image = $nb
		$private.gui.Controls.pboxNet.refresh()
		[System.Windows.Forms.Application]::DoEvents()  | out-null
	}
	
	method updateDiskGraph{
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		$img = $private.gui.Controls.pboxDisk.Image
		$nb = new-object system.drawing.Bitmap(128,32);
		
		$whiteBrush = new-object Drawing.SolidBrush white
		$mypen = new-object Drawing.Pen orange
		$myPen.color = 'orange'
		$myPen.width = 1
		
		$rect = new-object system.drawing.Rectangle(0, 0, 127, 31);
		
		$g = [system.drawing.Graphics]::FromImage($nb);
		$g.FillRectangle($whiteBrush, $rect);
		$g.DrawImage($img, -1, 0);
		$g.drawLine($myPen, 127, $( [int]( ( $this.diskUtilization * 32 ) ) ), 127, 31)
		
		
		$private.gui.Controls.pboxDisk.Image = $nb
		$private.gui.Controls.pboxDisk.refresh()
		[System.Windows.Forms.Application]::DoEvents()  | out-null
	}
	
	method updateRamGraph{
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		$img = $private.gui.Controls.pboxRam.Image
		$nb = new-object system.drawing.Bitmap(128,32);
		
		$whiteBrush = new-object Drawing.SolidBrush white
		$mypen = new-object Drawing.Pen red
		$myPen.color = 'red'
		$myPen.width = 1
		
		$rect = new-object system.drawing.Rectangle(0, 0, 127, 31);
		
		$g = [system.drawing.Graphics]::FromImage($nb);
		$g.FillRectangle($whiteBrush, $rect);
		$g.DrawImage($img, -1, 0);
		$g.drawLine($myPen, 127, $( [int](32 - ( ( $this.PhysMem.TotalVisibleMemorySize - $this.PhysMem.FreePhysicalMemory) / $this.PhysMem.TotalVisibleMemorySize ) * 32 ) ), 127, 31)
		
		
		$private.gui.Controls.pboxRam.Image = $nb
		$private.gui.Controls.pboxRam.refresh()
		[System.Windows.Forms.Application]::DoEvents()  | out-null
	}
	
	method updateCommitGraph{
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		$img = $private.gui.Controls.pboxCommit.Image
		$nb = new-object system.drawing.Bitmap(128,32);
		
		$whiteBrush = new-object Drawing.SolidBrush white
		$mypen = new-object Drawing.Pen blue
		$myPen.color = 'blue'
		$myPen.width = 1
		
		$rect = new-object system.drawing.Rectangle(0, 0, 127, 31);
		
		$g = [system.drawing.Graphics]::FromImage($nb);
		$g.FillRectangle($whiteBrush, $rect);
		$g.DrawImage($img, -1, 0);
		$g.drawLine($myPen, 127, $( [int](32 - ( ( $this.OSMem.CommittedBytes / $this.OSMem.CommitLimit )  * 32 ) ) ) , 127, 31)
		
		
		$private.gui.Controls.pboxCommit.Image = $nb
		$private.gui.Controls.pboxCommit.refresh()
		[System.Windows.Forms.Application]::DoEvents()  | out-null
	}
	
	
	method updateCpuGraph{
		[System.Windows.Forms.Application]::DoEvents()  | out-null
		$img = $private.gui.Controls.pboxCpu.Image
		$nb = new-object system.drawing.Bitmap(128,32);
		
		$whiteBrush = new-object Drawing.SolidBrush white
		$mypen = new-object Drawing.Pen black
		$myPen.color = 'black'
		$myPen.width = 1
		
		$rect = new-object system.drawing.Rectangle(0, 0, 127, 31);
		
		$g = [system.drawing.Graphics]::FromImage($nb);
		$g.FillRectangle($whiteBrush, $rect);
		$g.DrawImage($img, -1, 0);
		$g.drawLine($myPen, 127, $( [int](32 - ($this.cpuLoad / 100 * 32 ) ) ) , 127, 31)
		
		
		$private.gui.Controls.pboxCpu.Image = $nb
		$private.gui.Controls.pboxCpu.refresh()
		[System.Windows.Forms.Application]::DoEvents()  | out-null
	}
	
	method resizeImage{
		param($image, $width, $height)
		$newImage = new-object 'system.drawing.bitmap'(16, 16);
		$graphicsHandle = [system.drawing.graphics]::FromImage($newImage)
		$graphicsHandle.InterpolationMode = 'HighQualityBicubic'
		$graphicsHandle.DrawImage($image, 0, 0, $width, $height);
		return $newImage
						
	}
	
	method updateProcessNodes{
		param($processes)
		
		if( $private.gui.Controls.lstActiveProcess.Columns.count -gt 0 -and $private.gui.Controls.lstActiveProcess.Visible -eq $true){
			try{
				$this.ProcessCount = $processes.count
				
				$newRow = $false
				#add and update existing items
				foreach($process in ($processes | ? { $_.parentProcessId -ne $pid} ) ){
					#col 3
					$row = $null
					$private.gui.Controls.lstActiveProcess.rows | % {
						if($_.cells[4].value -eq $($process.id)){
							$row = $_.index
						}
					}
					
					#see if the current process already exists
					if($utilities.isBlank($row) -eq $true){
						$newRow = $true
						write-host 'setting to true'
						$dataGridRow = new-object "system.windows.forms.DataGridViewRow"
						$dataGridRow.CreateCells($private.gui.Controls.lstActiveProcess) | out-null
						$dataGridRow.tag = "PID:$($process.id)"
						$dataGridRow.height = 20
						$row = $private.gui.Controls.lstActiveProcess.Rows.Add($dataGridRow);
					}
					
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[0].value = $false
					
					if($utilities.isBlank($process.path) -eq $false){
						if( (test-path $($process.path)) -eq $true){
							$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[1].Value = $this.resizeImage( ( [System.Drawing.Icon]::ExtractAssociatedIcon($process.Path)), 16, 16 )
						}else{
							$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[1].Value = $this.resizeImage( ( [system.drawing.image]::FromFile( "$pwd\images\file.gif" ) ), 16, 16 )
						}
					}else{
						$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[1].Value = $this.resizeImage( ( [system.drawing.image]::FromFile( "$pwd\images\file.gif" ) ), 16, 16 )
					}
					
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[2].Value = $process.name
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[3].Value = $process.owner
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[4].Value = [int]$($process.id)
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[5].Value = [int]$($process.parentProcessId)
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[6].Value = "$($process.PercentProcessorTime / 100) %"
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[7].Value = "$($process.PrivateMemorySize64 / 1KB) K"
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[8].Value = "$($process.WorkingSet64 / 1KB) K"
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[9].Value = [int]$($process.HandleCount)
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[10].Value = $process.description
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[11].Value = $process.company
					$private.gui.Controls.lstActiveProcess.Rows[$row].Cells[12].Value = $process.Path
					#only the check box should be editable
					@(1..11) | % { $private.gui.Controls.lstActiveProcess.Rows[$row].Cells[$_].readonly = $true }
					[System.Windows.Forms.Application]::DoEvents()  | out-null
				}

				if($newRow -eq $true){
					write-host "Going to sort on $( $private.gui.Controls.lstActiveProcess.SortedColumn )"
				}
				
				#remove old dead items
				if($private.gui.Controls.lstActiveProcess.rows.count -gt 0){
					$nodeListPIDs = @()
					$private.gui.Controls.lstActiveProcess.rows | % { $nodeListPIDs += $_.cells[4].value }
					$runningPIDS = ($processes | select -expand id)
					
					foreach($deadItem in ( compare-Object $nodeListPIDs $runningPIDS | ? { $_.SideIndicator -eq '<='} | select -expand InputObject ) ) {
						$deadRow = ( $private.gui.Controls.lstActiveProcess.rows | ? { $_.tag -eq "PID:$($deadItem)" } )
						$private.gui.Controls.lstActiveProcess.rows.removeAt( $deadRow.index)
					}
				}
				
				# if($newRow -eq $true){
					$private.gui.Controls.lstActiveProcess.Sort( ($private.gui.Controls.lstActiveProcess.SortedColumn), ($private.gui.Controls.lstActiveProcess.sortedOrder) ) 
					write-host "Sorting on $( $private.gui.Controls.lstActiveProcess.SortedColumn )"
				# }
			}catch{
				write-host $_.Exception.Message
			}
		}
	}
	
	method getProcesses{
		$private.job = start-job -scriptBlock {
			$processes = @{}
			$parents = @{}
			$cpu = @{}
			gwmi win32_process |% {
				$parents[$_.handle.ToString()] 		= $_.parentProcessId
				$processes[$_.handle.ToString()] 	= $_.getowner().user
			}
			
			gwmi Win32_PerfFormattedData_PerfProc_Process | %{
				$cpu[ $($_.IDProcess.ToString()) ] = $_.PercentProcessorTime
			}
			
			$results = get-process | select id, name, Path, HandleCount, startTime, cpu, PrivateMemorySize64, WorkingSet64, description, company, 
				@{l="parentProcessId";e={$parents[$_.id.tostring()]}}, 
				@{l="Owner";e={$processes[$_.id.tostring()]}},
				@{l="PercentProcessorTime";e={$cpu[$_.id.ToString()]}}
			
			($results | ?{ $_.parentProcessId -ne $pid } | convertTo-XML).outerXml
		}
		
		while($private.job.state -eq 'Running'){
			[System.Windows.Forms.Application]::DoEvents()  | out-null			
		}
		
		return ( $utilities.convertFromXML( ([xml](receive-job -job ($private.job)) ) ) )
		
	}
}

$processManager.New().Execute()  | out-null