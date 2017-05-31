if(!(test-path "$pwd\bin\PolFileEditor.dll")){
	Add-Type -Language CSharpVersion3 -TypeDefinition ([System.IO.File]::ReadAllText("$pwd\types\PolFileEditor.cs")) -OutputAssembly "$pwd\bin\PolFileEditor.dll" -outputType Library
}
if(!("TJX.PolFileEditor.PolFile" -as [type])){
	Add-Type -path "$pwd\bin\PolFileEditor.dll"
}

Import-Module groupPolicy -errorAction SilentlyContinue

$gpoClass = New-PSClass gpo{
	note -private hive
	note -private hivePath
	
	note -private gpoPath
	note -private gpoPol
	note -private entries @()
	
	property entries -get {return ,$private.entries}
	property hive -get {return ,$private.hive}
	property gpoPath -get {return ,$private.gpoPath}
	
	method reset{
		$private.entries = @()
	}
	
	method parsePol{
		param($polPath)
		if( (test-path $polPath) -eq $true){
			$private.gpoPol.LoadFile($polPath)
			foreach($e in ( $private.gpoPol.Entries ) ){
				if($e -ne $null){
					$entry = @{
						"hive" = $private.hive;
						"keyName" = $e.keyName;
						"valueName" = $e.valuename;
						"value" = $e.stringValue;
						"type" = $e.type;
						"action" = "U";
					}
					if($cstsClass.verbose){
						$uiClass.writeColor("$($uiClass.STAT_OK) Consumed #yellow#$( $entry.keyName )#\#green#$($entry.ValueName)# --> #green#$( $entry.value )#")
					}
					$private.entries += $entry
					
				}else{
					$uiClass.writeColor("$($uiClass.STAT_ERROR) Could Not Parse GPO File Entry for #yellow#$($gpoPath)#")
				}
			}
		}
	}
	
	method parseXml{
		param($xmlPath)
		if( (test-path $xmlPath) -eq $true){
			$xml = [xml](gc $xmlPath)
			$xml.RegistrySettings.Registry | select -expand Properties | % {
				$entry = @{
					"hive" = $private.hive;
					"keyName" = $_.key;
					"valueName" = $_.name;
					"value" = $_.value;
					"type" = $_.type;
					"action" = $_.action;
				}
				if($cstsClass.verbose){
					$uiClass.writeColor("$($uiClass.STAT_OK) Consumed #yellow#$( $entry.keyName )#\#green#$($entry.ValueName)# --> #green#$( $entry.value )#")
				}
				$private.entries += $entry
			}
		}
	}
	
	method parseGpo{
		

		if( (test-path $private.gpoPath) -eq $true){
			#parse registry.pol
			if( (test-path "$($private.gpoPath)\$($private.hivePath)\registry.pol") -eq $true){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing $($private.hive) Local GPO Registry.pol file for #yellow#$($private.gpoPath)#")
				$this.parsePol( "$($private.gpoPath)\$($private.hivePath)\registry.pol" )
			}else{
				$uiClass.writeColor("$($uiClass.STAT_ERROR) $($private.hivePath) Registry.pol file missing for #yellow#$($private.gpoPath)#")
			}
			
			#parse registry.xml
			if( (test-path "$($private.gpoPath)\$($private.hivePath)\preferences\registry\registry.xml") -eq $true){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing $($private.hive) Local GPO Registry.xml file for #yellow#$($private.gpoPath)#")
				$this.parseXml( "$($private.gpoPath)\$($private.hivePath)\preferences\registry\registry.xml" )
				
			}else{
				$uiClass.writeColor("$($uiClass.STAT_ERROR) $($private.hivePath) Registry.XMLfile missing for #yellow#$($private.gpoPath)#")
			}
		}else{
			#its a title, see if we can find a gpo with this title
			$domain = ([ADSI]"LDAP://RootDSE").Get("ldapServiceName").Split(":")[0]
			get-gpo -all -ErrorAction SilentlyContinue | ? { $_.GpoStatus -like '*Enabled*' } | ? { $_.DisplayName -eq $private.gpoPath -or $_.Id -eq $private.gpoPath} | select DisplayName, Id | sort DisplayName | %{
				$gpoId = $_.Id
				
				#parse registry.pol
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing $($private.hivePath) Domain GPO Registry.pol file for #yellow#$($private.gpoPath)#")
				gci "\\$($domain)\sysvol\*\Policies\{$($gpoId)}\$($private.hivePath)\Registry.pol" | %{ $this.parsePol($_.FullName) }
				
				#parse registry.xml
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing $($private.hivePath) Domain GPO Registry.xml file for #yellow#$($private.gpoPath)#")
				gci "\\$($domain)\sysvol\*\Policies\{$($gpoId)}\$($private.hivePath)\preferences\registry\Registry.xml" | %{ $this.parseXml($_.FullName) }
			}
		}
	}
	
	constructor{
		param($gpoPath, $hive)
		$private.gpoPath = $gpoPath
		$private.hive = $hive
		if($private.hive -eq "HKEY_LOCAL_MACHINE"){
			$private.hivePath = "Machine"
		}else{
			$private.hivePath = "User"
		}
		
		$private.gpoPol = New-Object TJX.PolFileEditor.PolFile
		
		#see if this is a path or a title
		if($utilities.isBlank($gpoPath) -eq $false){
			#do other stuff as needed
		}else{
			$uiClass.writeColor(
				( "$($uiClass.STAT_ERROR) Missing GPO Files/Data:`n`tPath  : #yellow#{0}#" -f $private.gpoPath )
			)
			return $false
		}
	}
}