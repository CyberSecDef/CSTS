method -private showHardware{
	$private.loadDb()

	$private.showWait();
	
	$i = 0
	$webVars = @{}
	
	
	$tmp = $( $private.xml.cstsPackage.assets.asset |  sort { $_.hostName } | % { 
$i= $i + 1;
@"
<tr>
	<td><input type="checkbox" class="asset_checkbox" id="host_$($_.id)" /></td>
	
	<td>
		<a href="#" onclick="client.assets.hosts.edit('$($_.id)')" title='$($_.osProductKey)'>
			$($_.hostname.ToString().ToUpper())
		</a>
	</td>
	<td>$($_.ip)</td>
	<td>$($_.deviceType)</td>
	<td>$($_.os)</td>
	<td>$($_.manufacturer)</td>
	<td>$($_.model)</td>
	<td>$($_.firmware)</td>
	<td>$($_.location)</td>
	<td>$($_.description)</td>
</tr>
"@
})

	$info = ([adsisearcher]"objectclass=organizationalunit")
	$info.PropertiesToLoad.AddRange("CanonicalName")
	$o = ( $info.findall().properties.canonicalname | sort )
	$nodes = @{}
	foreach($ou in $o){
		$currentOu = ""
		foreach($chunk in ($ou -split '/')    ){
			$currentOu = $currentOu + "." + '"' + $chunk + '"'
			if( (invoke-expression "`$nodes$($currentOu)") -eq $null ){
				invoke-expression "`$nodes$($currentOu) = @{}"
			}
		}
	}

	$global:output = ""
	function formatNodes{
		param($node)
		
		foreach($name in ( $node.keys | sort ) ){
			$global:output += "{text: ""$name"" `r`n"
			if( $($node.$name).count -gt 0){
				$global:output += ",nodes: ["
				formatNodes($node.$name)
				
				if($global:output.substring($global:output.length -1 ) -eq ','){
					$global:output = $global:output.substring(0, $global:output.length -1 )
				}
				
				$global:output += "]`r`n"
			}
			$global:output += "},"
		}
	}
	formatNodes($nodes); 

	$webVars['adTree'] =  $global:output.substring(0, $global:output.length -1 ) 
	
	

	$webVars['assetCount'] =  $i
	$webVars['assetList'] =  $tmp
	$webVars['pwd'] = $pwd
	$webVars['package'] =  $private.package.toUpper()
	$webVars['mainContent'] = gc "$($pwd)\wwwroot\views\packageManager\assets.tpl"

	$html = $private.renderTpl("packageManagerDefault.tpl", $webVars)

	$private.displayHtml( $html  )
}

