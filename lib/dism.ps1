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
$dismClass = new-PSClass dism{	
	note -static PsScriptName "dism library"
	note -static Description ( ($(((get-help .\template.ps1).Description)) | select Text).Text)
	
	note -private wimPath ""
	note -private job
	note -private argumentList ""
	
	property executing 		-get {return ((get-process | ? { $_.name -eq 'dism' }).count -ne $null) }
	property wimPath   		-get {return $private.wimPath } -set {  param($newWim) $private.wimPath = $newWim }
	property job       		-get {return $private.job}
	property argumentList 	-get {return $private.argumentList}
	
	note -static dismReports @{
		"Drivers" = @('Published Name', 'Original File Name', 'Inbox', 'Class Name', 'Provider Name', 'Date', 'Version' );
		"Updates" = @('Package Identity','State','Release Type','Install Time') 
		"Features" = @('Feature Name','State') 
	}
	
	# Type, Manufacturer, Name, Text, Tag
	note -static dismNodeLevels @{
		"Drivers" = @('Class Name', 'Provider Name','Original File Name','Original File Name','Published Name');
		"Updates" = @('Release Type','State','Package Identity','Package Identity','Package Identity');
	}
	
	constructor{
		param()
		[gc]::collect()
	}

	method getJobResults{
		if($private.job -is [System.Management.Automation.Job] -and ($private.job).state -ne 'Running' ){
			return (receive-job -job ($private.job))
		}else{
			return $false
		}
	}
	
	method getDrivers{
		if($this.wimPath){
			$private.argumentList = "dism.exe /get-drivers /Image:'$($this.wimPath)\'"
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
		}else{
			$private.argumentList = ""
			return $false
		}
		[gc]::collect()
	}
	
	method getUpdates{
		if($this.wimPath){
			$private.argumentList = "dism.exe /get-packages /Image:'$($this.wimPath)\'"
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
		}else{
			$private.argumentList = ""
			return $false
		}
		[gc]::collect()
	}
	
	method getFeatures{
		if($this.wimPath){
			$private.argumentList = "dism.exe /get-features /Image:'$($this.wimPath)\'"
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
		}else{
			$private.argumentList = ""
			return $false
		}
		[gc]::collect()
	}
	
	method parseResults{
		param($resultType)
		$content = $this.getJobResults()
		$key = ($dismClass.dismReports[$resultType] | select -first 1)
		$line = $($content | select-string -pattern "$key" | select -expand lineNumber -first 1)
		$length = $content.count
		
		$content = $content[$($line - 1)..$($length)]
		$content = $content[0..$($content.count - 3)]
		
		$container = @()
		for($i = 0; $i -lt $content.count - ($dismClass.dismReports[$resultType].count); $i=$i + ($dismClass.dismReports[$resultType].count+1) ) {
			$node = @{}
			$ki = 0
			foreach($k in ($dismClass.dismReports[$resultType])){
				$node.$k = ($content[$i + $ki] -split ':')[1].ToString().Trim()
				$ki++
			}
			$container += $node
		}
		[gc]::collect()
		return @{"results" = $container}
	}
	
	method applyUnattendFile{
		param([string]$unattendFile = "")
		if($utilities.isBlank($unattendFile) -eq $false){
			if($this.wimPath){
				$private.argumentList = "dism.exe /Image:'$($this.wimPath)\'  /apply-unattend:$($unattendFile)"
				$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
			}
		}
		[gc]::collect()
	}
	
	method setProdKey{
		param([string]$prodKey = "")
		if($utilities.isBlank($prodKey) -eq $false){
			if($this.wimPath){
				$private.argumentList = "dism.exe /Image:'$($this.wimPath)\'  /Set-ProductKey:$($prodKey)"
				$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
			}
		}
		[gc]::collect()
	}
	
	method addDrivers{
		param([string]$driverPath = "")
		if($this.wimPath){
			if( (test-path $driverPath) -eq $true){
				$private.argumentList = "dism.exe /Image:'$($this.wimPath)\'  /Add-Driver /Driver:'$($driverPath)' /recurse"
				$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
			}else{
				$private.argumentList = ""
				return $false
			}
		}
		[gc]::collect()
	}
	
	method removeDriver{
		param($selDriver)
		if($this.wimPath){
			$private.argumentList = "dism.exe /Image:'$($this.wimPath)\'  /Remove-Driver /Driver:'$($selDriver)'"
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
		}else{
			$private.argumentList = ""
			return $false
		}
		[gc]::collect()
	}
	
	method mountWim{
		param(
			[string]$wimFileName = "",
			[int]$wimIndex = 0,
			[string]$isoFileName = ""
		)
		
		$wimName = ([io.path]::GetFileNameWithoutExtension($wimFilename))
		if( ( test-path "$($pwd)\wim\offline\$($isoFileName)\$($wimName)\$($wimIndex)\") -eq $false){
			new-item -type directory "$($pwd)\wim\offline\$($isoFileName)\$($wimName)\$($wimIndex)\" -force
		}
		$private.wimPath = "$($pwd)\wim\offline\$($isoFileName)\$($wimName)\$($wimIndex)\"
		$private.argumentList = "dism.exe /mount-wim /wimFile:'$($wimFileName)' /index:$($wimIndex) /mountdir:'$($this.wimPath)\'"
		
		if( ( test-path "$($private.wimPath)\*") -eq $false){
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $($private.argumentList)
		}else{
			return $false
		}
		[gc]::collect()
	}
	
	method dismountWim{
		param( $commit )
		if($this.wimPath){
			$private.argumentList = "dism.exe /unmount-wim /mountdir:'$($this.wimPath)\' $(@('/discard','/commit')[$commit])"
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
		}else{
			$private.argumentList = ""
			return $false
		}
		[gc]::collect()
	}
	
	#must be called after dismounted.....this deletes the wim folder, which is needed because dism gets confused
	method cleanupWim{
		if($this.wimPath){
			remove-item $this.wimpath -recurse -force -errorAction	 SilentlyContinue
			$private.argumentList = "dism.exe /cleanup-wim"
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
		}else{
			$private.argumentList = ""
			return $false
		}
		[gc]::collect()
	}
	
	method listWimInfo{
		param( [string]$wimFileName = "" )

		if($utilities.isBlank($wimFileName) -eq $false){
			$private.argumentList = "dism.exe /get-wiminfo /wimFile:'$($wimFileName)'"
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $($private.argumentList)
		}else{
			$private.argumentList = ""
			return $false
		}
		[gc]::collect()
	}
		
	method updateFeature{
		param([string]$feature = "", [bool]$state = $false)
		if($this.wimPath){
			$private.argumentList = "dism.exe /Image:'$($this.wimpath)\' $(@('/Disable-Feature','/Enable-Feature')[$state]) /FeatureName:'$($feature)'"
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
		}else{
			$private.argumentList = ""
			return $false
		}
		[gc]::collect()
	}
	
	method addUpdates{
		param( [string]$updatePath = "")
		if($this.wimPath){
			if( (test-path $updatePath) -eq $true){
				$private.argumentList = "dism.exe /Image:'$($this.wimPath)\'  /Add-Package /PackagePath:'$($updatePath)' "
				$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
			}else{
				$private.argumentList = ""
				return $false
			}
		}
		[gc]::collect()
	}
	
	method removeUpdate{
		param( $selUpdate )
		
		if($this.wimPath){
			$private.argumentList = "dism.exe /Image:'$($this.wimPath)\' /Remove-Package /PackageName:'$($selUpdate)'"
			$private.job = start-job -scriptBlock { param($dismCmd) invoke-expression "$dismCmd" } -argumentList $private.argumentList
		}else{
			$private.argumentList = ""
			return $false
		}
		[gc]::collect()
	}
	
}