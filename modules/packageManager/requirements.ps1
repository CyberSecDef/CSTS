method -private showRequirements{
	$webVars = @{}
	$private.showWait();

	$i = 0
	$webVars['reqSummaryTab'] = $(
	
		"<tr><td><input type='checkbox'/></td><td>ACAS</td><td>Credentialed ACAS Scan</td><td>NA</td><td>NA</td><td>"
		$private.xml.selectNodes("//cstsPackage/assets/asset[@id=//cstsPackage/requirements/acas/hosts/host[translate(@required,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHJIKLMNOPQRSTUVWXYZ')='TRUE' and translate(@credentialed,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHJIKLMNOPQRSTUVWXYZ')='TRUE']/@assetId]") | sort { $_.hostname } | % { 
			"<span class='label label-primary'>$($_.hostname)</span>"
		}
		"</td></tr>"
	
		"<tr><td><input type='checkbox'/></td><td>ACAS</td><td>Non-Credentialed ACAS Scan</td><td>NA</td><td>NA</td><td>"
		$private.xml.selectNodes("//cstsPackage/assets/asset[@id=//cstsPackage/requirements/acas/hosts/host[translate(@required,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHJIKLMNOPQRSTUVWXYZ')='TRUE' and translate(@credentialed,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHJIKLMNOPQRSTUVWXYZ')='FALSE']/@assetId]") | sort { $_.hostname } | % { 
			"<span class='label label-primary'>$($_.hostname)</span>"
		}
		"</td></tr>"
		
		
		$private.xml.selectNodes("//cstsPackage/requirements/ckls/ckl") | sort { $_.title} | % {
@"
	<tr>
		<td><input type='checkbox'></td>					
		<td>CKL</td>
		<td>$($_.title)</td>
		<td>$($_.version)</td>
		<td>$($_.release)</td>
		<td></td>
	</tr>
"@		
		}

		
		
		$private.xml.selectNodes("//cstsPackage/requirements/scaps/scap") | sort { $_.title} | % { 
@"
	<tr>
		<td><input type='checkbox'></td>					
		<td>SCAP</td>
		<td>$($_.title)</td>
		<td>$($_.version)</td>
		<td>$($_.release)</td>
		<td>$(
			$_.hosts.host | % {
				"<span class='label label-primary'>$( $private.xml.selectSingleNode("//cstsPackage/assets/asset[@id='$($_.assetId)']/hostname") | select -expand '#text' )</span>"
			}
		)</td>
	</tr>
"@			
		}
		
		
		
	)
		
		
	
	$i = 0
	$webVars['reqAcasTab'] = $( $private.xml.cstsPackage.assets.asset | sort { $_.hostname } | % { 
$i = $i + 1;
$req = @("","checked='checked'")[  $( [bool]( ($private.xml.selectSingleNode("//cstsPackage/requirements/acas/hosts/host[@assetId='$($_.id)']") -ne $null) -and ($private.xml.selectSingleNode("//cstsPackage/requirements/acas/hosts/host[@assetId='$($_.id)']").attributes['required'].value -eq 'True' ) ) ) ]
$cred = @("","checked='checked'")[ $( [bool]( ($private.xml.selectSingleNode("//cstsPackage/requirements/acas/hosts/host[@assetId='$($_.id)']") -ne $null) -and ($private.xml.selectSingleNode("//cstsPackage/requirements/acas/hosts/host[@assetId='$($_.id)']").attributes['credentialed'].value -eq 'True' ) ) ) ]
@"
<tr> 
	<td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> 
	<td>$($_.hostname)</td> 
	<td>$($_.ip)</td> 
	<td> <input type="checkbox" class="acas_scan_req" name="acas_scan_req" data-asset="$($_.id)" data-on-text='YES' data-off-text='NO' $($req)> </td> 
	<td> <input type="checkbox" class="acas_cred_req" name="acas_cred_req" data-asset="$($_.id)" data-on-text='YES' data-off-text='NO' $($cred)> </td> 
</tr> 
"@
	})
	
	
	
	
	$webVars['availCkl'] = $(
		$private.xml.cstsPackage.settings.stigs.manual | sort { $_.title, $_.version, $_.release } | % {
			"<option data-path='$($_.filename)'>$( $_.title -replace 'Security Technical Implementation Guide','' -replace '\(STIG\)','' -replace '  ',' ') V$($_.Version)R$($_.release)</option>"
		}
	)
	
	
	$webVars['selCkl'] = $(
		$private.xml.selectNodes("//cstsPackage/requirements/ckls/ckl") |
		sort { $_.title, $_.version, $_.release } | % {
			"<option data-path='$($_.filename)'>$( $_.title -replace 'Security Technical Implementation Guide','' -replace '\(STIG\)','' -replace '  ',' ' ) V$($_.Version)R$($_.release)</option>"
		}
	)
	
	
	$webVars['availScap'] = $(
		$private.xml.cstsPackage.settings.stigs.benchmark | sort { $_.title, $_.version, $_.release } | % {
			"<option data-path='$($_.filename)'>$( $_.title -replace 'Security Technical Implementation Guide','' -replace '\(STIG\)','' -replace '  ',' ' ) V$($_.Version)R$($_.release)</option>`r`n"
		}
	)
	
	
	
	
	$webVars['reqScapTab'] = $( $private.xml.cstsPackage.assets.asset | sort { $_.hostname } | % { 
		$i = $i + 1;
		$hostname = $_.hostname
		$assetId = $_.id
@"
<tr> 
	<td>$($_.hostname)</td> 
	<td>$($_.ip)</td> 
	<td><select multiple='multiple' class="form-control input-sm" size="10" id="availScap_$($_.id)"> {{availScap}} </select> </td> 
	<td>
		<button class="btn btn-default" onclick="client.requirements.scap.add('availScap_$($_.id)','selScap_$($_.id)');"> --&gt; </button> <br />
		<button class="btn btn-default" onclick="client.requirements.scap.addAll('availScap_$($_.id)');"> &gt; &gt; </button><br /><br />
		<button class="btn btn-default" onclick="client.requirements.scap.remove('selScap_$($_.id)');"> &lt;-- </button><br />
		<button class="btn btn-default" onclick="client.requirements.scap.removeAll('selScap_$($_.id)');"> &lt; &lt; </button><br />
	</td>
	<td>
		<select multiple='multiple' class="form-control input-sm selScap" size="10" id="selScap_$($_.id)">
			$(
				#get all the scap results that exist from committed scans
				
				$private.xml.selectNodes("//cstsPackage/scans/scap/scan[./hosts/host/hostname='$($hostname.ToUpper())']") | Sort { $_.benchmark, $_.version, $_.release } | % { 
					"<option>$( $_.benchmark -replace 'Security Technical Implementation Guide','' -replace '\(STIG\)','' -replace '  ',' ' ) V$($_.version)R$($_.release)</option>`r`n"
				}
			)
			
			$(
				#get all the scap results that exist from committed requirements
				
				$private.xml.selectNodes("//cstsPackage/requirements/scaps/scap[./hosts/host/@assetId='$($assetId)']") | Sort { $_.title, $_.version, $_.release } | % { 
					"<option data-path='$($_.filename)'>$( $_.title -replace 'Security Technical Implementation Guide','' -replace '\(STIG\)','' -replace '  ',' ' ) V$($_.version)R$($_.release)</option>`r`n"
				}
			)
			
			
		</select> 
	</td> 
</tr> 
"@
	})
	
	$webVars['pwd'] = $pwd
	$webVars['package'] =  $private.package.toUpper()
	$webVars['mainContent'] = gc "$($pwd)\wwwroot\views\packageManager\requirements.tpl"
	$html = $private.renderTpl("packageManagerDefault.tpl", $webVars)
	$private.displayHtml( $html  )
	
}


