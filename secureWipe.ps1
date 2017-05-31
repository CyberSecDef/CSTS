<#
.SYNOPSIS
	This script will securely wipe a user selected hard drive.
.DESCRIPTION
	This script will securely wipe a user selected hard drive.  It does this by creating a random, temporary file that fills up all the free space on the partition.
.EXAMPLE
	C:\PS>.\wipe -targetPartition "c:\" -wipeType Random
	This will wipe the c: drive with random data
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Nov 30, 2015
#>
[CmdletBinding()]
param (	
	[string] $targetPartition = $null,
	$wipeType = "Random",
	[int32]  $arraySize = 16MB,
	[double] $spaceToLeave = 100MB
)   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$secureWipeClass = new-PSClass secureWipe{
	note -static PsScriptName "secureWipe"
	note -static Description ( ($(((get-help .\secureWipe.ps1).Description)) | select Text).Text)
	
	note -private mainProgressBar
	note -private gui
	
	note -private targetPartition
	note -private wipeType [secureWipe.wipeType]::Random
	note -private arraySize
	note -private spaceToLeave
	
	constructor{
		param()
		
		$private.targetPartition = $targetPartition
		[secureWipe.wipeType]$private.wipeType = [secureWipe.wipeType]$wipeType
		$private.arraySize = $arraySize
		$private.spaceToLeave = $spaceToLeave
		
		while($utilities.isBlank($private.targetPartition) -eq $true){
			$private.gui = $null
			$private.gui = $guiClass.New("secureWipe.xml")
			$private.gui.generateForm() | out-null;
			
			gwmi win32_volume | ? {$_.name -like '*:\' } | select -expand name | sort | %{
				$private.gui.Controls.cboTargetPartition.Items.Add($_) | out-null
			}
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog() | Out-Null	
			
			$private.targetPartition = $private.gui.Controls.cboTargetPartition.text
			$private.wipeType = $private.gui.Controls.cboWipeType.text
			$private.spaceToLeave = $private.gui.Controls.txtSpaceToLeave.text
			
		}
	}
	
	method Execute{
		param($par)
		
		$fixedRoot = ($private.targetPartition.Trim("\") -replace "\\","\\") + "\\"
		$fileName = "wipespace.dat"
		$filePath = join-path $fixedRoot $fileName
		
		$volume = gwmi win32_volume -filter "name='$($fixedRoot)'"
		
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Processing Partition #yellow#$($fixedRoot)#")
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Will fill all but #yellow#$($private.spaceToLeave) MB# on partition")
		$uiclass.writeColor("$($uiclass.STAT_WAIT) Creating temporary file #yellow#$($filePath)#")
		
		if($volume){
			$fileSize = $volume.freeSpace - $private.spaceToLeave
			$byteArray = new-object byte[]($private.arraySize)
			$stream = [io.file]::OpenWrite("$($filePath)")
			$sw = [system.diagnostics.stopwatch]::startNew()
			
			switch($private.wipeType){
				([secureWipe.wipeType]::Random) { 
					(new-object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($byteArray) 
					$uiclass.writeColor("$($uiclass.STAT_OK) Created #yellow#Random# Byte Array")
				}
				([secureWipe.wipeType]::One) { 
					$byteArray = [Byte[]] (,0xFF * $private.arraySize)
					$uiclass.writeColor("$($uiclass.STAT_OK) Created #yellow#One-Filled# Byte Array")
				}
				([secureWipe.wipeType]::Zero) {
					$byteArray = [Byte[]] (,0x00 * $private.arraySize)
					$uiclass.writeColor("$($uiclass.STAT_OK) Created #yellow#Zero-Filled# Byte Array")
				}
			}
			
			$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
			try{
				$curFileSize = 0
				$uiclass.writeColor("$($uiclass.STAT_WAIT) Filling temporary file #yellow#$($filename)# on #green#$fixedRoot# partition")
				while($curFileSize -lt $fileSize){
					if($private.wipeType -eq [secureWipe.wipeType]::Random){
						(new-object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($byteArray) 
						if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
							$uiclass.writeColor("$($uiclass.STAT_OK) Regenerated #yellow#Random# Byte Array")
						}
					}
					
					$stream.write($byteArray,0,$byteArray.length)
					$curFileSize += $byteArray.length
					$elapsed = "{0:c}" -f ([timespan]::fromSeconds( [math]::round( $sw.elapsed.totalSeconds)))
					$eta = "{0:c}" -f ([timespan]::fromSeconds( [math]::round( $sw.elapsed.totalSeconds / ($curFileSize/$fileSize) ) ) )
					$private.mainProgressBar.Activity("$($private.targetPartition) - Elapsed $($elapsed) - ETA: $($eta)").Status("$($curFileSize / 1gb) gb").Percent(($curFileSize/$fileSize*100)).Render()
					
				}
			}finally{
				if($stream){
					$stream.close()
				}
				remove-item "$($filepath)"
			}
		}
		
		$uiClass.errorLog()
	}
}

$secureWipeClass.New().Execute()  | out-null