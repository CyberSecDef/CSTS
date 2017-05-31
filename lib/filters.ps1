#filters that accept a piped parameter and return boolean results
filter isIp{ return $_ -match "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$" }
filter isNumeric{  return ( ($_ -match "^[\d\.]+$") -and  ( ( $_.toString().toCharArray() | ? { $_ -eq '.' } | Measure-Object).count -le 1 ) )}
filter isInteger{ return $_ -match "^[\d]+$" }

filter Get-RandomString { 
	$set    = "abcdefghijklmnopqrstuvwxyz0123456789. ".ToCharArray()
	$result = ""
	for ($x = 0; $x -lt $_; $x++) {
		$result += $set | Get-Random
	}
	return $result
}

filter ConvertFrom-SDDL
{
    Param (
        [Parameter( Position = 0, Mandatory = $True, ValueFromPipeline = $True )]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $RawSDDL
    )
    Set-StrictMode -Version 2
    $RawSecurityDescriptor = [Int].Assembly.GetTypes() | ? { $_.FullName -eq 'System.Security.AccessControl.RawSecurityDescriptor' }
    try{
        $Sddl = [Activator]::CreateInstance($RawSecurityDescriptor, [Object[]] @($RawSDDL))
    }catch [Management.Automation.MethodInvocationException]{
        throw $Error[0]
    }

    if ($Sddl.Group -eq $null){
        $Group = $null
    }else{
        $SID = $Sddl.Group
        $Group = $SID.Translate([Security.Principal.NTAccount]).Value
    }
    
    if ($Sddl.Owner -eq $null){
        $Owner = $null
    }else{
        $SID = $Sddl.Owner
        $Owner = $SID.Translate([Security.Principal.NTAccount]).Value
    }

    $ObjectProperties = @{
        Group = $Group
        Owner = $Owner
    }

    if ($Sddl.DiscretionaryAcl -eq $null){
        $Dacl = $null
    }else{
        $DaclArray = New-Object PSObject[](0)

        $ValueTable = @{}

        $EnumValueStrings = [Enum]::GetNames([System.Security.AccessControl.CryptoKeyRights])
        $CryptoEnumValues = $EnumValueStrings | % {
                $EnumValue = [Security.AccessControl.CryptoKeyRights] $_
                if (-not $ValueTable.ContainsKey($EnumValue.value__)){
                    $EnumValue
                }
        
                $ValueTable[$EnumValue.value__] = 1
            }

        $EnumValueStrings = [Enum]::GetNames([System.Security.AccessControl.FileSystemRights])
        $FileEnumValues = $EnumValueStrings | % {
                $EnumValue = [Security.AccessControl.FileSystemRights] $_
                if (-not $ValueTable.ContainsKey($EnumValue.value__)){
                    $EnumValue
                }
        
                $ValueTable[$EnumValue.value__] = 1
            }

        $EnumValues = $CryptoEnumValues + $FileEnumValues

        foreach ($DaclEntry in $Sddl.DiscretionaryAcl){
            $SID = $DaclEntry.SecurityIdentifier
            $Account = $SID.Translate([Security.Principal.NTAccount]).Value

            $Values = New-Object String[](0)

            # Resolve access mask
            foreach ($Value in $EnumValues){
                if (($DaclEntry.Accessmask -band $Value) -eq $Value){
                    $Values += $Value.ToString()
                }
            }

            $Access = "$($Values -join ',')"

            $DaclTable = @{
                Rights = $Access
                IdentityReference = $Account
                IsInherited = $DaclEntry.IsInherited
                InheritanceFlags = $DaclEntry.InheritanceFlags
                PropagationFlags = $DaclEntry.PropagationFlags
            }

            if ($DaclEntry.AceType.ToString().Contains('Allowed')){
                $DaclTable['AccessControlType'] = [Security.AccessControl.AccessControlType]::Allow
            }else{
                $DaclTable['AccessControlType'] = [Security.AccessControl.AccessControlType]::Deny
            }

            $DaclArray += New-Object PSObject -Property $DaclTable
        }
        $Dacl = $DaclArray
    }
    $ObjectProperties['Access'] = $Dacl
    $SecurityDescriptor = New-Object PSObject -Property $ObjectProperties
    Write-Output $SecurityDescriptor
}