method -private commitRequirements{
	
	#remove all acas nodes
	$private.xml.selectNodes("//cstsPackage/requirements/acas/hosts/host") | %{ $_.parentNode.removeChild($_) }
	
	#add all assets 
	$private.xml.selectNodes("//cstsPackage/assets/asset") | %{
		$acasReq = $private.xml.createElement("host")
		$acasReq.setAttribute('assetId',$_.Id)
		$private.xml.selectSingleNode("//cstsPackage/requirements/acas/hosts").appendChild($acasReq);
	}
	
	$private.getElementsByName('acas_scan_req') | % { 
		$private.xml.selectSingleNode("//cstsPackage/requirements/acas/hosts/host[@assetId='$($_.getAttribute('data-asset'))']").setAttribute('required', $( $_.DomElement.checked ) );
	}
	
	$private.getElementsByName('acas_cred_req') | % { 
		$private.xml.selectSingleNode("//cstsPackage/requirements/acas/hosts/host[@assetId='$($_.getAttribute('data-asset'))']").setAttribute('credentialed', $( $_.DomElement.checked ) );
	}
	
	#remove all ckl nodes
	$private.xml.selectNodes("//cstsPackage/requirements/ckls/ckl") | %{ $_.parentNode.removeChild($_) }
	
	$private.getElementById('sel-stig').DomElement | %{
		$ckl = [xml](gc ".\stigs\$($_.GetAttribute('data-path'))")
		$prop = @{}
		$prop.id = [guid]::newGuid().guid
		$prop.filename = $_.GetAttribute('data-path')  
		$prop.version = $ckl.benchmark.version
		$prop.release = ( ( ( [regex]::matches( ( ($ckl.benchmark.'plain-text' | ? { $_.id -eq 'release-info'} ).'#text' ), "Release: ([0-9.]+)" ) ) | select groups).groups[1] | select -expand value )
		$prop.title = $ckl.Benchmark.title
		
		$cklReq = $private.xml.createElement('ckl')
		$cklReq.setAttribute("id", $prop.id) | out-null
		@('filename','title','version','release') | %{ $cklReq.appendChild( $private.xml.createElement( $_ ) )  | out-null}
		@('filename','title','version','release') | %{
			$cklReq.selectSingleNode( $_ ).appendChild( $private.xml.createTextnode( $prop.$($_) ) ) | out-null;
		}
		
		$private.xml.selectSingleNode('//cstsPackage/requirements/ckls').appendChild($cklReq)  | out-null;
	}
	
	#remove all scap nodes
	$private.xml.selectNodes("//cstsPackage/requirements/scaps/scap") | %{ $_.parentNode.removeChild($_) }
	
	$scapContainer = @{}
	$private.getElementsByClassName('selScap') | ? { $_.children -ne $null} | % {
		$parentId = $_.id;
		foreach($child in $_.children){
			
			if($child.DomElement.GetAttribute('data-path') -eq $null -or $child.DomElement.GetAttribute('data-path') -eq '' -or $child.DomElement.GetAttribute('data-path') -is 'DBNull'){
				$private.xml.cstsPackage.settings.stigs.benchmark | ? { 
					"$($_.title -replace 'Security Technical Implementation Guide','' -replace '\(STIG\)','' -replace '  ',' ' ) V$($_.Version)R$($_.release)" -eq $child.innerText
				} | select -first 1 | % {
					
					if($scapContainer.containsKey( $_.id ) -eq $false){
						$scapContainer.add( $($_.id), @() );
					}
					$scapContainer[$_.id] += $parentId -replace 'selScap_',''
				}
			}else{
				$private.xml.cstsPackage.settings.stigs.benchmark | ? { $_.filename -eq $child.DomElement.GetAttribute('data-path') } | select -first 1 | % {
					if($scapContainer.containsKey( $_.id ) -eq $false){
						$scapContainer.add( $($_.id), @() );
					}
					$scapContainer[$_.id] += $parentId -replace 'selScap_',''
				}
			}
		}
	}
	
	$scapContainer.keys | %{
	
		$s = $private.xml.selectSingleNode("//cstsPackage/settings/stigs/benchmark[@id='$($_)']")
		$scapReq = $private.xml.createElement('scap')
		$scapReq.setAttribute("id", ( [guid]::newGuid().guid ) ) | out-null
		@('filename','title','version','release','hosts') | %{ $scapReq.appendChild( $private.xml.createElement( $_ ) )  | out-null}
		@('filename','title','version','release') | %{
			$scapReq.selectSingleNode( $_ ).appendChild( $private.xml.createTextnode( $s.$($_) ) ) | out-null;
		}
		
		$($scapContainer.$_) | % {
			$shost = $private.xml.createElement('host')
			$shost.setAttribute("assetId", "$($_)") | out-null
			$scapReq.selectSingleNode( 'hosts' ).appendChild($shost)
		}
		
		
		$private.xml.selectSingleNode('//cstsPackage/requirements/scaps').appendChild($scapReq)  | out-null;
		
		
	}
	
	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showRequirements()
}


