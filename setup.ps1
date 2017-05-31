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
param ([switch]$reload	)   
clear;
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$setupClass = new-PSClass setup{
	note -static PsScriptName "setup"
	note -static Description ( ($(((get-help .\template.ps1).Description)) | select Text).Text)
	
	note -private mainProgressBar
	note -private gui
	
	note -private createStatements @{
		"commonPort" = "create table commonPort( ID INTEGER PRIMARY KEY NOT NULL, Port integer NOT NULL, purpose text );";
		"errorCode"  = "create table errorCode( ID INTEGER PRIMARY KEY NOT NULL, errorCode TEXT NOT NULL, decimal INT NOT NULL, integer INT not null, errorString text, description text );";
		"iavm"       = "create table iavm( ID INTEGER PRIMARY KEY NOT NULL, iavm text, acknowledge date, mitigation date, summary text);"
		"system"     = "create table system( ID INTEGER PRIMARY KEY NOT NULL, hostname text, ip text, mac text);";
		
	}
	
	constructor{
		param()

	}
	
	method load{
		param( $table, $csv )
		
		$private.mainProgressBar.Activity("Populating $($table) table").Status(("{0:N2}% complete" -f 25)).Percent(25).Render()
		if($reload -eq $true){
			if( $dbClass.Get().exists($table) ){
				$uiclass.writeColor("$($uiClass.STAT_WAIT) Dropping #green#$($table)# table")
				$dbClass.Get().query( "drop table $($table);" ).execNonQuery() 
			}
		}
		if( !$dbClass.Get().Exists($table) ){
			$uiclass.writeColor("$($uiClass.STAT_WAIT) Creating #green#$($table)# table")
			$dbClass.Get().query( $private.createStatements.$($table) ).execNonQuery()
		}

		
		$uiclass.writeColor("$($uiClass.STAT_WAIT) Populating #green#$($table)# table")	
		$recordProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
		$records = Import-Csv $csv
		$i = 0
		$t = $records.count
		$sql = "select ID from $($table) where 1=1 "
		foreach($col in ($records[0] | gm -memberType NoteProperty)){
				$sql += " and $($col.name) = :$($col.name) "
		}
		
		foreach($record in $records){
			$i++
			$p = 100 * $i / $t
			$recordProgressBar.Activity("$($i) / $($t) : Populating $($table) ").Status(("{0:N2}% complete" -f $p)).Percent($p).Render()
			
			$searchTerms = @{}
			($record | gm -memberType NoteProperty) | % { $searchTerms.add( $($_.name), $record.($_.name) )  }
			
			$res = $dbClass.Get().query($sql, $searchTerms).execReader().Results()
			
			if($res.count -eq 0){
				#new entry
				$data = @{}
				foreach($col in ( $record | gm -memberType noteProperty | select -expand name ) ){
					$data.Add( $col, $($record.$col))
				}
				$e = $entityClass.new($table, $data )
				$e.save()
			}else{
				$uiClass.writeColor("$($uiClass.STAT_WARN) Skipping $($table) record #yellow#$($record.$($record | gm -memberType NoteProperty | select -expand Name -first 1))#, it already exists ")
			}
			
		}
		$recordProgressBar.Completed($true).Render() 
		
	}
	
	
	method Execute{
		param()
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		$uiclass.writeColor("$($uiClass.STAT_WAIT) Opening database")
		$private.mainProgressBar.Activity("Opening Database").Status(("{0:N2}% complete" -f 10)).Percent(10).Render()
				
		
		$uiclass.writeColor("$($uiClass.STAT_WAIT) Populating #green#IAVMs# table")
		if($reload -eq $true){ $dbclass.get().query( "drop table iavm;" ).execNonQuery() }
		$private.mainProgressBar.Activity("Populating IAVM Data table").Status(("{0:N2}% complete" -f 50)).Percent(50).Render()
		$res = $dbclass.get().query("SELECT name FROM sqlite_master where type = 'table' and name='iavm' ").execAssoc()
		if( $res.count -eq 0){ $dbclass.get().query( $private.createStatements.iavm ).execNonQuery() }
		
		$insertSql = "insert into iavm (iavm, acknowledge, mitigation, summary) values (:iavm, :acknowledge, :mitigation, :summary);"
		$selectSql = "select iavm from iavm where iavm = :iavm and acknowledge = :acknowledge and mitigation = :mitigation and summary = :summary;"
		$iavmProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
	
		$iavmFiles = gci -include "*.xml" -path '.\iavm\' -recurse | ? { $_.name -match "[0-9]+-[AB]-[0-9]+.+\.xml" } 
		$i = 0
		$t = $iavmFiles.count
		foreach($iavmFile in $iavmFiles){
			$iavm = [xml](get-content $iavmFile.fullname)
			
			if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Adding IAVM #yellow#$($iavm.iavmNotice.iavmNoticeNumber)# - #green#$($iavm.iavmNotice.title)#")
			}
			
			$i++
			$p = 100 * $i / $t
			$iavmProgressBar.Activity("$($i) / $($t) : Populating Iavm table -> $($iavm.iavmNotice.iavmNoticeNumber) - $($iavm.iavmNotice.title) ").Status(("{0:N2}% complete" -f $p)).Percent($p).Render()
			$res = $dbclass.get().query($selectSql, @{ ":iavm" = $($iavm.iavmNotice.iavmNoticeNumber); ":acknowledge" = $($iavm.iavmNotice.acknowledgeDate); ":mitigation" = $($iavm.iavmNotice.poamMitigationDate); ":summary" = $($iavm.iavmNotice.executiveSummary) }).execAssoc(); 			
			if( $res.count  -eq 0 ){
				$dbclass.get().query($insertSql, @{ ":iavm" = $($iavm.iavmNotice.iavmNoticeNumber); ":acknowledge" = $($iavm.iavmNotice.acknowledgeDate); ":mitigation" = $($iavm.iavmNotice.poamMitigationDate); ":summary" = $($iavm.iavmNotice.executiveSummary) }).execNonQuery();
			}else{
					$uiClass.writeColor("$($uiClass.STAT_WARN) Skipping IAVM #yellow#$($iavm.iavmNotice.iavmNoticeNumber)#, it already exists ")
			}
		}

		@('system','errorCode','commonPort') | %{
			$this.load($_,"$pwd\setup\$($_).csv")
		}
	
		$dbclass.get().close()
		$uiClass.errorLog()
	}
}

$setupClass.New().Execute()  | out-null