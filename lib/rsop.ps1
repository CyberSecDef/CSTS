if(!(test-path "$pwd\bin\PolFileEditor.dll")){
	Add-Type -Language CSharpVersion3 -TypeDefinition ([System.IO.File]::ReadAllText("$pwd\types\PolFileEditor.cs")) -OutputAssembly "$pwd\bin\PolFileEditor.dll" -outputType Library
}
if(!("TJX.PolFileEditor.PolFile" -as [type])){
	Add-Type -path "$pwd\bin\PolFileEditor.dll"
}

Import-Module groupPolicy -errorAction SilentlyContinue


$rsopClass = New-PSClass rsop{
	note -private rsopSource
	note -private user
	note -private computer
	note -private settings @{
		"AppliedGpo" = @{'Computer' = @(); 'User' = @();}
		"DeniedGpo" = @{'Computer' = @(); 'User' = @();}
		"SecGroup" = @{'Computer' = @(); 'User' = @();}
		"softwareInstalls" = @{'Computer' = @(); 'User' = @();}
		"startupScripts" = @{'Computer' = @(); }
		"accountPolicies" = @{'Computer' = @(); }
		"auditPolicies" = @{'Computer' = @(); }
		"secOpts" = @{'Computer' = @(); }
		"eventLogSettings" = @{'Computer' = @(); }
		"systemServices" = @{'Computer' = @(); }
		"adminTemplates" = @{'Computer' = @(); 'User' = @();}
		"userPrivs" = @{'User' = @();}
	}

	property settings -get {return ,$private.settings}
	
	
	
	method reset{
		$private.entries = @()
	}
	
	method parse{
	
		$lines = $private.rsopSource | select-string -pattern '^[\t\s]*-+$' | select -expand lineNumber
	
		@('COMPUTER SETTINGS','USER SETTINGS') | %{
			for($i=0; $i -lt $lines.count; $i++){
				if($private.rsopSource[ $lines[$i] - 2 ] -eq $_  ){
					set-variable -name $($_.replace('SETTINGS','').Trim()) -value $($lines[$i]-2)
				}
			}
		}
		
		$private.user = $user
		$private.computer = $computer

		$i = 0
		while($i -lt ($lines.length) ){
			$dashLine = $lines[$i] - 1
			$headerLine = $lines[$i] - 2
			$startLine = $lines[$i]
			$endLine = $lines[$i+1] - 3
			$type = @('User','Computer')[$private.computer..$private.user -contains $headerLine]
			$block = 1
			
			switch(   $( ($private.rsopSource[ $headerLine ]).Trim())    ){
				"The user has the following security privileges"{
					$private.rsopSource[$startLine..$endLine] | %{
						$private.settings.userPrivs.$type += $_.trim()
					}
				}
				"Applied Group Policy Objects" {
					$private.rsopSource[$startLine..$endLine] | %{
						$private.settings.appliedGPO.$type += $_.trim()
					}
				}
				"The following GPOs were not applied because they were filtered out" {
					for($l = $startLine; $l -lt $endLine; $l = $l+3){
						$private.settings.DeniedGpo.$type += $private.rsopSource[$l].trim(); 
					}
				}
				
				"The computer is a part of the following security groups" {
					$private.rsopSource[$startLine..$endLine] | %{
						$private.settings.SecGroup.$type += $_.trim()
					}
				}
				
				"The user is a part of the following security groups" {
					$private.rsopSource[$startLine..$endLine] | %{
						$private.settings.SecGroup.$type += $_.trim()
					}
				}
				
				
				"Account Policies" {
					while($private.rsopSource[$startLine+$block].trim() -ne ''){ $block++}; $block = $block+2;
					for($l = $startLine; $l -lt $endLine; $l = $l+$block){
						$tmpObj = @{}
						for($bl = 0; $bl -lt $block; $bl++){
							if($private.rsopSource[$l+$bl].trim() -ne ''){
								$tmpObj.$("$($private.rsopSource[$l+$bl].split(':')[0])".trim()) = $("$($private.rsopSource[$l+$bl].split(':')[1])".trim())
							}
						}
						$private.settings.accountPolicies.$type += $tmpObj
					}
				}
				"Audit Policy" {
					while($private.rsopSource[$startLine+$block].trim() -ne ''){ $block++}; $block = $block+2;
					for($l = $startLine; $l -lt $endLine; $l = $l+$block){
						$tmpObj = @{}
						for($bl = 0; $bl -lt $block; $bl++){
							if($private.rsopSource[$l+$bl].trim() -ne ''){
								$tmpObj.$("$($private.rsopSource[$l+$bl].split(':')[0])".trim()) = $("$($private.rsopSource[$l+$bl].split(':')[1])".trim())
							}
						}
						$private.settings.auditPolicies.$type += $tmpObj
					}
				}
				"System Services" {
					while($private.rsopSource[$startLine+$block].trim() -ne ''){ $block++}; $block = $block+2;
					for($l = $startLine; $l -lt $endLine; $l = $l+$block){
						$tmpObj = @{}
						for($bl = 0; $bl -lt $block; $bl++){
							if($private.rsopSource[$l+$bl].trim() -ne ''){
								$tmpObj.$("$($private.rsopSource[$l+$bl].split(':')[0])".trim()) = $("$($private.rsopSource[$l+$bl].split(':')[1])".trim())
							}
						}
						$private.settings.systemServices.$type += $tmpObj
					}
				}
				
				"Administrative Templates"{
					while($private.rsopSource[$startLine+$block].trim() -ne ''){ $block++}; $block = $block+2;
					for($l = $startLine; $l -lt $endLine; $l = $l+$block){
						$tmpObj = @{}
						for($bl = 0; $bl -lt $block; $bl++){
							if($private.rsopSource[$l+$bl].trim() -ne ''){
								$tmpObj.$("$($private.rsopSource[$l+$bl].split(':')[0])".trim()) = $("$($private.rsopSource[$l+$bl].split(':')[1])".trim())
							}
						}
						$private.settings.adminTemplates.$type += $tmpObj
					}
				}
				"Event Log Settings"{
					while($private.rsopSource[$startLine+$block].trim() -ne ''){ $block++}; $block = $block+2;
					for($l = $startLine; $l -lt $endLine; $l = $l+$block){
						$tmpObj = @{}
						for($bl = 0; $bl -lt $block; $bl++){
							if($private.rsopSource[$l+$bl].trim() -ne ''){
								$tmpObj.$("$($private.rsopSource[$l+$bl].split(':')[0])".trim()) = $("$($private.rsopSource[$l+$bl].split(':')[1])".trim())
							}
						}
						$private.settings.eventLogSettings.$type += $tmpObj
					}
				}
				"Security Options" {
					while($private.rsopSource[$startLine+$block].trim() -ne ''){ $block++}; $block = $block+2;
					for($l = $startLine; $l -lt $endLine; $l = $l+$block){
						$tmpObj = @{}
						for($bl = 0; $bl -lt $block; $bl++){
							if($private.rsopSource[$l+$bl].trim() -ne ''){
								$tmpObj.$("$($private.rsopSource[$l+$bl].split(':')[0])".trim()) = $("$($private.rsopSource[$l+$bl].split(':')[1])".trim())
							}
						}
						$private.settings.secOpts.$type += $tmpObj
					}
				}
			}
			$i++
		}

		
	}
	
	constructor{
		param([string]$path = '')
		if($utilities.isBlank($path) -eq $true){
			$private.rsopSource = ( gpresult /v)
		}else{
			$private.rsopSource= gc $($path)
		}
		
		

	}
}