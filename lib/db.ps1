import-module "$pwd\modules\SQLite"
$dbClass = New-PSClass Db{
	note -static singleton 

	note -private dbConnection	#database connection
	note -private dbCommand
	
	constructor{
		if ([System.IntPtr]::Size -eq 4) { 
			[void][System.Reflection.Assembly]::LoadFrom("$pwd\bin\SQLite\x32\System.Data.SQLite.dll")
		} else { 
			[void][System.Reflection.Assembly]::LoadFrom("$pwd\bin\SQLite\x64\System.Data.SQLite.dll")
		}
	}

	method -static get{
		if($utilities.isBlank($dbClass.singleton) -eq $true){
			$dbClass.singleton = $dbClass.new()
		}
		$dbClass.singleton.open() | out-null
		return ,($dbclass.singleton)
	}
	
	method query{
		param($sql, $parms)
		
		$private.dbCommand = New-Object -TypeName System.Data.SQLite.SQLiteCommand
		$private.dbCommand.Connection = $private.dbConnection
		$private.dbCommand.CommandText = $sql
		if($parms -ne $null){
			foreach($par in ($parms.getEnumerator() ) ){
				$private.dbCommand.Parameters.Add(  ( new-object -TypeName System.Data.SQLite.SQLiteParameter( "$($par.name)", ($par.value)  ) ) ) | out-null
			}
			$private.dbCommand.prepare()
		}

		return $this
	}
	
	method table{
		param($tbl)
		if($utilities.isBlank($tbl) -eq $false){
			return ($this.query("select * from $($tbl)").execReader($tbl))
		}
	}
	
	method schema{
		return $private.dbConnection.getSchema()
	}
		
	method execAssoc{
		param($tbl = 'custom')
		$dbReader = $private.dbCommand.executeReader()
		$results = @()
		
		while ($dbReader.Read()){
			$row = @{}
			for($f=0; $f -lt $dbReader.fieldCount; $f++){
				$row.$($dbReader.getName($f)) = $dbReader.getValue($f)
			}
			$results +=  $row
		}
		$dbReader.close()
		return ,$results
	}
	
	method execReader{
		param($tbl = 'custom')
		$dbReader = $private.dbCommand.executeReader()
		$results = $entityCollectionClass.New()
		
		while ($dbReader.Read()){
			$row = @{}
			for($f=0; $f -lt $dbReader.fieldCount; $f++){
				$row.$($dbReader.getName($f)) = $dbReader.getValue($f)
			}
			$results.addEntity( $entityClass.new($tbl, $row) )
		}
		$dbReader.close()
		return $results
	}
	
	method execNonQuery{
		param()
		
		$private.dbCommand.ExecuteNonQuery()
	}
	
	method close{
		
		if( (get-psdrive | ? { $_.name -eq 'cyberDb' }) -ne $null ){
			Remove-PSDrive cyberDb
		}
		
		$private.dbConnection.close()
		return $this
	}
	
	method open{
		param($dbFile = "$pwd\db\db.sqlite")
		
		#mount as a drive
		if( (get-psdrive | ? { $_.name -eq 'cyberDb' }) -eq $null ){
			mount-sqlite -name cyberDb -dataSource $dbFile
		}
		
		#create Connection
		if($private.dbConnection -eq $null -or $private.dbConnection.state -ne 'Open'){
			$private.dbConnection = New-Object -TypeName System.Data.SQLite.SQLiteConnection
			$private.dbConnection.ConnectionString = "Data Source=$($dbFile)"
			$private.dbConnection.open()
		}
		
		return $this
	}
	
	method exists{
		param($table)
		$res = $dbClass.Get().query("SELECT name FROM sqlite_master where type = 'table' and name='$($table)' ").execReader('sqlite_master')
		return [bool]($res.count())
	}
}


