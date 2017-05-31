method -private showScap{
	$i = 0
	$webVars = @{}

	$tmp = $( $private.xml.cstsPackage.scans.scap.scan  | sort { $_.benchmark } | % { 
	$i = $i + 1;

@"
<tr>
	<td><input type="checkbox" class="asset_checkbox" id="scap_$($_.id)" /></td>
	<td>$($i)</td>
	<td>$($_.benchmark)</td>
	<td>V$($_.version)R$($_.release)</td>
	<td>$(
		if($_.hosts.host -eq $null){
			0
		}elseif($_.hosts.host.count -eq $null){
			1
		}else{
			$_.hosts.host.count
		}
	)</td>
	<td class='small'>$(
		$_.hosts.host | sort { $_.hostname } | % {
			$h = $_
			if([int]$h.score -eq 100){
				"<span class='label label-primary' data-toggle='tooltip' data-placement='left' title='Score: $($h.score)' >$($h.hostname)</span>"
			}elseif([int]$h.score -gt 90){
				"<span class='label label-success' data-toggle='tooltip' data-placement='left' title='Score: $($h.score)' >$($h.hostname)</span>"
			}elseif([int]$h.score -gt 80){
				"<span class='label label-warning' data-toggle='tooltip' data-placement='left' title='Score: $($h.score)' >$($h.hostname)</span>"
			}else{
				"<span class='label label-danger' data-toggle='tooltip' data-placement='left' title='Score: $($h.score)' >$($h.hostname)</span>"
			}
		}
	)</td>
</tr>
"@
})

	$webVars['scapScanList'] = $tmp

	$webVars['pwd'] = $pwd
	$webVars['package'] =  $private.package.toUpper()
	$webVars['mainContent'] = gc "$($pwd)\wwwroot\views\packageManager\scans\scap.tpl"
	$html = $private.renderTpl("packageManagerDefault.tpl", $webVars)
	$private.displayHtml( $html  )
}
	
