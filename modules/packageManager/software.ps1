method -private showSoftware{
	$webVars = @{}
	$i = 0

	$private.showWait();
	
	$applications = $private.xml.selectNodes("//cstsPackage/applications/application") | sort { $_.name } 

	$tmp = ""
	foreach($app in $applications){
		$i = $i + 1;
		$tmp += @"
<tr>
	<td><input type="checkbox" class="asset_checkbox" id="software_$($app.id)" /></td>
	<td><a href="#" onclick="client.software.edit('$($app.id)')">$($app.name.ToString().ToUpper())</a></td>
	<td>$($app.version)</td>
	<td>$($app.Vendor)</td>
	<td>$(
		$hosts = @()
		$app.hosts.host  | % { $hosts += $private.xml.selectSingleNode("//cstsPackage/assets/asset[@id='$($_.assetId)']/hostname").'#text' }
		$hosts  | sort | % { "<span title='$($_.installDate)' class='label label-primary'>$( $_ )</span>"}
	)</td>
</tr>
"@
}

	$webVars['softwareList'] = $tmp
	$webVars['softwareCount'] =  $i
	$webVars['mainContent'] = gc "$($pwd)\wwwroot\views\packageManager\software.tpl"

	$html = $private.renderTpl("packageManagerDefault.tpl", $webVars)

	$private.displayHtml( $html  )
}

method -private assetsEditSoftwareSubmitClick{
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Editting Software $( $private.gui.controls.webDisplay.document.getElementById('editSoftware_Name').GetAttribute('value').trim().toUpper())"
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0

	$prop = @{
		"id" 			= $private.gui.controls.webDisplay.document.getElementById('editSoftware_Id').GetAttribute('value');
		"name" 			= $private.gui.controls.webDisplay.document.getElementById('editSoftware_Name').GetAttribute('value');
		"version" 		= $private.gui.controls.webDisplay.document.getElementById('editSoftware_Version').GetAttribute('value');
		"vendor" 		= $private.gui.controls.webDisplay.document.getElementById('editSoftware_Vendor').GetAttribute('value');
	}
	$private.gui.controls.stbMain.Items['stbProgress'].value = 10
	
	$private.xml.selectNodes("//cstsPackage/applications/application[@id='$($prop.id)']")  | % {
		$_.ParentNode.RemoveChild($_)
	}

	$private.gui.controls.stbMain.Items['stbProgress'].value = 40
	$software = $private.xml.createElement("application")
	@('name','version','vendor','hosts') | % { $software.appendChild( $private.xml.createElement( $_ ) ) | out-null }
	$software.setAttribute('id',$prop.id) | out-null

	$software.selectSingleNode('name').appendChild($private.xml.createTextnode( $prop.name )) | out-null;
	$software.selectSingleNode('version').appendChild($private.xml.createTextnode( $prop.version )) | out-null;
	$software.selectSingleNode('vendor').appendChild($private.xml.createTextnode( $prop.vendor )) | out-null;

	$private.gui.controls.webDisplay.document.getElementById('editSoftware_Hosts').GetAttribute('value') -split "," -split " " | % { $_.trim() } | ? { $_ -ne ''} | % {

		$h = $private.xml.selectSingleNode("//cstsPackage/assets/asset[translate(hostname,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')='$($_.ToString().ToUpper())']")

		if($h -ne $null){
			$install = $private.xml.createElement('host')
			$install.setAttribute("assetId", $h.id) | out-null

			$node = $private.xml.createElement('installDate')
			$node.appendChild( $private.xml.createTextNode( '' ) ) | out-null
			$install.appendChild( $node)  | out-null

			$software.selectSingleNode('hosts').appendChild($install) | out-null;
		}
	}
	$private.xml.selectSingleNode('//cstsPackage/applications').appendChild($software);

	$private.gui.controls.stbMain.Items['stbProgress'].value = 85
	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showSoftware()
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: "
}

#this is here because some registry values have utf bytes at the end.  
#these are hidden in regedit, but show up in data pulls
#things like \u0072 will show up as null, then H.  
#the data pulls then make the string 'Microsoft H' which is not valid.
method -private normalizeRegistryValue{
	param($val)
	
	if($val -ne $null){
		$b = [System.Text.Encoding]::GetEncoding('ascii').GetBytes( $val )
		if($b[-2] -eq 0 -and $b[-1] -eq 72){
			[system.array]::Resize([ref]$b,($b.Count-2)) | out-null
		}
		
		$val = [System.Text.Encoding]::GetEncoding('ascii').GetString( $b )
		$val =  $val -replace '[^a-zA-Z0-9\- \.\ ]','';
	}
	return $val
}


