[reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
[reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null
[reflection.assembly]::loadwithpartialname("System.Drawing.Graphics") | Out-Null
[reflection.assembly]::loadwithpartialname("Microsoft.VisualBasic") | Out-Null
$forms = "System.Windows.Forms"
$size = "System.Drawing.Size"

$progressBarClass = new-PSClass ProgressBar{
	note -private parentId
	note -private id
	note -private activity
	note -private status
	note -private currentOperation
	note -private PercentComplete
	note -private completed

	note -private mapping
	
	method Get{
		param($key)
		return $private.$key
	}
	
	method Render{
		
		$pbar = @{}
		foreach($prop in ($private | get-member -membertype noteproperty )) {
			if(!$utilities.isBlank($($private.$($prop.name))) -and $prop.name -notlike "*__*"){
				$pbar.Add("$($prop.name)","$($private.$($prop.name))")
			}
		}

		if($private.completed){
			try{
				write-progress -id $private.id -Status $private.status -Completed True
			}catch{
				write-host "Could not close progress bar $($private.id)"
			}
		}else{
			try{
				write-progress @pbar	
			}catch{
				$uiClass.log( ( $error | out-string ) , $true)
				$error.clear()
				return
			}
		}
		
		$msg = ""
		foreach($field in $pbar.keys){
			if($field -notlike "*id*"){
				$msg += "$field`: $($pbar.$field), "
			}
		}
		
		return $this
	}
	
	method Id{
		param($v)
		$private.id =  $v
		return $this
	}
	
	method Completed{
		param($v)
		$private.completed =  [bool] $v
		return $this
	}
	
	method Percent{
		param($v)
		$private.percentComplete =  $v
		return $this
	}
	
	method ParentId{
		param($v)
		$private.parentId =  $v
		return $this
	}
	
	method CurrentOp{
		param($v)
		$private.currentOperation =  $v
		return $this
	}
	
	method Status{
		param($v)
		$private.status =  $v
		return $this
	}
	
	method Activity{
		param($v)
		$private.activity =  $v
		return $this
	}
	
	
	constructor{
		param($params)
		
		$private.id = [int32]((([datetime] (Get-Date) - [datetime] "1/1/1970").TotalMilliseconds) % 1000000000)
		
		if($params.count -gt 0){
			Foreach ($key in $params.GetEnumerator() ){
				$private.$($Key.name) = $params.$($key.name)
			}
		}
	}
}

$uiClass = new-PSClass UI{
	note -static STAT_OK 	"[    #green#Ok# ]"
	note -static STAT_ERROR "[ #red#Error# ]"
	note -static STAT_WARN "[  #magenta#Warn# ]"
	note -static STAT_WAIT 	"[  #yellow#Wait# ]"
	note -static STAT_TEST 	"[  #yellow#Test# ]"
	note -static STAT  		"[       ]"
	
	method -static space{
		param( [int] $n )
		
		$space = ""
		1..$n | %{
			$space += " "
		}
		return $space
	}
	
	method -static getShortString{
		param(
			[string] $s, 
			[int] $length
		)

		if($s.length -le $length){
			return $s
		}else{
			$startPart = $s.Substring(0, $length - 8) 
			$endPart = $s.Substring($s.length - 5) 
			return "$startPart...$endPart"
		}
	}

	method -static log{
		param(
			$msg
		)
		$callingScript = $MyInvocation.BoundParameters.Class.ClassName
		$d = (get-date -format "yyyyMMdd")
		$ts = (get-date -format "yyyy-MM-dd HH:mm:ss")
		add-content "$pwd\logs\$($callingScript)_$d.log" "[$($ts)] $($msg)"
	}
	
	method -static errorLog{
		$currentErrors = @()
		$error | %{
			$currentErrors += $_
		}
		
		 foreach($e in $currentErrors){
			$callingScript = $MyInvocation.BoundParameters.Class.ClassName
			$d = (get-date -format "yyyyMMdd")
			$ts = (get-date -format "yyyy-MM-dd HH:mm:ss")
			add-content "$pwd\logs\$($callingScript)_error_$d.log" "[$($ts)]"
			foreach($name in ( $e | gm -MemberType Property | Select Name ) ){
				$msg = "$($name.Name):`t $($e.$($name.Name))"
				add-content "$pwd\logs\$($callingScript)_error_$d.log" $msg
			}
		 }
	}
	
	
	method -static writeSameLine{
		param($msg)
		if($_.fullname.length -gt 115){
			Write-Host "`r$($msg.substring(1,115).PadRight(119,' ' ))" -nonewline
		}else{
			Write-Host "`r$($msg.PadRight(119,' ' ))" -nonewline
		}
	}
	
	method -static clearLine{
		write-host "`r                                                                                                                      `r" -noNewLine
	}
	
	method -static writeColor{
		param ($message = "", $noNewLine = $false)
		if ( $message ){
			write-host -noNewLine "$(get-date -format 'HH:mm:ss') "
			$logMsg = ""
			$colors = @("black","blue","cyan","darkblue","darkcyan","darkgray","darkgreen","darkmagenta","darkred","darkyellow","gray","green","magenta","red","white","yellow");
	 
			$defaultFGColor = $host.UI.RawUI.ForegroundColor
	 
			$CurrentColor = $defaultFGColor
	 
			$message = $message.split("#")
	 
			foreach( $string in $message ){
				if ( $colors -contains $string.tolower() -and $CurrentColor -eq $defaultFGColor ){
					$CurrentColor = $string         
				}else{
					$logMsg = $logMsg + $string
									
					write-host -nonewline -f $CurrentColor $string
					$CurrentColor = $defaultFGColor
				}
			}
		}
		$uiClass.log($logMsg) | out-null
		if($noNewLine -ne $true){
			write-host ""
		}
	}
}

$guiClass = new-PSCLass GUI{
	note -private form
	note -private controls @{}
	note -private vars  @{}
	note -private template ""
	
	property Controls -get { $private.controls }
	property Vars -get { $private.vars }
	property Form -get { $private.form }
	
	method actInvokeFileBrowser{
		param($filter)

		$owner = New-Object Win32Window -ArgumentList ([System.Diagnostics.Process]::GetCurrentProcess().MainWindowHandle)

		$dialog = New-Object "$forms.OpenFileDialog"
		if($utilities.isBlank($filter) -eq $false){
			$strFilter = ""
			$filter.keys | % {
				 $strFilter += "$($_)|$($filter.$_)|"
			}
			$strFilter += "All files (*.*)|*.*"
			$dialog.Filter = $strFilter
		}
		
		$dialog.ShowHelp = $true
		$Show = $dialog.ShowDialog($owner)
	
		If ($Show -eq 'OK') {
			return $dialog.FileName
		}
	}
	
	method actInvokeFolderBrowser{
		param($rootPath = "")
		if( $utilities.isBlank($rootPath) -eq $true){
			$rootPath = "0"
		}
		$folder = ( new-object -com Shell.Application ).BrowseForFolder(0, "Select Location of Scans:", 0x0001C2D1, $rootPath)
		if ($folder.Self.Path -ne "") {
			return $folder.self.path
		}
	}
	
	method -static renderSubForm{
		param($tplName)
		[xml]$xml = Get-Content $tplName
		
		$tabIndex = 0
		$controls = @{}
		$xml.form.controls.control | % {
			$tabIndex++
			$controls.add($_.id, ( New-Object "$($forms).$($_.type)" ) )
			
			foreach($var in @('text','name','multiLine','View','maximum','minimum','BackColor','foreColor','dock','checked','scrollbars','sorted','checkBoxes','details','wordwrap','gridLines','borderStyle','anchor')){
				if($_.$var){ $controls.$($_.name).$var = $_.$var }
			}
			
			if($_.type -eq 'textBox' -or $_.type -eq 'label'){
			
				if($_.fontFamily){$fontFamily = $_.fontFamily}else{$fontFamily='Arial'}
				if($_.fontSize){$fontSize = $_.fontSize}else{$fontSize=8}
				if($_.fontStyle){$fontStyle = $_.fontStyle}else{$fontStyle="Regular"}
				
				$controls.$($_.name).Font = new-object System.drawing.Font([system.drawing.fontFamily]$fontFamily, [float]$fontSize, [system.drawing.fontStyle]$fontStyle);
				
				if($_.textAlignment){
					$controls.$($_.name).textAlign = $_.textAlignment
				}
				
				if($_.wordwrap){
					if($_.wordWrap -eq 'true'){
						$controls.$($_.name).wordWrap = $true
					}else{
						$controls.$($_.name).wordWrap = $false
					}
				}
			}
			
			if($_.type -eq 'picturebox' -and $_.imagePath){
				$i = [system.drawing.image]::FromFile( "$pwd\images\$($_.imagePath)" )
				$controls.$($_.name).image = $i
			}
			
			if($_.type -eq 'listView' -and $_.column){
				foreach($col in $_.column){
					$controls.$($_.id).Columns.Add($col) | out-null
				}
			}
			
			if($_.type -eq 'dataGridView' -and $_.column){
				$c = 0
				foreach($col in $_.column){
					switch($col.type){
						"checkBox" { $cell = new-object System.Windows.Forms.DataGridViewCheckBoxColumn;}
						"image" { $cell = new-object System.Windows.Forms.DataGridViewImageColumn;}
						default {$cell = new-object System.Windows.Forms.DataGridViewTextBoxColumn}
					}
					$cell.Name = $col.'#text'
					$controls.$($_.id).Columns.add($cell) | out-null
					$c++
				}
			}
			
			
			if($_.type -eq 'tabControl' -and $_.tab){
				foreach($tab in $_.tab){
					$controls.$($_.id).TabPages.Add($tab) | out-null
				}
			}
			
			if($_.type -eq 'menuStrip' -and $_.menuCat.count -gt 0){
				$menuName = $_.name
				foreach($menu in $_.menuCat){
				
					$menuHeader = new-object System.Windows.Forms.ToolStripMenuItem
					$menuHeader.text = "$($menu.text)"
					$menuHeader.name = "$($menu.name)"
					
					foreach($item in $menu.item){
						$menuItem = new-object System.Windows.Forms.ToolStripMenuItem
						$menuItem.name = $item.name
						$menuItem.text = $item.'#text'
						$menuHeader.DropDownItems.Add($menuItem) | out-null
					}
					
					$controls.$menuName.Items.Add($menuHeader) | out-null
				}
			}
			
			if($_.type -eq 'toolStrip' -and $_.item){
				$controls.$($_.name).autoSize = $false
				foreach($tool in $_.item){
					switch($tool.type){
						"label" {$toolItem = new-object System.Windows.Forms.ToolStripStatusLabel}
						"textBox" {$toolItem = new-object System.Windows.Forms.ToolStripTextBox}
						"progressBar" {$toolItem = new-object System.Windows.Forms.ToolStripProgressBar}
						"dropDownButton" {$toolItem = new-object System.Windows.Forms.ToolStripDropDownButton}
						"splitButton" {$toolItem = new-object System.Windows.Forms.ToolStripSplitButton}
						"seperator" {$toolItem = new-object System.Windows.Forms.ToolStripSeparator}
						"Button" {$toolItem = new-object System.Windows.Forms.ToolStripButton}
						default {$toolItem = new-object System.Windows.Forms.ToolStripMenuItem}
					}
					$toolItem.text = "$($tool.text)"
					$toolItem.name = "$($tool.name)"
					
					if($tool.imagePath){
						$toolItem.image = [system.drawing.image]::FromFile( "$pwd\images\$($tool.imagePath)" )
					}
					if($tool.width){
						$toolItem.width = $tool.width
					}
					if($tool.toolTipText){
						$toolItem.toolTipText = $($tool.toolTipText)
					}
					$controls.$($_.name).Items.Add($toolItem) | out-null
				}
			}
			
			if($_.type -eq 'statusStrip' -and $_.item){
				foreach($status in $_.item){
					switch($status.type){
						"label" {$statusItem = new-object System.Windows.Forms.ToolStripStatusLabel}
						"progressBar" {$statusItem = new-object System.Windows.Forms.ToolStripProgressBar}
						"dropDownButton" {$statusItem = new-object System.Windows.Forms.ToolStripDropDownButton}
						"splitButton" {$statusItem = new-object System.Windows.Forms.ToolStripSplitButton}
						"seperator" {$statusItem = new-object System.Windows.Forms.ToolStripSeparator}
						default {$statusItem = new-object System.Windows.Forms.ToolStripMenuItem}
					}
					$statusItem.text = "$($status.text)"
					$statusItem.name = "$($status.name)"
					if($status.imagePath){
						$statusItem.image = [system.drawing.image]::FromFile( "$pwd\images\$($status.imagePath)" )
					}
					if($status.toolTipText){
						$statusItem.toolTipText = $($status.toolTipText)
					}
					
					$controls.$($_.name).Items.Add($statusItem) | out-null
				}
			}
			
			if($_.type -eq 'comboBox' -and $_.item.count -gt 0){
				foreach($col in $_.item){
					
					$controls.$($_.id).Items.Add( 
						
						#this is a funk way that powershell handles unary operations like ( test ? true results : false results)
						@($col.'#text',$col)[($col.'#text' -eq $null)] 
						
					) | out-null
				}
				
				$selText = ""
				foreach($col in $_.item){
					if($col.selected -eq 'selected'){
						$selText = "$($col.'#text')"
					}
				}
				
				if($utilities.isBlank($selText) -eq $false){
					$controls.$($_.id).SelectedIndex = $Controls.$($_.id).FindStringExact($selText)
				}
			}
			
			if($_.type -eq 'datetimepicker' -and $_.showTime -eq 'true'){
				$controls.$($_.name).format = 'Time'
				$controls.$($_.name).showUpDown = 'true'
			}
			
			if($_.locationX -and $_.locationY){ $controls.$($_.name).Location = New-Object $size($_.locationX,$_.locationY) }
			if($_.sizeX -and $_.sizeY){ $controls.$($_.name).Size = New-Object $size($_.sizeX,$_.sizeY) }
			
		
			$controls.$($_.name).tabIndex = $tabIndex
		}
		
		return $controls
		
	}
	
	method generateForm{
		#this is updating the internal form object
		#this is done this way since the render process is a class method, not an instance method.
		#the internal form object doesn't exist in the static class
		[xml]$xml = get-content "$pwd\templates\$($private.template)"
		foreach($var in @('name','text','FormBorderStyle','BackColor')){
			if($xml.form.$var){ $private.form.$var = $xml.form.$var  }
		}
		
		if($xml.form.clientSizeX -and $xml.form.clientSizeY){
			$private.form.ClientSize = New-Object $size($xml.form.clientSizeX,$xml.form.clientSizeY)
		}
		
		if($xml.form.minSizeX -and $xml.form.minSizeY){
			$private.form.MinimumSize = New-Object $size($xml.form.minSizeX,$xml.form.minSizeY)
		}
		
		
		#this builds everything on the internal controls and forms objects.
		#the rendering from xml is done in a separate method that returns a hash array
		#this is done so that other classes can call the single set of rendering methods incase they dont need to update the gui form object (tabControls)
		$guiClass.renderSubForm("$pwd\templates\$($private.template)").getEnumerator() | % {
			if($utilities.isBlank($_.name) -ne $true){
				$private.controls.add($_.name, $_.value )
				$private.form.Controls.Add($private.controls.$($_.name))
				
				#this is in here to bring the tool bars down below any menu strips
				if($_.value.name -like "*tool*"){
					$_.value.bringToFront()
				}
			}
		}

	}
	
	method Input{
		param($prompt = "", $title = "", $default = "")
		return $([Microsoft.VisualBasic.Interaction]::InputBox("$($prompt)", "$($title)", "$($default)"))
	}
	
	method Confirm{
		param($prompt)
		if( (New-Object -ComObject Wscript.Shell).Popup($prompt,0,"Done",0x1) -eq 1){
			return $true
		}else{
			return $false
		}
	}
	
	constructor{
		param(
			[string] $template = ""
		)
		
		if((test-path "$pwd\bin\win32Window.dll") -eq $false){
			Add-Type -Language CSharpVersion3 -TypeDefinition ([System.IO.File]::ReadAllText("$pwd\types\win32Window.cs")) -ReferencedAssemblies "System.Windows.Forms.dll" -ErrorAction Stop -OutputAssembly "$pwd\bin\win32Window.dll" -outputType Library
		}
		
		if (!("Win32Window" -as [type])) {
			Add-Type -path "$pwd\bin\win32Window.dll"
		}
		
		
		$private.form = New-Object "$forms.form"
		$private.controls = @{}
		$private.vars = @{}
		
		$private.template = $template
	}
}