method -private assetsEditHostsSubmitClick{
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Editting Host $( $private.gui.controls.webDisplay.document.getElementById('editHost_HostName').GetAttribute('value').trim().toUpper())"
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	

	$prop = @{
		"id" = $private.gui.controls.webDisplay.document.getElementById('editHost_Id').GetAttribute('value');
		"hostname" = $private.gui.controls.webDisplay.document.getElementById('editHost_HostName').GetAttribute('value');
		"ip" = $private.gui.controls.webDisplay.document.getElementById('editHost_IP').GetAttribute('value');
		"manufacturer" = $private.gui.controls.webDisplay.document.getElementById('editHost_Manufacturer').GetAttribute('value');
		"model" = $private.gui.controls.webDisplay.document.getElementById('editHost_Model').GetAttribute('value');
		"firmware" = $private.gui.controls.webDisplay.document.getElementById('editHost_Firmware').GetAttribute('value');
		
		"location" = $private.gui.controls.webDisplay.document.getElementById('editHost_Location').GetAttribute('value');
		"description" = $private.gui.controls.webDisplay.document.getElementById('editHost_Description').GetAttribute('value');
		
		"os" = $private.gui.controls.webDisplay.document.getElementById('editHost_OS').GetAttribute('value');
		"osProductKey" = $private.gui.controls.webDisplay.document.getElementById('editHost_OSProdKey').GetAttribute('value');
		
		"deviceType" = ( $private.gui.controls.webDisplay.document.getElementById('editHost_deviceType').DomElement | ? { $_.selected -eq $true } | select -expand TextContent);
	}
	
	$private.gui.controls.stbMain.Items['stbProgress'].value = 10
	
	$asset = $private.xml.selectSingleNode("//cstsPackage/assets/asset[@id='$($prop.id)']")

	$private.xml.selectNodes("//cstsPackage/assets/asset[@id='$($prop.id)']/ip")  | % {
		$_.ParentNode.RemoveChild($_)
	}

	$private.gui.controls.stbMain.Items['stbProgress'].value = 40
	$asset.hostname = $prop.hostname.ToString()

	($prop.ip -split ' ') | % {
		$tmp = $private.xml.createElement( 'ip' )
		$tmp.appendChild($private.xml.createTextnode( $_ ))
		$asset.appendChild($tmp)
	}

	$private.gui.controls.stbMain.Items['stbProgress'].value = 75
	$asset.manufacturer = $prop.manufacturer.ToString()
	$asset.model = $prop.model.ToString()
	$asset.firmware = $prop.firmware.ToString()
	$asset.location = $prop.location.ToString()
	$asset.description = $prop.description.ToString()
	
	$asset.os = $prop.os.ToString()
	$asset.osProductKey = $prop.osProductKey.ToString()
	$asset.deviceType = $prop.deviceType.ToString()
	
	$private.gui.controls.stbMain.Items['stbProgress'].value = 85
	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showHardware()
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: "
}

method -private assetsImportHostsButtonClick{
	#determine ou to query
	$ldapStr = ""
	($private.gui.controls.webDisplay.document.getElementById('importOU').GetAttribute('value')) -split '\\' | % {
		$ldapStr += ",OU=$($_)"
	}
	
	$ldapStr = $ldapStr.subString(1)
	
	$Root = [ADSI]"LDAP://RootDSE"
	$ldapStr += ",$($Root.rootDomainNamingContext)"
	$ldapStr = "LDAP://" + $ldapStr
	
	$DirSearcher = New-Object System.DirectoryServices.DirectorySearcher([adsi]$ldapStr)
	$DirSearcher.Filter = '(objectClass=Computer)'
	$searcher = $DirSearcher.FindAll()
		
	$total = ($searcher).count
	$i = 0
	$searcher.GetEnumerator() | % {
		[System.Windows.Forms.Application]::DoEvents() 
		$h = $_
		
		$i = $i + 1

		$p = $( [Math]::round( (100 * $i / $total),0)  )

		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Adding Host $($h.properties.name.trim().toUpper())"
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p
		$importHostName = "$($h.properties.name.trim().toUpper())"
		
		if($importHostName -ne ''){
		
			$asset = $private.xml.selectSingleNode("//cstsPackage/assets/asset[./hostname = '$($h.properties.name.trim().toUpper())']")
			if ( $asset -eq $null ) {
				$asset = $private.xml.createElement('asset')
				$asset.setAttribute("id", [guid]::newGuid().guid)
				$private.xml.selectSingleNode('//cstsPackage/assets').appendChild($asset)
				
				@('manufacturer','model','firmware','hostname','location','description','os','deviceType','osProductKey') | %{
					$asset.appendChild( $private.xml.createElement( $_ ) )
				}
			}
			
			@('manufacturer','model','firmware','hostname','location','description','os','deviceType','osProductKey') | %{
				$asset.selectSingleNode($_).innerText = '';
			}
			
			$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($h.properties.name.trim().toUpper())'" -errorAction silentlyContinue
			if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {

				$Reg = [WMIClass] ("\\" + $($h.properties.name.trim().toUpper()) + "\root\default:StdRegProv")
				$values = [byte[]]($reg.getbinaryvalue(2147483650,"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion","DigitalProductId").uvalue)

				$prodKey = $utilities.decodeProductKey( $($values) )
				if($prodKey -like '*BBBBB*'){
					$values = [byte[]]($reg.getbinaryvalue(2147483650,"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion","DigitalProductId4").uvalue)
					$prodKey = $utilities.decodeProductKey( $($values) )
				}
				
				$asset.selectSingleNode('osProductKey').appendChild( $private.xml.createTextnode( $prodKey  ) );
			}
			
			$asset.selectSingleNode('hostname').appendChild($private.xml.createTextnode($h.properties.name.trim().toUpper()));
			$asset.selectSingleNode('location').appendChild($private.xml.createTextnode($($h.properties.location) + ' ' + $($h.properties.roomNumber)));
			$asset.selectSingleNode('description').appendChild($private.xml.createTextnode($h.properties.description));
			
			$os = gwmi -Computer "$($h.properties.name.trim().toUpper())" -Class Win32_OperatingSystem | select caption, ServicePackMajorVersion
			
			$asset.selectSingleNode('os').appendChild(
				$private.xml.createTextnode("$($os.caption -replace '[^a-zA-Z0-9 ]','') SP$($os.ServicePackMajorVersion)".Trim() )
			);
			
			$asset.selectSingleNode('deviceType').appendChild( $private.xml.createTextnode( @('Workstation','Server')[ ($os.caption -like '*windows server*') ] ) );
			
			$ip = ''
			try{
				$ErrorActionPreference = 'Ignore'
				[System.Net.Dns]::GetHostAddresses($importHostName) | select -first 1 | %{
					$ip = $_
					
				}
			}catch{
				
			}
			
			$asset.selectNodes('ip') | % {
				$_.parentNode.removeChild($_)
			}
			$ipNode = $private.xml.createElement('ip')
			$ipNode.appendChild($private.xml.createTextnode($ip))
			$asset.appendChild($ipNode)
			
			$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($importHostName)'" -errorAction silentlyContinue
			if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
				try{
					$comp = gwmi win32_computerSystem -computerName $importHostName -errorAction silentlyContinue
					$bios = gwmi win32_bios -computerName $importHostName -errorAction silentlyContinue

					$asset.selectSingleNode('manufacturer').appendChild( $private.xml.createTextnode( $comp.Manufacturer.trim() ) );
					$asset.selectSingleNode('model').appendChild( $private.xml.createTextnode( $comp.model.trim() ) );
					$asset.selectSingleNode('firmware').appendChild( $private.xml.createTextnode( $bios.SMBIOSBIOSVersion.trim() ) );
				}catch{
				
				}
			}
		}
	}

	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = 'Status: '

	
	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showHardware()
}

