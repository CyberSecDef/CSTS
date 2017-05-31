$loggerClass = New-PSClass Logger{
	
	method -static Log{
		param($Request)
		
		$LogDate = Get-Date -format yyyy-MM-dd
		$LogTime = Get-Date -format HH:mm:ss
		$LogSiteName = $config.HostName
		if ($LogSiteName -eq "+") { $LogSiteName = "localhost" }
		
		$LogComputerName = Get-Content env:computername
		$LogServerIP = $Request.LocalEndPoint.Address
		$LogMethod = $Request.HttpMethod
		$LogUrlStem = $Request.RawUrl
		$LogServerPort = $Request.LocalEndPoint.Port
		$LogClientIP = $Request.RemoteEndPoint.Address
		$LogClientVersion = $Request.ProtocolVersion
		if (!$LogClientVersion) { $LogClientVersion = "-" } else { $LogClientVersion = "HTTP/" + $LogClientVersion }
		$LogClientAgent = [string]$Request.UserAgent
		if (!$LogClientAgent) { $LogClientAgent = "-" } else { $LogClientAgent = $LogClientAgent.Replace(" ","+") }
		$LogClientCookie = [string]$Response.Cookies.Value
		if (!$LogClientCookie) { $LogClientCookie = "-" } else { $LogClientCookie = $LogClientCookie.Replace(" ","+") }
		$LogClientReferrer = [string]$Request.UrlReferrer
		if (!$LogClientReferrer) { $LogClientReferrer = "-" } else { $LogClientReferrer = $LogClientReferrer.Replace(" ","+") }
		$LogHostInfo = [string]$LogServerIP + ":" + [string]$LogServerPort

		# Log Output
		$LogOutput = "$LogDate $LogTime $LogSiteName $LogComputerName $LogServerIP $LogMethod $LogUrlStem $LogServerPort $LogClientIP $LogClientVersion $LogClientAgent $LogClientCookie $LogClientReferrer $LogHostInfo $LogResponseStatus"		
		add-content ($config.logRoot) $LogOutput
	}
	
	method -static Error{
		param($msg)
		
		add-content ($config.logRoot) $msg
	}
} 



