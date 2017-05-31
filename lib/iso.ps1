$isoClass = New-PSClass Iso{
	note -static MediaType @{CDR=2; CDRW=3; DVDRAM=5; DVDPLUSR=6; DVDPLUSRW=7; DVDPLUSR_DUALLAYER=8; DVDDASHR=9; DVDDASHRW=10; DVDDASHR_DUALLAYER=11; DISK=12; DVDPLUSRW_DUALLAYER=13; BDR=18; BDRE=19; MAX=19 } 
	
	note -private Path
	note -private Target
	note -private Media
	note -private Title
	note -private Force
		
	note -private Image
	
	method makeIso{
		
		if (!("ISOFile" -as [type])) {
			#this is done this way because powershell can't do unsafe and outputAssembly at the same time
			$winDir = $env:windir
			$framework = [System.Runtime.InteropServices.RuntimeEnvironment]::GetSystemVersion()
			invoke-expression "$($winDir)\Microsoft.NET\Framework\$($framework)\csc.exe /target:library /unsafe /out:$($pwd)\bin\isoFiles.dll $($pwd)\types\isoFiles.cs"  | out-null
			add-type -path "$(pwd)\bin\isoFiles.dll"
		}
		
		if ($isoClass.MediaType[$private.Media] -eq $null) { 
			write-debug "Unsupported Media Type: $($private.Media)"; 
			write-debug ("Choose one from: " + $isoClass.MediaType.Keys); 
			break 
		} 
		($private.Image = new-object -com IMAPI2FS.MsftFileSystemImage -Property @{VolumeName=$($private.Title)}).ChooseImageDefaultsForMediaType($isoClass.MediaType[$private.Media]) 
		if ((Test-Path $private.Path) -and (!$private.Force)) { "File Exists $private.Path"; break } 
		if (!($private.Target = New-Item -Path $private.Path -ItemType File -Force)) { "Cannot create file $($private.Path)"; break } 
	}
	
	method createDirectory{
		param($name, $parent)
		if($parent -eq $null){
			$private.Image.Root.item('\').AddDirectory($name)
		}else{
			$private.Image.Root.item($parent).AddDirectory($name)
		}
	}
	
	method addSource{
		param($Source, $path)
				
		if($path -eq $null){
			$folder = $private.Image.Root
		}else{
			$folder = $private.Image.Root.Item($path)
		}
		
		switch ($Source) {
			{ $_ -is [string] } {  $folder.AddTree((Get-Item $_).FullName, $true); continue } 
			{ $_ -is [IO.FileInfo] } { $folder.AddTree($_.FullName, $true); continue } 
			{ $_ -is [IO.DirectoryInfo] } {  $folder.AddTree($_.FullName, $true); continue } 
		}
	}
	
	method finalize{
		param($bootable)
        if($bootable -ne $null -and (test-path $bootable) -eq $true){
            ($Stream = New-Object -ComObject ADODB.Stream).Open() 
            $Stream.Type = 1  # adFileTypeBinary 
            $Stream.LoadFromFile((Get-Item $bootable).Fullname) 
            ($Boot = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($Stream) 
            $private.Image.BootImageOptions=$Boot
        }
		
		$Result = $private.Image.CreateResultImage() 
		[ISOFile]::Create($private.Target.FullName,$Result.ImageStream,$Result.BlockSize,$Result.TotalBlocks) 
	}
		
	constructor{
		Param ( 
			[string] $Path = "$($env:temp)\" + (Get-Date).ToString("yyyyMMdd-HHmmss.ffff") + ".iso",
			[string] $Media = "DISK", 
			[string] $Title = (Get-Date).ToString("yyyyMMdd-HHmmss.ffff"), 
			[switch] $Force 
		)
		
		$private.Path = $Path
		$private.Media = $Media
		$private.Title = $Title
		$private.Force = $Force
		
	}	
}