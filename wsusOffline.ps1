<#
.SYNOPSIS
	This script will create DVD ISOs with all windows update patches installed.
.DESCRIPTION
	This script will create DVD ISOs with all windows update patches installed.
.PARAMETER reDownload 
	If present, patches will be redownloaded even if they have been previously downloaded
.PARAMETER threads 
	The number of threads to be made available for file downloads.  Defaults to 10
.PARAMETER refreshDays
	How old should the microsoft CAB file be kept before forcing new downloads
.EXAMPLE
	C:\PS>.\wsusOffline.ps1
	This example will create update ISO images for all supported windows products
.EXAMPLE
	C:\PS>.\wsusOffline.ps1 -reDownload -threads 15
	This example will create update ISO images for all supported windows products by redownloading all patches and utilizing 15 download streams
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Version History:
		2015-02-12 - Inital Script Creation 
#>
[CmdletBinding()]
param ( [switch] $reDownload, [int] $threads, [int] $refreshDays )   
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }
#this is a test
$wsusOfflineClass = new-PSClass wsusOffline{
	note -static PsScriptName "wsusOffline"
	note -static Description ( ($(((get-help .\wsusOffline.ps1).Description)) | select Text).Text)
	
	note -private mainProgressBar
	note -private reDownload
	note -private threads 10
	note -private RefreshDays 3
	
	
	note -private badLanguages @("-af-za_", "-al_", "-am-et_", "-am_", "-arab-iq_", "-arab-pk_", "-as-in_", "-ba_", "-bd_", "-be-by_", "-beta_", "-bg_", "-bgr_", "-bn-bd_", "-bn-in_", "-bn_", "-ca_", "-cat_", "-chs_", "-cht_", "-cs-cz_", "-cs_", "-csy_", "-cym_", "-cyrl-ba_", "-cyrl-tj_", "-da-dk_", "-da_", "-dan_", "-de-de_", "-de_", "-deu_", "-el-gr_", "-el_", "-ell_", "-es-es_", "-es_", "-esn_", "-et_", "-eti_", "-eu_", "-euq_", "-fa-ir_", "-fi-fi_", "-fi_", "-fil-ph_", "-fin_", "-fr-fr_", "-fr_", "-fra_", "-gd-gb_", "-ge_", "-ger_", "-gl_", "-glc_", "-gu-in_", "-hbr_", "-he-il_", "-he_", "-heb_", "-hi_", "-hin_", "-hk_", "-hr_", "-hrv_", "-hu-hu_", "-hun_", "-hy-am_", "-id_", "-ig-ng_", "-in_", "-ind_", "-ir_", "-ire_", "-is-is_", "-is_", "-isl_", "-it-it_", "-it_", "-ita_", "-ja-jp_", "-jpn_", "-ka-ge_", "-ke_", "-kg_", "-kh_", "-km-kh_", "-kn-in_", "-ko-kr_", "-kok-in_", "-kor_", "-ky-kg_", "-latn-ng_", "-latn-uz_", "-lb-lu_", "-lbx_", "-lk_", "-lt_", "-lth_", "-lu_", "-lv_", "-lvi_", "-mi-nz_", "-ml-in_", "-mlt_", "-mn-mn_", "-mn_", "-mr-in_", "-ms-bn_", "-msl_", "-mt-mt_", "-mt_", "-nb-no_", "-nb_", "-ne-np_", "-ng_", "-nl-nl_", "-nl_", "-nld_", "-nn-no_", "-nn_", "-no_", "-non_", "-nor_", "-np_", "-nso-za_", "-nz_", "-or-in_", "-pa-in_", "-pe_", "-ph_", "-pk_", "-pl-pl_", "-pl_", "-plk_", "-pt-br_", "-pt-pt_", "-ptb_", "-ptg_", "-qut-gt_", "-quz-pe_", "-ro-ro_", "-ro_", "-rom_", "-ru-ru_", "-ru_", "-rus_", "-rw-rw_", "-si-lk_", "-sk-sk_", "-sk_", "-sky_", "-sl-si_", "-sl_", "-slv_", "-sq-al_", "-srl_", "-sv-se_", "-sv_", "-sve_", "-sw-ke_", "-ta-in_", "-te-in_", "-tha_", "-ti-et_", "-tk-tm_", "-tm_", "-tn-za_", "-tr-tr_", "-tr_", "-trk_", "-tt-ru_", "-ug-cn_", "-uk-ua_", "-uk_", "-ukr_", "-ur-pk_", "-uz_", "-vit_", "-wo-sn_", "-xh-za_", "-yo-ng_", "-za_", "-zh-cn_", "-zh-hk_", "-zh-tw_", "-zhh_", "-zu-za_", "-af-za_", "-ar-sa_", "-ar_", "-ara_", "-az-latn-", "-bg-bg_", "-bs-latn", "-ca-es", "-cy-gb", "-et-ee", "-eu-es", "-ga-ie", "-gl-es", "-hi-in", "-hr-hr", "-id-id", "-kk-kz", "-lt-lt", "-lv-lv", "-mk-mk", "-ms-my", "-prs-af", "-sr-cyrl", "-sr-latn", "-th-th", "-vi-vn"	)
	
	#https://github.com/tranquilit/WAPT/blob/master/waptwua.py
	note -private products @{
		"win51" = @("6964aab4-c5b5-43bd-a17d-ffb4346a8e1d","558f4bc3-4827-49e1-accf-ea79fd72d4c9", "83aed513-c42d-4f94-b4dc-f2670973902d");
		"win52" = @("6964aab4-c5b5-43bd-a17d-ffb4346a8e1d","7f44c2a7-bc36-470b-be3b-c01b6dc5dd4e", "dbf57a08-0d5a-46ff-b30c-7715eb9498e9", "032e3af5-1ac5-4205-9ae5-461b4e8cd26d", "a4bedb1d-a809-4f63-9b49-3fe31967b6d0", "4cb6ebd5-e38a-4826-9f76-1416a6f563b0", "83aed513-c42d-4f94-b4dc-f2670973902d");
		"win60" = @("6964aab4-c5b5-43bd-a17d-ffb4346a8e1d","26997d30-08ce-4f25-b2de-699c36a8033a", "ba0ae9cc-5f01-40b4-ac3f-50192b5d6aaf", "575d68e2-7c94-48f9-a04f-4b68555d972d", "83aed513-c42d-4f94-b4dc-f2670973902d");
		"win61" = @("6964aab4-c5b5-43bd-a17d-ffb4346a8e1d","bfe5b177-a086-47a0-b102-097e4fa1f807", "f4b9c883-f4db-4fb5-b204-3343c11fa021", "fdfe8200-9d98-44ba-a12a-772282bf60ef", "1556fc1d-f20e-4790-848e-90b7cdbedfda", "83aed513-c42d-4f94-b4dc-f2670973902d");
		"win62" = @("6964aab4-c5b5-43bd-a17d-ffb4346a8e1d","2ee2ad83-828c-4405-9479-544d767993fc", "a105a108-7c9b-4518-bbbe-73f0fe30012b", "83aed513-c42d-4f94-b4dc-f2670973902d");
		"win63" = @("6964aab4-c5b5-43bd-a17d-ffb4346a8e1d","405706ed-f1d7-47ea-91e1-eb8860039715", "18e5ea77-e3d1-43b6-a0a8-fa3dbcd42e93", "6407468e-edc7-4ecd-8c32-521f64cee65e", "d31bd4c3-d872-41c9-a2e7-231f372588cb", "83aed513-c42d-4f94-b4dc-f2670973902d");
		"win10" = @("6964aab4-c5b5-43bd-a17d-ffb4346a8e1d","a3c2375d-0c8a-42f9-bce0-28333e198407", "d2085b71-5f1f-43a9-880d-ed159016d5c6", "83aed513-c42d-4f94-b4dc-f2670973902d");
		# "ofc03" = @("1403f223-a63f-f572-82ba-c92391218055");
		# "ofc07" = @("041e4f9f-3a3d-4f58-8b2f-5e6fe95c4591");
		# "ofc10" = @("84f5f325-30d7-41c4-81d1-87a0e6535b66");
		# "ofc13" = @("704a0a4a-518f-4d69-9e03-10ba44198bd5");
	}	
		
	note -private downloadScriptBlock {
		Param( [string] $u, [string] $outFile, $reDownload )
		try{
			$file = ( $u.Substring($u.LastIndexOf("/") + 1) ).Trim()
			
			$platform = ""
			if($file.IndexOf("x86") -ne -1){
				$platform = "x86"
			}elseif($file.IndexOf("x64") -ne -1){
				$platform = "x64"
			}elseif($file.IndexOf("ia64") -ne -1){
				$platform = "ia64"
			}else{
				$platform = "x86_x64"
			}
							
			if( (test-path "$outFile\$platform\$file") -eq $false ){
				(new-object system.net.webclient).DownloadFile($u,"$outFile\$platform\$file")
			}elseif($reDownload -eq $true){
				if( test-path "$outFile\$platform\$file"){
					remove-item "$outFile\$platform\$file"
				}
				(new-object system.net.webclient).DownloadFile($u,"$outFile\$platform\$file")
			}
		}catch [system.exception]{
			write-host $error
		}	
	}
		
	method -private downloadWD{
		if( ( test-path ".\wsus" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus
		}
		
		if( ( test-path ".\wsus\wd\" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus\wd
		}
		
		@(
			"http://download.microsoft.com/download/DefinitionUpdates/mpas-feX64.exe,mpas-feX64.exe",
			"http://download.microsoft.com/download/DefinitionUpdates/mpas-fe.exe,mpas-fe.exe"
		) | % {
			$url = $_.Substring(0,$_.LastIndexOf(","))
			$file = $_.Substring($_.LastIndexOf(",") + 1)
			if( ( test-path ".\wsus\wd\$($file)") -eq $false){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($url)#")
				$utilities.getWebFile($url, "$pwd\wsus\wd\$file")
			}else{
				if( (new-timespan (get-item .\wsus\wd\$file).LastWriteTime (get-date) ).Days -gt $private.RefreshDays){
					$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($url)#")
					$utilities.getWebFile( $url, "$pwd\wsus\wd\$file")
				}else{
					$uiClass.writeColor("$($uiClass.STAT_OK) Using pre-existing #yellow#$($file)#")
				}
			}
		}
		
	}
	
	method -private downloadMSSE{
		if( ( test-path ".\wsus" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus
		}
		
		if( ( test-path ".\wsus\msse\" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus\msse
		}
		
		@(
"http://download.microsoft.com/download/A/3/8/A38FFBF2-1122-48B4-AF60-E44F6DC28BD8/ENUS/amd64/MSEInstall.exe,MSEInstall-x64-enu.exe",
"http://download.microsoft.com/download/DefinitionUpdates/mpam-fex64.exe,mpam-fex64.exe",
"http://definitionupdates.microsoft.com/download/DefinitionUpdates/NRI/amd64/nis_full.exe,nis_full_x64.exe"
		) | % {
			$url = $_.Substring(0,$_.LastIndexOf(","))
			$file = $_.Substring($_.LastIndexOf(",") + 1)
			if( ( test-path ".\wsus\msse\$($file)") -eq $false){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($url)#")
				#invoke-webRequest $url -outFile ".\wsus\msse\$file"
				$utilities.getWebFile($url,"$pwd\wsus\msse\$file") | out-null
			}else{
				if( (new-timespan (get-item .\wsus\msse\$file).LastWriteTime (get-date) ).Days -gt $private.RefreshDays){
					$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($url)#")
					$utilities.getWebFile($url, "$pwd\wsus\msse\$file")
				}else{
					$uiClass.writeColor("$($uiClass.STAT_OK) Using pre-existing #yellow#$($file)#")
				}
			}
		}
	}
	
	method -private downloadCPP{
		if( ( test-path ".\wsus" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus
		}
		
		if( ( test-path ".\wsus\cpp\" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus\cpp
		}
		
		@(
"http://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE,vcredist2005_x86.exe",
"http://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe,vcredist2008_x86.exe",
"http://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe,vcredist2010_x86.exe",
"http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe,vcredist2012_x86.exe",
"http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe,vcredist2013_x86.exe",
"http://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.EXE,vcredist2005_x64.exe",
"http://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe,vcredist2008_x64.exe",
"http://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe,vcredist2010_x64.exe",
"http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe,vcredist2012_x64.exe",
"http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe,vcredist2013_x64.exe"
		) | % {
			
			$url = $_.Substring(0,$_.LastIndexOf(","))
			$file = $_.Substring($_.LastIndexOf(",") + 1)
			if( ( test-path ".\wsus\cpp\$($file)") -eq $false){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($url)#")
				$utilities.getWebFile($url,"$pwd\wsus\cpp\$file")
			}else{
				if( (new-timespan (get-item .\wsus\cpp\$file).LastWriteTime (get-date) ).Days -gt $private.RefreshDays){
					$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($url)#")
					$utilities.getWebFile($url,"$pwd\wsus\cpp\$file")
				}else{
					$uiClass.writeColor("$($uiClass.STAT_OK) Using pre-existing #yellow#$($file)#")
				}
			}
		}
	}
	
	method -private downloadDotNet{
		if( ( test-path ".\wsus" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus
		}
		
		if( ( test-path ".\wsus\dotNet\" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus\dotNet
		}
		
		@(
			"http://download.microsoft.com/download/2/0/e/20e90413-712f-438c-988e-fdaa79a8ac3d/dotnetfx35.exe",
			"http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe",
			"http://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe"
		) | % {
			$file = $_.Substring($_.LastIndexOf("/") + 1)
			
			if( ( test-path ".\wsus\dotNet\$($file)") -eq $false){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($file)#")
				$utilities.getWebFile($_,"$pwd\wsus\dotNet\$file")
			}else{
				if( (new-timespan (get-item .\wsus\dotNet\$file).LastWriteTime (get-date) ).Days -gt $private.RefreshDays){
					$uiClass.writeColor("$($uiClass.STAT_WAIT) Re-Downloading #yellow#$($file)#")
					$utilities.getWebFile($_, "$pwd\wsus\dotNet\$file")
				}else{
					$uiClass.writeColor("$($uiClass.STAT_OK) Using pre-existing #yellow#$($file)#")
				}
			}
		}
	}
	
	method -private downloadWsusAgent{
		if( ( test-path ".\wsus" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus
		}
		
		if( ( test-path ".\wsus\wua\" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus\wua
		}
		
		@(
			"http://download.windowsupdate.com/windowsupdate/redist/standalone/7.4.7600.226/WindowsUpdateAgent30-x86.exe",
			"http://download.windowsupdate.com/windowsupdate/redist/standalone/7.4.7600.226/WindowsUpdateAgent30-x64.exe",
			"http://download.windowsupdate.com/microsoftupdate/v6/wsusscan/wsusscn2.cab"
		) | % {
			$file = $_.Substring($_.LastIndexOf("/") + 1)
			
			if( ( test-path ".\wsus\wua\$($file)") -eq $false){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($_)#")
				$utilities.getWebFile($_, "$pwd\wsus\wua\$file") | out-null
			}else{
				if( (new-timespan (get-item ".\wsus\wua\$file").LastWriteTime (get-date) ).Days -gt $private.RefreshDays){
					$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($_)#")
					$utilities.getWebFile($_,  "$pwd\wsus\wua\$file") | out-null
				}else{
					$uiClass.writeColor("$($uiClass.STAT_OK) Using pre-existing #yellow#$($file)#")
				}
			}
		}
		
		if(test-path ".\wsus\wua\package.cab"){ remove-item ".\wsus\wua\package.cab" }
		if(test-path ".\wsus\wua\package.xml"){ remove-item ".\wsus\wua\package.xml" }
		invoke-expression("expand.exe $pwd\wsus\wua\wsusscn2.cab -F:package.cab $pwd\wsus\wua\")
		invoke-expression("expand.exe $pwd\wsus\wua\package.cab $pwd\wsus\wua\package.xml")
		
	}
	
	method -private downloadUpdates{
		$downloadProgressBar =  $progressBarClass.New( @{ "parentId" = 1; "Activity" = "Downloading Files"; "Status" = "Please Wait..."; "PercentComplete" = 0; "Completed" = $false; "id" = 2 }).Render() 
		
		[xml] $xml = get-content "$pwd\wsus\wua\package.xml"
		$ns = new-object Xml.XmlNamespaceManager $xml.NameTable
		$ns.AddNamespace('dns', 'http://schemas.microsoft.com/msus/2004/02/OfflineSync')
		
		$productIndex = 0
		
		$totalNodesProcessed=0
		
		foreach($product in ( $private.products.keys | sort -Descending ) ){
			@("","x86","x64","x86_x64","ia64") | % {
				if( (test-path "$pwd\wsus\$product\$($_)" ) -eq $false){
					New-Item -ErrorAction SilentlyContinue -ItemType directory -Path "$pwd\wsus\$product\$($_)" 
				}
			}
			
			$productIndex++
			$i = (100*($productIndex/$($private.products.count)))
			$downloadProgressBar.Activity("$productIndex / $($private.products.count): $product ($($private.products.$product.count) Sub Products)").Status("{0:N2}% complete" -f $i).Percent($i).Render()	
			
			
			$subProduct = 0
			foreach($prodId in $private.products.$product){
				$productFileIndex = 0
				$subProduct++

				$downloadProgressBar.Activity("$productIndex / $($private.products.count): Processing Updates for $product - Sub Product $($subProduct) of $($private.products.$product.count)").Status("{0:N2}% complete" -f $i).Percent($i).Render()	
				
				$productNodes = $xml.selectnodes("//dns:OfflineSyncPackage/dns:Updates/dns:Update[not(./dns:SupersededBy)][./@DefaultLanguage='en' or not(./@DefaultLanguage)][./@IsBundle='true'][./dns:Categories/dns:Category[./@Type = 'Product' and ./@Id = '$($prodId)']]",$ns)
			
				$indFileBar =  $progressBarClass.New( @{ "parentId" = 2; "Activity" = "Downloading Files"; "Status" = "Please Wait..."; "PercentComplete" = 0; "Completed" = $false; "id" = 3 }).Render() 
				
				if($productNodes -ne $null -and $productNodes.count -gt 1) {
				
					$currentNode = 0
					$productNodes | %{
						$totalNodesProcessed++
						$productFileIndex++
						$currentNode++
						
						$ii = (100*$currentNode/$($productNodes.count))
						try{
							$indFileBar.Activity("$currentNode / $($productNodes.count):  $($_.updateId) ").Status("{0:N2}% complete" -f $ii).Percent($ii).Render()	
						}catch{
							
						}
						
						$currentThreads = (Get-Job | ? {$_.State -eq "Running"}).Count
						While ( $currentThreads -ge $private.threads){ 
							$uiClass.writeColor("$($uiClass.STAT_WAIT) Please wait... Currently using #green#$($currentThreads)# out of #green#$($private.threads)# threads.  ")
							Start-Sleep -seconds 1
							$currentThreads = (Get-Job | ? {$_.State -eq "Running"}).Count
						}
						
						
						if($_.EulaFiles -ne $null){
							$xml.SelectNodes("//dns:OfflineSyncPackage/dns:Updates/dns:Update[@RevisionId='$($_.RevisionId)']/dns:EulaFiles/dns:File[./dns:Language/@Name='en']/@Id",$ns) | %{
								$xml.selectnodes("//dns:OfflineSyncPackage/dns:FileLocations/dns:FileLocation[@Id = '$($_.'#text')']",$ns) | % {
									if(!$utilities.ContainsAny($_.Url,$private.badLanguages)){
										$uiClass.writeColor("$($uiClass.STAT_OK) #green#Downloading# file #yellow#$($_.Url.substring($_.url.lastindexof('/')+1))# for #green#$product#")
										Start-Job -ScriptBlock $private.downloadScriptBlock -ArgumentList ($_.Url ,(resolve-path "$pwd\wsus\$product\"),$private.reDownload)
									}
								}
							}
						}
							
						$xml.selectnodes("//dns:OfflineSyncPackage/dns:Updates/dns:Update[not(./dns:SupersededBy)][not(@isBundle)][./dns:BundledBy/dns:Revision/@Id='$($_.RevisionId)'][not(./dns:Languages) or ./dns:Languages/dns:Language/@Name='en']/dns:PayloadFiles/dns:File/@Id",$ns) | % {
							$fileId = $($_.'#text')
							
							$xml.selectnodes("//dns:OfflineSyncPackage/dns:FileLocations/dns:FileLocation[@Id = '$($_.'#text')']",$ns) | % {
								if(!$utilities.ContainsAny($_.Url,$private.badLanguages)){
									if($_.Url -notLike '*mui*'){
										$uiClass.writeColor("$($uiClass.STAT_OK) #green#Downloading# file #yellow#$($_.Url.substring($_.url.lastindexof('/')+1))# for #green#$product#")
										Start-Job -ScriptBlock $private.downloadScriptBlock -ArgumentList ($_.Url ,(resolve-path "$pwd\wsus\$product\"),$private.reDownload)
									}
								}
							}
						}
						
						
						get-job | ? { $_.State -eq 'Completed' } | remove-job
						[GC]::Collect()
					}
					$indFileBar.Completed($true).Render()
				}
				
				$deleteProgressBar =  $progressBarClass.New( @{ "parentId" = 2; "Activity" = "Deleting Superseded Files"; "Status" = "Please Wait..."; "PercentComplete" = 0; "Completed" = $false; "id" = 5 }).Render() 
				$deleteNodes = $xml.selectnodes("//dns:OfflineSyncPackage/dns:Updates/dns:Update[./dns:SupersededBy][./@DefaultLanguage='en' or not(./@DefaultLanguage)][./@IsBundle='true'][./dns:Categories/dns:Category[./@Type = 'Product' and ./@Id = '$($prodId)']]",$ns)
				$deleteNodeIndex = 0
				if($deleteNodes -ne $null -and $deleteNodes.count -gt 1){
					$deleteNodes | % {
						$deleteNodeIndex++
						
						$deleteProgressBar.Activity("$deleteNodeIndex / $($deleteNodes.count): Deleting Superseded Updates").Status("{0:N2}% complete" -f ( ([math]::round(100*100*$deleteNodeIndex/$($deleteNodes.count))/100))).Percent( ([math]::round(100*$deleteNodeIndex/$($deleteNodes.count))) ).Render()	
					
						$xml.selectnodes("//dns:OfflineSyncPackage/dns:Updates/dns:Update[not(@isBundle)][./dns:BundledBy/dns:Revision/@Id='$($_.RevisionId)'][not(./dns:Languages) or ./dns:Languages/dns:Language/@Name='en']/dns:PayloadFiles/dns:File/@Id",$ns) | % {
							$fileId = $($_.'#text')
							$xml.selectnodes("//dns:OfflineSyncPackage/dns:FileLocations/dns:FileLocation[@Id = '$($_.'#text')']",$ns) | % {
								$fileName = $($_.Url.substring($_.url.lastindexof('/')+1))
								if( (test-path "$pwd\wsus\$product\x86\$filename" ) -eq $true){ $uiClass.writeColor("$($uiClass.STAT_WAIT) #green#Deleting Superseded# file #yellow#$($fileName)# for #green#$product#"); remove-item "$pwd\wsus\$product\x86\$filename" }
								if( (test-path "$pwd\wsus\$product\x64\$filename" ) -eq $true){ $uiClass.writeColor("$($uiClass.STAT_WAIT) #green#Deleting Superseded# file #yellow#$($fileName)# for #green#$product#"); remove-item "$pwd\wsus\$product\x64\$filename" }
								if( (test-path "$pwd\wsus\$product\ia64\$filename" ) -eq $true){ $uiClass.writeColor("$($uiClass.STAT_WAIT) #green#Deleting Superseded# file #yellow#$($fileName)# for #green#$product#"); remove-item "$pwd\wsus\$product\ia64\$filename" }
								if( (test-path "$pwd\wsus\$product\x86_x64\$filename" ) -eq $true){ $uiClass.writeColor("$($uiClass.STAT_WAIT) #green#Deleting Superseded# file #yellow#$($fileName)# for #green#$product#"); remove-item "$pwd\wsus\$product\x86_x64\$filename" }
							}
						}
					}
				}
				$deleteProgressBar.Completed($true).Render()
			}
		}
		$downloadProgressBar.Completed($true).Render()
		
		sleep -seconds 10
		get-job | ? { $_.State -eq 'Completed' } | remove-job
		[GC]::Collect()
	
	}
		
	method -private downloadWindowsLiveEssentials{
		if( ( test-path ".\wsus" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus
		}
		
		if( ( test-path ".\wsus\wle\" ) -eq $false){
			New-Item -ItemType directory -Path .\wsus\wle
		}
		
		@(
			"http://wl.dlservice.microsoft.com/download/C/1/B/C1BA42D6-6A50-4A4A-90E5-FA9347E9360C/en/wlsetup-all.exe"
		) | % {
			$file = $_.Substring($_.LastIndexOf("/") + 1)
			
			if( ( test-path ".\wsus\wle\$($file)") -eq $false){
				$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($_)#")
				$utilities.getWebFile($_, "$pwd\wsus\wle\$file")
			}else{
				if( (new-timespan (get-item .\wsus\wle\$file).LastWriteTime (get-date) ).Days -gt $private.RefreshDays){
					$uiClass.writeColor("$($uiClass.STAT_WAIT) Downloading #yellow#$($_)#")
					$utilities.getWebFile($_, "$pwd\wsus\wle\$file")
				}else{
					$uiClass.writeColor("$($uiClass.STAT_OK) Using pre-existing #yellow#$($file)#")
				}
			}
		}
	}

	method -private makeIso{
		$isoProgressBar =  $progressBarClass.New( @{ "parentId" = 10; "Activity" = "Creating ISO Images"; "Status" = "Please Wait..."; "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render() 
		$isoIndex = 0
		
		foreach($product in ( $private.products.keys | sort -Descending ) ){
			$isoIndex++
			
			$isoProgressBar.Activity("$isoIndex / $($private.products.keys.count): Creating ISO Images for $($product)").Status("{0:N2}% complete" -f ( ([math]::round(100*100*$isoIndex/$($private.products.keys.count))/100))).Percent( ([math]::round(100*$isoIndex/$($private.products.keys.count))) ).Render()	
		
			foreach($arch in @("x64","x86","ia64")){
				$iso = $isoClass.New("$pwd\results\$($product)_$($arch).iso", 'DVDPLUSR_DUALLAYER', "$($product)_$($arch)_updates", $true)
				$iso.makeIso()
				$iso.createDirectory("updates")
				gci "$pwd\wsus\$product\x86_x64\" | %{
					$uiClass.writeColor("$($uiClass.STAT_OK) #green#Adding# file #yellow#$($_.name)# for #green#$($product) $($arch)#")
					$iso.addSource($_, "updates")
				}
				gci "$pwd\wsus\$product\$arch\" | %{
					$uiClass.writeColor("$($uiClass.STAT_OK) #green#Adding# file #yellow#$($_.name)# for #green#$($product) $($arch)#")
					$iso.addSource($_, "updates")
				}

				#os updates get the other files
				if($product -like 'win*'){
					$uiClass.writeColor("$($uiClass.STAT_OK) #green#Adding C++ Redistributables for #green#$($product) $($arch)#")
					$iso.addSource("$pwd\wsus\cpp\")
					
					$uiClass.writeColor("$($uiClass.STAT_OK) #green#Adding DotNet Framework Installations for #green#$($product) $($arch)#")
					$iso.addSource("$pwd\wsus\dotNet\")
					
					$uiClass.writeColor("$($uiClass.STAT_OK) #green#Adding Microsoft Security Essentials for #green#$($product) $($arch)#")
					$iso.addSource("$pwd\wsus\msse\")
					
					$uiClass.writeColor("$($uiClass.STAT_OK) #green#Adding Microsoft Windows Defender for #green#$($product) $($arch)#")
					$iso.addSource("$pwd\wsus\wd\")
					
					$uiClass.writeColor("$($uiClass.STAT_OK) #green#Adding Windows Live for #green#$($product) $($arch)#")
					$iso.addSource("$pwd\wsus\wle\")
					
					if( (test-path "$pwd\wsus\client") -eq $true){
						$uiClass.writeColor("$($uiClass.STAT_OK) #green#Adding Client Software Files for #green#$($product) $($arch)#")
						$iso.addSource("$pwd\wsus\client\")
					}
					
					$uiClass.writeColor("$($uiClass.STAT_OK) #green#Adding Installer Script #green#$($product) $($arch)#")
					$iso.addSource("$pwd\wsus\wua\installer.ps1")
				}
				$uiClass.writeColor("$($uiClass.STAT_OK) #green#Finalizing ISO Image for #green#$($product) $($arch)#")
				$iso.finalize()
				
				[GC]::Collect()
			}
		}
		
		$isoProgressBar.Completed($true).Render()
	}
	
	constructor{
		param()
		if($reDownload){$private.reDownload = $true}
		if($threads){$private.threads = $threads}
		if($refreshDays){$private.refreshDays = $refreshDays}
	}
	
	method Execute{
		$private.mainProgressBar =  $progressBarClass.New( @{ "parentId" = 0; "Activity" = "0 / 0 :"; "Status" = ("0% complete" ); "PercentComplete" = 0; "Completed" = $false; "id" = 1 }).Render()
		
		$private.mainProgressBar.Activity("Downloading Microsoft Dot Net").Status("Dot Net").Percent(10).Render()
		$private.downloadDotNet() | out-null
		
		$private.mainProgressBar.Activity("Downloading Microsoft C++ Redistributables").Status("C++").Percent(20).Render()
		$private.downloadCPP() | out-null
		
		$private.mainProgressBar.Activity("Downloading Microsoft Windows Live Essentials").Status("Live Essentials").Percent(30).Render()
		$private.downloadWindowsLiveEssentials() | out-null
		
		$private.mainProgressBar.Activity("Downloading Microsoft Security Essentials").Status("Security Essentials").Percent(40).Render()
		$private.downloadMSSE() | out-null
		
		$private.mainProgressBar.Activity("Downloading Microsoft Windows Defender").Status("Windows Defender").Percent(50).Render()
		$private.downloadWD() | out-null
		
		$private.mainProgressBar.Activity("Downloading Microsoft Update Agents").Status("Windows Update Agent").Percent(60).Render()
		$private.downloadWsusAgent() | out-null
		
		$private.mainProgressBar.Activity("Downloading Microsoft Updates").Status("Windows Updates").Percent(60).Render()
		$private.downloadUpdates() | out-null
		
		$private.mainProgressBar.Activity("Creating ISO Images").Status("Creating Images").Percent(80).Render()
		$private.makeIso() | out-null
		
		$private.mainProgressBar.Completed($true).Render()
		$uiClass.errorLog()
	}
}

$wsusOfflineClass.New().Execute() | out-null