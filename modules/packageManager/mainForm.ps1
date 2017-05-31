method -private onClick_mnuFileClose{
	write-host "the File Close Button was clicked"
	$private.gui.Form.close()
}

method -private onClick_mnuFileOpen{
	write-host "the File Open Button was clicked"
}

method -private OnClick_openToolStripMenuItem{
	write-host "in here"
}
	
method -private handleClickEvents{
	param($s, $e)
	
	$benchmark = measure-command{
		switch( $private.gui.controls.webDisplay.document.getElementFromPoint($e.clientMousePosition).ID ){
			"assets_add_hosts_submit" 			{ $private.assetsAddHostsSubmitClick() }
			"assets_remove_hosts_button" 		{ $private.assetsRemoveHostsButtonClick() }
			"assets_edit_hosts_submit" 			{ $private.assetsEditHostsSubmitClick() }
			"assets_reload_hosts_button" 		{ $private.assetsReloadHostsButtonClick() }
			"assets_import_hosts_button" 		{ $private.assetsImportHostsButtonClick() }
			
			"assets_add_software_submit" 		{ $private.assetsAddSoftwareSubmitClick() }
			"assets_remove_software_button" 	{ $private.assetsRemoveSoftwareButtonClick() }
			"assets_edit_software_submit" 		{ $private.assetsEditSoftwareSubmitClick() }
			"assets_reload_software_button" 	{ $private.assetsReloadSoftwareButtonClick() }

			"scans_reload_acas_button" 			{ $private.scansReloadAcasButtonClick() }
			"scans_remove_acas_button" 			{ $private.scansRemoveAcasButtonClick() }
			"scans_reload_scap_button" 			{ $private.scansReloadScapButtonClick() }
			"scans_remove_scap_button" 			{ $private.scansRemoveScapButtonClick() }
			"scans_reload_ckl_button" 			{ $private.scansReloadCklButtonClick() }
			"scans_remove_ckl_button" 			{ $private.scansRemoveCklButtonClick() }
			
			"asset_reload_host_software_submit" { $private.assetReloadHostSoftware() }
			"requirements-commit-updates"		{ $private.commitRequirements() }
			"export-current-report-link"		{ $private.exportCurrentReport() }
			
			"settings-scan-stigs"				{ $private.settingsScanStigs() }
		}
		
		
		
		if( ($private.gui.controls.webDisplay.document.getElementFromPoint($e.clientMousePosition) -ne $null) -and ($private.gui.controls.webDisplay.document.getElementFromPoint($e.clientMousePosition).GetAttribute('className') -like '*capture-me*' )){
			switch( $private.gui.controls.webDisplay.document.getElementFromPoint($e.clientMousePosition).GetAttribute('data-action') ){
					"select_package_hardware" 	{ $private.selectPackageHardware( 	$private.gui.controls.webDisplay.document.getElementFromPoint($e.clientMousePosition).GetAttribute('data-id')); }
					"select_package_software" 	{ $private.selectPackageSoftware( 	$private.gui.controls.webDisplay.document.getElementFromPoint($e.clientMousePosition).GetAttribute('data-id')); }
					"select_package_acas" 		{ $private.selectPackageAcas( 		$private.gui.controls.webDisplay.document.getElementFromPoint($e.clientMousePosition).GetAttribute('data-id')); }
					"select_package_ckl" 		{ $private.selectPackageCkl( 		$private.gui.controls.webDisplay.document.getElementFromPoint($e.clientMousePosition).GetAttribute('data-id')); }
					"select_package_scap" 		{ $private.selectPackageScap( 		$private.gui.controls.webDisplay.document.getElementFromPoint($e.clientMousePosition).GetAttribute('data-id')); }
					
			}
		}
	}
	$private.gui.controls.stbMain.Items['stbBenchmark'].text = [math]::Round( $($benchmark.totalSeconds), 2 )
}

