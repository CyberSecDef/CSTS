method -private showACAS{
	$i = 0
	$webVars = @{}

	$tmp = $( $private.xml.cstsPackage.scans.acas.scan  | sort { $_.fileName } | % { 
	$i = $i + 1;
@"
<tr>
	<td><input type="checkbox" class="asset_checkbox" id="acas_$($_.id)" /></td>
	<td>$($i)</td>
	<td>$($_.fileName)</td>
	<td>$($_.policyName)</td>
	<td>$($_.scanDate)</td>
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
		$_.hosts.host | sort { $_.fqdn } | % {
			if($_ -ne $null){
				if($_.fqdn.indexOf('.') -gt 0){
					$h = $_.fqdn.substring(0, $_.fqdn.indexOf('.')  )
				}else{
					$h = $_.fqdn
				}
			}

			if($private.xml.cstsPackage.assets.asset | ? { $_.hostName.toUpper().Trim() -eq $h}){
				"<span class='label label-success'>$h</span>"
			}else{
				"<span class='label label-warning'>$h</span>"
			}
			
		}
	)</td>
</tr>
"@
});

	$webVars['acasScanList'] = $tmp

	$webVars['pwd'] = $pwd
	$webVars['package'] =  $private.package.toUpper()
	$webVars['mainContent'] = gc "$($pwd)\wwwroot\views\packageManager\scans\acas.tpl"
	$html = $private.renderTpl("packageManagerDefault.tpl", $webVars)
	$private.displayHtml( $html  )
}
	