$entityClass = New-PSClass entity{
	note -private data @{}
	note -private table

	property data -get { return $private.data; }
	property table -get {return $private.table;}
	
	constructor{
		param($table, $data)
		$private.table = $table

		$data.id = $null
		if($utilities.isBlank($data) -eq $false){
			foreach($key in ($data.keys)){
				$private.data.$key = $data.$key
				
				#making data fields actual object properties
				$scriptProperty = invoke-expression "new-object management.automation.PsScriptProperty $key, { return `$this.get('$($key)') }"
				$this.psobject.properties.add($scriptProperty)		
			}
		}
		$private.data.Remove('name') # added because a 'name' key always gets populated
	}
	
	method getFields{
		return ($private.data.keys)
	}
	
	method toJSON{
		$json = "{""entity"": {""table"":""$($private.table)"", ""data"":["
		$private.data.keys | %{ $json += "{""name"":""$($_)"", ""dataType"":""$($private.data.$_.getType())"",""content"":""" + ($private.data.$_ -replace '"','\"' ) + """}," }
		$json = $json.substring(0,$json.length-1)
		$json += "]}}"
		
		return $json
	}
	
	method toXML{
		[system.xml.xmldocument]$xml = new-object system.xml.xmldocument
		[system.xml.xmlelement]$entity = $xml.createElement('entity')
		$xml.appendChild($entity) | out-null
		$entity.setAttribute('tableName',$private.table) | out-null
		
		foreach($key in $private.data.keys){
			$k = $xml.createElement($key)
			$k.setAttribute('dataType', $private.data.$key.getType()) | out-null
			$k.appendChild($xml.createTextNode($private.data.$key)) | out-null
			$entity.appendChild($k) | out-null
		}
		return ($xml)
	}
	
	method get{
		param($field)
		if($utilities.isBlank($private.data) -eq $false){
			if($private.data.keys -contains $field){
				return $private.data.$field
			}else{
				return $false
			}
		}
	}
	
	method set{
		param($field, $value)
		
		if($field -ne 'ID'){
			if($private.data.keys -contains $field){
				if( $value -is $private.data.$field.getType() ){
					$private.data.$field = $value
					return $this
				}else{
					return $false
				}
			}else{
				return $false
			}
		}else{
			return $false
		}
	}
	
	method delete{
		if($private.data.ID -ne 0 -and $private.data.ID -ne $null){
			$sql = "delete from $($private.table) where ID = :ID "
			$dbClass.get().query($sql, @{ "ID" = ($private.data.ID); } ).execNonQuery();
		}
		return $null
	}
	
	method save{
		#see if this is an insert or an update
		if($private.data.ID -eq 0 -or $private.data.ID -eq $null){
			#create insert statement
			$sql = "insert into $($private.table) ("
			$private.data.keys | ? { $_ -ne 'ID' } | % {
				$sql += "$($_),"
			}
			$sql = $sql.substring(0,$sql.length-1)
			$sql += ") Values ("
			$private.data.keys | ? { $_ -ne 'ID' } | % {
				$sql += ":$($_),"
			}
			$sql = $sql.substring(0,$sql.length-1)
			$sql += ")"
			
			$sqlFields = @{}
			$private.data.keys | ? { $_ -ne 'ID' } | % {
				$sqlFields.Add( $_, $private.data.$_)
			}
			
			
			$dbClass.get().query($sql,$sqlFields).execNonQuery();
			
			$sql = "select max(id) as idval from $($private.table) where 1=1 "
			$sqlFields = @{}
			$private.data.keys | ? { $_ -ne 'ID' } | % {
				$sql += " and $($_) = :$($_) "
				$sqlFields.Add( $_, $private.data.$_)
			}
			
			$private.data.ID = $dbclass.get().query($sql,$sqlFields).execAssoc().idVal
			
		}else{
			$sql = "update $($private.table) set "
			$private.data.keys | ? { $_ -ne 'ID' } | % {
				$sql += "$($_) = :$($_),"
			}
			$sql = $sql.substring(0,$sql.length-1)
			$sql += " where ID = :ID "
			
			$sqlFields = @{}
			$private.data.keys | % {
				$sqlFields.Add( $_, $private.data.$_)
			}
			
			
			$dbClass.get().query($sql,$sqlFields).execNonQuery();
		}
		return $this
	}
}



$entityCollectionClass = new-psclass entityCollection{
	note -private collection @()
	
	constructor{
	
	}
	
	method count{
		return $private.collection.count
	}
	
	method addEntity{
		param($entity)
		$private.collection += $entity
	}
	
	method removeEntity{
		param($id)
		$private.collection[$id] = $null
	}
	
	method getEntity{
		param($id)
		return $private.collection[$id]
	}
	
	method findByPk{
		param($pkid)
		
		if($pkid.count -gt 1){
			return ($private.collection | ? { $pkid -contains $_.id } )
		}else{
			return ($private.collection| ? { $_.get('id') -eq $pkid })
		}
	}
	
	method desc{
		param($param)
		$tmp = @()
		for($i = $( $private.collection.count - 1 ); $i -ge 0; $i--){
			$tmp += $private.collection[$i]
		}
		$private.collection = $tmp
		return $this
	}
	

	method toJSON{
	
		$json = "{""entities"": [ "
		$private.collection | % {
			$json += $_.toJSON() + ","
		}
		
		$json = $json.substring(0,$json.length-1)
		$json += "]}"
		
		return $json
	}
	
	method toXML{
		[system.xml.xmldocument]$xml = new-object system.xml.xmldocument
		[system.xml.xmlelement]$entities = $xml.createElement('entities')
		
		$private.collection | % {
			
			$xmlDocFragment = $xml.CreateDocumentFragment()
			$xmlDocFragment.InnerXml = $_.toXml().outerXml;
			
			$entities.appendChild($xmlDocFragment) | out-null
		}
		
		$xml.appendChild($entities) | out-null
		return ($xml)
	}
	
	
	
	
	
	#returns resultset without changing the internal result set
	method findOneBy{
		param($col,$param)

		if($col -clike '*And*'){
			$pI = 0
			$cols = $col -split 'And'
			$tmp = $private.collection
			foreach($c in $cols){
				$tmp = $tmp | ? { $_.get($c) -like "*$($param[$pi])*" }
				$pi++
			}
			
			$res = ($tmp | select -first 1)
		}else{

			$res = ($private.collection | ? { $_.get($col) -like "*$($param)*" } | select -first 1)
		}
		
		if($res -ne $null){
			return ,$res 
		}else{
			return $null
		}
	}
	
	#changes internal result set
	method orderBy{
		param($col,$param)
		$private.collection = $private.collection | sort { $_.get($col) }
		if($param -eq 'Desc'){
			$this.desc();
		}
		return $this
	}
	
	#changes internal result set
	method filterBy{
		param($col, $param)

		if($col -clike '*And*'){
			$pI = 0
			$cols = $col -split 'And'
			$tmp = $private.collection
			foreach($c in $cols){
				$tmp = $tmp | ? { $_.get($c) -like "*$($param[$pi])*" }
				$pi++
			}
			$private.collection = $tmp
		}else{
			$private.collection = $private.collection | ? { $_.get($col) -like "*$($param)*" }
		}
	}
	
	method magic{
		param($method, $param)
		switch($true){
			($method -like 'orderby*')   { $this.orderBy(   $($method -replace 'orderby',''),   $param); return $this }
			($method -like 'filterby*')  { $this.filterBy(  $($method -replace 'filterby',''),  $param) ; return $this }
			($method -like 'findoneby*') { return ($this.findOneBy( $($method -replace 'findoneby',''), $param)); }
		}
	}
	
	method first{
		param()
		if($private.collection.count -gt 0){
			return ($private.collection | select -first 1)
		}else{
			return $null
		}
	}
	
	method one{
		$row = $private.collection | select -first 1
		$key = $row.data.keys | select -first 1
		return $row.get($key)
	}
	
	method Results{
		param()
		if($private.collection.count -gt 0){
			return ($private.collection | ? { $utilities.isblank($_) -eq $false })
		}
	}
}