method -private settingsScanStigs{
	$stigs = @()
	$benchmarks = @()
	
	$i = 0
	$sources = ls -recurse $pwd\stigs\*manual-xccdf*.xml 
	$total = $sources.count
	$sources | % {
		$i = $i + 1
		$p = $( [Math]::round( (25 * $i / $total),0)  )
		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: $($i) / $($total) - Adding STIG $($_.name)"
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p
		[System.Windows.Forms.Application]::DoEvents() 
	
		$ckl = [xml](gc $_.fullname)
		$stig = @{}
		$stig.id = ( [guid]::newGuid().guid )
		$stig.fileName = $_.name
		$stig.date = $_.lastWriteTime
		$stig.title = $ckl.benchmark.title
		$stig.version = $ckl.benchmark.version
		$releaseInfo = ($ckl.Benchmark.'plain-text' | ? { $_.id -eq 'release-info' } | select -expand '#text' )
		$stig.release  = (( [regex]::matches( $releaseInfo, "Release: ([0-9.]+)") | select groups).groups[1] | select -expand value)
		
		$stigs += $stig
	}
	
	$i = 0
	$sources = ls -recurse $pwd\stigs\*benchmark-xccdf*.xml 
	$total = $sources.count
	$sources | % {
		$i = $i + 1
		$p = $( [Math]::round( (25 * $i / $total),0)  ) + 25
		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: $($i) / $($total) - Adding Benchmark $($_.name)"
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p
		[System.Windows.Forms.Application]::DoEvents() 
	
		$bench = [xml](gc $_.fullname)
		$benchmark = @{}
		$benchmark.id = ( [guid]::newGuid().guid )
		$benchmark.fileName = $_.name
		$benchmark.date = $_.lastWriteTime
		$benchmark.title = $bench.benchmark.title
		$benchmark.version = $bench.benchmark.version
		$releaseInfo = ($bench.Benchmark.'plain-text' | ? { $_.id -eq 'release-info' } | select -expand '#text' )
		$benchmark.release  = (( [regex]::matches( $releaseInfo, "Release: ([0-9.]+)") | select groups).groups[1] | select -expand value)
		
		$benchmarks += $benchmark
	}
	
	#update all packages
	$i = 0
	$packages = ls .\packages\*\package.xml 
	$total = $packages.count
	
	$packages | %{
		$i = $i + 1
		$p = $( [Math]::round( (50 * $i / $total),0)  ) + 50
		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: $($i) / $($total) - Updating $($_.fullname)"
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p
		[System.Windows.Forms.Application]::DoEvents() 
		
		$package = [xml](gc $_.fullname)
		
		$stigsNode = $package.selectSingleNode("//cstsPackage/settings/stigs")
		if($stigsNode -ne $null){
			$stigsNode.removeAll()
		}
		
		$stigs | % {
			$stig = $package.createElement('manual')
			$stig.setAttribute("id", $_.id)
			
			@('filename','title','version','release','date') | %{ $stig.appendChild( $package.createElement( $_ ) ) }
			$stig.selectSingleNode('filename').appendChild( $package.createTextnode( $_.fileName ))
			$stig.selectSingleNode('title').appendChild( $package.createTextnode( $_.title ))
			$stig.selectSingleNode('version').appendChild( $package.createTextnode( $_.version ))
			$stig.selectSingleNode('release').appendChild( $package.createTextnode( $_.release ))
			$stig.selectSingleNode('date').appendChild( $package.createTextnode( $_.date ))
						
			$package.selectSingleNode("//cstsPackage/settings/stigs").appendChild( $stig )
		}
		
		$benchmarks | % {
			$stig = $package.createElement('benchmark')
			$stig.setAttribute("id", $_.id)
			
			@('filename','title','version','release','date') | %{ $stig.appendChild( $package.createElement( $_ ) ) }
			$stig.selectSingleNode('filename').appendChild( $package.createTextnode( $_.fileName ))
			$stig.selectSingleNode('title').appendChild( $package.createTextnode( $_.title ))
			$stig.selectSingleNode('version').appendChild( $package.createTextnode( $_.version ))
			$stig.selectSingleNode('release').appendChild( $package.createTextnode( $_.release ))
			$stig.selectSingleNode('date').appendChild( $package.createTextnode( $_.date ))
						
			$package.selectSingleNode("//cstsPackage/settings/stigs").appendChild( $stig )
		}
		
		$package.save( $_.fullname)
	}
	
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status:"
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
}

method -private exportCurrentReport{
	$private.getElementsByClassName('exportable') | %{
		$_.outerHTML  | set-content "$($pwd)\results\test.doc"
	}
}

