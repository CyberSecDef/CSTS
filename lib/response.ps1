$ResponseClass = New-PSClass Response{
	note Response 
	
	constructor{
		param($Context)
		
		$this.Response = $Context.Response
		$this.Response.Headers.Add("Accept-Encoding","gzip");
		$this.Response.Headers.Add("Server","PowerShell Server");
		$this.Response.Headers.Add("X-Powered-By","Microsoft PowerShell");
	}
	
	method respond{
		param($html)

		if($config.IPWhiteList.Count -gt 0){
			if($config.IPWhiteList -contains $Context.Request.RemoteEndPoint.Address){
				$this.Response.ContentType = "text/html"
				$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
				$this.Response = New-Object IO.StreamWriter($this.Response.OutputStream,[Text.Encoding]::UTF8)
				$this.Response.WriteLine($html)
				$this.Response.Close()
			}else{
				$this.Response.ContentType = "text/html"
				$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
				$this.Response = New-Object IO.StreamWriter($this.Response.OutputStream,[Text.Encoding]::UTF8)
				$this.Response.WriteLine("Your IP Address has not been white listed for this web site")
				$this.Response.Close()			
			}
		}elseif($config.IPBlackList.Count -gt 0){
			if($config.IPBlackList -notcontains $Context.Request.RemoteEndPoint.Address){
				$this.Response.ContentType = "text/html"
				$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
				$this.Response = New-Object IO.StreamWriter($this.Response.OutputStream,[Text.Encoding]::UTF8)
				$this.Response.WriteLine($html)
				$this.Response.Close()
			}else{
				$this.Response.ContentType = "text/html"
				$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
				$this.Response = New-Object IO.StreamWriter($this.Response.OutputStream,[Text.Encoding]::UTF8)
				$this.Response.WriteLine("Your IP Address has been blacklist for this web site")
				$this.Response.Close()						
			}
		}else{
			$this.Response.ContentType = "text/html"
			$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
			$this.Response = New-Object IO.StreamWriter($this.Response.OutputStream,[Text.Encoding]::UTF8)
			$this.Response.WriteLine($html)
			$this.Response.Close()
		}
		

	}
	
	method sendFile{
		param($webFile,$mime)
		try{		
			if($config.IPWhiteList.Count -gt 0){
				if($config.IPWhiteList -contains $Context.Request.RemoteEndPoint.Address){
					$this.Response.ContentType = "$mime"
					$FileContent = [System.IO.File]::ReadAllBytes($webFile)
					$this.Response.ContentLength64 = $FileContent.Length
					$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
					$this.Response.OutputStream.Write($FileContent, 0, $FileContent.Length)
					$this.Response.Close()
				}else{
					$this.Response.ContentType = "text/html"
					$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
					$this.Response = New-Object IO.StreamWriter($this.Response.OutputStream,[Text.Encoding]::UTF8)
					$this.Response.WriteLine("Your IP Address has not been whitelisted for this web site")
					$this.Response.Close()
				}
			}elseif($config.IPBlackList.Count -gt 0){
				if($config.IPBlackList -notcontains $Context.Request.RemoteEndPoint.Address){
					$this.Response.ContentType = "$mime"
					$FileContent = [System.IO.File]::ReadAllBytes($webFile)
					$this.Response.ContentLength64 = $FileContent.Length
					$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
					$this.Response.OutputStream.Write($FileContent, 0, $FileContent.Length)
					$this.Response.Close()
				}else{
					$this.Response.ContentType = "text/html"
					$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
					$this.Response = New-Object IO.StreamWriter($this.Response.OutputStream,[Text.Encoding]::UTF8)
					$this.Response.WriteLine("Your IP Address has been blacklist for this web site")
					$this.Response.Close()						
				}
			}else{
				$this.Response.ContentType = "$mime"
				$FileContent = [System.IO.File]::ReadAllBytes($webFile)
				$this.Response.ContentLength64 = $FileContent.Length
				$this.Response.StatusCode = [System.Net.HttpStatusCode]::OK
				$this.Response.OutputStream.Write($FileContent, 0, $FileContent.Length)
				$this.Response.Close()
			}
		}catch{
			$loggerClass.Log($_)
		}
	}
	
	method GetMime{
		param($extension)
		
		switch ($extension){ 
			.ps1 {"text/ps1"}
			.psxml {"text/psxml"}
			.psapi {"text/psxml"}
			.posh {"text/psxml"}
			.html {"text/html"} 
			.htm {"text/html"} 
			.php {"text/php"} 
			.css {"text/css"} 
			.jpeg {"image/jpeg"} 
			.jpg {"image/jpeg"}
			.gif {"image/gif"}
			.ico {"image/x-icon"}
			.flv {"video/x-flv"}
			.swf {"application/x-shockwave-flash"}
			.js {"text/javascript"}
			.txt {"text/plain"}
			.rar {"application/octet-stream"}
			.zip {"application/x-zip-compressed"}
			.rss {"application/rss+xml"}
			.xml {"text/xml"}
			.pdf {"application/pdf"}
			.png {"image/png"}
			.mpg {"video/mpeg"}
			.mpeg {"video/mpeg"}
			.mp3 {"audio/mpeg"}
			.oga {"audio/ogg"}
			.spx {"audio/ogg"}
			.mp4 {"video/mp4"}
			.m4v {"video/m4v"}
			.ogg {"video/ogg"}
			.ogv {"video/ogg"}
			.webm {"video/webm"}
			.wmv {"video/x-ms-wmv"}
			.woff {"application/x-font-woff"}
			.eot {"application/vnd.ms-fontobject"}
			.svg {"image/svg+xml"}
			.svgz {"image/svg+xml"}
			.otf {"font/otf"}
			.ttf {"application/x-font-ttf"}
			.xht {"application/xhtml+xml"}
			.xhtml {"application/xhtml+xml"}
			default {"text/html"}
		}
	}
}