method -private getHostSoftware{
	param($assetId)
	
	$regPaths = @(
		'Software\Microsoft\Windows\CurrentVersion\Uninstall'
		'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
	)

	$asset = $private.xml.selectSingleNode("//cstsPackage/assets/asset[@id='$($assetId)']")
	
	$pingResult = Get-WmiObject -Class win32_pingstatus -Filter "address='$($asset.hostname.Trim())'"
	if( ($pingResult.StatusCode -eq 0 -or $pingResult.StatusCode -eq $null ) -and $utilities.isBlank($pingResult.IPV4Address) -eq $false ) {
		try{
			$remoteRegistry = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',"$($asset.hostname.Trim())")

			#delete all applications currently associated with 'this' host
			$private.xml.selectNodes("//*[@assetId='$($assetId)']") | % {
				$_.parentNode.removeChild($_)
			}

			$apps = @()
			#check for IE
			$remoteRegistryKey = $remoteRegistry.OpenSubKey("SOFTWARE\\Microsoft\\Internet Explorer")
			if($remoteRegistryKey -ne $null){

				$apps += @{
					"Name"  = "Internet Explorer"
					"Vendor" = "Microsoft"
					"InstallDate" = ""
					"Version" = @( $remoteRegistryKey.getValue("svcVersion"),  $remoteRegistryKey.getValue("version") )[ ( $remoteRegistryKey.getValue("version").toString().subString(0,1) -lt 10 ) ]
				}
			}

			#check for java
			if( ( test-path "\\$($asset.hostname.Trim())\c`$\Program Files (x86)\Java") -eq $true){
				gci "\\$($asset.hostname.Trim())\c`$\Program Files (x86)\Java" -recurse -include "java.exe" -errorAction silentlyContinue| % {
					$apps += @{
						"Name"  = "Java - 32 Bit"
						"Vendor" = "Oracle"
						"InstallDate" = ""
						"Version" = [system.diagnostics.fileversioninfo]::GetVersionInfo( $_.FullName  ).FileVersion
					}
				}
			}
			#check for java
			if( ( test-path "\\$($asset.hostname.Trim())\c`$\Program Files\Java") -eq $true){
				gci "\\$($asset.hostname.trim())\c`$\Program Files\Java" -recurse -include "java.exe" -errorAction silentlyContinue | % {
					$apps += @{
						"Name"  = "Java - 64 Bit"
						"Vendor" = "Oracle"
						"InstallDate" = ""
						"Version" = [system.diagnostics.fileversioninfo]::GetVersionInfo( $_.FullName  ).FileVersion
					}
				}
			}

			#get all other apps on system
			foreach($regPath in $regPaths){
				[System.Windows.Forms.Application]::DoEvents()
				$remoteRegistryKey = $remoteRegistry.OpenSubKey($regPath)
				
				if($remoteRegistryKey -ne $null){
					$remoteSubKeys = $remoteRegistryKey.GetSubKeyNames()
					$remoteSubKeys | % {

						[System.Windows.Forms.Application]::DoEvents()
						$remoteSoftwareKey = $remoteRegistry.OpenSubKey("$regPath\\$_")
						if( $remoteSoftwareKey.GetValue("DisplayName") -and $remoteSoftwareKey.GetValue("UninstallString") ){
							$remReg = @{
								"Name"  = $remoteSoftwareKey.GetValue("DisplayName") -replace '[^a-zA-Z0-9\- \.]','';
								"Vendor" = $private.normalizeRegistryValue( $remoteSoftwareKey.GetValue("Publisher") );
								"InstallDate" = $remoteSoftwareKey.GetValue("InstallDate") -replace '[^a-zA-Z0-9\- \.]','';
								"Version" =$remoteSoftwareKey.GetValue("DisplayVersion") -replace '[^a-zA-Z0-9\- \.]','';
							}
							if( $remReg.name -notlike '*gdr*' -and $remReg.name -notlike '*security*' -and $remReg.name -notlike '*update*' -and $remReg.name -notlike '*driver*' -and $remReg.name -notlike '*runtime*' -and $remReg.name -notlike '*redistributable*' -and $remReg.name -notlike '*framework*'-and $remReg.name -notlike '*hotfix*'  -and $remReg.name -notlike '*plugin*' -and $remReg.name -notlike '*plug-in*' -and $remReg.name -notlike '*debug*' -and $remReg.name -notlike '*addin*' -and $remReg.name -notlike '*add-in*' -and $remReg.name -notlike '*library*' -and $remReg.name -notlike '*add-on*' -and $remReg.name -notlike '*extension*' -and $remReg.name -notlike '*setup*' -and $remReg.name -notlike '*installer*'){
								$apps += $remReg
							}
						}
					}
				}
			}

			foreach($app in $apps){
				
				if($( $private.xml.cstsPackage.applications.application | ? { $_.name -eq $app.Name -and $_.version -eq $app.Version} ) -eq $null){
					$softwareId = [guid]::newGuid().guid
					$application = $private.xml.createElement('application')
					$application.setAttribute("id", $softwareId) | out-null
					@('vendor','version','name','hosts') | %{ $application.appendChild( $private.xml.createElement( $_ ) )  | out-null}
					$application.selectSingleNode('name').appendChild($private.xml.createTextnode( $app.name ))  | out-null;
					$application.selectSingleNode('version').appendChild($private.xml.createTextnode( $app.Version ))  | out-null;
					$application.selectSingleNode('vendor').appendChild($private.xml.createTextnode( $app.Vendor  ))  | out-null;
					$private.xml.selectSingleNode('//cstsPackage/applications').appendChild($application)  | out-null;
				}

				if( ($( $private.xml.cstsPackage.applications.application | ? { $_.name -eq $app.Name -and $_.version -eq $app.Version} ).hosts.host | ? { $_.assetId -eq $($assetId) }) -eq $null){
					$install = $private.xml.createElement('host')
					$install.setAttribute('assetId',$($assetId))  | out-null
					$node = $private.xml.createElement('installDate')
					$node.appendChild( $private.xml.createTextNode( $($app.InstallDate)) )
					$install.appendChild( $node)
					$( $private.xml.cstsPackage.applications.application | ? { $_.name -eq $app.Name -and $_.vendor -eq $app.Vendor -and $_.version -eq $app.Version} ).selectSingleNode('hosts').appendChild($install) | out-null
				}
			}
		}catch{

		}
	}

	#delete non-existing hosts
	$private.xml.selectNodes("//cstsPackage/applications/hosts/host[not(@assetId=//cstsPackage/assets/asset/@id)]") | % {
		$_.ParentNode.RemoveChild($_)
	}
	
	#delete applications that aren't installed on any hosts...technically, this should never get called
	$private.xml.selectNodes("//cstsPackage/applications/application[not(./hosts/host)]") | % {
		$_.ParentNode.RemoveChild($_)
	}

	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")

}

