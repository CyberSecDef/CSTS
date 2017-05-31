$config = @{}

$config.Add("WebRoot","C:\sandbox\scripts\wwwroot")
$config.Add("LogRoot","C:\sandbox\scripts\logs\web.log")
$config.Add("Port","2223")
$config.Add("HostName","127.0.0.1")

$config.Add("DirectoryBrowsing",$true)

$config.Add("ContentBlackList",@())

$config.Add("IPWhiteList",@())
$config.Add("IPBlackList",@())