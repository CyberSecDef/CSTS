$HostGuiClass = new-PSClass HostGui{
    note -private LdapRoot 
    note -private domain 
    note -private gui

    note -private onDomain
    note -private hostcsvpath 
    note -private computers 
    note -private ou
    
    property HostCsvPath -get { $private.hostcsvpath }
    property Computers -get { $private.computers }
    property OU -get { $private.ou }
        
    method -private addNode{
        param ($selectedNode, $name, $text, $tag )
        
        if($private.onDomain -eq $true){
            $newNode = new-object "$forms.TreeNode"
            $newNode.Name = $name
            $newNode.Text = $text
            $newNode.Tag = $tag
            $selectedNode.Nodes.Add($newNode) | Out-Null
            return $newNode
        }
    }
    
    method -private parseAdNodes{
        param( $parentNode, $path )
        if($private.onDomain){
            $prefix = "LDAP://"
            if($path -ne "" -and $path -ne $null){
                $query = $path.path
            }else{
                $query = "$($prefix)$($private.domain)"
            }
            
            $uiClass.writeColor("$($uiClass.STAT_WAIT) #green#Parsing OU:# $query") | out-null
                
            $root = new-object directoryservices.directoryentry $query
            $selector = new-object directoryservices.directorysearcher
            $selector.searchroot = $root
            $selector.SearchScope  = "OneLevel"
            $ous = $selector.findall() | ? {$_.path -match 'LDAP://OU=*' } 
            
            $ous | sort { $_.Path } | % {
                $path = $_.Path.replace(",$($private.domain)","").replace("LDAP://","")
                $newNode = $private.addNode($parentNode,$_.path,$path.split(",")[0].replace("OU=",""), "OU")
                $private.parseAdNodes($newNode ,$_) | out-null
            }
        }
    }
    
    method -private actListColumnClick{
        [System.Windows.Forms.ColumnClickEventHandler]{
        
            if($private.gui.Vars.LastColumnClicked -eq $_.Column){
                $private.gui.Vars.LastColumnAscending = (-not $private.gui.Vars.LastColumnAscending )
            }
            
            $private.gui.Vars.LastColumnClicked = $_.Column

            $array = New-Object System.Collections.ArrayList

            foreach($item in $private.gui.Controls.lstPreview.Items){
                $psobject = New-Object PSObject 
                $psobject | Add-Member -type 'NoteProperty' -Name 'Text' -value $item.SubItems[$_.Column].Text
                $psobject | Add-Member -type 'NoteProperty' -Name 'ListItem'-value $item
                $array.Add($psobject) | out-null
            }

            if($private.gui.Vars.LastColumnAscending){
                $array = ($array | Sort-Object -Property Text)
            }else{
                $array = ($array | Sort-Object -Property Text -Descending )
            }

            $private.gui.Controls.lstPreview.BeginUpdate() | out-null
            $private.gui.Controls.lstPreview.Items.Clear() | out-null
            $index = 0
            foreach($item in $array){
                $index++
                
                $item.ListItem.SubItems[0].Text = $index
                $private.gui.Controls.lstPreview.Items.Add($item.ListItem) | out-null
            }
            
            $private.gui.Controls.lstPreview.EndUpdate() | out-null;
        }
    }
    
    method -private actClearSelections{
        
        $private.hostCsvPath = ""
        $private.gui.Controls.txtFileName.text = ""
        $private.gui.Controls.treeOu.selectedNode = $null
        $private.gui.Controls.txtCsv.text = ""
        $private.gui.Controls.txtCommand.Text = ""
        $private.gui.Controls.lstPreview.Items.Clear() | out-null
    }
    
        
    method -private actExecute{
        $private.actGetCommand() | out-null
        $uiClass.writeColor("$($uiClass.STAT_WAIT) #green#Command:# $($private.gui.Controls.txtCommand.Text)")
        
        $private.gui.Form.close();
    }
    
    method -private actGetPreview{
        $private.gui.Controls.lstPreview.Items.Clear() | out-null
        $index = 0
                
        $systems = $dbclass.get().table('system')
        
        #add empty item as stupid hack to prevent duplicates
        $item =  New-Object "$forms.ListviewItem"( "" )
        $private.gui.Controls.lstPreview.Items.Add( $item ) | out-null
        
        # index, hostname, ip, MAC, Active
        
        if($private.hostCsvPath -ne $null -and $private.hostCsvPath -ne ""){
            if(test-path $($private.hostCsvPath)){
                $csvHosts = import-csv $($private.hostCsvPath)
                $csvHostIndex = 0
                foreach($hostName in $csvHosts){
                    
                    [System.Windows.Forms.Application]::DoEvents()  | out-null
                    
                    $csvHostIndex++
                    $private.gui.Controls.pbrPreview.Value = (33 * ($csvHostIndex/($csvHosts.count)))
                    if($hostname -ne $null -and $private.gui.Controls.lstPreview.FindItemWithText("$($hostName.HostName)", $true, 0)  -eq $null ){
                        $index++ | out-null
                        
                        $macDbData = $systems.magic('findOneByHostname',"$($hostName.HostName.Trim())")
                        
                        $item =  New-Object "$forms.ListviewItem"( $index )
                        if($macDbData.count -ne 0 -and $utilities.isBlank($hostName.Hostname) -eq $false ){
                            $item.SubItems.Add( "$($hostName.Hostname)".ToUpper().Trim() ) | out-null
                            $item.SubItems.Add( "$($macDbData.IP)" ) | out-null
                            $item.SubItems.Add( "$($macDbData.MAC)" ) | out-null
                        }else{
                            $item.SubItems.Add( "$($hostName.Hostname)".ToUpper().Trim() ) | out-null
                        
                        }
                        
                        $private.gui.Controls.lstPreview.Items.Add( $item ) | out-null
                    }
                }
            }
        }                           
        
        $private.gui.Controls.pbrPreview.Value = 33
        
        $txtCsvIndex = 0;
        $txtCsvIndexCount = $private.gui.Controls.txtCsv.Text.split(",").count;
        $private.gui.Controls.txtCsv.Text.split(",") | %{
            $txtCsvIndex++
            [System.Windows.Forms.Application]::DoEvents() 
            $private.gui.Controls.pbrPreview.Value = 33 + (33 * ($txtCsvIndex/($txtCsvIndexCount)))
            $hostName = $_
            if($_ -ne $null -and $_ -ne "" -and $private.gui.Controls.lstPreview.FindItemWithText("$($hostName.trim())", $true, 0) -eq $null ){
                $index++ 
                
                $macDbData = $systems.magic('findOneByHostname',"$($hostName.Trim())")
                
                $item =  New-Object "$forms.ListviewItem"( $index )
                
                if($macDbData.count -ne 0){
                    $item.SubItems.Add( "$($hostName)".ToUpper().Trim() ) | out-null
                    $item.SubItems.Add( $macDbData.IP ) | out-null
                    $item.SubItems.Add( $macDbData.MAC ) | out-null
                }else{
                    $item.SubItems.Add( "$($hostName)".ToUpper().Trim() ) | out-null
                }
                $private.gui.Controls.lstPreview.Items.Add( $item ) | out-null
            }
        }
        
        $private.gui.Controls.pbrPreview.Value = 66
        if($private.gui.Controls.treeOu.SelectedNode -ne $null){
            if ($private.gui.Controls.treeOu.SelectedNode.Tag -eq "OU") {
                $ds = New-Object DirectoryServices.DirectorySearcher
                $ds.Filter = "ObjectCategory=Computer"
                $ds.SearchRoot = $private.gui.Controls.treeOu.SelectedNode.Name
                
                $dsFind = $ds.FindAll()
                
                $dsIndex = 0
                if($utilities.isBlank($dsFind) -eq $true){
                    $dsCount = 1
                }else{
                    $dsCount = $dsFind.count
                }

                $dsFind | % {
                    $dsIndex++
                    [System.Windows.Forms.Application]::DoEvents()  | out-null
                    $private.gui.Controls.pbrPreview.Value = 64 + (33 * ($dsIndex/($dsCount)))
                    $hostName = ("$( $_.Properties.dnshostname )")
                    
                    if($hostName -ne "" -and $private.gui.Controls.lstPreview.FindItemWithText("$($hostName)", $true, 0) -eq $null ){
                        $index++ 
                        if($hostName.IndexOf(".") -ne "-1"){
                            $hostName = $hostName.substring(0,$hostName.IndexOf("."))
                        }
                        
                        $macDbData = $systems.magic('findOneByHostname',"$($hostName.Trim())")
                        $item =  New-Object "$forms.ListviewItem"( $index )
                        
                        if($macDbData.count -ne 0 ){
                            $item.SubItems.Add( "$($hostName)".ToUpper().Trim() ) | out-null
                            $item.SubItems.Add( $macDbData.IP ) | out-null
                            $item.SubItems.Add( $macDbData.MAC) | out-null
                        }else{
                            $item.SubItems.Add( "$($hostName)".ToUpper().Trim() ) | out-null
                        }
                        
                        $private.gui.Controls.lstPreview.Items.Add( $item ) | out-null
                    }
                }
            }
        }

        $private.gui.Controls.lstPreview.Items[0].Remove() | out-null
        $private.gui.Controls.lstPreview.AutoResizeColumns('ColumnContent') | out-null
        $private.gui.Form.refresh() | out-null
        $private.gui.Controls.pbrPreview.Value = 0
    }

    method -private actGetCommand{
        $private.gui.Controls.txtCommand.Text = ""
        
         $private.OU = ""
        if($private.gui.Controls.treeOu.SelectedNode -ne $null){
            if($private.gui.Controls.treeOu.SelectedNode.Tag -eq "OU") {
                $private.OU = $private.gui.Controls.treeOu.SelectedNode.Name.replace("LDAP://","")
            }
        }
        if($private.OU -ne ""){
            $private.gui.Controls.txtCommand.Text += "-ou `"$($private.OU)`" "
        }

        $private.computers = $private.gui.Controls.txtCsv.Text
        if($private.computers -ne "" -and $private.computers -ne $null){
            $private.gui.Controls.txtCommand.Text += "-computers `"$($private.computers)`" "
        }
                
        $private.hostcsvpath = $private.gui.Controls.txtFileName.Text
        if($private.hostCsvPath -ne "" -and $private.hostCsvPath -ne $null){
            $private.gui.Controls.txtCommand.Text += "-HostCsvPath `"$($private.hostCsvPath)`" "
        }
        
        $private.gui.Form.refresh() | out-null
    }
    
    method -private actGetHelpTree{
        if($private.onDomain){
            [System.Windows.Forms.Application]::DoEvents();
            if ($private.gui.Controls.cmdletNodes) { 
                $private.gui.Controls.treeOu.Nodes.remove($private.gui.Controls.cmdletNodes) | out-null
                $private.gui.form.Refresh() | out-null
            }
                    
            $private.gui.Controls.cmdletNodes = New-Object "$forms.TreeNode"
            $private.gui.Controls.cmdletNodes.text = $private.domain 
            $private.gui.Controls.cmdletNodes.Name = $private.domain 
            $private.gui.Controls.cmdletNodes.Tag = "root"
            $private.gui.Controls.treeOu.Nodes.Add($private.gui.Controls.cmdletNodes) | Out-Null
            
            $private.parseAdNodes($private.gui.Controls.cmdletNodes) | out-null
            
            $private.gui.Controls.cmdletNodes.Expand() | out-null
        }
    }
    
    
    constructor{
        
        if( (gwmi win32_computerSystem | select -expand partOfDomain) ){
            $private.LdapRoot = [ADSI]"LDAP://RootDSE"
            $private.domain = $private.LdapRoot.Get("rootDomainNamingContext")
            $private.onDomain = $true
        }else{
            $private.LdapRoot = $null
            $private.domain = $null
            $private.onDomain = $false
        }
        
        $private.gui = $guiClass.New("hosts.xml")
        
        $private.gui.generateForm() | out-null;
        
        $private.gui.Vars.add("LastColumnClicked",0) | out-null
        $private.gui.Vars.add("LastColumnAscending",$false) | out-null
                
        $private.gui.Controls.btnExecute.add_Click({ $private.actExecute() }) | out-null
        $private.gui.Controls.btnClearSelections.add_Click({ $private.actClearSelections() }) | out-null
        $private.gui.Controls.btnPreviewHosts.add_Click({ $private.actGetPreview() }) | out-null
        $private.gui.Controls.txtCsv.add_TextChanged({ $private.actGetCommand() }) | out-null
        $private.gui.Controls.btnOpenCsvFile.add_Click({ 
            $private.hostCsvPath = $private.gui.actInvokeFileBrowser(); 
            $private.gui.Controls.txtFileName.Text = $private.hostCsvPath
            $private.actGetCommand()  | out-null
        })
        $private.gui.Controls.lstPreview.add_ColumnClick( $private.actListColumnClick()) | out-null
        $private.gui.Controls.treeOu.add_AfterSelect( { $private.actGetCommand() } ) | out-null
        $private.gui.Form.add_Load( { $private.actGetHelpTree() }) | out-null
        $private.gui.Form.ShowDialog()| Out-Null
    }
}