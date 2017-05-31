$scapClass = New-PSClass scap{
	note -private xccdfPath
	note -private xccdfXml
	note -private xccdfNs
	
	note -private ovalPath
	note -private ovalXml
	note -private ovalNs
	
	note -private profile
	
	note -private entries @()
	
	note -private title ""
	
	property title -get {return $private.title}
	property entries -get {return ,$private.entries}
	property xccdfPath -get {return $private.xccdfPath}
	property ovalPath -get {return $private.ovalPath}
	property profile -get {return $private.profile}
	
	method parseXccdf{
		[xml]$private.xccdfXml = (gc $private.xccdfPath)
		$private.xccdfNs = new-object Xml.XmlNamespaceManager $private.xccdfXml.NameTable
		$private.xccdfNs.AddNamespace("dsig", "http://www.w3.org/2000/09/xmldsig#" );
		$private.xccdfNs.AddNamespace("xhtml", "http://www.w3.org/1999/xhtml" );
		$private.xccdfNs.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance" );
		$private.xccdfNs.AddNamespace("cpe", "http://cpe.mitre.org/language/2.0" );
		$private.xccdfNs.AddNamespace("dc", "http://purl.org/dc/elements/1.1/" );
		$private.xccdfNs.AddNamespace("ns", "http://checklists.nist.gov/xccdf/1.1" );
	}
	
	method parseOval{
		[xml]$private.ovalXml = (gc $private.ovalPath)
		$private.ovalNs = new-object Xml.XmlNamespaceManager $private.ovalXml.NameTable
		$private.ovalNs.AddNamespace("ns", "http://oval.mitre.org/XMLSchema/oval-definitions-5" );
		$private.ovalNs.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance" );
		$private.ovalNs.AddNamespace("win", "http://oval.mitre.org/XMLSchema/oval-definitions-5#windows" );
		$private.ovalNs.AddNamespace("win-def", "http://oval.mitre.org/XMLSchema/oval-definitions-5#windows" );
	}
	
	method reset{
		$private.entries = @()
	}
	
	constructor{
		param($xccdfPath, $ovalPath, $profile )
		$private.xccdfPath = $xccdfPath
		$private.ovalPath = $ovalPath
		$private.profile = $profile
				
				
		if($utilities.isBlank($profile) -eq $false -and $utilities.isBlank($xccdfPath) -eq $false -and $utilities.isBlank($ovalPath) -eq $false){
			if( (test-path $private.xccdfPath) -and (test-path $private.ovalPath) ){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Parsing #yellow#$($private.xccdfPath)#")
				$this.parseXccdf()
				$this.parseOval()
			}else{
				$uiClass.writeColor(
					( "$($uiClass.STAT_ERROR) Missing Scap Files/Data:`n`tXCCDF  : #yellow#{0}#`n`tOVAL   : #yellow#{1}#`n`tProfile: #yellow#{2}#" -f $xccdfPath,$ovalPath,$profile )
				)
				return false
			}
		}else{
			$uiClass.writeColor(
				( "$($uiClass.STAT_ERROR) Missing Scap Files/Data:`n`tXCCDF  : #yellow#{0}#`n`tOVAL   : #yellow#{1}#`n`tProfile: #yellow#{2}#" -f $xccdfPath,$ovalPath,$profile )
			)
			return false
		}
		
	}
	
	method parseScap{
		$private.title = ($private.xccdfXml.selectSingleNode("/ns:Benchmark/ns:title", $private.xccdfNs)).'#text'
		
		foreach($rule in ($private.xccdfXml.selectNodes("/ns:Benchmark/ns:Profile[@id='$($private.profile)']/ns:select[@selected='true']/@idref", $private.xccdfNs))){
			foreach($group in ($private.xccdfXml.selectNodes("//ns:Group[@id=`'$($rule.'#text')`']/ns:Rule/ns:check/ns:check-content-ref/@name", $private.xccdfNs))){
				foreach($test in ($private.ovalXml.selectNodes("//ns:oval_definitions/ns:definitions/ns:definition[@id=`'$($group.'#text')`']/ns:criteria/ns:criterion/@test_ref", $private.ovalNs) )){
					if($cstsClass.verbose){
						$uiClass.writeColor("$($uiClass.STAT_OK) Consuming Test #yellow#$($test.'#text')#")
					}
					$obj = ($private.ovalXml.selectNodes("//ns:oval_definitions/ns:tests/win:registry_test[@id=`'$($test.'#text')`']/win:object/@object_ref", $private.ovalNs) | select '#text').'#text'
					$state = ($private.ovalXml.selectNodes("//ns:oval_definitions/ns:tests/win:registry_test[@id=`'$($test.'#text')`']/win:state/@state_ref", $private.ovalNs)  | select '#text').'#text'
					
					$regObj = $private.ovalXml.selectNodes("//ns:oval_definitions/ns:objects/win:registry_object[@id=`'$($obj)`']", $private.ovalNs)
					if($regObj -ne $null){
						$regState = $private.ovalXml.selectSingleNode("//ns:oval_definitions/ns:states/win:registry_state[@id=`'$($state)`']", $private.ovalNs)
						if($regState -ne $null -and $regState.value.operation -ne 'pattern match'){
							if( ( ($regState | select type ).type.var_ref ) -like '*:var:*' ){
								$typeVar = ($private.ovalXml.selectSingleNode("//*[@id=`'$( ( ($regState | select type ).type.var_ref ) )`']", $private.ovalNs) | select value).value
							}else{
								$typeVar = $utilities.xmlText( ($regState | select Type ).type )
							}
							
							if($utilities.isBlank($typeVar) -eq $true){
								$typeVar = 'reg_dword'
							}
							
							if( ( ($regState | select Value ).Value.var_ref ) -like '*:var:*' ){
								if(
									$utilities.isBlank( ($private.xccdfXml.selectSingleNode("//*[@export-name=`'$( ( ($regState | select Value ).Value.var_ref ) )`']", $private.xccdfNs) ) ) -eq $false
								){
									$varRef = ($regState | select Value ).Value.var_ref
									$varName = ($private.xccdfXml.selectSingleNode("//*[@export-name='$($varRef)']", $private.xccdfNs) | select -expand 'value-id')
									$valueVar = ( $private.xccdfXml.selectSingleNode("//*[@id='$($varName)']", $private.xccdfNs) | select -expand value | ? { $_.selector -eq $null } )
								}else{
									$valueVar = ( ($private.ovalXml.selectSingleNode("//*[@id=`'$( ( ($regState | select Value ).Value.var_ref ) )`']", $private.ovalNs) | select value).value )
								}
								
							}else{
								$valueVar = $utilities.xmlText( ($regState | select Value ).Value )
							}
							
							$entry = @{
								"hive" = ($utilities.xmlText( ( $regObj | select Hive ).hive ));
								"keyName" = ($utilities.xmlText( ( $regObj | select Key ).key ));
								"valueName" = ($utilities.xmlText( ( $regObj | select Name ).name ));
								"value" = ($valueVar);
								"type" = ($typeVar);
								"action" = "U"
							}
							$private.entries += $entry
						}
					}
				}
			}
		}
	}
} 