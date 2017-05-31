cls
@echo off
echo Adding permissions to PowerShell to execute scripts
REG ADD HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell /v ExecutionPolicy /t REG_SZ /d Unrestricted /f
powershell.exe -file setup.ps1