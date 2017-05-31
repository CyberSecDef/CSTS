#todo -> rsa import certificates
# $crypto = $cryptoClass.New()
# $crypto.hashTypes.keys | % { write-host -noNewLine "$_ --> "; write-host $crypto.getHash("this is a test",$_ ) }
# $iv = $crypto.gen3DesIV()
# write-host "3Des Random Key --> $($crypto.gen3DesKey())"; 
# write-host
# write-host "3Des Random IV  --> $iv"; 
# $encText = $crypto.enc3Des("blah blah blah blah blah blahblah blah blah blah blah blahblah blah blah blah blah blahblah blah blah blah blah blah","SomeTestThisIs!!",$iv)
# write-host  "3Des Encrypted Hex --> $($encText.EncryptedString)"; 
# $decText = $crypto.dec3Des($encText.EncryptedString,"SomeTestThisIs!!", $iv)
# write-host "3Des Decrypted Hex --> $($decText.decryptedString)"; 
# $rsaKeys = $crypto.genRSAKeys()
# write-host "RSA Public key --> $($rsaKeys.public)"
# write-host "RSA Private key --> $($rsaKeys.private)"
# $encText = $crypto.encRSA("blah blah blah blah blah ",$rsaKeys.public)
# write-host "RSA Public Key --> $($encText.PublicKey)"
# write-host "RSA Encrypted --> $($encText.EncryptedString)"
# $decText = $crypto.decRSA($encText.EncryptedString,$rsaKeys.private)
# write-host "RSA Decrypted --> $($decText.DecryptedString)"
# write-host "Random Number --> $($crypto.genRandomNumber(1,10))"
# write-host "Random Numbers --> $($crypto.genRandomNumbers(10,1,10))"
# write-host "Random Hash --> $($crypto.genRandomHash(100))"
# write-host "Random Hex --> $($crypto.genRandomHash(100,$true))"
# write-host "-------"
# $iv = $crypto.genAesIV()
# write-host "AES Random Key --> $($crypto.genAesKey())"; 
# write-host "AES Random IV  --> $iv"; 
# $encText = $crypto.encAes("blah blah blah blah blah blahblah blah blah blah blah blahblah blah blah blah blah blahblah blah blah blah blah blah","SomeTestThisIs!!",$iv)
# write-host  "Aes Encrypted Hex --> $($encText.EncryptedString)"; 
# $decText = $crypto.decAes($encText.EncryptedString,"SomeTestThisIs!!", $iv)
# write-host "Aes Decrypted Hex --> $($decText.decryptedString)"; 
# $file = [System.IO.File]::ReadAllBytes( "c:\users\1042375507\Documents\scripts\archiveEventLogs.ps1" )
# $encText = $crypto.encAes($file,"SomeTestThisIs!!", $iv)
# write-host "AES Encrypted File --> $($encText.EncryptedString)"
# $decText = $crypto.decAes($encText.EncryptedString,"SomeTestThisIs!!", $iv)
# write-host "Aes Decrypted Hex --> $($decText.decryptedString)";

