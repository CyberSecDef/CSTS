<#
.SYNOPSIS
	This script will generate hashes for submitted folder paths to determine if the files have changed.
.DESCRIPTION
	This script will generate hashes for submitted folder paths to determine if the files have changed.
.PARAMETER CheckFolder
    Folder which needs to be scanned for file changes
.PARAMETER KnownGoodFolder
    Optional path to compare a folder against with known good files
.PARAMETER HashAlgorithm
    Hashing algorithm to use to compare files.  SHA-1 is the only option on a FIPS compliant system
.PARAMETER reportScans
    The number of previous scan results to include in the HTML report output.  Defaults to 10
.PARAMETER ignore
    Files extensions to ignore
.PARAMETER executables
    Only scan executables (*.exe, *.bat, *.com, *.cmd, and *.dll)
.PARAMETER Recurse 
    Causes the script to check all subfolders of the given folders.	
.PARAMETER Update
    The script will automatically correct any mismatches or missing files it finds (use with caution)
.PARAMETER RemoveExtras
    The script will remove any extra files found in the CheckFolder
.PARAMETER CopyBackExtras
    The script will copy any extra files found in the CheckFolder location back to the KnownGoodFolder location
.EXAMPLE
	C:\PS>.\fileVerification.ps1 -checkFolder "c:\testFolder" -knownGoodFolder "c:\good" -recurse
	This will compare two folders and generate an xml report
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: John Laska
	Author: Robert Weber
	Date:   Aug 24, 2015
