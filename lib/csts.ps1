$cstsClass = New-PSClass csts{
	property verbose -static -get { return ([System.Management.Automation.ActionPreference]::SilentlyContinue -ne $VerbosePreference) }
	
}