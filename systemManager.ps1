<#
.SYNOPSIS
	[Incomplete script!] This is a template for new scripts
.DESCRIPTION
	[Incomplete script!] This is a template for new scripts
.EXAMPLE
	C:\PS>.\template.ps1
	This will bring up the new script
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Nov 19, 2015
#>
[CmdletBinding()]
param (	)   

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$systemManagerClass = new-PSClass systemManager{
	note -static PsScriptName "systemManager.ps1"
	note -static Description ( ($(((get-help .\systemManager.ps1).Description)) | select Text).Text)
	
	note -private tabData @{}
	note -private mainProgressBar
	note -private gui
	note -private hklm
	note -private hkcu
	
	constructor{
		param()
		
		if((test-path "$pwd\bin\iconTools.dll") -eq $false){
			Add-Type -Language CSharpVersion3 -TypeDefinition ([System.IO.File]::ReadAllText("$pwd\types\iconTools.cs")) -ReferencedAssemblies @("System.Drawing","WindowsBase","System.Windows.Forms")  -ErrorAction Stop -OutputAssembly "$pwd\bin\iconTools.dll" -outputType Library
		}
		
		if (!("csts.iconTools" -as [type])) {
			Add-Type -path "$pwd\bin\iconTools.dll"
		}
		
		$private.hklm = $registryClass.New()
		$private.hkcu = $registryClass.New()
				
		$private.gui = $null
		
		$private.gui = $guiClass.New("systemManager.xml")
		$private.gui.generateForm() | out-null;
		
		$private.gui.controls.toolMain.autosize = $true
		$private.gui.controls.toolMain.stretch = $true
		$private.gui.controls.toolMain.items['tsiTxtAddress'].dock = 'Fill'
		$private.gui.form.add_resize({$self.formResize()})
		$private.gui.controls.toolMain2.items['tsiAdd'].add_click({$self.addTab()})
		
		
		$this.formResize()
		$this.addTab('C:\')
		
		
		$private.gui.Form.ShowDialog() | Out-Null	
	}
		
	method quickNode{
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
	
	method updateFSItems{
		param($node)
		$selHost = $private.tabData[ $node.node.treeview.parent.tag ].host
		if($utilities.isBlank($selHost) -eq $true){
			$selHost = 'localhost'
		}
		
		switch($node.node.tag){
			((whoami).substring((whoami).lastIndexOf('\')+1)) {}
			"FileSystem" {

				$tabListView = ( $node.node.treeview.parent.controls | ? { ($_.getType()) -like "*ListView*" } | select -first 1 )

				$tabListView.Columns.Clear();
				$tabListView.Columns.Add('Name') | out-null
				$tabListView.Columns.Add('Ext') | out-null
				$tabListView.Columns.Add('Size') | out-null
				$tabListView.Columns.Add('Date Created') | out-null
				$tabListView.Columns.Add('Date Accessed') | out-null
				$tabListView.Columns.Add('Date Modified') | out-null
				$tabListView.Columns.Add('File Version') | out-null
				$tabListView.Columns.Add('SHA1 Hash') | out-null

				$tabListView.Items.Clear();					
				$sha1 = New-Object -TypeName System.Security.Cryptography.SHA1CryptoServiceProvider
				$photoList = new-object system.windows.forms.ImageList
				#get icons
				
				$currPath = "\\$($selhost)\$($node.node.name -replace '([a-zA-z]{1}):\\','$1$\')"
				gci $currPath | ? { $_.PSIsContainer -eq $false} | % {
					$photoList.Images.Add(
						[csts.iconTools]::ExtractAssociatedIcon($_.fullName)
					);
				}
				$tabListView.SmallImageList = $photoList
				$i = 0
				
				
				
				gci $currPath | ? { $_.PSIsContainer -eq $false} | % {
					$item =  New-Object "$forms.ListviewItem"( $_.name.substring($_.name.lastIndexOf('\') + 1 ) )
					$item.tag = ($_.fullName -replace '\\\\[a-zA-Z0-9-_.]+\\([a-zA-Z]{1})\$','$1:')
					$item.imageIndex  = $i
					$item.subitems.add($_.extension.toString().replace('.','').ToUpper())
					$item.subitems.add( "$([math]::round( $_.length / 1KB, 2) ) K" )
					$item.subitems.add($_.CreationTimeUtc.ToString())
					$item.subitems.add($_.LastAccessTimeUtc.ToString())
					$item.subitems.add($_.LastWriteTimeUtc.ToString())
					
					$item.subitems.add("$($_.versioninfo.fileVersion)")
					if($_.length -lt 1mb){
						$item.subitems.add( [System.BitConverter]::ToString($sha1.ComputeHash( [System.IO.File]::ReadAllBytes( $($_.fullname) ))))
					}else{
						$item.subitems.add( "" )
					}
					
					$tabListView.Items.Add($item);
					$i++
				}
				
				$tabListView.FullRowSelect = $true
				$tabListView.AutoResizeColumns('ColumnContent') | out-null
			}
			"Certificates" {}
			"RegistryHive" {}
			"RegistryKey" {
				if($node.node.name.substring(0,4) -eq 'hklm'){
					$reg = $private.hklm
				}else{
					$reg = $private.hkcu
				}
				
				
				$tabListView = ( $node.node.treeview.parent.controls | ? { ($_.getType()) -like "*ListView*" } | select -first 1 )

				$tabListView.Columns.Clear();
				$tabListView.Columns.Add('Name') | out-null
				$tabListView.Columns.Add('Type') | out-null
				$tabListView.Columns.Add('Data') | out-null

				$tabListView.Items.Clear();	
				
				foreach($valName in ($reg.key.GetValueNames() | sort ) ){
					$item =  New-Object "$forms.ListviewItem"( $valName )
					$item.tag = $valName
					$item.subitems.add(
						$reg.key.getValueKind( $valName ).ToString().ToUpper()
					)
					
					switch( ( $reg.key.getValueKind( $valName ).ToString().ToUpper() ) ){
						"BINARY" { 
							
							$item.subitems.add( ( ($reg.key.getValue( $valName ) | % { $_.ToString('X2') } ) -join " " ).toLower() )
						}
						default { $item.subitems.add( $reg.key.getValue( $valName ).ToString() ) }
					}
						
					$tabListView.Items.Add($item);
				}
				
				$tabListView.FullRowSelect = $true
				$tabListView.AutoResizeColumns('ColumnContent') | out-null
			}
			default {}
			
		}
	}
	
	method updateFSNodes{
		param($node)
		$node.node.treeview.parent.text = $node.node.text
		$selHost = $private.tabData[ $node.node.treeview.parent.tag ].host
		if($utilities.isBlank($selHost) -eq $true){
			$selHost = 'localhost'
		}
		write-host "NAME: $($node.node.name)"
		write-host "TAG: $($node.node.tag)"
		write-host "Text: $($node.node.text)"
		switch($node.node.tag){
			"System" {   }
			"Computer" { 
				$node.node.nodes.clear(); 
				gwmi win32_logicalDisk -computerName $selHost | select -expand DeviceId | sort | % {
					$node.node.Nodes.Add($self.quickNode("$($_)\",'FileSystem')) | Out-Null; 
				}
				$node.node.expand() 
			}
			"Certificates" { $node.node.nodes.clear(); gci cert:\ | select -expand Location | sort | % { $node.node.Nodes.Add($self.quickNode($_,'CertificateHive')) | Out-Null; $node.node.expand()} }
			"Environment" {  }
			"Favorites" { }
			"Recycle Bin" { }
			"Registry" { $node.node.nodes.clear(); $node.node.Nodes.Add($self.quicknode('HKCU','RegistryHive')) | Out-Null; $node.node.Nodes.Add($self.quickNode('HKLM','RegistryHive')) | Out-Null; $node.node.expand() }
			((whoami).substring((whoami).lastIndexOf('\')+1)){ 
				$node.node.nodes.clear()
				gci -path (gci env:\USERPROFILE | select -expand value) | % { 
					$node.node.Nodes.Add($self.quickNode($_.name,'FileSystem', $_.fullname)) | Out-Null; $node.node.expand() } 
			}
			"RegistryKey" {
				$private.gui.controls.toolMain.items['tsiTxtAddress'].text = "\\$($selHost)\$($node.node.name)"
				switch($node.node.name.substring(0,6)){
					"hklm:\" {
						$node.node.nodes.clear()
						$private.hklm.open($selhost,"LocalMachine")
						
						$selKey = $node.node.name.substring(6)
						$private.hklm.openSubKey($selKey)
						$private.hklm.GetSubKeyNames() | %{
							$node.node.Nodes.Add($self.quickNode(
								$_,
								'RegistryKey', 
								"HKLM:\$($selKey)\$($_)"
							)) | Out-Null; 
							$node.node.expand()
						}
						
					}
					"hkcu:\" {
						$node.node.nodes.clear()
						$private.hkcu.open($selhost,"CurrentUser")
						
						$selKey = $node.node.name.substring(6)
						$private.hkcu.openSubKey($selKey)
						$private.hkcu.GetSubKeyNames() | %{
							$node.node.Nodes.Add($self.quickNode(
								$_,
								'RegistryKey', 
								"HKCU:\$($selKey)\$($_)"
							)) | Out-Null; 
							$node.node.expand()
						}
						
					}
				}
			}
			"RegistryHive" {
				$private.gui.controls.toolMain.items['tsiTxtAddress'].text = "\\$($selHost)\$($node.node.name)"
				switch($node.node.name){
					"hklm" {
						$node.node.nodes.clear()
						$private.hklm.open($selhost,"LocalMachine")
						$private.hklm.openSubKey('')
						$private.hklm.GetSubKeyNames() | %{
							$node.node.Nodes.Add($self.quickNode(
								$_,
								'RegistryKey', 
								"HKLM:\$($_)"
							)) | Out-Null; 
							$node.node.expand()
						}
						$private.hklm.close()
					}
					"hkcu" {
						$node.node.nodes.clear()
						$private.hkcu.open($selhost,"CurrentUser")
						$private.hkcu.openSubKey('')
						$private.hkcu.GetSubKeyNames() | %{
							$node.node.Nodes.Add($self.quickNode(
								$_,
								'RegistryKey', 
								"HKCU:\$($_)"
							)) | Out-Null; 
							$node.node.expand()
						}
						$private.hkcu.close()
					}
				}
			}
			"FileSystem" {
				$private.gui.controls.toolMain.items['tsiTxtAddress'].text = "\\$($selHost)\$($node.node.name -replace '([a-zA-z]{1}):\\','$1$\')"
				$node.node.nodes.clear()
				$currPath = "\\$($selhost)\$($node.node.name -replace '([a-zA-z]{1}):\\','$1$\')"
				gci $currPath | ? { $_.PSIsContainer -eq $true} | % {
					$node.node.Nodes.Add($self.quickNode(
						$_.name,
						'FileSystem', 
						($_.fullname -replace '\\\\[a-zA-Z0-9-_.]+\\([a-zA-Z]{1})\$','$1:')
					)) | Out-Null; 
					$node.node.expand()
				}
			}
		}
		
		
	}
	method addTab{
		param($path = "C:\")
		
		if( (test-path $path) -eq $false){
			$path = 'C:\'
		}
		
		
		$currentTabCount = $private.gui.controls.tabControl.tabCount
		$private.gui.controls.tabControl.tabPages.add($path)
		$private.gui.controls.tabControl.selectTab( $currentTabCount )
		
		$treeview = new-object "System.Windows.Forms.treeview"
		$treeView.add_AfterSelect({ $self.updateFSNodes( $_ ); $self.updateFSItems( $_ ) })
		$treeview.dock = 'left'
		$treeview.width = 200
		$treeview.sorted = $true
		
		$treeview.Nodes.Add($self.quickNode("System (localhost)")) | Out-Null
		$treeview.Nodes[0].expand() | out-null
		@('Local Group Policy','Auditpol','Local Security Policy','Task Scheduler','Event Viewer','Shared Folders','Local Users And Groups','Device Manager','Computer','Recycle Bin','Services', 'Environment','Certificates', ((whoami).substring((whoami).lastIndexOf('\')+1)), 'Favorites', 'Registry') | % { 
			$treeview.Nodes[0].nodes.Add($self.quickNode($_) ) | Out-Null 
		}
		
		$private.gui.controls.tabControl.selectedTab.controls.add( $treeView )
		$private.gui.controls.tabControl.selectedTab.tag = [guid]::newGuid() | select -expand guid
		$private.tabData.Add( $private.gui.controls.tabControl.selectedTab.tag, @{} )
		$private.tabData[$private.gui.controls.tabControl.selectedTab.tag].Add("host","localhost")
		
		#create Context menu for tree node on this tab
		#Node List Context Menu
		$context = new-object "system.windows.forms.ContextMenu"
		$menuItemArray = @(
			@{"weight" = 1; "Tag" = "REMCON"; "Text" = "Connect to Remote Host"; "Value" = $null},
			@{"weight" = 2; "Tag" = ""; "Text" = "New Value"; "Value" = @(
					@{"weight" = 1; "Tag" = ""; "Text" = "String"; "Value" = $null;},
					@{"weight" = 2; "Tag" = ""; "Text" = "Binary"; "Value" = $null;},
					@{"weight" = 3; "Tag" = ""; "Text" = "DWord"; "Value" = $null;},
					@{"weight" = 4; "Tag" = ""; "Text" = "QWord"; "Value" = $null;}
				)
			}
		)
		foreach($menuArrayItem in ($menuItemArray | sort { $_.Weight} ) ){
			$menuItem = new-object "System.windows.forms.MenuItem"
			$menuitem.text = $menuArrayItem.Text
			$menuItem.tag =  $menuArrayItem.tag
			if($menuArrayItem.Value -eq $null){
				$menuitem.add_click( { $self.tabTreeView_OnClick($this) }) | out-null
			}else{
				foreach($subMenuArrayItem in ($menuArrayItem.Value | sort { $_.weight } ) ){
					if($subMenuArrayItem.Value -eq $null){
						$subMenuItem = new-object "System.windows.forms.MenuItem"
						$subMenuItem.text = $subMenuArrayItem.Text
						$subMenuItem.add_click( { $self.tabTreeView_OnClick($this) }) | out-null
					}
					$menuItem.menuItems.add($subMenuItem) | out-null
				}
			}
			$context.menuItems.Add($menuItem) | out-null
		}
		$treeView.ContextMenu = $context;
		
		
		$listView = new-object "System.Windows.Forms.listView"
		$listView.dock = 'right'
		$listView.width = ( $private.gui.form.width - 25 - $treeview.width)
		$listview.view = 'details'
		$private.gui.controls.tabControl.selectedTab.controls.add( $listView )
		
	}
	
	method connectToRemoteHost{
		$selHost = $private.gui.Input('Enter the computer name to connect to.','Remote Connection' )
		if($utilities.isBlank($selHost) -eq $false){
			$private.tabData[$private.gui.controls.tabControl.selectedTab.tag].host = $selHost
		}
		
		$tabTreeView = ($private.gui.controls.tabControl.selectedTab.controls | ? { ($_.getType()) -like "*TreeView*" } | select -first 1 )
		$tabTreeView.nodes.clear()
		
		$tabTreeView.Nodes.Add($self.quickNode("System ($($selhost))")) | Out-Null
		$tabTreeView.Nodes[0].expand() | out-null
		@('Local Group Policy','Auditpol','Local Security Policy','Task Scheduler','Event Viewer','Shared Folders','Local Users And Groups','Device Manager','Computer','Recycle Bin','Services', 'Environment','Certificates', ((whoami).substring((whoami).lastIndexOf('\')+1)), 'Favorites', 'Registry') | % { 
			$tabTreeView.Nodes[0].nodes.Add($self.quickNode($_) ) | Out-Null 
		}
		$tabTreeView.Nodes[0].expand()
		
		$tabListView = ($private.gui.controls.tabControl.selectedTab.controls | ? { ($_.getType()) -like "*List*" } | select -first 1 )
		$tabListView.items.clear()
	}
	
	method tabTreeView_OnClick{
		param($contextItem)
		
		switch($contextItem.tag){
			"REMCON" { $this.connectToRemoteHost()}
		}
	}
	
	method formResize{
		$private.gui.controls.toolMain.items['tsiTxtAddress'].size = new-object "$size"(( $private.gui.controls.toolMain.width - $private.gui.controls.toolmain.items['tsiLblAddress'].width - 15),40)
		$private.gui.controls.tabControl.bringToFront() | out-null
		
		$controlHeights = 0
		$private.gui.controls.keys | ? { $_ -ne 'tabControl'} | % {
			$controlHeights += $private.gui.controls.$_.height + 8
		}
		$private.gui.controls.tabControl.size = new-object "$size"(( $private.gui.controls.form1.width - 10  ), ( $private.gui.form.height - $controlHeights) )

		$private.gui.controls.tabControl.tabPages | % { 
			$tabTreeView = ($_.controls | ? { ($_.getType()) -like "*TreeView*" } | select -first 1 )
			$tabListView = ($_.controls | ? { ($_.getType()) -like "*ListView*" } | select -first 1 )
			$tabListView.width = ( $private.gui.form.width - 25 - $tabTreeView.width)
		}
		
		
		$private.gui.controls.tabControl2.dock = 'Bottom'
		$private.gui.controls.tabControl2.bringToFront() | out-null
	}
	
	
	method Execute{
		param($par)
		
		$uiClass.errorLog()
	}
}

$systemManagerClass.New().Execute()  | out-null