method -private selectPackageHardware{
	param($package)
	$private.gui.controls.treePackages.selectedNode = $private.gui.controls.treePackages.Nodes['Packages'].Nodes[$package].Nodes['Hardware']
}
method -private selectPackageSoftware{
	param($package)
	$private.gui.controls.treePackages.selectedNode = $private.gui.controls.treePackages.Nodes['Packages'].Nodes[$package].Nodes['Software']
}
method -private selectPackageAcas{
	param($package)
	$private.gui.controls.treePackages.selectedNode = $private.gui.controls.treePackages.Nodes['Packages'].Nodes[$package].Nodes['Scans'].Nodes['ACAS']
}
method -private selectPackageCkl{
	param($package)
	$private.gui.controls.treePackages.selectedNode = $private.gui.controls.treePackages.Nodes['Packages'].Nodes[$package].Nodes['Scans'].Nodes['CKL']
}
method -private selectPackageScap{
	param($package)
	$private.gui.controls.treePackages.selectedNode = $private.gui.controls.treePackages.Nodes['Packages'].Nodes[$package].Nodes['Scans'].Nodes['SCAP']
}
	
method -private getElementById{
	param($id)
	
	return $private.gui.controls.webDisplay.document.getElementById($id)
}

method -private getElementsByClassName{
	param($className)
	$elements = @()
	$private.gui.controls.webDisplay.document.All | % {
		if($_.GetAttribute('classname') -like "*$($className)*"){
			$elements += $_
		}
	}

	return $elements
}

method -private getElementsByName{
	param($name)
	$elements = @()
	$private.gui.controls.webDisplay.document.All | % {
		if($_.GetAttribute('name') -eq $name){
			$elements += $_
		}
	}

	return $elements
}
	
method -private loadDb{
	$private.xml = [xml](gc "$($pwd)\packages\$($private.package)\package.xml" -ReadCount 0)
	$private.findings = [xml](gc "$($pwd)\packages\$($private.package)\findings.xml" -ReadCount 0)
}

method -private navTreeSelect{
	param($o)
	
	$benchmark = measure-command {
		$node = $o.node
		switch($node.level){
			0{ $private.showDashboard() | out-null }
			1{
				$private.package = $node.text
				$private.loadDb()
				$private.renderPackageSummary($private.package) | out-null
			}
			2{
				$private.package = $node.parent.text
				$private.loadDb()
				switch($node.text){
					"Hardware" 		{ $private.showHardware(  ) }
					"Software" 		{ $private.showSoftware(  ) }
					"Scans" 		{ $private.showScans( ) }
					"Requirements" 	{ $private.showRequirements( ) }
					"Findings" 	{ $private.showFindings( ) }
				}
			}
			3{
				$private.package = $node.parent.parent.text
				$private.loadDb()
				switch($node.text){
					"ACAS" 		{ $private.showACAS(  ) }
					"SCAP" 		{ $private.showSCAP(  ) }
					"CKL" 		{ $private.showCKL(  ) }
				}
			}
		}
	}
	
	$private.gui.controls.stbMain.Items['stbBenchmark'].text = [math]::Round( $($benchmark.totalSeconds), 2 )
}

method -private newNode{
	param(
		$text,
		$tag = "",
		$name = ""
	)
	if($tag -eq ''){ $tag = $text}
	if($name -eq ''){ $name = $text}

	$newNode = new-object "System.Windows.Forms.TreeNode"
	$newNode.Name = $name
	$newNode.Text = $text
	$newNode.Tag = $tag
	return $newNode
}

method Execute{
	$uiClass.errorLog()
}