method -private assetsReloadHostsButtonClick{

	$checkboxes = $private.getElementsByClassName('asset_checkbox')
	$i = 0
	$total = $checkBoxes.length
	$checkBoxes | % {
		$i = $i + 1
		$p = $( [Math]::round( (100 * $i / $total),0)  )
		if( $_.GetAttribute('checked') -eq $true){
			$id = $_.id -replace 'host_',''
			$private.gui.controls.stbMain.Items['stbProgress'].value = $p
			$asset = $private.xml.selectSingleNode("//cstsPackage/assets/asset[@id='$($id)']")
			$hostname = $asset.hostname.trim()
			$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: $($i) / $($total) - Reloading data for '$($hostname)'"
			$asset.isEmpty = $true
			#placeholders
			@('manufacturer','model','firmware','hostname','location','description','os','deviceType','osProductKey') | %{
				$asset.appendChild( $private.xml.createElement( $_ ) )
			}

			$asset.selectSingleNode('hostname').appendChild( $private.xml.createTextnode( $hostname )  )

			#ip
			try{
				[System.Net.Dns]::GetHostAddresses($hostname) | %{
					$ip = $private.xml.createElement('ip')
					$ip.appendChild($private.xml.createTextnode($_))
					$asset.appendChild($ip)
				}
			}catch{
				$ip = $private.xml.createElement('ip')
				$asset.appendChild($ip)
			}
			$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($hostname)'" -errorAction silentlyContinue
			if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
				#fill in manufacturer, model and firmware
				try{
					$comp = gwmi win32_computerSystem -computerName $hostname -errorAction silentlyContinue
					$bios = gwmi win32_bios -computerName $hostname -errorAction silentlyContinue

					$asset.selectSingleNode('manufacturer').appendChild( $private.xml.createTextnode( $comp.Manufacturer ) );
					$asset.selectSingleNode('model').appendChild( $private.xml.createTextnode( $comp.model ) );
					$asset.selectSingleNode('firmware').appendChild( $private.xml.createTextnode( $bios.SMBIOSBIOSVersion ) );
									
					$os = gwmi -Computer $hostname -Class Win32_OperatingSystem | select caption, ServicePackMajorVersion
					$asset.selectSingleNode('os').appendChild(
						$private.xml.createTextnode("$($os.caption -replace '[^a-zA-Z0-9 ]','') SP$($os.ServicePackMajorVersion)".Trim() )
					);
					
					$asset.selectSingleNode('deviceType').appendChild( $private.xml.createTextnode( @('Workstation','Server')[ ($os.caption -like '*windows server*') ] ) );
					$Searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ErrorAction 'Stop' -ErrorVariable ErrProcessNewObjectSearcher
					$Searcher.Filter = "(&(objectCategory=Computer)(name=$($hostname)))"
                    $Searcher.SizeLimit = 1
					$Searcher.SearchRoot = ""
					$res = $searcher.findall() | select -expand properties | select @{ n='description'; e={$_.description }},  @{ n='location'; e={$_.location }}
					$asset.selectSingleNode('location').appendChild( $private.xml.createTextnode( $res.location ) );
					$asset.selectSingleNode('description').appendChild( $private.xml.createTextnode( $res.description  ) );

					$Reg = [WMIClass] ("\\" + $($hostname) + "\root\default:StdRegProv")
					$values = [byte[]]($reg.getbinaryvalue(2147483650,"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion","DigitalProductId").uvalue)

					$prodKey = $utilities.decodeProductKey( $($values) )
					if($prodKey -like '*BBBBB*'){
						$values = [byte[]]($reg.getbinaryvalue(2147483650,"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion","DigitalProductId4").uvalue)
						$prodKey = $utilities.decodeProductKey( $($values) )
					}
					
					$asset.selectSingleNode('osProductKey').appendChild( $private.xml.createTextnode( $prodKey  ) );
			
			
				}catch{
				
				}
			}
		}
		$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	}

	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showHardware()
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: "
}