method -private assetReloadHostSoftware{

	$checkboxes = $private.getElementsByClassName('asset_checkbox') | ? { $_.GetAttribute('checked') -eq $true }
	$i = 0
	$total = $checkBoxes.length
	$checkBoxes | % {
		$i = $i + 1
		$p = $( [Math]::round( (100 * $i / $total),0)  )
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p
		$id = $_.id -replace 'host_',''
		$asset = $private.xml.selectSingleNode("//cstsPackage/assets/asset[@id='$($id)']")
		$hostname = $asset.hostname
		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: $($i) / $($total) - Reloading software for $($asset.hostname)"

		$private.getHostSoftware( $($asset.id) )

	}

	$private.showHardware()
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: "
}


method -private assetsReloadSoftwareButtonClick{

	#connect to each host
	$hosts = ( $private.xml.selectNodes('//cstsPackage/assets/asset') | sort { $_.hostname} )
	$i = 0
	$total = $hosts.length

	foreach($asset in $hosts){
		[System.Windows.Forms.Application]::DoEvents()
		$i++
		$p = $( [Math]::round( (100 * $i / $total),0)  )
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p
		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: $($i) / $($total) - Reloading software from $($asset.hostname)"

		$private.getHostSoftware( $asset.id)
	}

	$private.showSoftware()
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: "
}

method -private assetsRemoveSoftwareButtonClick{

	[System.Windows.Forms.Application]::DoEvents()
	$private.getElementsByClassName('asset_checkbox') | ? { $_.GetAttribute('checked') -eq $true } | % {
		$id = $_.id -replace 'software_',''

		$private.xml.selectNodes("//cstsPackage/applications/application[@id='$($id)']") | % {
			$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Removing $($_.name)"
			$_.ParentNode.RemoveChild($_)
		}
	}

	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showSoftware()
}

method -private assetsAddSoftwareSubmitClick{
	$application = $private.xml.createElement('application')
	$application.setAttribute("id", [guid]::newGuid().guid)

	#placeholders
	@('vendor','version','name','hosts') | %{
		$application.appendChild( $private.xml.createElement( $_ ) ) | out-null
	}

	$application.selectSingleNode('name').appendChild($private.xml.createTextnode(
		$private.gui.controls.webDisplay.document.getElementById('addSoftware_Name').GetAttribute('value').trim()
	))| out-null;

	$application.selectSingleNode('version').appendChild($private.xml.createTextnode(
		$private.gui.controls.webDisplay.document.getElementById('addSoftware_Version').GetAttribute('value').trim()
	))| out-null;

	$application.selectSingleNode('vendor').appendChild($private.xml.createTextnode(
		$private.gui.controls.webDisplay.document.getElementById('addSoftware_Vendor').GetAttribute('value').trim()
	))| out-null;


	$private.gui.controls.webDisplay.document.getElementById('addSoftware_Hosts').GetAttribute('value') -split "," -split " " | % { $_.trim() } | ? { $_ -ne ''} | % {
		$h = $private.xml.selectSingleNode("//cstsPackage/assets/asset[translate(hostname,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')='$($_.ToString().ToUpper())']")

		if($h -ne $null){

			$install = $private.xml.createElement('host')
			$install.setAttribute("assetId", $h.id) | out-null

			$node = $private.xml.createElement('installDate')
			$node.appendChild( $private.xml.createTextNode( '' ) ) | out-null
			$install.appendChild( $node)  | out-null

			$application.selectSingleNode('hosts').appendChild($install) | out-null;
		}
	}

	$private.xml.selectSingleNode('//cstsPackage/applications').appendChild($application)

	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = 'Status: '

	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showSoftware()
}