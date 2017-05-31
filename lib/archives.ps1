$archiveClass = New-PSClass archive{
	note -static singleton 
	
	note -private archive	
	note -private job
	
	property job -get {return $private.job}
	
	constructor{
		param()
		
	}
	
	method -static get{
		if($utilities.isBlank($archiveClass.singleton) -eq $true){
			$archiveClass.singleton = $archiveClass.new()
		}
		
		return ,($archiveClass.singleton)
	}
	
	method extractIso{
		param( [string]$selectedISO = '', [string]$outputPath = '')
		[Array]$arguments = "x", "'$($selectedISO)'", "-o$($outputPath)\"
		if( (test-path "$($outputPath)") -eq $false){
			$isoJobSB = {
				param($cwd,$selectedIso, $outputPath)
				invoke-expression "$($cwd)\bin\7zip\7z.exe x '$($selectedISO)' '-o$($outputPath)'"
			}
			
			$private.job = start-job -scriptBlock $isoJobSB -ArgumentList @($pwd,$selectedISO,$outputPath)
		}else{
			return $false
		}
	}
	
} 



