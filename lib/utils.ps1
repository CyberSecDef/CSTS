$utilities = New-PSClass Utilities{
	note -static timer 
	
	method -static GetTitleCase{
		param($msg)
		
		$msg -split " " | % {
			$_.substring(0,1).toUpper()+$_.substring(1)
		}
	}
	
	method -static startTimer{
		$this.timer = [system.diagnostics.stopWatch]::startNew()
	}
	
	method -static stopTimer{
		$this.timer.stop() | out-null
	}
	
	method -static elapsed{
		$this.timer.elapsed;
	}
	
	method -static GetRegContent {
		param($filePath)
		$ini = @{}
		switch -regex -file $filePath{
			"^\[(.+)\]" { # Section
				$section = $matches[1]
				$ini[$section] = @{}
				$CommentCount = 0
			}
			"^(;.*)$" { # Comment
				$value = $matches[1]
				$CommentCount = $CommentCount + 1
				$name = "Comment" + $CommentCount
				$ini[$section][$name] = $value
			} 
			"(.+?)\s*=(.*)" { # Key
				$name,$value = $matches[1..2]
				$ini[$section][$name] = $value
			}
		}
		return $ini
	}
	
	method -static ConvertFromXml{
		param($xml)
		$results = @()
		foreach ($Object in @($XML.Objects.Object)) {
			$PSObject = New-Object PSObject
			foreach ($Property in @($Object.Property)) {
				$PSObject | Add-Member NoteProperty $Property.Name $Property.InnerText
			}
			$results += $PSObject
		}
		return $results	
	}

	method -static getXml{
		param($xml, $indent = 4)
		$stringWriter = new-object System.IO.StringWriter
		$xmlWriter = new-object System.xml.xmlTextWriter $stringWriter
		$xmlWriter.formatting = 'indented'
		$xmlWriter.indentation = $indent
		$xml.WriteContentTo($xmlWriter)
		$xmlWriter.flush()
		$stringWriter.flush()
		return $StringWriter.ToString()
	}

	method -static dump{
		param(
			$obj,
			[string]$format = "table",
			[switch]$gm = $true
		)
		if($gm -eq $true){
			switch($format){
				"table" { $obj | gm | ft | out-string | write-host }
				"list"  { $obj | gm | fl | out-string | write-host }
			}
		}else{
			switch($format){
				"table" { $obj | ft | out-string | write-host }
				"list"  { $obj | fl | out-string | write-host }
			}
		}
	}
	
	method -static print_r{
		param($obj, $index = 0)
		$utilities.printR($obj, $index)
	}
	
	method -static printR{
		param($obj, $index = 0)
		
		for($i=0; $i -lt $index; $i++){ write-host "    " -noNewLine }
		write-host "$( $obj.getType() -replace '\[\]','' )" -noNewLine
		if($obj.length -ne $null){
			write-host "[$($obj.length)] = " -noNewLine
		}
		
		switch($obj.getType()){
			"dateTime" { write-host " => {$($obj.toString()) {"}
			"System.DateTime" { write-host " => { $($obj.toString()) }"}
			"int" { write-host " $($obj)"}
			"long" { write-host " $($obj)"}
			"string" { write-host "'$($obj)'"}
			"System.Array" {
				write-host "{"
				for($c = 0; $c -lt $obj.length; $c++){
					for($i=0; $i -le $index; $i++){ write-host "    " -noNewLine}
					write-host "[$($c)] => " 
					$utilities.printR( ($obj[$c]), ($index + 2) ) 
				}
				for($i=0; $i -lt $index; $i++){ write-host "    " -noNewLine}
				write-host "}"
			}
			"System.Object[]" {
				write-host "{"
				for($c = 0; $c -lt $obj.length; $c++){
					for($i=0; $i -le $index; $i++){ write-host "    " -noNewLine}
					write-host "[$($c)] => " 
					$utilities.printR( ($obj[$c]), ($index + 2) ) 
				}
				for($i=0; $i -lt $index; $i++){ write-host "    " -noNewLine}
				write-host "}"
			}
			"Hashtable" {
				write-host "{"
				foreach($c in ($obj.keys | sort)){
					for($i=0; $i -le $index; $i++){ write-host "    " -noNewLine}
					write-host "[$($c)] => " 
					$utilities.printR( ($obj.$c), ($index + 2) ) 
				}
				for($i=0; $i -lt $index; $i++){ write-host "    " -noNewLine}
				write-host "}"
			}
			"System.Collections.Hashtable" {
				write-host "{"
				foreach($c in ($obj.keys | sort)){
					for($i=0; $i -le $index; $i++){ write-host "    " -noNewLine}
					write-host "[$($c)] => " 
					$utilities.printR( ($obj.$c), ($index + 2) ) 
				}
				for($i=0; $i -lt $index; $i++){ write-host "    " -noNewLine}
				write-host "}"
			}
			"System.Management.Automation.PSCustomObject" {
				write-host "{"
				write-host "    methods =>"
				foreach($m in ($obj | gm -memberType ScriptMethod | sort ) ){
					for($i=0; $i -le $index+1; $i++){ write-host "    " -noNewLine}
					write-host "$($m.name)()" 
				}

				write-host "    properties => "
				
				foreach($c in ( $obj | gm | ? {  $_.memberType -ne 'scriptMethod' -and $_.memberType -ne 'Method'} | sort  ) ){
					for($i=0; $i -le $index+1; $i++){ write-host "    " -noNewLine}
					write-host "[$($c.name)] => " 
					$utilities.printR( ($c), ($index + 4) ) 
				}
				for($i=0; $i -lt $index; $i++){ write-host "    " -noNewLine}
				write-host "}"
			}
			
			default {
				write-host "{Cannot Parse Object to Print}"
			}
			
		}
		
		
		
	}
	
	
	method -static IsFileLocked{
		param($filePath)
		Rename-Item $filePath $filePath -ErrorVariable errs -ErrorAction SilentlyContinue
		return ($errs.Count -ne 0)
	}

	method -static xmlText{
		param(
			$xml
		)

		if($xml -ne $null){
			switch( ($xml.GetType()).Name ){
				'String' { return ( $xml -replace "`n","" -replace "`r","") }
				'XmlElement' { return ( ($xml.innerText) -replace "`n","" -replace "`r","" )}
			}
		}
	}
	
	method -static decodeProductKey{
		param ($data)
	
		$productKey = $null

		$binArray = ($data)[52..66]
		$charsArray = "B","C","D","F","G","H","J","K","M","P","Q","R","T","V","W","X","Y","2","3","4","6","7","8","9"
		
		For ($i = 24; $i -ge 0; $i--) {
			$k = 0
			For ($j = 14; $j -ge 0; $j--) {
				$k = $k * 256 -bxor $binArray[$j]
				$binArray[$j] = [math]::truncate($k / 24)
				$k = $k % 24
			}
			$productKey = $charsArray[$k] + $productKey
			If (($i % 5 -eq 0) -and ($i -ne 0)) {
				$productKey = "-" + $productKey
			}
		}
					
		return $productKey
	}
	

	method -static processXslt{
		param(
			[string]$xmlPath, 
			[string] $xslPath,
			$argParms = $null
		)
		
		if($utilities.isBlank($argParms) -eq $false){
			$arglist = new-object System.Xml.Xsl.XsltArgumentList
			
			$argParms.keys | % {
				$arglist.AddParam($_, "", $argParms.$_);
			}
			
		}else{
			$arglist = $null;
		}
		 
		
		
		$xmlContent = [string](gc $xmlPath)
		
		$inputstream = new-object System.IO.MemoryStream
		$xmlvar = new-object System.IO.StreamWriter($inputstream)
		$xmlvar.Write( $xmlContent)
		$xmlvar.Flush()
		$inputstream.position = 0
		$xmlObj = new-object System.Xml.XmlTextReader($inputstream)
		$output = New-Object System.IO.MemoryStream
		$xslt = New-Object System.Xml.Xsl.XslCompiledTransform
		
		$reader = new-object System.IO.StreamReader($output)
		
		$resolver = New-Object System.Xml.XmlUrlResolver
		$xslSettings = New-Object System.Xml.Xsl.XsltSettings($false,$true)
		$xslSettings.EnableDocumentFunction = $true
		$xslt.Load($xslPath,$xslSettings, $resolver)
				
		$xslt.Transform($xmlObj, $arglist, $output)
		$output.position = 0
		$transformed = [string]$reader.ReadToEnd()
		$reader.Close()
		return $transformed
	}
	
	method -static getEnums{
		param($type)
		return [System.Enum].GetValues($type)
	}
	
	method -static ContainsAny{
		param( [string]$s, [string[]]$items )
		$matchingItems = @($items | where { $s.Contains( $_ ) })
		[bool]$matchingItems
	}

	method -static zipFolder{
		param([string]$folder)
		
		$zipFileName = "$folder.zip"
		
	
		if(-not (test-path($zipfilename))){
			set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
			(dir $zipfilename).IsReadOnly = $false  
		}

		$shellApplication = new-object -com shell.application
		$zipPackage = $shellApplication.NameSpace($zipfilename)
		if($zipPackage -ne $null){
			foreach($file in (gci $folder) ){ 
				if(test-path $file.FullName){
				$zipPackage.CopyHere($file.FullName)
					do{
						Start-sleep -milliseconds 500
					}while($zipPackage.Items().count -eq 0)
				}
			}
		}
	}
	
	method -static isBlank{
		param($var)
		if($var -eq "" -or $var -eq $null -or $var.getType() -like '*DBNULL*'){
			return $true
		}else{
			return $false
		}
	}
	
	method -static getWebFile{
		param(
			[string] $url,
			[string] $outFile
		)
		
		$path = (split-path $outFile)
		if( (test-path $path) -eq $false){
			New-Item -ItemType Directory -Path $path -Force
		}
		if( (test-path $outfile) -eq $true){
			remove-item $outfile
		}
		(new-object system.net.webclient).DownloadFile($url,$outfile)
	}
	
	method -static getFolderHash{
		param($folder)
		
		$files = dir $folder -Recurse |? { -not $_.psiscontainer }
    
		$allBytes = new-object System.Collections.Generic.List[byte]
		foreach ($file in $files){
			$allBytes.AddRange([System.IO.File]::ReadAllBytes($file.FullName))
			$allBytes.AddRange([System.Text.Encoding]::UTF8.GetBytes($file.Name))
		}
		$hasher = [System.Security.Cryptography.SHA1]::Create()
		$ret = [string]::Join("",$($hasher.ComputeHash($allBytes.ToArray()) | %{"{0:x2}" -f $_}))
		
		return $ret
	}
	
	method -static hashToObj{
		param ( $hashtable	); 
		$i = 0;
     
		foreach ($myHashtable in $hashtable) { 
			if ($myHashtable.GetType().Name -eq 'hashtable') { 
				$output = New-Object -TypeName PsObject; 
				Add-Member -InputObject $output -MemberType ScriptMethod -Name AddNote -Value {  
					Add-Member -InputObject $this -MemberType NoteProperty -Name $args[0] -Value $args[1]; 
				}; 
				$myHashtable.Keys | Sort-Object | % {  
					$output.AddNote($_, $myHashtable.$_);  
				} 
				return $output; 
			} else { 
				Write-Warning "Index $i is not of type [hashtable]"; 
			} 
			$i += 1;  
		} 
	}


}
#added alias as I keep mistyping utilities
$utils = $utilities 

Function gwmic([string]$computername,[string]$namespace="root\cimv2",[string]$class,[int]$timeout=15) { 
	$ConnectionOptions = new-object System.Management.ConnectionOptions 
	$EnumerationOptions = new-object System.Management.EnumerationOptions
	$timeoutseconds = new-timespan -seconds $timeout 
	$EnumerationOptions.set_timeout($timeoutseconds)

	$assembledpath = "\\" + $computername + "\" + $namespace 
	#write-host $assembledpath -foregroundcolor yellow

	$Scope = new-object System.Management.ManagementScope $assembledpath, $ConnectionOptions 
	$Scope.Connect()

	$querystring = "SELECT * FROM " + $class 
	#write-host $querystring

	$query = new-object System.Management.ObjectQuery $querystring 
	$searcher = new-object System.Management.ManagementObjectSearcher 
	$searcher.set_options($EnumerationOptions) 
	$searcher.Query = $querystring 
	$searcher.Scope = $Scope

	trap { $_ } $result = $searcher.get()

	return $result 
}


$env:temp = "$pwd\temp"