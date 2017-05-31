$regFileClass = new-PSClass RegFile{
	note -private regFilePath
	note -private entries @()
	property entries -get {return ,$private.entries}

	method parseReg{
		$regItems = $utilities.GetRegContent($private.regFilePath)
		foreach($regItem in $regItems.getEnumerator() ){
			$name = $regItem.Name.ToString()
			$keyName = ""
			
			if($name -like '*HKEY_LOCAL_MACHINE*'){
				$hive = "HKEY_LOCAL_MACHINE"
				$keyName = $name.subString( $name.indexOf("\") + 1 );
			}elseif( $name -like '*HKEY_CLASSES_ROOT*'){
				$hive = "HKEY_LOCAL_MACHINE"
				$keyName = "Software\Classes\$($name.subString( $name.indexOf("\") + 1 ))";
			}elseif( $name -like '*HKEY_CURRENT_USER*'){
				$hive = "HKEY_CURRENT_USER"
				$keyName = $name.subString( $name.indexOf("\") + 1 );
			}
			
			foreach($value in $regItem.value.getEnumerator() ){
				$type = "REG_SZ"
				$action = "U"
				
				if($value.name -eq "@"){
					$value.name = '(Default)'
				}
				#binary values not supported
				if($value.value -like 'hex*'){
					continue;
				}
				if($value.value -like 'dword:*'){
					$type = "REG_DWORD"
					$value.value = $value.value.substring(6);
				}
				if($value.value -eq '-'){
					$type = "REG_NONE"
					$value.value = ""
					$action = "D"
				}
				
				$entry = @{
					"hive" = $hive;
					"keyName" = $keyName;
					"valueName" = $value.name.Trim('"');
					"value" = $value.value;
					"type" = $type;
					"action" = $action;
				}
						
				if($cstsClass.verbose){
					$uiClass.writeColor("$($uiClass.STAT_OK) Consumed #yellow#$( $entry.keyName )#\#green#$($entry.ValueName)# --> #green#$( $entry.value )#")
				}
				$private.entries += $entry			
			}			
		}
	}
	
	constructor{
		param($regFilePath)
		
		if( (test-path $regFilePath) -eq $true){
			$private.regFilePath = $regFilePath
			
		}
		
	}
}

$registryClass = New-PSClass Registry{
	note -private regObj $null;
	note -private regKey $null
	note -private status $null;
	
	property Key -get{ return $private.regKey}
	
	method open{
		param($computerName, $hive)
		
		try{
			$pingResult = Get-WmiObject -Class win32_pingstatus -Filter "address='$($computerName.Trim())'"
			if( ($pingResult.StatusCode -eq 0 -or $pingResult.StatusCode -eq $null ) -and $utilities.isBlank($pingResult.IPV4Address) -eq $false ) {
				$private.regObj = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($hive,$computerName) 
				$private.status = $true
			}else{
				return $false
			}
		}catch{
			$private.status = $false
		}
	}
	
	method GetSubKeyNames{
		try{
			if($utilities.isBlank($private.regKey) -eq $false){
				return $private.regKey.GetSubKeyNames()
			}else{
				return $false
			}
		}catch{
			return $false
		}
	}
	
	method openSubKey{
		param($path)
		if($private.status -eq $true){
			try{
				$private.regKey = $private.regObj.openSubKey( ($path.replace("\\","\").replace("\","\\")), $true )
			}catch{
				write-host $_.Exception.message
				return $false
			}
		}else{
			return $false
		}
	}
	
	method createSubKey{
		param($path)
		
		if($private.status -eq $true){
			try{
				$private.regKey = $private.regObj.createSubKey( ($path.replace("\\","\").replace("\","\\")) )
			}catch{
				return $false
			}
		}else{
			return $false
		}
	}
	
	# creating this as a static function
	# there is also an instance function that calls this.
	method -static getValueType{
		param($valueType)
		
		$type = ""
		switch($valueType){
			"REG_BINARY" { $type = "Binary";  }
			"Binary" { $type = "Binary" }
			"REG_DWORD" { $type = "DWord";  }
			"Dword" { $type = "DWord";  }
			"" { $type = "DWord";  }
			"REG_None" { $type = "DWord";  }
			"None" { $type = "DWord";  }
			"REG_EXPAND_SZ" { $type = "ExpandString";  }
			"ExpandString" { $type = "ExpandString";  }
			"REG_MULT_SZ" { $type = "MultiString";  }
			"REG_MULTI_SZ" { $type = "MultiString";  }
			"MultiString" { $type = "MultiString";  }
			"REG_QWORD" { $type = "QWord";  }
			"QWord" { $type = "QWord";  }
			"REG_SZ" { $type = "String";  }
			"String" { $type = "String";  }
		}
		
		return $type
	}
	
	method getValueType{
		param($valueType)
		
		return $registryClass.getValueType($valueType)
	}
	
	method getValue{
		param($valueName)
		try{
			if($utilities.isBlank($private.regKey) -eq $false){
				return $private.regKey.getValue($valueName)
			}else{
				return $false
			}
		}catch{	
			return $false
		}
	}
	
	method setValue{
		param($keyName, $valueName, $value, $valueType)
		$this.createSubKey($keyName)
		try{
			if($utilities.isBlank($private.regKey) -eq $false){
				$private.regKey.setValue($valueName,$value,[Microsoft.Win32.RegistryValueKind]::$($this.getValueType($valueType)))
			}else{
				return $false
			}
		}catch{
			return $false
		}
	}
	
	method close{
		if($private.status -eq $true){
			$private.status = $false
			$private.regObj.close()
		}else{
			return $false
		}
	}
	
	constructor{
	
	}
}

$registryCollectionClass = New-PSClass registryCollection{
	note -private entries @();

	property All -get{ return $private.entries}
	
	method Filter{
		param($filter = @())
		$results = @()
		foreach($entry in $private.entries){
			$keep = $true
			foreach($key in $filter.keys){
				if($entry.$key -ne $filter.$key){
					$keep = $false
				}
			}
			if($keep -eq $true){
				$results += $entry
			}
		}

		return $results
	}
	
	method Count{
		return $private.entries.length
	}
	
	method Get{
		param($index)
		
		return $private.entries[$index]
	}
	
	method Add{
		param($registry)
		$private.entries += $registry
	}
	
	method Del{
		param($index)
		$private.entries[$index] = $null
	}
	
	constructor{
	
	}
}

$registryEntryClass = New-PSClass RegistryEntry{
	note -static allowedTypes @("REG_BINARY","REG_DWORD","REG_MULTI_SZ","REG_QWORD","REG_SZ","REG_NONE")
	note -static allowedHives @("HKEY_LOCAL_MACHINE","HKEY_CURRENT_USER")
	
	note -private hive
	note -private keyName
	note -private valueName
	note -private type
	note -private value

	property Hive -get{ return $private.hive} -set{ param($val);$private.hive = $val}
	property KeyName -get{ return $private.keyName} -set{ param($val);$private.keyName = $val}
	property ValueName -get{ return $private.valueName} -set{ param($val);$private.valueName = $val}
	property Type -get{ return $private.type} -set{ param($val);$private.type = $val}
	property Value -get{ return $private.value} -set{ param($val);$private.value = $val}
	
	constructor{
		param(
			$hive = "HKEY_LOCAL_MACHINE",
			$KeyName = $null,
			$ValueName = $null,
			$type = $null,
			$value = $null
		)
		
		$private.hive = $hive;
		$private.KeyName = $KeyName;
		$private.ValueName = $ValueName;
		$private.type = $type;
		$private.Value = $value;
		
		if($registryEntryClass.allowedTypes -notContains $private.type){
			write-host ("`n `n *** Invalid Registry Value Type Submitted: ***`nHive: {0}`nKey: {1}`nName: {2}`nType: {3}`nValue: {4} `n `n" -f $private.hive, $private.keyName, $private.valueName, $private.type, $private.value)
		}
	}
}