method -private scansReloadAcasButtonClick{

	if( ( $private.xml.cstsPackage.scans.acas -is 'System.String' ) -ne $true ){
		$private.xml.cstsPackage.scans.acas.removeAll()
	}

	$acasScans = ls "$($pwd)\packages\$($private.package)\scans\acas\"
	$private.findings.selectSingleNode('//cstsPackage/findings/acas').isEmpty = $true
	
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Reloading ACAS Scan Data"
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$i = 0
	$total = $acasScans.length
	foreach($acasScan in $acasScans){
		$i = $i + 1
		$p = $( [Math]::round( (100 * $i / $total),0)  )
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p
		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: $($i) / $($total) - Reloading ACAS Scan Data from $($acasScan.name)"


		$shell = new-object -com shell.application
		$zip = $shell.NameSpace($acasScan.fullname)
		$shell.Namespace("$(pwd)\temp").copyhere(($zip.items()))
		$nessus = ([xml](gc "$($pwd)\temp\$(($zip.items()) | select -expand name)" -readcount 0))
		remove-item "$($pwd)\temp\$(($zip.items()) | select -expand name)"

		$scanId = [guid]::newGuid().guid
		$scan = $private.xml.createElement('scan')
		$scan.setAttribute("id", $scanId)

		@('fileName','policyName','scanDate','hosts','scanName') | %{ $scan.appendChild( $private.xml.createElement( $_ ) ) }

		$scan.selectSingleNode('fileName').appendChild($private.xml.createTextnode( $acasScan.name ));
		$scan.selectSingleNode('policyName').appendChild($private.xml.createTextnode( $nessus.NessusClientData_v2.Policy.PolicyName ));
		$scan.selectSingleNode('scanName').appendChild($private.xml.createTextnode( $nessus.NessusClientData_v2.Report.name ));
		
		$scan.selectSingleNode('scanDate').appendChild($private.xml.createTextnode( [datetime]::ParseExact( ( $nessus.NessusClientData_v2.Report.ReportHost[0].HostProperties.tag | ? { $_.name -eq 'HOST_START' } | select -expand '#text' ),'ddd MMM d H:mm:ss yyyy',$null, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces).ToShortDateString() ) );


		#scan info
		$nessus.NessusClientData_v2.Report.ReportHost | % {
			$acasHost = $private.xml.createElement('host')
			@('fqdn', 'ip', 'credentialed', 'scanDate') | %{ $acasHost.appendChild( $private.xml.createElement( $_ ) ) }

			$acasHost.selectSingleNode('fqdn').appendChild( $private.xml.createTextnode( ( $_.HostProperties.tag | ? { $_.name -eq 'host-fqdn' } | select -expand '#text' ) )  );
			$acasHost.selectSingleNode('ip').appendChild( $private.xml.createTextnode( ( $_.HostProperties.tag | ? { $_.name -eq 'host-ip' } | select -expand '#text' ) )  );
			$acasHost.selectSingleNode('credentialed').appendChild( $private.xml.createTextnode( ( $_.HostProperties.tag | ? { $_.name -eq 'Credentialed_Scan' } | select -expand '#text' ) )  );
			$acasHost.selectSingleNode('scanDate').appendChild( $private.xml.createTextnode( 
				[datetime]::ParseExact( ( $_.HostProperties.tag | ? { $_.name -eq 'HOST_START' } | select -expand '#text' ) ,'ddd MMM d H:mm:ss yyyy',$null, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces).ToShortDateString() 
			)  );

			$scan.selectSingleNode('hosts').appendChild( $acasHost );
			
			#findings data
			$fqdn = ( $_.HostProperties.tag | ? { $_.name -eq 'host-fqdn' } | select -expand '#text' )
			if($fqdn.indexOf('.') -gt 0){
				$h = $fqdn.substring(0, $fqdn.indexOf('.')  )
			}else{
				$h = $fqdn
			}
			
			$_.ReportItem | %{
				[System.Windows.Forms.Application]::DoEvents() 
				
				$finding = $private.findings.selectSingleNode("//cstsPackage/findings/acas/finding[./source='ACAS' and ./pluginId = '$($_.pluginId)']")
				
				if($finding -eq $null){
					$finding = $private.findings.createElement( 'finding' )
					@('iaControl', 'source', 'group', 'vulnId', 'ruleId', 'pluginId', 'description', 'riskStatement', 'rawRisk', 'impact', 'likelihood', 'correctiveAction', 'mitigation', 'remediation', 'residualRisk', 'status', 'comments', 'scd', 'resources', 'milestones', 'assets' ) | %{ $finding.appendChild( $private.findings.createElement( $_ ) ) }

					$finding.selectSingleNode('source').innerText = 'ACAS'
					$finding.selectSingleNode('group').innerText = $_.pluginFamily
					$finding.selectSingleNode('pluginId').innerText = $_.pluginID
					$finding.selectSingleNode('description').innerText = $_.description
					$finding.selectSingleNode('riskStatement').innerText = $_.synopsis
					$finding.selectSingleNode('rawRisk').innerText = $_.risk_factor
					$finding.selectSingleNode('impact').innerText = $_.severity
					$finding.selectSingleNode('likelihood').innerText = $_.risk_factor
					$finding.selectSingleNode('correctiveAction').innerText = $_.solution
					$finding.selectSingleNode('status').innerText = 'Ongoing'
					
					$finding.setAttribute("id", [guid]::newGuid().guid)
					$finding.setAttribute("scanId", $scanId)
					
					$private.findings.selectSingleNode('//cstsPackage/findings/acas').appendChild($finding);
				}
				
				$asset = $private.findings.createElement( 'asset' )
				$asset.setAttribute('status', 'Ongoing')
				
				$comments = $_.plugin_output
				$asset.appendChild($private.findings.createElement('comments'))
				$asset.selectSingleNode('comments').appendChild($private.findings.createTextNode( $comments ) )
				
				$asset.setAttribute('hostname',$h)
				
				$assetNode = $private.xml.selectSingleNode("//cstsPackage/assets/asset[translate(./hostname,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ') = '$( $h.toString().toUpper() )']")
				$asset.setAttribute('assetId',$assetNode.id)
				
				$asset.setAttribute("scanId", $scanId)
				
				$finding.selectSingleNode('assets').appendChild($asset)
			}
		}

		$private.xml.selectSingleNode('//cstsPackage/scans/acas').appendChild($scan);
		
		
		#finding info
		
		$private.findings.save( "$($pwd)\packages\$($private.package)\findings.xml")
		$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	}

	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: "
	$private.showACAS()

}

method -private scansRemoveAcasButtonClick{
	$private.getElementsByClassName('asset_checkbox') | % {
		if( $_.GetAttribute('checked') -eq $true){
			$id = $_.id -replace 'acas_',''

			$private.xml.selectNodes("//cstsPackage/scans/acas/scan[@id='$($id)']") | % {
				$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Removing $($_.fileName)"
				$_.ParentNode.RemoveChild($_)
			}
		}
	}

	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showAcas()
}