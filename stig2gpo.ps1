<#
.SYNOPSIS
	This is a script will parse either a STIG or SCAP Results and generate a GPO
.DESCRIPTION
	This is a script will parse either a STIG or SCAP Results and generate a GPO.  It can accept either STIG or SCAP XCCDF/OVAL files
.PARAMETER profile
	which profile, if any, should be selected from the STIG
.PARAMETER xccdfPath
	The path to the XCCDF being parsed
.PARAMETER ovalPath
	The path to the OVAL being parsed
.EXAMPLE
	C:\PS>.\stig2gpo.ps1 -xccdfPath "C:\stigs\U_Windows_7_V1R22_STIG_Benchmark-xccdf.xml" -ovalPath "C:\stigs\U_Windows_7_V1R22_STIG_Benchmark-oval.xml"
	This example will parse the files in the path listed and save the gpo
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS
	All outputs are sent to the console and logged in the log folder
.NOTES
	Todo:  
	Author: Robert Weber
	Date:   Dec 30, 2014
#>
[CmdletBinding()]
Param($profile, $xccdfPath, $ovalPath)

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$stig2GpoClass = new-PSClass Stig2Gpo{
	note -static PsScriptName "stig2gpo"
	note -static Description ( ($(((get-help .\stig2gpo.ps1).Description)) | select Text).Text)
	
	note -private profile
	note -private xccdfPath
	note -private ovalPath
	
	note -private gui

	note -private gpoPolicies @()
	
	method -private text{
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

	method execRegistry{
		param(
			$group,
			$rule,
			$testObj,
			$valueId
		)

		[xml] $xccdfXml = Get-Content $private.xccdfPath
		[xml] $ovalXml  = Get-Content $private.ovalPath

		$registryObj = $ovalXml.selectSingleNode("//*[@id='$($testObj.object.'object_ref')']")
		$registrySte = $ovalXml.selectSingleNode("//*[@id='$($testObj.state.'state_ref')']")
		$valueNode = $xccdfXml.SelectSingleNode("//*[@id='$valueId']")

		$hive = $private.text($registryObj.hive)
		
		$itemList = @()
		#if value nodes present, use them.
		if($valueId -ne $null){
			$selText = $private.text( ($valueNode.value | ? {  $_.selector -eq $null }  | Select -first 1 )) 
			
			$valueNode.value | ? { $_.selector -ne $null } | % {
				$valueNodes = ""
				if( $private.text($_) -eq $selText){
					$selText = "$($_.selector) ($($selText))"
					$itemList += @{ "*** $($_.selector) ***" = $private.text($_) }
				}else{
					$itemList += @{ $_.selector = $private.text($_) }
				}
			}
		}else{
			#if not, use the single value from the oval document and 0 (v-2374)
			
			#can only do this for equals, not pattern matches,  bitwise, etc.
			switch( $true ) {
				($registrySte.value.operation -eq "equals" -or
				$registrySte.value.operation -eq "less than or equal" -or 
				$registrySte.value.operation -eq "greater than or equal" )
				{
					$valueNodes = ""
					$val = $private.text($registrySte.value)
					$selText = "enabled ($val)"
					if( $private.text($val) | isInteger){
						if($private.text($val) -ne 0){
							$itemList += @{ "enabled ($val)" = $val } 
							$itemList += @{ "disabled (0)" = 0} 
						}else{
							$itemList += @{ "enabled ($val)" = $val } 
							$itemList += @{ "disabled ( )" = "" } 
						}
					}else{
						$itemList += @{ "enabled ($val)" = $val } 
						$itemList += @{ "disabled ( )" = "disabled" } 
					}
				}
				
				
				default {
					return $null
				}
			}
			
		}
		
		$ruleDescriptionLink = "$($rule.id)_$($valueId)_$($cryptoClass.Get().GenRandomHash(10))_EXPLAIN".replace("-","_")
		
		#official stigs have ugly xml inside the description, get rid of it
		try{
			[xml] $description =  "<root>" + $private.text($rule.description).replace('"','') + "</root> " 
			$ruleDescription = "$($private.text($description.root.VulnDiscussion ))\n\nIA Controls: $($private.text($description.root.IAControls ))"
		}catch{
			$ruleDescription = $private.text($rule.description).replace('"','')
		}
		
		$ruleDescription += "\nRule Id: $($private.text($rule.id))\nHive: $hive\nKey: $($private.text($registryObj.key))\nName: $($private.text($registryObj.Name))\n\n*** Required Selection: $($selText) ***"
				
		$pol = $gpoPolicyClass.New()
		$pol.Set( "groupId", $group )
		$pol.Set( "polClass", @('USER','MACHINE')[ ( $hive -like '*MACHINE*' ) ])
		$pol.Set( "category", $private.text($xccdfXml.Benchmark.title.replace('/','-').replace(":"," - ") ) )
		$pol.Set( "keyName", $private.text($registryObj.key) )
		$pol.Set( "policy", $group + " - " + $rule.id + " - " + $private.text($rule.title.replace('/','-').replace(":"," - ") ) )
		$pol.Set( "part", $valueId )
		
		if( $private.text($registryObj.Name."#text") -creplace '[^A-Za-z_0-9\.\(\) ]','x' -eq $private.text($registryObj.Name."#text") ){
			$pol.Set( "valueName", $private.text($registryObj.Name."#text") )
		}else{
			$pol.Set( "valueName", $private.text($registryObj.Name) )
		}
		
		
		$pol.Set( "explain", $group + " - " + $rule.id + " - " + $ruleDescription )
		$pol.Set( "explainLink", $ruleDescriptionLink )
		
		
		$itemList | % {  $pol.addItemList(  $_  ) }
		
		return $pol
	}

	method Execute{

		#see if this is a scap or a stig
		#/cdf:Benchmark/cdf:TestResult/cdf:rule-result
		[xml] $xccdfXml = Get-Content $private.xccdfPath
		[xml] $ovalXml  = Get-Content $private.ovalPath

		$admContent = ""

		$groups = $xccdfXml.Benchmark.Group
		
		foreach($group in $groups){
			#see if this group is in the profile
			$continue = $true
			if($profile -ne "" -and $profile -ne $null){
				$profileData = $xccdfXml.SelectSingleNode("//*[@id='$profile']")
				
				$continue = $false
				
				if ( ( $profileData.'select' | ? { $_.idref -eq  $group.id } | ? { $_.selected -eq 'true'} ) -ne $null){
					$continue = $true
				}
			}
		
			if($continue){
				foreach($rule in $group.rule){
					if($rule.check.'check-export'.'value-id' -ne $null){
						$valueId = "$($rule.check.'check-export'.'value-id')"
					}else{
						$valueId = $null
					}

					$ovalDefinitionId = $rule.check.'check-content-ref'.name
					$ovalDefinition = $ovalXml.SelectSingleNode("//*[@id='$ovalDefinitionId']")

					if( ($ovalDefinition.criteria.childNodes ).count -gt 0){
						foreach($criterion in $ovalDefinition.criteria.childNodes ){
							switch( $true ) {
								( $criterion.name -like '*criterion*' ) {
									$testObj = $ovalXml.selectSingleNode("//*[@id='$($criterion.'test_ref')']")
									switch($testObj.name){
										{$_ -like '*registry_test'} {
											$results = $this.execRegistry($group.id, $rule, $testObj, $valueId)
											if($results -ne $null){
												$private.gpoPolicies += $results
												$uiClass.writeColor( "$($uiClass.STAT_OK) Created Policy - #green#$($group.id)# - #green#$($rule.id)# - $( @('','* ')[ ($valueId -eq $null) ] )$( $uiClass.GetShortString( $rule.title.replace('/','-').replace(':',' - '), 60 ) )" -replace "`n","")
											}else{
												$uiClass.writeColor( "$($uiClass.STAT_ERROR) Missing Value - #green#$($group.id)# - #green#$($rule.id)# - $( @('','* ')[ ($valueId -eq $null) ] )$( $uiClass.GetShortString( $rule.title.replace('/','-').replace(':',' - '), 60 ) )" -replace "`n","")
											}
										}
										default { $uiClass.writeColor( "$($uiClass.STAT_ERROR) Bad Object Type - #green#$($group.id)# - #green#$($rule.id)# - $( $uiClass.GetShortString( $rule.title.replace('/','-').replace(':',' - '), 60 ) )" -replace "`n","" ) }
									}
								}
								( $criterion.name -Like "*extend_definition*" ) {
								
								}
								default {
									$uiClass.writeColor( "$($uiClass.STAT_ERROR) Missing Criterion - #green#$($group.id)# - #green#$($rule.id)# - $( $uiClass.GetShortString( $rule.title.replace('/','-').replace(':',' - '), 60 ) ) " -replace "`n","" )
								}
							}
						}
					}else{
						if( $($ovalDefinition.metadata.title ) ) {
							$uiClass.writeColor( "$($uiClass.STAT_ERROR) Missing Criteria - #green#$($ovalDefinition.id)# - $($ovalDefinition.metadata.title.replace('/','-').replace(':',' - ')) " -replace "`n","" )
						}else{
							$uiClass.writeColor( "$($uiClass.STAT_ERROR) Missing Criteria - #green#$($ovalDefinition.id)# " -replace "`n","" )
						}
					}
				}
			}
		}
		$uiClass.errorLog()
	}

	method Export{

		[xml] $xccdfXml = Get-Content $private.xccdfPath
		$ts = (get-date -format "yyyyMMddHHmmss")
		
		$adm = $admClass.New($private.gpoPolicies)
		$adm.Export("$($xccdfXml.Benchmark.title.replace('/','-').replace(':',' - '))_$ts.adm")
		
		$admx = $admxClass.New($private.gpoPolicies, $xccdfXml.Benchmark.title)
		$admx.Export("$($xccdfXml.Benchmark.title.replace('/','-').replace(':',' - '))_$ts.admx")
		
		$adml = $admlClass.New($private.gpoPolicies, $xccdfXml.Benchmark.title)
		$adml.Export("$($xccdfXml.Benchmark.title.replace('/','-').replace(':',' - '))_$ts.adml")
	}
	
	method mode{
		$this.Execute()
		$this.Export() | out-null
	}
	
	constructor{
		param(
			[string] $profile,
			[string] $xccdfPath,
			[string] $ovalPath
		)

		$private.profile = $profile
		$private.xccdfPath = $xccdfPath
		$private.ovalPath = $ovalPath
		
		while($private.xccdfPath -eq "" -or $private.xccdfPath -eq $null -or $private.ovalPath -eq "" -or $private.ovalPath -eq $null -or $private.profile -eq "" -or $private.profile -eq $null){
			$private.gui = $null
			$private.gui = $guiClass.New("stig2gpo.xml")
			$private.gui.generateForm();
			$private.gui.Controls.btnXccdf.add_Click({ 
				$private.gui.Controls.txtXccdf.Text = $private.gui.actInvokeFileBrowser()
				if( (test-path $private.gui.Controls.txtXccdf.Text.replace("xccdf","oval") ) -eq $true -and $private.gui.Controls.txtOval.Text -eq "" ){
					$private.gui.Controls.txtOval.Text = $private.gui.Controls.txtXccdf.Text.replace("xccdf","oval")
				}

				if( (test-path $private.gui.Controls.txtXccdf.Text.replace("xccdf","oval") ) -eq $true ){
					$private.gui.Controls.cboProfile.Items.clear()
					([xml] (gc $private.gui.Controls.txtXccdf.Text)).Benchmark.Profile | % {  $private.gui.Controls.cboProfile.Items.Add($_.title) }
				}
			})
			
			$private.gui.Controls.btnOval.add_Click({ 
				$private.gui.Controls.txtOval.Text = $private.gui.actInvokeFileBrowser() 
				if( ( test-path $private.gui.Controls.txtOval.Text.replace("xccdf","oval") ) -eq $true -and $private.gui.Controls.txtXccdf.Text -eq "" ){
					$private.gui.Controls.txtXccdf.Text = $private.gui.Controls.txtOval.Text.replace("oval","xccdf")
				}
				
				if( (test-path $private.gui.Controls.txtXccdf.Text.replace("xccdf","oval") ) -eq $true ){
					$private.gui.Controls.cboProfile.Items.clear()
					([xml] (gc $private.gui.Controls.txtXccdf.Text)).Benchmark.Profile | % {  $private.gui.Controls.cboProfile.Items.Add($_.title) }
				}
			})
			
			
			$private.gui.Controls.btnExecute.add_Click({ $private.gui.Form.close() })
			$private.gui.Form.ShowDialog()| Out-Null
			
			$private.profile = $private.gui.Controls.cboProfile.Text
			$private.xccdfPath = $private.gui.Controls.txtXccdf.Text
			$private.ovalPath = $private.gui.Controls.txtOval.Text
		}
	}
}

$admxClass = new-PSClass admx{
	note -private policies
	note -private admxTemplate "<?xml version=""1.0"" encoding=""utf-8""?>`n<policyDefinitions xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" revision=""1.0"" schemaVersion=""1.0"" xmlns=""http://schemas.microsoft.com/GroupPolicy/2006/07/PolicyDefinitions""></policyDefinitions>"
	note -private Xml
	note -private stigTitle
	
	constructor{
		param($p,$stigTitle)
		
		$private.policies = $p	
		$private.stigTitle = $stigTitle
		
		$private.Xml = [xml] $private.admxTemplate
		$policyNamespaces = $private.Xml.CreateElement("policyNamespaces", $private.Xml.DocumentElement.NamespaceURI)
		
		$target = $private.Xml.CreateElement("target", $private.Xml.DocumentElement.NamespaceURI)
		$targetPrefix = $private.Xml.CreateAttribute("prefix")
		$targetPrefix.value = "iaWork"
		$targetNameSpace = $private.Xml.createAttribute("namespace")
		$targetNameSpace.value = "IAWork.STIG.GPO.$($cryptoClass.Get().GenRandomHash(10))"
		$target.Attributes.append($targetPrefix)| out-null
		$target.Attributes.append($targetNameSpace)| out-null
		$policyNamespaces.appendChild($target) | out-null
		
		$using = $private.Xml.CreateElement("using", $private.Xml.DocumentElement.NamespaceURI)
		$usingPrefix = $private.Xml.CreateAttribute("prefix")
		$usingPrefix.value = "windows"
		$usingNameSpace = $private.Xml.createAttribute("namespace")
		$usingNameSpace.value = "Microsoft.Policies.Windows"
		$using.Attributes.append($usingPrefix)| out-null
		$using.Attributes.append($usingNameSpace)| out-null
		$policyNamespaces.appendChild($using) | out-null
		
		$private.Xml.policyDefinitions.AppendChild( $policyNamespaces ) | out-null
		
		$resources = $private.Xml.CreateElement("resources", $private.Xml.DocumentElement.NamespaceURI)
		$resMinReq = $private.Xml.CreateAttribute("minRequiredRevision")
		$resMinReq.Value = "1.0"
		$resources.attributes.append($resMinReq) | out-null
		
		$private.Xml.policyDefinitions.AppendChild( $resources ) | out-null
		
		$categories = $private.Xml.CreateElement("categories", $private.Xml.DocumentElement.NamespaceURI)
		
		$category = $private.Xml.CreateElement("category", $private.Xml.DocumentElement.NamespaceURI)
		$catName = $private.Xml.createAttribute("name")
		$catName.Value = "InformationAssurance"
		$displayName = $private.Xml.createAttribute("displayName")
		$displayName.value = "`$(string.CatInfoAssurance)"
		$category.Attributes.append($catName) | out-null
		$category.Attributes.append($displayName) | out-null
		$categories.appendChild($category) | out-null
				
		$category = $private.Xml.CreateElement("category", $private.Xml.DocumentElement.NamespaceURI)
		$catName = $private.Xml.createAttribute("name")
		$catName.Value = $private.stigTitle.Replace(" ","")
		$displayName = $private.Xml.createAttribute("displayName")
		$displayName.value = "`$(string.CatInfoAssuranceStig)"
		$category.Attributes.append($catName) | out-null
		$category.Attributes.append($displayName) | out-null
		
		$parentCategory = $private.Xml.CreateElement("parentCategory", $private.Xml.DocumentElement.NamespaceURI)
		$parentRef = $private.Xml.createAttribute("ref")
		$parentRef.Value = "InformationAssurance"
		$parentCategory.Attributes.append($parentRef) | out-null
		$category.appendChild($parentCategory) | out-null
		
		$categories.appendChild($category) | out-null
		$private.Xml.policyDefinitions.appendChild($categories) | out-null
		
		$policies = $private.Xml.createElement("policies", $private.Xml.DocumentElement.NamespaceURI)
		$policies.Attributes.Append($private.Xml.createAttribute("iaTest")) | out-null
		
		$private.Xml.policyDefinitions.appendChild($policies) | out-null
		
	}
	
	method getPolicy{
		param($p)
		
		$policy = $private.Xml.createElement("policy", $private.Xml.DocumentElement.NamespaceURI)
		
		$pAtts = @{}
		$pAtts.Add("name","$($p.valueName)_$($p.idHash)")
		$pAtts.Add("class",$p.polClass.substring(0,1).toUpper() + $p.polClass.substring(1).toLower())
		$pAtts.Add("displayName","`$(string.$($p.valueName)_$($p.idHash)_display)")
		$pAtts.Add("explainText","`$(string.$($p.valueName)_$($p.idHash)_explain)")
		$pAtts.Add("presentation","`$(presentation.$($p.valueName)_$($p.idHash))")
		$pAtts.Add("key","$($p.keyName)")

		$pAtts.GetEnumerator() | % {
			$tempAtt = $private.Xml.createAttribute($_.Key)
			$tempAtt.Value = $_.Value
			$policy.Attributes.Append($tempAtt) | out-null
		}
		
		$policyParentCat = $private.Xml.createElement("parentCategory", $private.Xml.DocumentElement.NamespaceURI)
		$policyParentCatRef = $private.Xml.createAttribute("ref")
		$policyParentCatRef.value = $private.stigTitle.Replace(" ","")
		$policyParentCat.Attributes.Append($policyParentCatRef) | out-null
		$policy.appendChild($policyParentCat)
		
		$policySupportedOn = $private.Xml.createElement("supportedOn", $private.Xml.DocumentElement.NamespaceURI)
		$policySupportedOnRef = $private.Xml.createAttribute("ref")
		$policySupportedOnRef.value = "windows:SUPPRTED_WindowsVista"
		$policySupportedOn.Attributes.Append($policySupportedOnRef) | out-null
		$policy.appendChild($policySupportedOn)
		
		$policyElements = $private.Xml.createElement("elements", $private.Xml.DocumentElement.NamespaceURI)
		
		$policyElementsEnum = $private.Xml.createElement("enum", $private.Xml.DocumentElement.NamespaceURI)
		$policyElementsEnumId = $private.Xml.createAttribute("id")
		$policyElementsEnumId.Value = "$($p.valueName)_$($p.idHash)_enum"
		$policyElementsEnumValueName = $private.Xml.createAttribute("valueName")
		$policyElementsEnumValueName.value = $p.valueName
		$policyElementsEnumRequired = $private.Xml.createAttribute("required")
		$policyElementsEnumRequired.value = "true"
		$policyElementsEnum.Attributes.Append($policyElementsEnumId)
		$policyElementsEnum.Attributes.Append($policyElementsEnumValueName)
		$policyElementsEnum.Attributes.Append($policyElementsEnumRequired)
		
		$i = 0
		
		$p.itemList | % {
			$item = $private.Xml.createElement("item", $private.Xml.DocumentElement.NamespaceURI)
			$disp = $private.Xml.createAttribute("displayName")
			$disp.value = "`$(string.$($p.valueName)_$($p.idHash)_item_$($i))"
			$item.Attributes.append($disp)
			
			
			$_.GetEnumerator() | % {
				if( ( $_.value | isInteger) ){
					$value = $private.Xml.createElement("value", $private.Xml.DocumentElement.NamespaceURI)
					
					$dec = $private.Xml.createElement("decimal", $private.Xml.DocumentElement.NamespaceURI)
					$decVal = $private.Xml.createAttribute("value")
					$decVal.value = $_.Value
							
					$dec.Attributes.append($decVal) | out-null
					$value.appendChild($dec) | out-null
					
				}else{
					$value = $private.Xml.createElement("value", $private.Xml.DocumentElement.NamespaceURI)
					$string = $private.Xml.createElement("string", $private.Xml.DocumentElement.NamespaceURI)
					$string.appendChild($private.Xml.createTextNode("test")) | out-null
					$value.appendChild($string) | out-null
				}
				$item.appendChild($value)
			}
			$i++
			$policyElementsEnum.appendChild($item)
		}
		
		$policyElements.AppendChild($policyElementsEnum)
		$policy.appendChild($policyElements) | out-null

		$private.Xml.policyDefinitions.policies.appendChild($policy) | out-null
		
	}
	
	method Export{
		param($title)
		
		$private.policies | % {
			$this.getPolicy($_) | out-null
		}
		
		$savePath = [System.io.path]::GetFullPath( ( join-path $pwd "results\$title") )
		
		$private.Xml.Save( $savePath)  | out-null
		
		#and because powershell is stupid with line endings:
		( Get-Content $savePath ) | Set-Content $savePath
		"`n" | add-content $savePath
	}
}

$admlClass = new-PSClass adml{
	note -private policies
	note -private admlTemplate "<?xml version=""1.0"" encoding=""utf-8""?>`n<policyDefinitionResources xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" revision=""1.0"" schemaVersion=""1.0"" xmlns=""http://schemas.microsoft.com/GroupPolicy/2006/07/PolicyDefinitions""></policyDefinitionResources>"
	note -private Xml
	note -private stigTitle
	
	constructor{
		param($p,$stigTitle)
		
		$private.policies = $p	
		$private.stigTitle = $stigTitle
		
		$private.Xml = [xml] $private.admlTemplate
		
		$admlDisplayname = $private.Xml.CreateElement("displayName", $private.Xml.DocumentElement.NamespaceURI)
		$admlDisplayname.appendChild($private.Xml.CreateTextNode("Enter Display Name Here")) | out-null
		
		$admlDescription = $private.Xml.CreateElement("description", $private.Xml.DocumentElement.NamespaceURI)
		$admlDescription.appendChild($private.Xml.CreateTextNode("Enter Description Here")) | out-null
		
		$admlResources = $private.Xml.CreateElement("resources", $private.Xml.DocumentElement.NamespaceURI)
		$admlStringTable = $private.Xml.CreateElement("stringTable", $private.Xml.DocumentElement.NamespaceURI)
		
		$admlPresentationTable = $private.Xml.CreateElement("presentationTable", $private.Xml.DocumentElement.NamespaceURI)
		$admlPresentationTable.Attributes.Append($private.Xml.createAttribute("iaTest")) | out-null
		
		
		$admlResources.appendChild($admlStringTable) | out-null
		$admlResources.appendChild($admlPresentationTable) | out-null

		$string = $private.Xml.Createelement("string", $private.Xml.DocumentElement.NamespaceURI)
		$stringId = $private.Xml.createAttribute("id")
		$stringId.Value = "CatInfoAssurance"
		$string.Attributes.Append($stringId) | out-null
		$string.Appendchild($private.Xml.CreateTextNode("Information Assurance")) | out-null
		$admlStringTable.appendChild($string) | out-null
		
		$string = $private.Xml.Createelement("string", $private.Xml.DocumentElement.NamespaceURI)
		$stringId = $private.Xml.createAttribute("id")
		$stringId.Value = "CatInfoAssuranceStig"
		$string.Attributes.Append($stringId) | out-null
		$string.Appendchild($private.Xml.CreateTextNode($private.stigTitle)) | out-null
		$admlStringTable.appendChild($string) | out-null
		
		
		$private.Xml.policyDefinitionResources.appendChild($admlDisplayname) | out-null
		$private.Xml.policyDefinitionResources.appendChild($admlDescription) | out-null
		$private.Xml.policyDefinitionResources.appendChild($admlResources) | out-null
	}
	
	method getStrings{
		param($p)
		
		$string = $private.Xml.Createelement("string", $private.Xml.DocumentElement.NamespaceURI)
		$stringId = $private.Xml.createAttribute("id")
		$stringId.Value = "$($p.valueName)_$($p.idHash)_explain"
		$string.Attributes.Append($stringId) | out-null
		$string.Appendchild($private.Xml.CreateTextNode( $p.explain.replace("\n","`n"))) | out-null
		$private.Xml.policyDefinitionResources.resources.stringTable.appendChild($string) | out-null
		
		$string = $private.Xml.Createelement("string", $private.Xml.DocumentElement.NamespaceURI)
		$stringId = $private.Xml.createAttribute("id")
		$stringId.Value = "$($p.valueName)_$($p.idHash)_display"
		$string.Attributes.Append($stringId) | out-null
		$string.Appendchild($private.Xml.CreateTextNode( $p.policy))| out-null
		$private.Xml.policyDefinitionResources.resources.stringTable.appendChild($string) | out-null
		
		$i = 0
		$p.itemList | % {
			$_.GetEnumerator() | % {
				$string = $private.Xml.Createelement("string", $private.Xml.DocumentElement.NamespaceURI)
				$stringId = $private.Xml.createAttribute("id")
				$stringId.Value = "$($p.valueName)_$($p.idHash)_item_$($i)"
				$string.Attributes.Append($stringId) | out-null
				$string.Appendchild($private.Xml.CreateTextNode( $_.Name ))| out-null
				$private.Xml.policyDefinitionResources.resources.stringTable.appendChild($string) | out-null
			
				$i++
			}
		}
	}
	
	method getPresentations{
		param($p)
		
		$presentation = $private.Xml.createElement("presentation", $private.Xml.DocumentElement.NamespaceURI)
		$presentationId = $private.Xml.createAttribute("id")
		$presentationId.value = "$($p.valueName)_$($p.idHash)"
		$presentation.Attributes.append($presentationId)
		
		
		$dropDownList = $private.Xml.createElement("dropdownList", $private.Xml.DocumentElement.NamespaceURI)
		$dropDownListRefId = $private.Xml.createAttribute("refId")
		$dropDownListRefId.value = "$($p.valueName)_$($p.idHash)_enum"
		$dropDownList.Attributes.Append($dropDownListRefId)
		$dropDownList.appendChild($private.Xml.createTextnode("Sorted drop-down"))| out-null
		$presentation.appendChild($dropDownList)| out-null
	
		$private.Xml.policyDefinitionResources.resources.presentationTable.appendChild($presentation) | out-null
	}
	
	method Export{
		param($title)
		
		$private.policies | % {
			$this.getStrings($_) | out-null
			$this.getPresentations($_) | out-null
		}
		
		$savePath = [System.io.path]::GetFullPath( ( join-path $pwd "results\$title") )
		$private.Xml.Save( $savePath )  | out-null
		
		#and because powershell is stupid with line endings:
		( Get-Content $savePath ) | Set-Content $savePath 
		"`n" | add-content $savePath 
	}
}

$admClass = new-PSClass adm{
	note -private policies
	
	note -private admTemplate "CLASS {{polClass}}`nCATEGORY ""{{category}}""`n`tKEYNAME ""{{keyName}}""`n`tPOLICY ""{{policy}}""`n`t`tPART ""{{part}}"" DROPDOWNLIST REQUIRED`n`t`t`tVALUENAME ""{{valueName}}""`n`t`tITEMLIST`n[[valueNodes]] `t`t`tEND ITEMLIST`n`t`tEND PART`n`t`tEXPLAIN !!{{explainLink}}`n`tEND POLICY`nEND CATEGORY`n`n"
	
	constructor{
		param($p)
		$private.policies = $p
	}
	
	method getTemplate{
		param($policy)
		
		$template = $private.admTemplate
		
		$policy | gm -memberType scriptProperty | select Name | % { 
			$template = $template -replace "{{$($_.Name)}}",$policy.$($_.Name)
		}
		
		#now the itemLists
		$nodes = ""
		$policy.itemList | % {
			$_.GetEnumerator() | % {
				if( ( $_.value | isInteger) ){
					$nodes += "NAME ""$($_.Name)"" VALUE NUMERIC ""$($_.Value)""`n"
				}else{
					$nodes += "NAME ""$($_.Name)"" VALUE  ""$($_.Value)""`n"
				}
			}
		}
		
		$template = $template -replace "\[\[valueNodes\]\]",$nodes
		
		return $template
	}
	
	method Export{
		param($title)
		$title = $title.replace(':',' - ')
		$private.policies | % { 
			$this.getTemplate($_) | add-content ".\results\$title"
		}
		
		"`n[strings]`n" | add-content ".\results\$title"
		$private.policies | % { 
			"$($_.explainLink)=""$($_.explain)""" | add-content ".\results\$title"
		}
		
		#and because powershell is stupid with line endings:
		( Get-Content ".\results\$title" ) | Set-Content ".\results\$title"
	}
}

$gpoPolicyClass = new-PSClass gpoPolicy{
	note -private polClass 
	note -private category 
	note -private keyName 
	note -private policy 
	note -private part 
	note -private valueName 
	note -private itemList  @()
	note -private explain 
	note -private explainLink 
	note -private groupId
	note -private idHash
	
	property groupId -get{ return $private.groupId} -set{ param($val);$private.groupId = $val}
	property idHash -get{ return $private.idHash} -set{ param($val);$private.idHash = $val}
	property polClass -get{ return $private.polClass} -set{ param($val);$private.polClass = $val}
	property category -get{ return $private.category} -set{ param($val);$private.category = $val}
	property keyName -get{ return $private.keyName} -set{ param($val);$private.keyName = $val}
	property policy -get{ return $private.policy} -set{ param($val);$private.policy = $val}
	property part -get{ return $private.part} -set{ param($val);$private.part = $val}
	property valueName -get{ return $private.valueName} -set{ param($val);$private.valueName = $val}
	property explain -get{ return $private.explain} -set{ param($val);$private.explain = $val}
	property explainLink -get{ return $private.explainLink} -set{ param($val);$private.explainLink = $val}
	property itemList -get{ return $private.itemList } -set{ param($val);$private.itemList = $val}
	
	method addItemList{
		param($val)
		$private.itemList += $val
	}
	
	method Get{
		param($key)
		return $private.$key
	}
	
	method Set{
		param($key, $val)
		$private.$key = $val
	}
	
	constructor{
		$private.idHash = $cryptoClass.Get().GenRandomHash(10)
	}
}

$stig2gpo = $stig2GpoClass.New($profile, $xccdfPath, $ovalPath)
$stig2gpo.Execute()
$stig2gpo.Export()
# .\stig2gpo.ps1 -xccdfPath ".\stigs\U_Windows_7_V1R22_STIG_Benchmark-xccdf.xml" -ovalPath ".\stigs\U_Windows_7_V1R22_STIG_Benchmark-oval.xml" -profile "MAC-1_Classified"