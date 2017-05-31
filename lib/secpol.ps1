$secPolClass = new-PSClass SecPol{
	note -private infFilePath
	note -private entries @()
	property entries -get {return ,$private.entries}

	method parseSecPol{
		$secPolItems = $utilities.GetRegContent($private.infFilePath)
		foreach($secPolItem in $secPolItems.getEnumerator() ){
			$action = "U"
			$name = $secPolItem.Name.ToString()
			$keyName = ""
			
			$hive = $name
			
			foreach($value in $secPolItem.value.getEnumerator() ){
				$type = "";
				if($hive -eq 'Registry Values'){
					switch($value.value.substring(0,1)){
						1 {$type = "REG_SZ"; $value.value = $value.value.substring(2); }
						4 {$type = "REG_DWORD"; $value.value = $value.value.substring(2);}
						7 {$type = "REG_MULTI_SZ"; $value.value = $value.value.substring(2);}
						default {$type = "REG_DWORD"; $value.value = $value.value.substring(2);}
					}
				}
				
				$entry = @{
					"hive" = $hive;
					"keyName" = $value.name;
					"valueName" = "";
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
		param($infFilePath)
		#local secpol or inf path?
		if( $utilities.isBlank($infFilePath) -eq $true ){
			$ts = (get-date -format "yyyy-MM-dd_HH_mm_ss")
			invoke-expression "secedit /export /cfg '$($pwd)\temp\secpol_$($ts).inf'" | out-null
			$private.infFilePath = "$($pwd)\temp\secpol_$($ts).inf"
		}else{
			$private.infFilePath = $infFilePath
		}
	}
}