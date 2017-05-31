method -private showCkl{
	$i = 0
	$webVars = @{}

	$tmp = $( $private.xml.cstsPackage.scans.ckls.scan  | sort { $_.title } | % { 
	$i = $i + 1;

@"
<tr>
<td><input type="checkbox" class="asset_checkbox" id="ckl_$($_.id)" /></td>
<td>$($i)</td>
<td>$($_.title)</td>
<td>$(
	if( $_.version -ne '' -and $_.release -ne ''){
		"V$($_.version)R$($_.release)"
	}
)</td>
<td>$($_.ongoing)</td>
<td>$($_.notAFinding)</td>
<td>$($_.notApplicable)</td>
<td>$($_.notReviewed)</td>

</tr>
"@
})

	$webVars['cklScanList'] = $tmp

	$webVars['pwd'] = $pwd
	$webVars['package'] =  $private.package.toUpper()
	$webVars['mainContent'] = gc "$($pwd)\wwwroot\views\packageManager\scans\ckl.tpl"
	$html = $private.renderTpl("packageManagerDefault.tpl", $webVars)
	$private.displayHtml( $html  )
}

method -private scansReloadCklButtonClick{
	
	if( ( $private.xml.cstsPackage.scans.ckls -is 'System.String' ) -ne $true ){
		$private.xml.cstsPackage.scans.ckls.removeAll()
	}

	$cklScans = ls "$($pwd)\packages\$($private.package)\scans\ckl\" -filter "*.ckl" -recurse
	$private.findings.selectSingleNode('//cstsPackage/findings/ckl').isEmpty = $true

	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Reloading CKL Data"
	sleep 1
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$i = 0
	$total = $cklScans.length
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Reloading CKL Data"
	foreach($cklScan in $cklScans){
		$i = $i + 1
		$p = $( [Math]::round( (100 * $i / $total),0)  )
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p
		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: $($i) / $($total) - Parsing $($cklScan.name)"
		[System.Windows.Forms.Application]::DoEvents() 
	
		$ckl = ([xml](gc $cklScan.fullname -readcount 0))
		
		$title = $ckl.CHECKLIST.STIG_INFO.STIG_TITLE
		if($title -eq $null){
			$title = (select-xml "/CHECKLIST/STIGS/iSTIG/STIG_INFO/SI_DATA[./SID_NAME='title']/SID_DATA" $ckl | select -expand Node | select innerXml).innerxml 
		}
		
		#version and release info
		#newer ckls have the data embedded.  Check their first, then check filename
		$version = ''
		$release = ''
		
		$releaseInfo = select-xml "/CHECKLIST/STIGS/iSTIG/STIG_INFO/SI_DATA[./SID_NAME='releaseinfo']/SID_DATA" $ckl | select -expand Node | select -expand innerXml
		if($releaseInfo -ne $null -and $releaseInfo -ne ''){
			$version = (select-xml "/CHECKLIST/STIGS/iSTIG/STIG_INFO/SI_DATA[./SID_NAME='version']/SID_DATA" $ckl | select -expand Node | select innerXml).innerxml
			$release = (  ( ( [regex]::matches( $releaseInfo , "Release: ([0-9.]+)" ) ) | select groups).groups[1] | select -expand value  )
		}
		
		if($version -eq $null -or $release -eq $null){
			$m = ([regex]::matches(  [io.path]::GetFilename( $cklScan ) , "V([0-9]+)R([0-9]+)" ) | select -expand groups)
			if($m.count -ge 1){
				$version = $m[1].value
				$release = $m[2].value
			}
		}
		
		
		
		$ongoing = $ckl.selectNodes("//VULN[./STATUS='Open']").count
		$notAFinding = $ckl.selectNodes("//VULN[./STATUS='NotAFinding']").count
		$notApplicable = $ckl.selectNodes("//VULN[./STATUS='Not_Applicable']").count
		$notReviewed = $ckl.selectNodes("//VULN[./STATUS='Not_Reviewed']").count
		
		
		$scanId = [guid]::newGuid().guid
		$scan = $private.xml.createElement('scan')
		$scan.setAttribute("id", $scanId)

		@('title','version','release','ongoing','notAFinding','notApplicable','notReviewed','filename','scanDate') | %{ $scan.appendChild( $private.xml.createElement( $_ ) ) }
		$scan.selectSingleNode('title').appendChild($private.xml.createTextnode( $title ));
		$scan.selectSingleNode('version').appendChild($private.xml.createTextnode( $version ));
		$scan.selectSingleNode('release').appendChild($private.xml.createTextnode( $release ));
		$scan.selectSingleNode('ongoing').appendChild($private.xml.createTextnode( $ongoing ));
		$scan.selectSingleNode('notAFinding').appendChild($private.xml.createTextnode( $notAFinding ));
		$scan.selectSingleNode('notApplicable').appendChild($private.xml.createTextnode( $notApplicable ));
		$scan.selectSingleNode('notReviewed').appendChild($private.xml.createTextnode( $notReviewed ));
		$scan.selectSingleNode('filename').appendChild($private.xml.createTextnode( $cklScan.name ));
		$scan.selectSingleNode('scanDate').appendChild($private.xml.createTextnode( $cklScan.lastWriteTime.ToShortDateString()  ));
		
		
		$private.xml.selectSingleNode('//cstsPackage/scans/ckls').appendChild($scan);
		$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
		
		
		
		$ckl.selectNodes("//VULN") | %{
			$finding = $private.findings.createElement( 'finding' )
			@('iaControl', 'source', 'group', 'vulnId', 'ruleId', 'pluginId', 'description', 'riskStatement', 'rawRisk', 'impact', 'likelihood', 'correctiveAction', 'mitigation', 'remediation', 'residualRisk', 'status', 'comments', 'scd', 'resources', 'milestones', 'assets' ) | %{ $finding.appendChild( $private.findings.createElement( $_ ) ) }
			
			$finding.setAttribute("id", [guid]::newGuid().guid)
			$finding.setAttribute("scanId", $scanId)
			
			$finding.selectSingleNode('iaControl').innerText = ($_.stig_data | ? { $_.vuln_attribute -eq 'IA_Controls' }).ATTRIBUTE_DATA -replace '[^\x09-\x7F]+', ''
			$finding.selectSingleNode('source').innerText = 'CKL'
			$finding.selectSingleNode('group').innerText = ($_.stig_data | ? { $_.vuln_attribute -eq 'Group_Title' }).ATTRIBUTE_DATA -replace '[^\x09-\x7F]+', ''
			$finding.selectSingleNode('ruleId').innerText = ($_.stig_data | ? { $_.vuln_attribute -eq 'Rule_ID' }).ATTRIBUTE_DATA -replace '[^\x09-\x7F]+', ''
			$finding.selectSingleNode('vulnId').innerText = ($_.stig_data | ? { $_.vuln_attribute -eq 'Vuln_Num' }).ATTRIBUTE_DATA -replace '[^\x09-\x7F]+', ''
			$finding.selectSingleNode('description').innerText = ($_.stig_data | ? { $_.vuln_attribute -eq 'Vuln_Discuss' }).ATTRIBUTE_DATA -replace '[^\x09-\x7F]+', ''
			$finding.selectSingleNode('rawRisk').innerText = ($_.stig_data | ? { $_.vuln_attribute -eq 'Severity' }).ATTRIBUTE_DATA -replace '[^\x09-\x7F]+', ''
			
			$finding.selectSingleNode('likelihood').innerText = "Low"
			$finding.selectSingleNode('correctiveAction').innerText = ($_.stig_data | ? { $_.vuln_attribute -eq 'Fix_Text' }).ATTRIBUTE_DATA -replace '[^\x09-\x7F]+', ''
			$finding.selectSingleNode('status').innerText = ($_.status -replace '[^\x09-\x7F]+', '')
			$finding.selectSingleNode('comments').innerText = ($_.comments -replace '[^\x09-\x7F]+', '')
			
			$hostName = "$( $ckl.selectSingleNode('//CHECKLIST/ASSET/HOST_NAME').'#text' )"
			$asset = $private.findings.createElement( 'asset' )
			$asset.setAttribute('hostname', $hostname  )
			
			$assetNode = $private.xml.selectSingleNode("//cstsPackage/assets/asset[translate(./hostname,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ') = '$( $hostname.toString().toUpper() )']")
			$asset.setAttribute('assetId',$assetNode.id)
			
			$finding.selectSingleNode('assets').appendChild($asset)
				
			
			$private.findings.selectSingleNode('//cstsPackage/findings/ckl').appendChild($finding);
		}
		
		$private.findings.save( "$($pwd)\packages\$($private.package)\findings.xml")
	}

	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: "
	$private.showCKL()
}

method -private scansRemoveCklButtonClick{
	
	$private.getElementsByClassName('asset_checkbox') | % {
		if( $_.GetAttribute('checked') -eq $true){
			$id = $_.id -replace 'ckl_',''

			$private.xml.selectNodes("//cstsPackage/scans/ckls/scan[@id='$($id)']") | % {
				$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Removing $($_.fileName)"
				$_.ParentNode.RemoveChild($_)
			}
		}
	}

	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showCkl()
}