#>
[CmdletBinding()]
Param (
    $CheckFolder = "",
	$KnownGoodFolder = "",
    $HashAlgorithm='SHA1',
	$reportScans='10',
	$ignore=@(),
	[switch]$executables,
	[switch]$Recurse,
    [switch]$Update,
    [switch]$RemoveExtras,
    [switch]$CopyBackExtras
)

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$fileVerificationClass = new-PSClass fileVerification{
	note -static PsScriptName "fileVerification"
	note -static Description ( ($(((get-help .\fileVerification.ps1).Description)) | select Text).Text)
	
	note -static hashAlgorithms @( "MTD", "HMAC", "SHA1", "SHA256", "SHA384", "SHA512" 	)
	
	note -private mainProgressBar
	note -private gui
	
	note -private checkFolder
	note -private knownGoodFolder
	note -private recurse
	note -private hashAlgorithm
	note -private update
	note -private removeExtras
	note -private copyBackExtras
	note -private reportScans
	note -private ignore
	note -private executables
	note -private includes @("*.*")
	
	note -private xmlDb
	note -private crypto
	
	method -private transformReport{
		$utilities.processXslt("$pwd\db\fileVerification.xml","$pwd\templates\fileVerification.xsl", @{"reportScans" = $private.reportScans} ) | sc "$($pwd.ProviderPath)\results\$($fileVerificationClass.PsScriptName)_$(get-date -format 'yyyyMMddHHmmss').html"
	}
	
	method	-private saveXmlDb{
		$private.xmlDb.Save("$pwd\db\fileVerification.xml")
	}
	
	method -private openXmlDb{
		$private.xmlDb = New-Object system.xml.xmldatadocument
		if( (test-path "$pwd\db\fileVerification.xml") -eq $false){
			
			$xeRoot = $private.xmlDb.CreateElement('fileVerificationReport')
			$private.xmlDb.appendChild($xeRoot)
			$private.saveXmlDb()
		}else{
			$private.xmlDb.load("$pwd\db\fileVerification.xml")
		}
	}
	
	method -private createElement{
		param(
			[string]$name = "",
			$attributes = @{}
		)
		
		$node = $private.xmlDb.createElement($name)
		foreach($att in $attributes.keys){
			$node.setAttribute($att,$attributes.$att)
		}
		
		return $node
		
	}
	
	method -private scanPath{
		$subProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
		$uiClass.writeColor("$($uiClass.STAT_OK) Initializing Scan Entry in #green#File Verification Database# for #yellow#$($private.checkFolder)#");
		
		$xmlScan = $private.xmlDb.createElement("scan")
		$xmlScan.SetAttribute('TimeStamp', ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f (Get-Date) ));
		$xmlScan.SetAttribute('recurse',$private.recurse)
		$xmlScan.SetAttribute('hashAlgorithm',$private.hashAlgorithm)
		$xmlScan.SetAttribute('checkFolder',$private.checkFolder)
		$xmlScan.SetAttribute('knownGoodFolder',$private.knownGoodFolder)
		
		$xmlScan.appendChild( $private.xmlDb.createElement("files") )
		
		$xmlScan.appendChild($private.xmlDb.createElement("matches"))
		$xmlScan.selectSingleNode("matches").appendChild($private.xmlDb.createElement("original"))
		$xmlScan.selectSingleNode("matches").appendChild($private.xmlDb.createElement("recent"))
		$xmlScan.selectSingleNode("matches").appendChild($private.xmlDb.createElement("known"))
		
		$xmlScan.appendChild($private.xmlDb.createElement("mismatches"))
		$xmlScan.selectSingleNode("mismatches").appendChild($private.xmlDb.createElement("original"))
		$xmlScan.selectSingleNode("mismatches").appendChild($private.xmlDb.createElement("recent"))
		$xmlScan.selectSingleNode("mismatches").appendChild($private.xmlDb.createElement("known"))
		
		$xmlScan.appendChild($private.xmlDb.createElement("missing"))
		$xmlScan.selectSingleNode("missing").appendChild($private.xmlDb.createElement("original"))
		$xmlScan.selectSingleNode("missing").appendChild($private.xmlDb.createElement("recent"))
		$xmlScan.selectSingleNode("missing").appendChild($private.xmlDb.createElement("known"))
		
		$xmlScan.appendChild($private.xmlDb.createElement("extras"))
		$xmlScan.selectSingleNode("extras").appendChild($private.xmlDb.createElement("original"))
		$xmlScan.selectSingleNode("extras").appendChild($private.xmlDb.createElement("recent"))
		$xmlScan.selectSingleNode("extras").appendChild($private.xmlDb.createElement("known"))
		
		if( (test-path $private.checkFolder) -eq $true){
		
			$subProgressBar.Activity("Comparing Files against Known Good Folder").Status("10% complete").Percent(10).Render()
			$uiClass.writeColor("$($uiClass.STAT_OK) Comparing Files against #green#Known Good Folder#");
			
			$originalNode =  ( $private.xmlDb.selectNodes("//fileVerificationReport/scan[@checkFolder='$($private.checkFolder)']") | sort TimeStamp | select -first 1)
			$recentNode =  ( $private.xmlDb.selectNodes("//fileVerificationReport/scan[@checkFolder='$($private.checkFolder)']") | sort TimeStamp -descending | select -first 1)
			
			
			
			if($private.recurse -eq $true){
				$fileList = (gci $private.checkFolder -recurse -exclude $private.ignore -include $private.includes)
			}else{
				$fileList = (gci $private.checkFolder -exclude $private.ignore -include $private.includes)
			}
			
			
			#in known, missing from scanned
			if($utilities.isBlank($private.knownGoodFolder) -eq $false){
				
				$known = gci -recurse "$($private.knownGoodFolder)" -exclude $private.ignore | ? { $_.PSIsContainer -eq $false} | select @{Name="FullName";Expression={ 
					[regex]::Replace($_.FullName,[regex]::escape($($private.knownGoodFolder)),"","IgnoreCase")
				}}
				
				$scan = gci -recurse "$($private.checkFolder)" -exclude $private.ignore | ? { $_.PSIsContainer -eq $false} | select @{Name="FullName";Expression={ 
					[regex]::Replace($_.FullName,[regex]::escape($($private.checkFolder)),"","IgnoreCase")
				}} 
				Compare-Object -DifferenceObject $scan -ReferenceObject $known -property FullName | ? { $_.SideIndicator -eq "<=" } | % {

					$knownFile = get-item "$($private.knownGoodFolder)\$($_.fullName)" 

					$xmlScan.selectSingleNode("missing/known").appendChild(
						$private.createElement( "file", @{
							"path" = $knownFile.fullName;
							"knownHash" = $private.crypto.getHash( (gc $knownFile.fullName), $private.hashAlgorithm);
							
							"length" = $knownFile.length;
							"created" = "{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f $knownFile.CreationTimeUtc;
							"accessed" = "{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f $knownFile.LastAccessTimeUtc;
							"modified" = "{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f $knownFile.LastWriteTimeUtc;
						})
					)
				}
			}

			
			$subProgressBar.Activity("Comparing Files against Previous Scans").Status("25% complete").Percent(25).Render()
			$uiClass.writeColor("$($uiClass.STAT_OK) Comparing Files against #green#Previous Scans#");
			
			$currentFile = 0
			$totalFiles = $fileList.length
			$fileList | % {
				$currentFile++
				$i = [int](($currentFile / $totalFiles) * 50 + 25)
				$subProgressBar.Activity("$($currentFile) / $($totalFiles) : Analysing File $($_.fullName)").Status("$i% complete").Percent($i).Render()
				
				if($_.PSIsContainer -eq $false){
					$uiClass.writeColor("$($uiClass.STAT_WAIT) Analyzing #yellow#File# $($_.fullName)");
					$h = $private.crypto.getHash((gc $_.fullName), $private.hashAlgorithm )
					
					$xmlScan.selectSingleNode("files").appendChild(
						$private.createElement( "file", @{
							"hash" = $h;
							"path" = $_.FullName;
							"length" = $_.length;
							"created" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.CreationTimeUtc)).ToString();
							"accessed" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastAccessTimeUtc)).ToString();
							"modified" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastWriteTimeUtc)).ToString();
						})
					)

					if($utilities.isBlank($private.knownGoodFolder) -eq $false){
						$liveFilePath = $_.FullName
						$knownFilePath = ($_.FullName).replace($private.checkFolder,$private.knownGoodFolder)
						
						if( (test-path $knownFilePath ) -eq $false){
							
							$xmlScan.selectSingleNode("extras/known").appendChild(
								$private.createElement( "file", @{
									"scanHash" = $h;
									"path" = $_.FullName;
									
									"length" = $_.length;
									"created" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.CreationTimeUtc)).ToString();
									"accessed" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastAccessTimeUtc)).ToString();
									"modified" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastWriteTimeUtc)).ToString();
								})
							)
								
						}else{
							$knownGoodHash = $private.crypto.getHash( ( gc $knownFilePath), $private.hashAlgorithm )
							
							if($h -eq $knownGoodHash){
								$xmlScan.selectSingleNode("matches/known").appendChild(
									$private.createElement( "file", @{
										"path" = $_.FullName;
									})
								)
							}else{
								$xmlScan.selectSingleNode("mismatches/known").appendChild(
									$private.createElement( "file", @{
										"knownHash" = $knownGoodHash;
										"path" = $_.FullName;
										
										"length" = $_.length;
										"created" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.CreationTimeUtc)).ToString();
										"accessed" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastAccessTimeUtc)).ToString();
										"modified" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastWriteTimeUtc)).ToString();
									})
								)
							}
						}
					}
					
					
					#TODO: might not be first.....add check
					if(  ($private.xmlDb.selectNodes("//fileVerificationReport/scan[@checkFolder='$($private.checkFolder)']")).count -gt 0 ){
						
						$originalFile = $originalNode.selectSingleNode("files/file[@path='$($_.FullName)']")
						if( $originalFile -ne $null){
							if( ($originalFile | select hash).hash -eq $h){
								$xmlScan.selectSingleNode("matches/original").appendChild(
									$private.createElement( "file", @{
										"path" = $_.FullName;
									})
								)
							}else{
								$xmlScan.selectSingleNode("mismatches/original").appendChild(
									$private.createElement( "file", @{
										"scanHash" = $h;
										"path" = $_.FullName;
										
										"length" = $_.length;
										"created" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.CreationTimeUtc)).ToString();
										"accessed" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastAccessTimeUtc)).ToString();
										"modified" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastWriteTimeUtc)).ToString();
							
									})
								)
							}
						}else{
							$xmlScan.selectSingleNode("extras/original").appendChild(
								$private.createElement( "file", @{
									"scanHash" = $h;
									"path" = $_.FullName;
									
									"length" = $_.length;
									"created" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.CreationTimeUtc)).ToString();
									"accessed" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastAccessTimeUtc)).ToString();
									"modified" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastWriteTimeUtc)).ToString();
								})
							)
						}
						
						
						$recentFile = $recentNode.selectSingleNode("files/file[@path='$($_.FullName)']")
						if( $recentFile -ne $null){
							if( ($recentFile | select hash).hash -eq $h){
								$xmlScan.selectSingleNode("matches/recent").appendChild(
									$private.createElement( "file", @{
										"path" = $_.FullName;
									})
								)
							}else{
								$xmlScan.selectSingleNode("mismatches/recent").appendChild(
									$private.createElement( "file", @{
										"scanHash" = $h;
										"path" = $_.FullName;
										
										"length" = $_.length;
										"created" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.CreationTimeUtc)).ToString();
										"accessed" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastAccessTimeUtc)).ToString();
										"modified" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastWriteTimeUtc)).ToString();
									})
								)
							}
						}else{
							$xmlScan.selectSingleNode("extras/recent").appendChild(
								$private.createElement( "file", @{
									"scanHash" = $h;
									"path" = $_.FullName;
									
									"length" = $_.length;
									"created" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.CreationTimeUtc)).ToString();
									"accessed" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastAccessTimeUtc)).ToString();
									"modified" = ("{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}" -f ($_.LastWriteTimeUtc)).ToString();
								})
							)
						}
						
					}
				}
			}
			
			$subProgressBar.Activity("Comparing Files against Original Scan").Status("75% complete").Percent(75).Render()
			$uiClass.writeColor("$($uiClass.STAT_OK) Comparing Files against #green#Original Scan#");
			if($utilities.isBlank($originalNode) -eq $false){
				$originalNode.SelectNodes("files/file") | %{
					if($xmlScan.selectSingleNode("files").selectNodes("file[@path='$($_.path)']").count -eq 0){
						$xmlScan.selectSingleNode("missing/original").appendChild(
							$private.createElement( "file", @{
								"originalHash" = $_.hash;
								"path" = $_.path;
							})
						)
					}
				}
			}
			
			$subProgressBar.Activity("Comparing Files against Previous Scan").Status("90% complete").Percent(90).Render()
			$uiClass.writeColor("$($uiClass.STAT_OK) Comparing Files against #green#Previous Scan#");
			if($utilities.isBlank($recentNode) -eq $false){
				$recentNode.SelectNodes("files/file") | %{
					if($xmlScan.selectSingleNode("files").selectNodes("file[@path='$($_.path)']").count -eq 0){
						$xmlScan.selectSingleNode("missing/recent").appendChild(
							$private.createElement( "file", @{
								"recentHash" = $_.hash;
								"path" = $_.path;
							})
						)
					}
				}
			}
			
		}else{
			throw ("`n `n *** Invalid check folder selected: {0} *** `n `n" -f $private.checkFolder)
		}
		
		$private.xmlDb.selectSingleNode("//fileVerificationReport").appendChild($xmlScan)
		$subProgressBar.Completed($true).Render()
	}
	
	#this will only copy files back to a known good folder
	method -private actCopyBackExtras{
		#the database should be saved, the this recent node should be the results from the most recent scan
		if($utilities.isBlank($private.knownGoodFolder) -eq $false){
			$recentNode =  ( $private.xmlDb.selectNodes("//fileVerificationReport/scan[@checkFolder='$($private.checkFolder)']") | sort TimeStamp -descending | select -first 1)
			$recentNode.selectNodes("extras/known/file") | % {
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Copying #yellow#$($_.path)# to #green#Known Good Folder#")
				copy-item $_.path -Destination ( $_.path.replace($private.checkFolder,$private.knownGoodFolder) ) -recurse -force
			}
		}
	}
	
	#this will only update files in the scanned folder if a known good folder is specified.
	method -private actUpdate{
		#the database should be saved, the recent node should be the results from the most recent scan
		if($utilities.isBlank($private.knownGoodFolder) -eq $false){
			$recentNode =  ( $private.xmlDb.selectNodes("//fileVerificationReport/scan[@checkFolder='$($private.checkFolder)']") | sort TimeStamp -descending | select -first 1)
			#replace missing files
			$recentNode.selectNodes("missing/known/file") | % {
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Copying #yellow#$($_.path)# to #green#Scan Folder#")
				
				New-Item -ItemType File -Path ( [regex]::Replace($_.path,[regex]::escape($($private.knownGoodFolder)),[regex]::escape($private.checkFolder),"IgnoreCase") ) -Force
				copy-item  ($_.path) -Destination ( [regex]::Replace($_.path,[regex]::escape($($private.knownGoodFolder)),[regex]::escape($private.checkFolder),"IgnoreCase") ) -recurse -force
			}
			
			#replace Changed files
			$recentNode.selectNodes("mismatches/known/file") | % {
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Copying #yellow#$($_.path)# to #green#Scan Folder#")
				New-Item -ItemType File -Path $_.path -Force
				copy-item ( $_.path.replace($private.checkFolder,$private.knownGoodFolder) ) -Destination $_.path -recurse -force
			}
			
		}
	}
	
	
	#this will remove extras from current folder, comparing against known good folder.  extras compared to previous scans must be manually removed.
	method -private actRemoveExtras{
		#the database should be saved, the this recent node should be the results from the most recent scan
		$recentNode =  ( $private.xmlDb.selectNodes("//fileVerificationReport/scan[@checkFolder='$($private.checkFolder)']") | sort TimeStamp -descending | select -first 1)
		$recentNode.selectNodes("extras/known/file") | % { 
			$uiClass.writeColor("$($uiClass.STAT_WAIT) Removing Extra File #yellow#$($_.path)#")
			remove-item $_.path 
		}
	}
	
	method Execute{
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		$private.mainProgressBar.Activity("Opening File Database").Status(("{0:N2}% complete" -f 10)).Percent(10).Render()
		$private.openXmlDb()
		$private.mainProgressBar.Activity("Scanning File Paths").Status(("{0:N2}% complete" -f 25)).Percent(25).Render()
		$private.scanPath()
		$private.mainProgressBar.Activity("Saving File Database").Status(("{0:N2}% complete" -f 50)).Percent(50).Render()
		$private.saveXmlDb()
		$private.mainProgressBar.Activity("Generating Report").Status(("{0:N2}% complete" -f 75)).Percent(75).Render()
		$private.transformReport()
		
		$private.mainProgressBar.Activity("Updating File System ").Status(("{0:N2}% complete" -f 85)).Percent(85).Render()
		switch($true){
			$private.copyBackExtras 	{ $private.actCopyBackExtras() }
			$private.RemoveExtras 		{ $private.actRemoveExtras() }
			$private.update			{ $private.actUpdate() }
		}
		
		$private.mainProgressBar.Activity("Logging Errors").Status(("{0:N2}% complete" -f 95)).Percent(95).Render()
		$uiClass.errorLog()
		$private.mainProgressBar.Completed($true).Render() 
	}
	
	constructor{
		param()
		
		$private.checkFolder = $CheckFolder
		$private.knownGoodFolder = $KnownGoodFolder
		$private.hashAlgorithm = $HashAlgorithm
		$private.Recurse = $recurse
		$private.Update = $update
		$private.RemoveExtras = $removeExtras
		$private.CopyBackExtras = $copyBackExtras
		$private.reportScans = $reportScans
		$private.ignore = $ignore		
		$private.executables = $executables		
		
		$private.crypto = $cryptoClass.New()
		
		while( ($utilities.isBlank($private.checkFolder) -eq $true) -or ($utilities.isBlank($private.hashAlgorithm) -eq $true)){
			$private.gui = $null
		
			$private.gui = $guiClass.New("fileVerification.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			
			$private.gui.Controls.btnOpenCheckFolderBrowser.add_Click({ $private.gui.Controls.txtCheckFolder.Text = $private.gui.actInvokeFolderBrowser() })
			$private.gui.Controls.btnOpenKnownFolderBrowser.add_Click({ $private.gui.Controls.txtKnownGood.Text = $private.gui.actInvokeFolderBrowser() })
			
			#$private.gui.Controls.cboHash.SelectedIndex = $private.gui.Controls.cboHash.FindStringExact("SHA1")
			
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.checkFolder = $private.gui.Controls.txtCheckFolder.Text
			$private.knownGoodFolder = $private.gui.Controls.txtKnownGood.Text
			$private.gui.Controls.txtIgnore.Text.split(",") | %{
				$private.ignore += $_
			}
			$private.Recurse = $private.gui.Controls.chkRecurse.checked
			$private.Update = $private.gui.Controls.chkUpdate.checked
			$private.RemoveExtras = $private.gui.Controls.chkRemove.checked
			$private.CopyBackExtras = $private.gui.Controls.chkCopyBack.checked
			$private.hashAlgorithm = $private.gui.Controls.cboHash.text
			$private.reportScans = $private.gui.Controls.txtReportScans.text
			$private.executables = $private.gui.Controls.chkExec.checked
			
		}
		
		if($private.executables){
			$private.includes = @('*.exe', '*.bat', '*.com', '*.cmd', '*.dll')
		}
		
		if($fileVerificationClass.hashAlgorithms -notContains $private.hashAlgorithm){
			throw ("`n `n *** Invalid hash algorithm selected: {0} *** `n `n" -f $private.hashAlgorithm)
		}
		
		if( (test-path $private.checkFolder) -ne $true){
			throw ("`n `n *** Invalid check folder selected: {0} *** `n `n" -f $private.checkFolder)
		}
		
		if( ($utilities.isBlank($private.knownGoodFolder) -eq $false) -and (test-path $private.knownGoodFolder) -ne $true){
			throw ("`n `n *** Invalid known good folder selected: {0} *** `n `n" -f $private.knownGoodFolder)
		}
	}
}

$fileVerificationClass.New().Execute() | out-null