method -private assetsRemoveHostsButtonClick{

	$private.getElementsByClassName('asset_checkbox') | % {
		if( $_.GetAttribute('checked') -eq $true){
			$id = $_.id -replace 'host_',''

			$private.xml.selectNodes("//cstsPackage/assets/asset[@id='$($id)']") | % {
				$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Removing $($_.hostname)"
				$_.ParentNode.RemoveChild($_)
			}

			$private.xml.selectNodes("//cstsPackage/applications/application/hosts/host[@assetId='$($id)']") | % {
				$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Removing $($_.hostname)"
				$_.ParentNode.RemoveChild($_)
			}

			$private.xml.selectNodes("//cstsPackage/applications/application[count(hosts/host)=0]") | % {
				$_.ParentNode.RemoveChild($_)
			}
			
		}
	}

	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showHardware()
	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: "
}

method -private assetsAddHostsSubmitClick{
	$source = $private.gui.controls.webDisplay.document.getElementById('txtNewHosts').innerHTML -replace "`n",","

	$sources = ($source -split ',' | ? { $_.ToString().Trim() -ne ''} )
	$total = $sources.length
	$i = 0
	foreach($h in $sources){
		$i = $i + 1

		$p = $( [Math]::round( (100 * $i / $total),0)  )

		$private.gui.controls.stbMain.Items['stbStatus'].text = "Status: Adding Host $($h.trim().toUpper())"
		$private.gui.controls.stbMain.Items['stbProgress'].value = $p


		if ( $private.xml.cstsPackage.assets.asset.hostname | ? { $_.ToUpper() -eq $h.toUpper() } ) {

		}else{
			#this is a new host to add
			$asset = $private.xml.createElement('asset')
			$asset.setAttribute("id", [guid]::newGuid().guid)
			$hostname = $h.trim().toUpper()
			#placeholders
			@('manufacturer','model','firmware','hostname','location','description','os','deviceType','osProductKey') | %{
				$asset.appendChild( $private.xml.createElement( $_ ) )
			}

			#hostname
			$asset.selectSingleNode('hostname').appendChild($private.xml.createTextnode($h.trim().toUpper()));
			
			#ip
			try{
				[System.Net.Dns]::GetHostAddresses($h) | %{
					$ip = $private.xml.createElement('ip')
					$ip.appendChild($private.xml.createTextnode($_))
					$asset.appendChild($ip)
				}
			}catch{
				$ip = $private.xml.createElement('ip')
				$asset.appendChild($ip)
			}
			
			$Result = Get-WmiObject -Class win32_pingstatus -Filter "address='$($h)'" -errorAction silentlyContinue
			if( ($Result.StatusCode -eq 0 -or $Result.StatusCode -eq $null ) -and $utilities.isBlank($Result.IPV4Address) -eq $false ) {
			
				#fill in manufacturer, model and firmware
				try{
					$comp = gwmi win32_computerSystem -computerName $h -errorAction silentlyContinue
					$bios = gwmi win32_bios -computerName $h -errorAction silentlyContinue

					$asset.selectSingleNode('manufacturer').appendChild( $private.xml.createTextnode( $comp.Manufacturer ) );
					$asset.selectSingleNode('model').appendChild( $private.xml.createTextnode( $comp.model ) );
					$asset.selectSingleNode('firmware').appendChild( $private.xml.createTextnode( $bios.SMBIOSBIOSVersion ) );
					
					$os = gwmi -ComputerName $hostname -Class Win32_OperatingSystem | select caption, ServicePackMajorVersion
					$asset.selectSingleNode('os').appendChild(
						$private.xml.createTextnode("$($os.caption -replace '[^a-zA-Z0-9 ]','') SP$($os.ServicePackMajorVersion)".Trim() )
					);
					
					$asset.selectSingleNode('deviceType').appendChild( $private.xml.createTextnode( @('Workstation','Server')[ ($os.caption -like '*windows server*') ] ) );
					
					$Searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ErrorAction 'Stop' -ErrorVariable ErrProcessNewObjectSearcher
					$Searcher.Filter = "(&(objectCategory=Computer)(name=$($hostname)))"
                    $Searcher.SizeLimit = 1
					$Searcher.SearchRoot = ""
					$res = $searcher.findall() | select -expand properties | select @{ n='description'; e={$_.description }},  @{ n='location'; e={$_.location }}
					$asset.selectSingleNode('location').appendChild( $private.xml.createTextnode( $res.location ) );
					$asset.selectSingleNode('description').appendChild( $private.xml.createTextnode( $res.description  ) );
					
					#try to get the product key
					$Reg = [WMIClass] ("\\" + $($hostname) + "\root\default:StdRegProv")
					$values = [byte[]]($reg.getbinaryvalue(2147483650,"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion","DigitalProductId").uvalue)

					$prodKey = $utilities.decodeProductKey( $($values) )
					if($prodKey -like '*BBBBB*'){
						$values = [byte[]]($reg.getbinaryvalue(2147483650,"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion","DigitalProductId4").uvalue)
						$prodKey = $utilities.decodeProductKey( $($values) )
					}
					
					$asset.selectSingleNode('osProductKey').appendChild( $private.xml.createTextnode( $prodKey  ) );
					
					
					
				}catch{
				
				}
			}
			$private.xml.selectSingleNode('//cstsPackage/assets').appendChild($asset)
		}
	}

	$private.gui.controls.stbMain.Items['stbProgress'].value = 0
	$private.gui.controls.stbMain.Items['stbStatus'].text = 'Status: '

	$private.xml.save( "$($pwd)\packages\$($private.package)\package.xml")
	$private.showHardware()
}