method -private scansReloadScapButtonClick{
	
	if( ( $private.xml.cstsPackage.scans.scap -is 'System.String' ) -ne $true ){
		$private.xml.cstsPackage.scans.scap.removeAll()
	}
	
	$scapScans = ls "$($pwd)\packages\$($private.package)\scans\scap\" -filter "*xccdf*" -recurse
	$private.findings.selectSingleNode('//cstsPackage/findings/scap').isEmpty = $true

	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Reloading SCAP Scan Data"
	sleep 1
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$i = 0
	$total = $scapScans.length
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Reloading SCAP Scan Data"
	foreach($scapScan in $scapScans){
		$i = $i + 1
		$p = $( [Math]::round( (100 * $i / $total),0)  )
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p
		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: $($i) / $($total) - Parsing $($scapScan.name)"
		[System.Windows.Forms.Application]::DoEvents() 
		
		$scap = ([xml](gc $scapScan.fullname -readcount 0))
		 
		[System.Xml.XmlNamespaceManager] $xmlNs = $scap.NameTable
		
		$scap.DocumentElement.Attributes | ?{ $_.Prefix -eq 'xmlns' } | % { 
			$name = ($_.Name).split(":")[1]
			$uri = $_.'#text'
			$xmlNs.AddNamespace($name, $uri)
		}
		

		$benchmark = $scap.Benchmark.title
		$version = $scap.Benchmark.version
		$releaseInfo = ($scap.Benchmark.'plain-text' | ? { $_.id -eq 'release-info' } | select -expand '#text' )
		$release = (( [regex]::matches( $releaseInfo, "Release: ([0-9.]+)") | select groups).groups[1] | select -expand value)
		
		#see if the scan is already listed
		$scan = $private.xml.cstsPackage.scans.scap.scan | ? { $_.benchmark -eq $benchmark -and $_.version -eq $version -and $_.release -eq $release}
		
		if($scan -eq $null){
			$scanId = [guid]::newGuid().guid
			$scan = $private.xml.createElement('scan')
			$scan.setAttribute("id", $scanId)

			@('benchmark','version','release','hosts') | %{ $scan.appendChild( $private.xml.createElement( $_ ) ) }
			$scan.selectSingleNode('benchmark').appendChild($private.xml.createTextnode( $benchmark ));
			$scan.selectSingleNode('version').appendChild($private.xml.createTextnode( $version ));
			$scan.selectSingleNode('release').appendChild($private.xml.createTextnode( $release));
			$private.xml.selectSingleNode('//cstsPackage/scans/scap').appendChild($scan);
		
		}
		
		#add hosts
		$scapHost = $private.xml.createElement('host')
		@('hostname','ip','scanDate','score') | %{ $scapHost.appendChild( $private.xml.createElement( $_ ) ) }

		$scapHost.selectSingleNode('hostname').appendChild( $private.xml.createTextnode( $scap.Benchmark.TestResult.target ) );
		
		$scapHost.selectSingleNode('ip').appendChild( $private.xml.createTextnode( $scap.Benchmark.TestResult.'target-address' ) ) ;
		
		$scapHost.selectSingleNode('scanDate').appendChild( $private.xml.createTextnode( 
			[datetime]::ParseExact( ( $scap.Benchmark.TestResult.'start-time'  ) ,"yyyy-MM-dd'T'HH:mm:ss",$null, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces).ToShortDateString() 
		) );
		
		$scapHost.selectSingleNode('score').appendChild( $private.xml.createTextnode( ( $scap.Benchmark.TestResult.score | ? { $_.system -eq 'urn:xccdf:scoring:spawar-original' } | select -expand '#text' )  ) );

		$scan.selectSingleNode('hosts').appendChild( $scapHost);
		
		$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
		
		$scap.Benchmark.TestResult.'rule-result' | %{
			[System.Windows.Forms.Application]::DoEvents() 
		
			#only create if it doesn't already exist.
			$idRef = $_.idref
			$group = $scap.selectSingleNode("//cdf:Benchmark/cdf:Group[./cdf:Rule/@id='$($idRef)']", $xmlNs)
			$rule = $group.selectSingleNode("//cdf:Rule[@id='$($idRef)']", $xmlNs)
			
			$finding = $private.findings.selectSingleNode("//cstsPackage/findings/scap/finding[./source='SCAP' and ./vulnId = '$($group.id)' and ./ruleId = '$($idRef)']")
			
			if($finding -eq $null){
			
				$finding = $private.findings.createElement( 'finding' )
				$finding.setAttribute("scanId", $scanId)
				$finding.setAttribute("id", [guid]::newGuid().guid)
				@('iaControl', 'source', 'group', 'vulnId', 'ruleId', 'pluginId', 'description', 'riskStatement', 'rawRisk', 'impact', 'likelihood', 'correctiveAction', 'mitigation', 'remediation', 'residualRisk', 'scd', 'resources', 'milestones', 'assets' ) | %{ $finding.appendChild( $private.findings.createElement( $_ ) ) }
				
				$finding.selectSingleNode('source').innerText = 'SCAP'
				$finding.selectSingleNode('ruleId').innerText = $idRef -replace '[^\x09-\x7F]+', ''
							
				
				$finding.selectSingleNode('group').innerText = $group.title -replace '[^\x09-\x7F]+', ''
				$finding.selectSingleNode('vulnId').innerText = $group.id -replace '[^\x09-\x7F]+', ''
				$finding.selectSingleNode('description').innerText = $rule.description -replace '[^\x09-\x7F]+', ''
				$finding.selectSingleNode('riskStatement').innerText = $rule.title -replace '[^\x09-\x7F]+', ''
				$finding.selectSingleNode('rawRisk').innerText = $rule.severity -replace '[^\x09-\x7F]+', ''
				$finding.selectSingleNode('likelihood').innerText = 'Low' -replace '[^\x09-\x7F]+', ''
				$finding.selectSingleNode('correctiveAction').innerText = $rule.fixtext.innerText -replace '[^\x09-\x7F]+', ''
				
				
				if($utilities.isBlank( $rule.description ) -eq $false){
					try{
						$desc = [xml]( "<root>$($rule.description)</root>" )
						$finding.selectSingleNode('iaControl').innerText =  $desc.root.IAControls 
					}catch{
						$finding.selectSingleNode('iaControl').innerText =  ""
					}
				}
			}
			
			$asset = $private.findings.createElement( 'asset' )
			$comments = $_.outerXml
			$asset.appendChild($private.findings.createElement('comments'))
			$asset.selectSingleNode('comments').appendChild($private.findings.createTextNode( $comments ) )
			
			$asset.setAttribute('hostname',$scapHost.selectSingleNode('hostname').innerText)
			$assetNode = $private.xml.selectSingleNode("//cstsPackage/assets/asset[translate(./hostname,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ') = '$( $scapHost.selectSingleNode('hostname').innerText.toString().toUpper()   )']")
			$asset.setAttribute('assetId',$assetNode.id)
			
			if($_.result -eq 'pass'){
				$asset.setAttribute('status', 'Completed')
			}else{
				$asset.setAttribute('status', 'Ongoing')
			}
			
			$finding.selectSingleNode('assets').appendChild($asset)
			
			$private.findings.selectSingleNode('//cstsPackage/findings/scap').appendChild($finding);
		}
		
		$private.findings.save( "$($pwd)\packages\$($private.package)\findings.xml")
		
		
	}

	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: "
	$private.showScap()
	
}

method -private scansRemoveScapButtonClick{
	
	$private.getElementsByClassName('asset_checkbox') | % {
		if( $_.GetAttribute('checked') -eq $true){
			$id = $_.id -replace 'scap_',''

			$private.xml.selectNodes("//cstsPackage/scans/scap/scan[@id='$($id)']") | % {
				$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Removing $($_.fileName)"
				$_.ParentNode.RemoveChild($_)
			}
		}
	}

	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showScap()
}