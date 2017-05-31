<#
.SYNOPSIS
	[Incomplete script!] This is a template for new scripts
.DESCRIPTION
	[Incomplete script!] This is a template for new scripts
.EXAMPLE
	C:\PS>.\template.ps1
	This will bring up the new script
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Nov 19, 2015
#>
[CmdletBinding()]
param (	
	$computerName = "128.38.160.102",
	$port = 22,
	$username = "rweber",
	$password = "SharkTeeth12!@"
)   
if($pwd -ne (split-path $MyInvocation.MyCommand.definition)){
	set-location (split-path $MyInvocation.MyCommand.definition)
}

clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$testClass = new-PSClass something{
	note -static PsScriptName "consolePutty"
	note -static Description ( ($(((get-help .\console.ps1).Description)) | select Text).Text)
	
	note -private computerName
	note -private port
	note -private username
	note -private password
	
	note -private sshClient
	note -private sshStream
	note -private reader
	note -private writer
	note -private new $true
	
	constructor{
		param()
		
		if( ('renci.SshNet.SshClient' -is [type] ) -eq $false){
			add-type -path "$($pwd)\bin\Renci.SshNet35.dll"
		}
		
		$private.computerName = $computerName
		$private.port = $port
		$private.username = $username
		$private.password = $password
		
		$private.sshClient = new-object Renci.SshNet.SshClient(
			$($private.computerName), 
			$($private.port), 
			$($private.username), 
			$($private.password)
		)
		
		try{
			$private.sshClient.Connect()
		}catch{
			write-error  $_.Exception.Message
			break;
		}
		$private.sshStream = $private.sshClient.CreateShellStream("psshell", 80, 24, 800, 600, 1024)
		$private.reader = new-object System.IO.StreamReader($private.sshStream)
		$private.writer = new-object System.IO.StreamWriter($private.sshStream)
		$private.writer.AutoFlush = $true
		
	}
	
	method readStream{
		while ($private.sshStream.Length -eq 0){
			start-sleep -milliseconds 500
		}
		$content = $private.reader.ReadToEnd()
		$lines = $content -split "`n"
		for($i = 1; $i -lt $lines.count - 2; $i++){
			write-host "$($lines[$i])"
		}
		start-sleep -milliseconds 500
		if($private.sshStream.dataAvailable -eq $true){
			$this.readStream()
		}
	}
	
	method Execute{
		param()
		$host.ui.rawui.backgroundColor = 0
		$host.ui.rawui.foregroundColor = 7
		clear;
		$this.readStream();
		while(1){
			$command = Read-Host -Prompt "$($private.username)@$($private.computerName)]`$"
			if($command -eq 'quit'){
				break
			}
			$private.writer.WriteLine($command)
			$this.readStream();
		}
		$host.ui.rawui.backgroundColor = 5
		$host.ui.rawui.foregroundColor = 15
		clear
		
		$private.sshStream.Dispose()
		
		$private.sshClient.disconnect()
		$private.sshClient.dispose()
		
		$uiClass.errorLog()
	}
}

$testClass.New().Execute() | out-null