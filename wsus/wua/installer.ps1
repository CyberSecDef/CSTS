$optionsQ = @("ndp1.1sp1-kb867460","capicom","kb913433","rootsupd","rvkroots","kb923789","vcredist")
$optionsQN = @("\msxml","\ndp","FileFormatConverters","compatibilitypacksp","\OFV","940157","2553065")
$optionsQQN = @("KB2758694","KB954430")
$optionsQuietNoRestart = @("KB976932")

$skipFiles = @("clearcompressionflag","kb890830","cleanupwindowsdefendertasks","ndp4")

function execInstall([string]$filename, [string]$a){

	$ps = new-object System.Diagnostics.Process
	$ps.StartInfo.Filename = $filename
	$ps.StartInfo.Arguments = $a
	$ps.StartInfo.RedirectStandardOutput = $True
	$ps.StartInfo.UseShellExecute = $false
	$ps.start()
	$ps.WaitForExit()
	[string] $Out = $ps.StandardOutput.ReadToEnd();
	return $out
}

$updates = (gci "$pwd\updates" -recurse | ? { @(".msi",".msu",".cab",".exe") -contains $_.extension } )

$currentUpdate = 0
foreach($update in $updates){
	$currentUpdate++
	$p = ( "{0:N2}" -f (100*$currentUpdate/$($updates.count))  )
	Write-Progress -Activity "$($currentUpdate) / $($updates.count) : Installing $($update.name)" -PercentComplete $p -CurrentOperation "$($p)% complete" -Status "Please wait..."
	
	$install = $true
	foreach($skip in $skipfiles){
		if($update.name -like "*$($skip)*"){
			$install = $false
		}
	}

	if($install -eq $true){	
		write-host "Installing $($update.name)"
		switch($update.extension){
			".exe" {
				$options = ""
				foreach($f in $optionsQ){
					if($update.name -like "*$($f)*"){
						$options = "/Q"
					}
				}
				
				foreach($f in $optionsQQN){
					if($update.name -like "*$($f)*"){
						$options = "/qn /quiet /norestart"
					}
				}
				
				foreach($f in $optionsQuietNoRestart){
					if($update.name -like "*$($f)*"){
						$options = "/quiet /norestart"
					}
				}
								
				foreach($f in $optionsQN){
					if($f -like "\*"){
						if($update.name -like "$($f)*"){
							$options = "/q /norestart"
						}
					}else{
						if($update.name -like "*$($f)*"){
							$options = "/q /norestart"
						}
					}
				}
				
				if($update.name -like "ie*" -and $update.name -notLike "*kb*"){
					$options = "/quiet /norestart"
				}
				
				if($options -eq ""){
					$options = "/q /z"
				}
				
				execInstall $($update.fullname) $options | out-null
				
			}
			".msi" {
				$msiExec = [System.Environment]::ExpandEnvironmentVariables("%SystemRoot%\System32\msiexec.exe")
				execInstall $msiExec " /i $($update.fullname) /qn /norestart" | out-null
			}
			".msu" {
				$wusa = [System.Environment]::ExpandEnvironmentVariables("%SystemRoot%\System32\wusa.exe")
				execInstall $wusa " /i $($update.fullname) /quiet /norestart" | out-null
			}
			".cab" {
				$dism = [System.Environment]::ExpandEnvironmentVariables("%SystemRoot%\System32\Dism.exe")
				if( (test-path $dism) -eq $true){
					if( (test-path ([System.Environment]::ExpandEnvironmentVariables("%SystemRoot%\Sysnative\Dism.exe") ) ) -eq $true ){
						$dismExec = [System.Environment]::ExpandEnvironmentVariables("%SystemRoot%\Sysnative\Dism.exe")
						 execInstall $dismExec  " /Online /NoRestart /Add-Package /PackagePath:$($update.FullName)" | out-null
					}else{
						$dismExec = [System.Environment]::ExpandEnvironmentVariables("%SystemRoot%\System32\Dism.exe")
						 execInstall $dismExec " /Online /NoRestart /Add-Package /PackagePath:$($update.FullName)" | out-null
					}
				}else{
					$dirId = ([guid]::newGuid()).guid
					new-item -type directory -name "$pwd\temp\$($dirId)"
					$expand = [System.Environment]::ExpandEnvironmentVariables("%SystemRoot%\System32\expand.exe")
					execInstall $expand  " $($update.fullName) -F:* ""$pwd\temp\$($dirId)"" " | out-null
					$pkgMgr = [System.Environment]::ExpandEnvironmentVariables("%SystemRoot%\System32\PkgMgr.exe")
					execInstall $pkgMgr  " /ip /m:""$pwd\temp\$($dirId)"" /quiet /norestart " | out-null
					remove-item -force -name "$pwd\temp\$($dirId)" 
				}
			}
			
		}
	}
}