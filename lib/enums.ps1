if(!(test-path "$pwd\bin\enumerations.dll")){
	Add-Type -Language CSharpVersion3 -TypeDefinition ([System.IO.File]::ReadAllText("$pwd\types\enums.cs")) -OutputAssembly "$pwd\bin\enumerations.dll" -outputType Library
}
if(!("export.mergeType" -as [type])){
	Add-Type -path "$pwd\bin\enumerations.dll"
}