$cryptoClass = New-PSClass Crypto{
	note -static instance
	
	note hashTypes @{
		"SHA1" = "SHA1CryptoServiceProvider"; 
		"SHA256" = "SHA256CryptoServiceProvider";
		"SHA384" = "SHA384CryptoServiceProvider";
		"SHA512" = "SHA512CryptoServiceProvider";
		"HMAC" = "HMACSHA1";
		"MTD" = "MACTripleDES";
	}
	
	note encTypes @{
		"3Des" = "TripleDESCryptoServiceProvider";
		"RSA" = "RSACryptoServiceProvider";
		"AES" = "AesCryptoServiceProvider";	
	}
	
	constructor{
		
	}
	
	method -static Get{
		if($cryptoClass.instance -eq $null -or $cryptoClass.instance -eq ""){
			$cryptoClass.instance = $cryptoClass.New()
		}
		
		return $cryptoClass.instance
	}
	
	method genRSAKeys{
		$cipher = new-object System.Security.Cryptography.RSACryptoServiceProvider
		
		return @{
			"Private" = $cipher.ToXmlString($true);;
			"Public" = $cipher.ToXmlString($false);
		}
	}
	
	method encRSA{
		param($inBlock, $public)
		
		if($inBlock.getType().Name -eq "String"){
			$inBlock = [System.Text.Encoding]::UTF8.GetBytes($inBlock)
		}
		
		$rsaPublic = new-object System.Security.Cryptography.RSACryptoServiceProvider
        $rsaPublic.FromXmlString($public);
		
        $encryptedRSA = $rsaPublic.Encrypt($inBlock, $false);
        
		$encryptedHex = $this.array2Hex( $encryptedRSA )
		 		
		return @{
			"EncryptedString" = $encryptedHex;
			"PublicKey" = $public
		}
	}
	
	method decRSA{
		param($inBlock,$private)
		
		$tByteArray = $this.hex2Array($inBlock)
		
		$rsaPrivate = new-object System.Security.Cryptography.RSACryptoServiceProvider
        $rsaPrivate.FromXmlString($private);
        
		return @{
			"DecryptedString" = [System.Text.Encoding]::UTF8.GetString( $rsaPrivate.Decrypt($tByteArray, $false) );
			"Private" = $private
		}
		
	}
	
	
	method gen3DesIV{
		$cipher = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider
		$cipher.GenerateIV()
		return $this.array2Hex($cipher.IV)
	}
	
	method gen3DesKey{
		$cipher = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider
		$cipher.GenerateKey()
		return $this.array2Hex($cipher.Key)
	}
	
	method enc3Des{
		param($inBlock,$inKey, $iv)
		
		if($inBlock.getType().Name -eq "String"){
			$inBlock = [System.Text.Encoding]::UTF8.GetBytes($inBlock)
		}
				
		if($inKey.getType().Name -eq "String"){
			$inKey = [System.Text.Encoding]::UTF8.GetBytes($inKey)
		}
				
		if($inKey.length -eq 16 -or $inKey.length -eq 24){ 
			$cipher = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider
			$cipher.Mode = [System.Security.Cryptography.CipherMode]::CBC
			$cipher.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
			
			$cipher.Key = $inKey
			$cipher.iv = $this.hex2Array($iv)
			
			$encryptedHex = $this.array2Hex( $cipher.CreateEncryptor().TransformFinalBlock($inBlock, 0, $inBlock.Length) )
							
			return @{ "EncryptedString" = $encryptedHex; "Key" = $cipher.Key; "IV" = $cipher.IV }
		}else{
			return $false
		}
		
	}
	
	method dec3Des{
		param($inBlock,$inKey, $iv)
				
		if($inKey.getType().Name -eq "String"){
			$inKey = [System.Text.Encoding]::UTF8.GetBytes($inKey)
		}
		
		if($inKey.length -eq 16 -or $inKey.length -eq 24){ 
			
			$c = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider
			$c.Mode = [System.Security.Cryptography.CipherMode]::CBC
			$c.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
			$c.Key = $inKey
			$c.iv = $this.hex2Array($iv)
			
			
			$tByteArray = $this.hex2Array($inBlock)
					
			$res = [System.Text.Encoding]::UTF8.GetString( $c.CreateDecryptor().TransformFinalBlock($tByteArray, 0, $tByteArray.Length) );
			return @{ "DecryptedString" = $res; "Key" = $cipher.Key; "IV" = $iv }
			
			
		}else{
			return $false
		}
	}
	
	
	method genAesIV{
		$cipher = new-object System.Security.Cryptography.AESCryptoServiceProvider
		$cipher.GenerateIV()
		return $this.array2Hex($cipher.IV)
	}
	
	method genAESKey{
		$cipher = new-object System.Security.Cryptography.AESCryptoServiceProvider
		$cipher.GenerateKey()
		return $this.array2Hex($cipher.Key)
	}
	
	method encAes{
		param($inBlock,$inKey, $iv)
		
		if($inBlock.getType().Name -eq "String"){
			$inBlock = [System.Text.Encoding]::UTF8.GetBytes($inBlock)
		}
				
		if($inKey.getType().Name -eq "String"){
			$inKey = [System.Text.Encoding]::UTF8.GetBytes($inKey)
		}
				
		if($inKey.length -eq 16 -or $inKey.length -eq 24){ 
			$cipher = new-object System.Security.Cryptography.AESCryptoServiceProvider
			$cipher.Mode = [System.Security.Cryptography.CipherMode]::CBC
			$cipher.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
			
			$cipher.Key = $inKey
			$cipher.iv = $this.hex2Array($iv)
			
			$encryptedHex = $this.array2Hex( $cipher.CreateEncryptor().TransformFinalBlock($inBlock, 0, $inBlock.Length) )
							
			return @{ "EncryptedString" = $encryptedHex; "Key" = $cipher.Key; "IV" = $cipher.IV }
		}else{
			return $false
		}
		
	}
	
	method decAes{
		param($inBlock,$inKey, $iv)
				
		if($inKey.getType().Name -eq "String"){
			$inKey = [System.Text.Encoding]::UTF8.GetBytes($inKey)
		}
		
		if($inKey.length -eq 16 -or $inKey.length -eq 24){ 
			
			$c = new-object System.Security.Cryptography.AESCryptoServiceProvider
			$c.Mode = [System.Security.Cryptography.CipherMode]::CBC
			$c.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
			$c.Key = $inKey
			$c.iv = $this.hex2Array($iv)
			
			
			$tByteArray = $this.hex2Array($inBlock)
					
			$res = [System.Text.Encoding]::UTF8.GetString( $c.CreateDecryptor().TransformFinalBlock($tByteArray, 0, $tByteArray.Length) );
			return @{ "DecryptedString" = $res; "Key" = $cipher.Key; "IV" = $iv }
			
			
		}else{
			return $false
		}
	}
	
	method getHash{
		param(
			[string] $textToHash = "",
			[string] $hashType = "SHA512"
		)
		
		$hasher = new-object System.Security.Cryptography.$($this.hashTypes.$hashType)
		try{
			$hashByteArray = $hasher.ComputeHash( [System.Text.Encoding]::UTF8.GetBytes($textToHash) )
		}catch{
			return "File Error"
		}
		return [System.BitConverter]::ToString($hashByteArray).Replace("-","")
	}   
	
	method array2Hex{
		param( $byteArray)
		$encryptedHex = ""
		$byteArray| % { $encryptedHex += ('{0:X}' -f [int] $_).PadLeft(2,"0") }
		
		return $encryptedHex
	}
	
	method hex2Array{
		param( [string] $inBlock )
		
		[byte[]] $tByteArray = @()
		For ( $i = 0; $i -lt ($inBlock.Length/2); $i++ ) {
			$Chars = $inBlock.Substring($i*2,2)
			$Byte = [Byte] "0x$Chars"
			$tByteArray += $Byte
		}
		
		return $tByteArray
		
	}
	
	method genRandomHash{
		param(
			[int] $length,
			[bool] $hex = $false
		)	
		
		if($hex){
			$chars = "ABCDEF0123456789"
		}else{
			$chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
		}
		
		$results = ""
		for($i = 0; $i -lt $length; $i++){
			$results += ($chars.substring( $this.genRandomNumber(0, $chars.length-1),1))
		}
		
		return $results
	}
	
	method genRandomNumber{
		param(
			[int] $min,
			[int] $max
		)
		$bytes = new-object "System.Byte[]" 1
		$rnd = new-object System.Security.Cryptography.RNGCryptoServiceProvider
		$rnd.GetBytes($bytes)
		
		return [Math]::floor( ($bytes[0]/256)  * ($max - $min + 1)) + $min;
		
	}
	
	method genRandomNumbers{
		param(
			[int] $length,
			[int] $min,
			[int] $max
		)
		
		$results = @()
		for($i = 0; $i -lt $length; $i++){
			$results += $this.genRandomNumber($min, $max)
		}
		
		return $results
	}
	
}