method -private addPackageNode{
	param( [string] $package)

	$private.gui.controls.treePackages.Nodes['Packages'].Nodes.Add( $private.newNode( $package ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes.Add( $private.newNode( 'Hardware' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes.Add( $private.newNode( 'Software' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes.Add( $private.newNode( 'Requirements' ) ) | Out-Null
	
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes.Add( $private.newNode( 'Scans' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Scans'].Nodes.Add( $private.newNode( 'ACAS' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Scans'].Nodes.Add( $private.newNode( 'CKL' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Scans'].Nodes.Add( $private.newNode( 'SCAP' ) ) | Out-Null

	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes.Add( $private.newNode( 'Findings' ) ) | Out-Null
	
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes.Add( $private.newNode( 'Details' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Details'].Nodes.Add( $private.newNode( 'HBSS' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Details'].Nodes.Add( $private.newNode( 'IAVM' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Details'].Nodes.Add( $private.newNode( 'Operating Systems' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Details'].Nodes.Add( $private.newNode( 'PKI' ) ) | Out-Null
	
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes.Add( $private.newNode( 'Evidence' ) ) | Out-Null
	
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes.Add( $private.newNode( 'Reports' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'ACAS Reports' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'Asset Overview' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'DADMS' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'Discrepencies' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'Finding Review' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'HwSw List' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'Package Summary' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'POAM' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'RAR' ) ) | Out-Null
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes['Reports'].Nodes.Add( $private.newNode( 'Test Plan' ) ) | Out-Null
	
	$private.gui.controls.treePackages.Nodes['Packages'].Nodes[ $package ].Nodes.Add( $private.newNode( 'Archives' ) ) | Out-Null
	
}

method -private renderTpl{
	param($tpl, $vars)
	
	$vars['pwd'] = $pwd
	$vars['package'] =  $private.package.toUpper()
		
	$html = ( (gc "$($pwd)\wwwroot\views\$($tpl)") -join "`r`n" ) -replace '@""','@"'
	
	
	while($html -like '*$[a-zA-Z]*' -or $html -like "`{`{[a-zA-Z]*`}`}" -or $html -like '\[\[(.+?)\]\]' ){
		$html = $ExecutionContext.InvokeCommand.ExpandString( $html )

		#get page includes
		$html -match '\[\[([a-zA-Z0-9\.\\/]+?)\]\]' | out-null;
		if($matches){
			[regex]::matches( $html, '\[\[([a-zA-Z0-9\.\\/]+?)\]\]' ) | %{
				$html = $html.replace("[[$($_.groups[1].value)]]", ( (gc "$(pwd)\$($_.groups[1].value)") -join "`r`n") )
			}
		}
		
		$html = $html -replace '{{([a-zA-Z0-9_\.]+?)}}', '`$(`$vars[''$1''])'
	}

	
	
	return $html
}

method -private displayHtml{
	param($html)

	#this way caused a flash
	# $private.gui.controls.webDisplay.Navigate("about:blank") | out-null;
	# $private.gui.controls.webDisplay.Document.OpenNew($false) | out-null;
	# $private.gui.controls.webDisplay.Document.Write($html) | out-null;
	# $private.gui.controls.webDisplay.Refresh() | out-null;
	
	#this appears to be working better, am testing.
	$private.gui.controls.webDisplay.Refresh() | out-null;
	$private.gui.controls.webDisplay.DocumentText = $html
	
	while( $private.gui.controls.webDisplay.ReadyState  -ne 'Complete' ){
		[System.Windows.Forms.Application]::DoEvents()
		sleep -milliseconds 100
	}
	
}

method -private showWait{
	$webVars = @{}
	$webVars['mainContent'] = ( (gc "$($pwd)\wwwroot\views\packageManager\wait.tpl" ) -join "`r`n")
	$html = $private.renderTpl("packageManagerDefault.tpl", $webVars)
	$private.displayHtml( $html  )
}

constructor{
	param()

	$private.gui = $null

	$private.gui = $guiClass.New("packageManager.xml")
	$private.gui.generateForm() | out-null;
	$private.gui.controls.treePackages.Nodes.Add( $private.newNode('Packages') ) | Out-Null
	ls -Directory .\packages\ | select -expand Name | sort  | % {
		$private.addPackageNode( $_.ToUpper() )
	}
	$private.gui.controls.treePackages.Nodes['Packages'].expand() | out-null
	$private.gui.controls.treePackages.add_AfterSelect( { $private.navTreeSelect( $_ ) } ) | out-null
	$private.gui.controls.webDisplay.BringToFront() | out-null
	
	#added here to create first 'document'.  The displayHtml needs this done once
	$private.gui.controls.webDisplay.Navigate("about:blank") | out-null;
	$private.gui.controls.webDisplay.Document.OpenNew($false) | out-null;
	
	$private.displayHtml('<html />') | out-null
	$private.gui.controls.webDisplay.document.add_click( { $private.handleClickEvents($this, $_) } ) | out-null

	$private.gui.controls.stbMain.BringToFront() | out-null
	$private.gui.controls.stbMain.Items['stnStatusBlank'].Spring = $true

	
	$private.gui.Form.ShowDialog() | Out-Null
}

method -private renderPackageSummary{
	
}

method -private showDashboard{
	$i = 0;
	$private.showWait()
	
	
	
	$webVars = @{}
	
	$webVars['packages'] =  $( ls -Directory .\packages\ | select -expand Name | sort  | % { $i = $i + 1;
	$findings = [xml](gc "$(pwd)\packages\$($_.ToString())\findings.xml" -ReadCount 0)
	
@"
<tr>
	<td>$($i)</td>
	<td>$($_.ToString().ToUpper())</td>
	<td>
		<button class="btn btn-default capture-me" data-action="select_package_hardware" data-id="$($_.ToString().ToUpper())">
			$(
				if( (test-path "$(pwd)\packages\$($_.ToString())\package.xml") -eq $true){
					if((([xml](gc "$(pwd)\packages\$($_.ToString())\package.xml" -ReadCount 0)).cstsPackage.assets.asset).length -eq $null){
						1
					}else{
						(([xml](gc "$(pwd)\packages\$($_.ToString())\package.xml" -ReadCount 0)).cstsPackage.assets.asset).length
					}
				}else{
					0
				}
			)
	</button>
	</td>
	<td>
		<button class="btn btn-default capture-me" data-action="select_package_software" data-id="$($_.ToString().ToUpper())">
			$(
				if( (test-path "$(pwd)\packages\$($_.ToString())\package.xml") -eq $true){
					if((([xml](gc "$(pwd)\packages\$($_.ToString())\package.xml" -ReadCount 0)).cstsPackage.applications.application).length -eq $null){
						1
					}else{
						(([xml](gc "$(pwd)\packages\$($_.ToString())\package.xml" -ReadCount 0)).cstsPackage.applications.application).length
					}
				}else{
				0
				}
			)
		</button>
	</td>
	<td>
		<button class="btn btn-primary capture-me" data-action="select_package_acas" data-id="$($_.ToString().ToUpper())">
			ACAS <span class="badge"> $( ( ([xml](gc "$(pwd)\packages\$($_.ToString())\package.xml" -ReadCount 0)).cstsPackage.scans.acas.scan).length  )</span>
		</button> 
		&nbsp;
		<button class="btn btn-info capture-me" data-action="select_package_ckl" data-id="$($_.ToString().ToUpper())">
			CKL <span class="badge"> $( ( ([xml](gc "$(pwd)\packages\$($_.ToString())\package.xml" -ReadCount 0)).cstsPackage.scans.ckls.scan).length  ) </span>
		</button>		
		&nbsp;
		<button class="btn btn-success capture-me" data-action="select_package_scap" data-id="$($_.ToString().ToUpper())">
			SCAP <span class="badge"> $( ( ([xml](gc "$(pwd)\packages\$($_.ToString())\package.xml" -ReadCount 0)).cstsPackage.scans.scap.scan).length  ) </span>
		</button>
		
	</td>
	<td>
		<button class="btn btn-danger capture-me" data-action="select_package_finding" data-id="$($_.ToString().ToUpper())">
			O <span class="badge"> $( 
				[int]($findings.selectNodes("//cstsPackage/findings/acas/finding[status='Ongoing'  and ./rawRisk !='None']").count) +
				[int]($findings.selectNodes("//cstsPackage/findings/ckl/finding[status='Ongoing']").count) +
				[int]($findings.selectNodes("//cstsPackage/findings/scap/finding[./assets/asset/@status='Ongoing']").count)
			)</span>
		</button> 
		&nbsp;
		<button class="btn btn-warning capture-me" data-action="select_package_finding" data-id="$($_.ToString().ToUpper())">
			NR <span class="badge"> $( 
				[int]($findings.selectNodes("//cstsPackage/findings/acas/finding[./status='' and ./rawRisk !='None']").count) +
				[int]($findings.selectNodes("//cstsPackage/findings/ckl/finding[status='Not_Reviewed']").count) +
				[int]($findings.selectNodes("//cstsPackage/findings/scap/finding[./assets/asset/@status='Error']").count)
			)</span>
		</button> 
		&nbsp;
		<button class="btn btn-success capture-me" data-action="select_package_finding" data-id="$($_.ToString().ToUpper())">
			C <span class="badge"> $( 
				[int]($findings.selectNodes("//cstsPackage/findings/acas/finding[./status='Completed' and ./rawRisk !='None']").count) +
				[int]($findings.selectNodes("//cstsPackage/findings/ckl/finding[status='NotAFinding']").count) +
				[int]($findings.selectNodes("//cstsPackage/findings/scap/finding[./assets/asset/@status='Completed']").count)
			)</span>
		</button> 
		&nbsp;
		<button class="btn btn-info capture-me" data-action="select_package_finding" data-id="$($_.ToString().ToUpper())">
			NA <span class="badge"> $(
				[int]($findings.selectNodes("//cstsPackage/findings/ckl/finding[status='Not_Applicable']").count) 
			)</span>
		</button> 
		&nbsp;
	</td>
	
</tr>
"@
} );
	$webVars['mainContent'] = gc "$($pwd)\wwwroot\views\packageManager\packages.tpl"
	$private.displayHtml(  $private.renderTpl("packageManagerDefault.tpl", $webVars)  )
}