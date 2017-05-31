. "$pwd\conf\webConfig.ps1"
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$ServerClass = New-PSClass Server{
	note -private Listener
	
	constructor{
		param($port = "")
		if($port -ne "" -and $port -ne $null){
			$config.port = $port
		}
	}
	
	method Start{
		$this.Stop()
		
		$private.Listener = New-Object Net.HttpListener
		$private.Listener.Start()
		
		$prefix = "http://$($config.HostName):$($config.port)/"
		write-host $prefix
		
		$private.Listener.Prefixes | out-string | write-host
		
		$private.Listener.Prefixes.Add($prefix)
		
		$this.Listen()
	}
	
	method Stop{
		try{
			$private.Listener.Stop()
			$private.Listener.Close()	
		}catch{
			write-host "Unable to Stop the server as it is not running"
		}
	}
	
	method Listen{
		
		$processing = $true
		write-host "Starting Server"
	
		while($processing){
			
			#see if there are any config files in the folder
			
			$Context = $private.listener.GetContext()
						
			$PSRequest = $RequestClass.New($Context)
			$PSResponse = $ResponseClass.New($Context)
			$loggerClass.Log($Context.Request)

			$webFile = "$($config.webRoot)$( $($PSRequest.RawUrl()).Split('?')[0])"
			
			#get folder webfile is in, to test for additional config files
			$folder = split-path $webFile
			if(test-path "$($folder)\webConfig.ps1" ){
				. "$($folder)\webConfig.ps1"
			}			
			
			if($webFile -like "*shutdown*"){
				$processing = $false
			}else{
				#see if the file exists
				if(test-path $webFile){
					
					#if this is a ps1 file, parse it
					if($webFile.substring($webFile.length - 4, 4) -eq '.ps1'){
						. $webFile
						$page = $PageClass.New($PSRequest)
						$html = $page.WebResponse()
						$PSResponse.respond($html)
					}else{
						#get the mime type
						$ext = [System.IO.Path]::GetExtension($webFile)
						$mime = $PSResponse.GetMime($ext)
	
						
						if($config.ContentBlackList -contains $mime){
							$PSResponse.respond($null)
							
						}else{
							if($mime -like '*text*'){
								$html = get-content $webFile
								$PSResponse.respond($html)
							}else{
			
								$PSResponse.sendFile($webFile,$mime)
							}
						}
					}
				}else{
					$html = "404"
					$PSResponse.respond($html)
				}				
			}
		}
		
		$this.Stop()
	}
}

$myServer = $ServerClass.New()
$myServer.Start()
#$myServer.Stop()