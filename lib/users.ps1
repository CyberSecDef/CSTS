$users = New-PSClass Users{
	
	method -static getDomainUser{
		param (
			[string] $ou,
			[string] $userName
		)
		
		if($utilities.isBlank( $ou ) -eq $false -and $utilities.isBlank($userName) -eq $false){
			$root = [ADSI] "LDAP://$($ou)"
			$searcher = new-object System.DirectoryServices.DirectorySearcher($root)
			$searcher.filter = "(&(objectClass=user)(sAMAccountName= $userName))"
			$userSearcher = ( $searcher.findall() | select -first 1 )
			return ([ADSI]$userSearcher.path)
		}else{
			return $false
		}
	}
	method -static getLocalUser{ 
		param (
		[string] $computerName,
		[string] $userName
		)
		
		if($utilities.isBlank( $computerName ) -eq $false -and $utilities.isBlank($userName) -eq $false){
			[ADSI]$server="WinNT://$computerName"
            return ($server.children | ? {$_.schemaclassname -eq "user" -and $_.name -eq $userName} )
		}else{
			return $false
		}
	}
	
	method -static addDomainUser{ 
		param (
			[string]$ou,
			[string]$UserName,
			[string]$Password,
			$properties
		)

		if($utilities.isBlank( $ou ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $password ) -eq $false -and $utilities.isBlank( $users.getDomainUser($ou,$userName) ) -eq $true ){
			$objOU = [ADSI] "LDAP://$($ou)"
			$user = $objOU.create("User","CN="+ $username)
			$user.setinfo()
			
			$user.sAMAccountName = $username
			$user.setinfo()
			
			if($utilities.isBlank( $properties ) -eq $false){
				$properties.keys |  % {
					$user.$($_) = $properties.$($_)
					$user.setinfo()
				}
			}
			
			return $user
		}else{
			return $false
		}
	}
	method -static addLocalUser{ 
		param (
			[string]$ComputerName,
			[string]$UserName,
			[string]$Password,
			[switch]$PasswordNeverExpires,
			[string]$Description
		)

		if($utilities.isBlank( $computerName ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $password ) -eq $false -and $utilities.isBlank( $users.getLocalUser($computerName,$userName) ) -eq $true ){
			[ADSI]$server="WinNT://$computerName"
			$user=$server.Create("User",$UserName)
			$user.SetPassword($Password)
			$user.SetInfo()
		   		   
		   if ($Description){
			$user.Put("Description",$Description)
		   }

			if ($PasswordNeverExpires){
				$flag=$User.UserFlags.value -bor 0x10000
				$user.put("userflags",$flag)
			}
			$user.SetInfo()
			
			return $user;
		}else{
			return $false
		}
	}
	
	method -static addLocalUserToGroup{
		param(
			[string]$computerName,
			[string]$userName,
			[string]$groupName
		)
		
		if($utilities.isBlank( $computerName ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $groupName ) -eq $false -and $utilities.isBlank( $users.getLocalUser($computerName,$userName) ) -eq $false ){
			$objUser = [ADSI]("WinNT://$($computerName)/$($userName)") 
			$objGroup = [ADSI]("WinNT://$($computerName)/$($groupName)") 
			try{
				$objGroup.PSBase.Invoke("Add",$objUser.PSBase.Path)
				$objUser.setInfo()
				$objGroup.setInfo()
			}catch{
				return -1
			}
		}else{
			return $false
		}
	}
	
	
	method -static removeDomainUser{
		param (
			[string]$ou,
			[string]$UserName
		)

		if($utilities.isBlank( $ou ) -eq $false -and $utilities.isBlank($userName) -eq $false  -and $utilities.isBlank( $users.getDomainUser($ou,$userName) ) -eq $false){
			$userOu = [ADSI] "LDAP://$($ou)"
			$user = $userOU.delete('User','CN='+ $username)
			return $user
		}else{
			return $false
		}
	
	}
	method -static removeLocalUser{ 
		param (
			[string]$ComputerName,
			[string]$UserName
		)

		if($utilities.isBlank( $computerName ) -eq $false -and $utilities.isBlank($userName) -eq $false  -and $utilities.isBlank( $users.getLocalUser($computerName,$userName) ) -eq $false){
			[ADSI]$server="WinNT://$computerName"
			
			try{
				$server.delete("user",$UserName)
			}catch{
				return -1
			}
		}else{
			return $false
		}
	}
	
	method -static resetDomainUserPassword{
		param (
			[string]$ou,
			[string]$UserName,
			[string]$NewPassword
		)

		if($utilities.isBlank( $ou ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $NewPassword ) -eq $false ){
			$user_acc=$users.getDomainUser($ou , $UserName)
			if($user_acc -ne $false){
				$user_acc.psbase.invoke("SetPassword",$NewPassword) 
				$user_acc.psbase.commitchanges()
			}
		}else{
			return $false
		}
	}
	method -static resetLocalUserPassword{
		param (
			[string]$ComputerName,
			[string]$UserName,
			[string]$NewPassword,
			[switch]$PasswordNeverExpires,
			[switch]$ForcePasswordReset
		)

		if($utilities.isBlank( $computerName ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $NewPassword ) -eq $false ){
			$user_acc=$users.getLocalUser($ComputerName , $UserName)
			if($user_acc -ne $false){
				$user_acc.setpassword($NewPassword)

				if ($PasswordNeverExpires){
					$flag=$User_acc.UserFlags.value -bor 0x10000
					$user_acc.put("userflags",$flag)
				}else{
					$flag=$User_acc.UserFlags.value -bxor 0x10000
					$user_acc.put("userflags",$flag)
				}

				if ($ForcePasswordReset){
					$user_acc.Put("passwordexpired",1)
				}else{
					$user_acc.Put("passwordexpired",0)
				}

				$user_acc.SetInfo()
			}
		}else{
			return $false
		}
	}

	method -static getDomainUserPasswordInfo{
	param (
			[string]$ou,
			[string]$UserName
		)

		if($utilities.isBlank( $ou ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $users.getDomainUser($ou,$userName) ) -eq $false){
			$user_acc=$users.getDomainUser($ou, $UserName)
			$passSet = (  new-timespan -start ( [datetime]::FromFileTime($user_acc.ConvertLargeIntegerToInt64($user_acc.pwdLastSet.value)) )  )
			$passAge='{0:00}:{1:00}:{2:00}:{3:00}' -f ( $passSet | % {$_.Days, $_.Hours, $_.Minutes, $_.Seconds})

			$return = [pscustomobject]@{
				OU=$ou;
                User=$UserName;
                PasswordAge= $passAge;
                PasswordLastSet=( [datetime]::FromFileTime($user_acc.ConvertLargeIntegerToInt64($user_acc.pwdLastSet.value)) );
            }
			
			return $return
        }else{
			return $false
		}
	}
	method -static getLocalUserPasswordInfo{ 
		param (
			[string]$ComputerName,
			[string]$UserName
		)

		if($utilities.isBlank( $computerName ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $users.getLocalUser($computerName,$userName) ) -eq $false){
			$user_acc=$users.getLocalUser($ComputerName, $UserName)
			[string]$UserName=$user_acc.Name
			$passSet= (Get-Date).AddSeconds(-($user_acc.PasswordAge.value))
			$passAge='{0:00}.{1:00}:{2:00}:{3:00}' -f ((Get-Date) - $passSet| % {$_.Days, $_.Hours, $_.Minutes, $_.Seconds})
			if ($user_acc.PasswordExpired.Value -eq 0){
				[bool]$expired=0
            }else {
				[bool]$expired=1
            }

			$return = [pscustomobject]@{
				SystemName=$computerName;
                User=$UserName;
                PasswordAge=$passAge;
                PasswordLastSet=$passSet;
                PasswordExpired=$expired;
            }
			
			return $return
        }else{
			return $false
		}
	}

	method -static disableDomainUser{
		param (
			[string]$ou,
			[string]$UserName
		)

		if($utilities.isBlank( $ou ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $users.getDomainUser($ou,$userName) ) -eq $false){
			$user_acc= $users.getDomainUser($ou,$UserName)
			
			$user_acc.psbase.invokeSet("AccountDisabled", "True")
			$user_acc.setinfo()
		}else{
			return $false
		}
	}
	method -static disableLocalUser{ 
		param (
			[string]$ComputerName,
			[string]$UserName
		)

		if($utilities.isBlank( $computerName ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $users.getLocalUser($computerName,$userName) ) -eq $false){
			$user_acc= $users.getLocalUser($ComputerName,$UserName)
			$user_acc.userflags.value = $user_acc.userflags.value -bor "0x0002"
			$user_acc.SetInfo()
		}else{
			return $false
		}
	}
	
	method -static enableDomainUser{
		param (
			[string]$ou,
			[string]$UserName
		)

		if($utilities.isBlank( $ou ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $users.getDomainUser($ou,$userName) ) -eq $false){
			$user_acc= $users.getDomainUser($ou,$UserName)
			
			$user_acc.psbase.invokeSet("AccountDisabled", "False")
			$user_acc.setinfo()
		}else{
			return $false
		}
	}
	method -static enableLocalUser{ 
		param (
			[string]$ComputerName,
			[string]$UserName
		)

		if($utilities.isBlank( $computerName ) -eq $false -and $utilities.isBlank($userName) -eq $false -and $utilities.isBlank( $users.getLocalUser($computerName,$userName) ) -eq $false){
			$user_acc=$users.getLocalUser($ComputerName,$UserName)
			if ($user_acc.userflags.value -band "0x0002"){
				$user_acc.userflags.value = $user_acc.userflags.value -bxor "0x0002"
				$user_acc.SetInfo()
            }
		}else{
			return $false
		}
	}
}