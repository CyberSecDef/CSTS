$RequestClass = New-PSClass Request{
	note -private Request
	note -private InputStream
	note -private ContentEncoding
	note Get
	note Post
	note Cookies
	note -private Context
	
	constructor{
		param($context)
		$private.Context = $context
		
		$private.Request = $Context.Request
		$InputStream = $private.Request.InputStream
		$ContentEncoding = $private.Request.ContentEncoding
	
		$this.Get = $RequestClass.ParsePSQueryString($private.Request) 
		$this.Post = $RequestClass.ParsePSPost( $InputStream, $ContentEncoding)
		
		$this.Cookies = $private.Request.Cookies["PowerShellSessionID"];
		if (!$this.Cookies){
			$this.NewCookie("PowerShellSessionID", $RequestClass.NewPSTimeStamp())
		}
		
	}
	
	method NewCookie{
		param($name, $value)
		
		$PSCookie = New-Object Net.Cookie
		$PSCookie.Name = $name
		$PSCookie.Value = $value
		
		$private.Context.Response.AppendCookie($PSCookie)
	}

	method RawUrl{
		return $private.Request.RawUrl.ToString()
	}
		
	
	method -static ParsePSQueryString{
		param($Request)
		
		if ($Request -ne $null -and $Request -ne ""){
			$RequestQueryString = $Request.RawUrl.Split("?")[1]		
			$QueryStrings = $Request.QueryString
		
			$Properties = New-Object Psobject
			$Properties | Add-Member Noteproperty RequestQueryString $RequestQueryString
			foreach ($Query in $QueryStrings){
				$QueryString = $Request.QueryString["$Query"]
				if ($QueryString -and $Query){
					$Properties | Add-Member Noteproperty $Query $QueryString
				}
			}
			return $Properties
		}
	}
	
	method -static ParsePSPost{
		param($InputStream, $ContentEncoding)
			
		$RawPost = New-Object IO.StreamReader ($InputStream, $ContentEncoding)
		$RawPost = $RawPost.ReadToEnd()
		$RawPost = $RawPost.ToString()
		
		if ($RawPost)
		{
			$RawPost = $RawPost.Replace("+"," ")
			$RawPost = $RawPost.Replace("%20"," ")
			$RawPost = $RawPost.Replace("%21","!")
			$RawPost = $RawPost.Replace('%22','"')
			$RawPost = $RawPost.Replace("%23","#")
			$RawPost = $RawPost.Replace("%24","$")
			$RawPost = $RawPost.Replace("%25","%")
			$RawPost = $RawPost.Replace("%27","'")
			$RawPost = $RawPost.Replace("%28","(")
			$RawPost = $RawPost.Replace("%29",")")
			$RawPost = $RawPost.Replace("%2A","*")
			$RawPost = $RawPost.Replace("%2B","+")
			$RawPost = $RawPost.Replace("%2C",",")
			$RawPost = $RawPost.Replace("%2D","-")
			$RawPost = $RawPost.Replace("%2E",".")
			$RawPost = $RawPost.Replace("%2F","/")
			$RawPost = $RawPost.Replace("%3A",":")
			$RawPost = $RawPost.Replace("%3B",";")
			$RawPost = $RawPost.Replace("%3C","<")
			$RawPost = $RawPost.Replace("%3E",">")
			$RawPost = $RawPost.Replace("%3F","?")
			$RawPost = $RawPost.Replace("%5B","[")
			$RawPost = $RawPost.Replace("%5C","\")
			$RawPost = $RawPost.Replace("%5D","]")
			$RawPost = $RawPost.Replace("%5E","^")
			$RawPost = $RawPost.Replace("%5F","_")
			$RawPost = $RawPost.Replace("%7B","{")
			$RawPost = $RawPost.Replace("%7C","|")
			$RawPost = $RawPost.Replace("%7D","}")
			$RawPost = $RawPost.Replace("%7E","~")
			$RawPost = $RawPost.Replace("%7F","_")
			$RawPost = $RawPost.Replace("%7F%25","%")
			
			$PostStream = $RawPost
			$RawPost = $RawPost.Split("&")

			$Properties = New-Object Psobject
			$Properties | Add-Member Noteproperty PostStream $PostStream
			foreach ($Post in $RawPost)
			{
				$PostValue = $Post.Replace("%26","&")
				$PostContent = $PostValue.Split("=")
				$PostName = $PostContent[0].Replace("%3D","=")
				$PostValue = $PostContent[1].Replace("%3D","=")

				if ($PostName.EndsWith("[]"))
				{
					$PostName = $PostName.Substring(0,$PostName.Length-2)

					if (!(New-Object PSObject -Property @{PostName=@()}).PostName)
					{
						$Properties | Add-Member NoteProperty $Postname (@())
						$Properties."$PostName" += $PostValue
					}
					else
					{
						$Properties."$PostName" += $PostValue
					}
				} 
				else
				{
					$Properties | Add-Member NoteProperty $PostName $PostValue
				}
			}
			return $Properties
		}		
	}
	
	method -static NewPSTimeStamp{
	    $now = Get-Date
		$hr = $now.Hour.ToString()
		$mi = $now.Minute.ToString()
		$sd = $now.Second.ToString()
		$ms = $now.Millisecond.ToString()
		return "$($hr)$($mi)$($sd)$($ms)"
	}	
}