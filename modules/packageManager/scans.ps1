method -private showScans{
	$private.showWait()
	$i = 0
	$webVars = @{}

	$webVars['acasOldScan30'] = $( $private.xml.cstsPackage.scans.acas.scan | ? { 
		(new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -ge 30 -and (new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -lt 45
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.fileName)</td> <td>$($_.policyName)</td> <td>$($_.scanDate)</td> <td>$( if($_.hosts.host -eq $null){ 0 }elseif($_.hosts.host.count -eq $null){ 1 }else{ $_.hosts.host.count } )</td> </tr> "
	})

	$i = 0
	$webVars['acasOldScan45'] = $( $private.xml.cstsPackage.scans.acas.scan | ? { 
		(new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -ge 45 -and (new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -lt 60
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.fileName)</td> <td>$($_.policyName)</td> <td>$($_.scanDate)</td> <td>$( if($_.hosts.host -eq $null){ 0 }elseif($_.hosts.host.count -eq $null){ 1 }else{ $_.hosts.host.count } )</td> </tr> "
	})

	$i = 0
	$webVars['acasOldScan60'] = $( $private.xml.cstsPackage.scans.acas.scan | ? { 
		(new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -ge 60 -and (new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -lt 90
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.fileName)</td> <td>$($_.policyName)</td> <td>$($_.scanDate)</td> <td>$( if($_.hosts.host -eq $null){ 0 }elseif($_.hosts.host.count -eq $null){ 1 }else{ $_.hosts.host.count } )</td> </tr> "
	})

	$i = 0
	$webVars['acasOldScan90'] = $( $private.xml.cstsPackage.scans.acas.scan | ? { 
		(new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -ge 90
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.fileName)</td> <td>$($_.policyName)</td> <td>$($_.scanDate)</td> <td>$( if($_.hosts.host -eq $null){ 0 }elseif($_.hosts.host.count -eq $null){ 1 }else{ $_.hosts.host.count } )</td> </tr> "
	})


	$i = 0
	$webVars['nonCred'] = $( $private.xml.cstsPackage.scans.acas.scan | ? { $_.hosts.host.credentialed -eq 'false' } | sort { $_.scanDate } | % { 
		foreach($h in ( $_.hosts.host ) ){
			if( $h.credentialed -eq 'false' ){
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.fileName)</td> <td>$($_.policyName)</td> <td>$($h.scanDate)</td> <td> $($h.fqdn) </td> <td> $($h.ip) </td> </tr> "
			}
		}
	})
	
	$i = 0
	$packageHosts = @()
	$private.xml.selectNodes('//cstsPackage/assets/asset/hostname') | % {
		$packageHosts += $_.'#text'
	}
	
	$acasHosts = @()
	$private.xml.selectNodes('//cstsPackage/scans/acas/scan/hosts/host/fqdn') | % {
		$acasHosts += ( $_.'#text' -split '\.' | select -first 1 @{n='hostname';e={"$($_)".ToUpper()}} | select -expand hostname )
	}
	
	$scapHosts = @()
	$private.xml.selectNodes('//cstsPackage/scans/scap/scan/hosts/host/hostname') | % {
		$scapHosts += ( $_.'#text' -split '\.' | select -first 1 @{n='hostname';e={"$($_)".ToUpper()}} | select -expand hostname )
	}
	
	$webVars['extraAcasHosts'] = $( $private.xml.cstsPackage.scans.acas.scan | sort { $_.scanDate } | % { 
		foreach($h in ( $_.hosts.host ) ){
			if( $packageHosts -notContains ( $h.fqdn -split '\.' | select -first 1 @{n='hostname';e={"$($_)".ToUpper()}} | select -expand hostname )){
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.fileName)</td> <td>$($_.policyName)</td> <td>$($h.scanDate)</td> <td> $($h.fqdn) </td> <td> $($h.ip) </td> </tr> "
			}
		}
	})
	
	$i = 0
	$webVars['extraScapHosts'] = $( $private.xml.cstsPackage.scans.scap.scan | sort { $_.benchmark } | % { 
		foreach($h in ( $_.hosts.host | sort {$_.hostname} ) ){
			if( $packageHosts -notContains $h.hostname){
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.benchmark)</td> <td>V$($_.version)R$($_.release)</td> <td>$($h.hostname)</td> <td> $($h.scanDate) </td> <td> $($h.score) </td> </tr> "
			}
		}
	})
	
	$i = 0
	$webVars['missingAcasHosts'] = $( 
		foreach($h in $packageHosts ){
			if( $acasHosts -notContains $h ){
				$i = $i + 1;
				$hData = ($private.xml.cstsPackage.assets.asset | ? { $_.hostname -eq $h })
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($hData.hostname)</td> <td>$($hData.ip)</td> <td>$($hData.manufacturer)</td> <td>$($hData.model)</td> <td>$($hData.firmware)</td>  </tr> "
			}
		}
	)

	$i = 0
	$webVars['acasReqCredMissRows'] = $( 
		foreach($h in ( $private.xml.cstsPackage.requirements.acas.hosts.host | ? { $_.credentialed -eq 'True'}  | select -expand assetId | % { $assetId = $_; $private.xml.cstsPackage.assets.asset | ? { $_.id -eq $assetId } }  ) ){
			if( $acasHosts -notContains $h.hostname ){
				$i = $i + 1;

				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($h.hostname)</td> <td>$($h.ip)</td> <td>$($h.manufacturer)</td> <td>$($h.model)</td> <td>$($h.firmware)</td>  </tr> "
			}
		}
	)
	
	
	
	
	$webVars['missingScapScans'] = $( 
		foreach($reqScap in ( $private.xml.cstsPackage.requirements.scaps.scap ) ){
			
			
			if( ($private.xml.cstsPackage.scans.scap.scan | ? { $_.benchmark -eq $reqScap.title -and $_.version -eq $reqScap.version -and $_.release -eq $reqScap.release } ) -eq $null ){
			#missing scap in general
@"			
<tr>
	<td><input type='checkbox' class='asset_checkbox' id='scap$($_.id)' /></td> 
	<td>$($reqScap.title)</td> <td>$($reqScap.version)</td> <td>$($reqScap.release)</td>
	<td>$(
		$reqScap.hosts.host | % {
			"<span class='label label-primary'> $( $private.xml.selectSingleNode("//cstsPackage/assets/asset[@id = '$($_.assetId)']/hostname") | select -expand '#text' )</span>&nbsp;"
		}
	)</td>
</tr>
"@
			}else{
				#see if the actual hosts required have the scap 'title, version, release, hostname
				$reqScap.hosts.host | % {
					
					$hostScapScans = $private.xml.selectNodes("//cstsPackage/scans/scap/scan[./benchmark='$($reqScap.title)' and ./version='$($reqScap.version)' and ./release='$($reqScap.release)' and ./hosts/host/hostname = //cstsPackage/assets/asset[@id='$($_.assetId)']/hostname ]")
					if($hostScapScans.count -eq 0){
@"			
<tr>
	<td><input type='checkbox' class='asset_checkbox' id='scap$($_.id)' /></td> 
	<td>$($reqScap.title)</td> <td>$($reqScap.version)</td> <td>$($reqScap.release)</td>
	<td>
		<span class='label label-primary'> 
			$( $private.xml.selectSingleNode("//cstsPackage/assets/asset[@id = '$($_.assetId)']/hostname") | select -expand '#text' )
		</span>&nbsp;
	</td>
</tr>
"@						
					}
				}
			}
		}
	)
	
	

	$webVars['cklMissingRows'] = $( 
		foreach($reqCkl in ( $private.xml.cstsPackage.requirements.ckls.ckl ) ){
			
			if(
				($private.xml.cstsPackage.scans.ckls.scan | ? { $_.title -eq $reqCkl.title -and $_.version -eq $reqCkl.version -and $_.release -eq $reqCkl.release } ) -eq $null
			){
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='ckl$($_.id)' /></td> <td>$($reqCkl.title)</td> <td>$($reqCkl.version)</td> <td>$($reqCkl.release)</td></tr> "
			}
		
		}
	)
	
	
	


	
	
	$i = 0
	$dups = @()
	foreach($ah in ( $private.xml.cstsPackage.scans.acas.scan.hosts.host.fqdn ) ){
		$n = $private.xml.cstsPackage.scans.acas.scan.hosts.host | ? { $_.fqdn -eq $ah }
		if($n.count -ne $null -and $n.count -gt 1){
			$dups += $ah
		}
	}
	
	$webVars['duplicateAcasHosts'] = $(
		foreach($dup in ( $dups | sort | select -unique )){
			$hData = ($private.xml.cstsPackage.assets.asset | ? { $_.hostname -eq ( $dup -split '\.' | select -first 1 @{n='hostname';e={"$($_)".ToUpper()}} | select -expand hostname ) })
			if($hData -ne $null){
				$i = $i + 1
@"
<tr> 
<td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> 
<td>$($i)</td> 
<td>$($hData.hostname)</td> 
<td>$($hData.ip)</td> 
<td>$($hData.manufacturer)</td> 
<td>$($hData.model)</td>	
<td>$( $private.xml.selectNodes("//cstsPackage/scans/acas/scan[./hosts/host/fqdn = '$($dup)']") | % { "<span class='label label-info'>$($_.fileName)</span>" })</td>
</tr>

"@
			}
		}
	)
	
	
	
	
	$i = 0
	$webVars['duplicateScapHosts'] = $(
		foreach($scapBenchmark in ($private.xml.cstsPackage.scans.scap.scan )){
			foreach($scapDup in ( $scapBenchmark.hosts.host | group hostname | ? { $_.count -gt 1} ) ){
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($scapBenchmark.id)' /></td> <td>$($i)</td> <td>$($scapBenchmark.benchmark)</td> <td>V$($scapBenchmark.version)R$($scapBenchmark.release)</td> <td>$($scapDup.name)</td>  </tr> "
			}
		}
	)
	
	$i = 0
	$webVars['cklOldScan30'] = $( $private.xml.cstsPackage.scans.ckls.scan | ? { 
		(new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -ge 30 -and (new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -lt 45
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.title)</td> <td>V$($_.version)R$($_.release)</td> <td>$($_.scanDate)</td> <td>$($_.filename)</td> </tr> "
	})
	
	$i = 0
	$webVars['cklOldScan45'] = $( $private.xml.cstsPackage.scans.ckls.scan | ? { 
		(new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -ge 45 -and (new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -lt 60
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.title)</td> <td>V$($_.version)R$($_.release)</td> <td>$($_.scanDate)</td> <td>$($_.filename)</td> </tr> "
	})
	
	$i = 0
	$webVars['cklOldScan60'] = $( $private.xml.cstsPackage.scans.ckls.scan | ? { 
		(new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -ge 60 -and (new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -lt 90
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.title)</td> <td>V$($_.version)R$($_.release)</td> <td>$($_.scanDate)</td> <td>$($_.filename)</td> </tr> "
	})
	
	$i = 0
	$webVars['cklOldScan90'] = $( $private.xml.cstsPackage.scans.ckls.scan | ? { 
		(new-timespan -start ([datetime]"$($_.scanDate)") -end (get-date) | select -expand days) -ge 90 
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.title)</td> <td>V$($_.version)R$($_.release)</td> <td>$($_.scanDate)</td> <td>$($_.filename)</td> </tr> "
	})
	
	$i = 0
	$webVars['cklReqNotRev'] = $( $private.xml.cstsPackage.scans.ckls.scan | ? { 
		$_.notReviewed -ne 0
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($_.title)</td> <td>V$($_.version)R$($_.release)</td> <td>$($_.scanDate)</td> <td>$($_.filename)</td><td>$($_.notReviewed)</td> </tr> "
	})
	
	$i = 0
	$webVars['cklOver10'] = $( $private.xml.cstsPackage.scans.ckls.scan | ? { 
		$open = [int]$_.notReviewed + [int]$_.ongoing
		$all = [int]$_.notReviewed + [int]$_.ongoing + [int]$_.notAFinding + [int]$_.notApplicable
		( ( $open  / $all ) -ge .1 )
	} | sort { $_.scanDate } | % { 
		$i = $i + 1;
		"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td>  <td>$($_.scanDate)</td> <td>$($_.filename.replace('_',' '))</td><td>$($_.ongoing)</td><td>$($_.notReviewed)</td><td>$($_.notAFinding)</td><td>$($_.notApplicable)</td><th> $( [int]$_.notReviewed + [int]$_.ongoing + [int]$_.notAFinding + [int]$_.notApplicable ) </th></tr> "
	})
	

	
	
	$i = 0
	$webVars['scapOldScan30'] = $( $private.xml.cstsPackage.scans.scap.scan | % { 
		$scap = $_
		foreach($scanDate in $_.hosts.host){
			if( (new-timespan -start ([datetime]"$($scanDate.scanDate)") -end (get-date) | select -expand days) -ge 30 -and (new-timespan -start ([datetime]"$($scanDate.scanDate)") -end (get-date) | select -expand days) -lt 45 ){ 
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($scap.benchmark)</td> <td>V$($scap.version)R$($scap.release)</td> <td> $($scanDate.hostname)</td><td>$($scanDate.scanDate)</td> <td>$($scanDate.score)</td> </tr> "
			}
		}
	} )
	
	$i = 0
	$webVars['scapOldScan45'] = $( $private.xml.cstsPackage.scans.scap.scan | % { 
		$scap = $_
		foreach($scanDate in $_.hosts.host){
			if( (new-timespan -start ([datetime]"$($scanDate.scanDate)") -end (get-date) | select -expand days) -ge 45 -and (new-timespan -start ([datetime]"$($scanDate.scanDate)") -end (get-date) | select -expand days) -lt 60 ){ 
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($scap.benchmark)</td> <td>V$($scap.version)R$($scap.release)</td> <td> $($scanDate.hostname)</td><td>$($scanDate.scanDate)</td> <td>$($scanDate.score)</td> </tr> "
			}
		}
	} )
	
	$i = 0
	$webVars['scapOldScan60'] = $( $private.xml.cstsPackage.scans.scap.scan | % { 
		$scap = $_
		foreach($scanDate in $_.hosts.host){
			if( (new-timespan -start ([datetime]"$($scanDate.scanDate)") -end (get-date) | select -expand days) -ge 60 -and (new-timespan -start ([datetime]"$($scanDate.scanDate)") -end (get-date) | select -expand days) -lt 90 ){ 
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($scap.benchmark)</td> <td>V$($scap.version)R$($scap.release)</td> <td> $($scanDate.hostname)</td><td>$($scanDate.scanDate)</td> <td>$($scanDate.score)</td> </tr> "
			}
		}
	} )
	

	$i = 0
	$webVars['scapOldScan90'] = $( $private.xml.cstsPackage.scans.scap.scan | % { 
		$scap = $_
		foreach($scanDate in $_.hosts.host){
			if( (new-timespan -start ([datetime]"$($scanDate.scanDate)") -end (get-date) | select -expand days) -ge 90 ){ 
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($scap.benchmark)</td> <td>V$($scap.version)R$($scap.release)</td> <td> $($scanDate.hostname)</td><td>$($scanDate.scanDate)</td> <td>$($scanDate.score)</td> </tr> "
			}
		}
	} )



	$i = 0
	$webVars['scapBelow90'] = $( $private.xml.cstsPackage.scans.scap.scan | sort { $_.benchmark } |% { 
		$scap = $_
		foreach($scanDate in ( $_.hosts.host | sort { $_.hostname} ) ){
			if( [int]"$($scanDate.score)" -le 90 ){ 
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($scap.benchmark)</td> <td>V$($scap.version)R$($scap.release)</td> <td> $($scanDate.hostname)</td><td>$($scanDate.scanDate)</td> <td>$($scanDate.score)</td> </tr> "
			}
		}
	} )
	
	
	$i = 0
	$webVars['scapNoCkl'] = $( $private.xml.selectNodes("//cstsPackage/scans/scap/scan[not(./benchmark=//cstsPackage/scans/ckls/scan/title)]") | sort { $_.benchmark } |% { 
	
		$scap = $_
		foreach($scanDate in ( $_.hosts.host | sort { $_.hostname} ) ){
			if( [int]"$($scanDate.score)" -le 90 ){ 
				$i = $i + 1;
				"<tr> <td><input type='checkbox' class='asset_checkbox' id='acas_$($_.id)' /></td> <td>$($i)</td> <td>$($scap.benchmark)</td> <td>V$($scap.version)R$($scap.release)</td> <td> $($scanDate.hostname)</td><td>$($scanDate.scanDate)</td> <td>$($scanDate.score)</td> </tr> "
			}
		}
	} )
	
	$i = 0
	$webVars['scapOpenCklClosed'] = $(
		$private.findings.selectNodes("//cstsPackage/findings/scap/finding[./assets/asset/@status='Ongoing']") | % {
			$private.findings.selectNodes("//cstsPackage/findings/ckl/finding[ (status='NotAFinding' or status='NotApplicable' or status='Not Applicable') and ./vulnId='$($_.vulnId)' and ./ruleId = '$($_.ruleId)' and ./group = '$($_.group)' ]") | 				sort { $_.group, $_.vulnId, $_.ruleId } | % {
				$ckl = $private.xml.selectSingleNode("//cstsPackage/scans/ckls/scan[@id='$($_.scanId)']")
				$i = $i + 1;
@"
<tr> 
	<td><input type='checkbox' class='asset_checkbox' id='scap_$($_.id)' /></td> 
	<td>$($ckl.title) V$($ckl.version)R$($ckl.release)</td> 
	<td>$($ckl.filename)</td> 
	<td> $($_.group)</td> 
	<td> $($_.vulnId)</td> 
	<td> $($_.ruleId)</td> 
</tr> 
"@
			
			
			}
		}
	)
	
	
	$webVars['pwd'] = $pwd
	$webVars['package'] =  $private.package.toUpper()
	$webVars['mainContent'] = gc "$($pwd)\wwwroot\views\packageManager\scans.tpl"
	$html = $private.renderTpl("packageManagerDefault.tpl", $webVars)
	$private.displayHtml( $html  )
}