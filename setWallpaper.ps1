<#
.SYNOPSIS
	[ALPHA LEVEL SCRIPT!] This is a script that will set the users wallpaper to be a data dump of pertinent host information.
.DESCRIPTION
	[ALPHA LEVEL SCRIPT!] This is a script that will set the users wallpaper to be a data dump of pertinent host information like hostname, disk usage and logon times.
.PARAMETER Color
	The color to set the background to.  Defaults to CornflourBlue
.EXAMPLE
	C:\PS>.\setWallpaper.ps1
	This example will set the background to cornFlourBlue and dump the system information in white text
.EXAMPLE
	C:\PS>.\setWallpaper.ps1 -color red
	This example will set the background to red and dump the system information in white text
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   Dec 30, 2014
#>
[CmdletBinding()]
Param(  
		[string]$Color = "CornflourBlue",
		[String]$class = "UNCLASSIFIED"
)
	
#Text Overlay Options
[BOOLEAN]$TextOverlay = $True   
[STRING]$TextColor = "White"
[STRING]$FontName = "Times New Roman"
[INT]$FontSize = 12
[BOOLEAN]$ApplyHeader = $false
[STRING]$TextAlign = "Right"
[STRING]$Position = "High"     
 
#Wallpaper Style Options
[STRING]$Style = "Fit"         
 
$Grey = @(192,192,192)
$Black = @(0,0,0)
$White = @(255,255,255)
$Red = @(220,20,60)
$Green = @(0,128,0)
$Yellow = @(255,255,0)
$Blue = @(0,0,255)
$CornflourBlue = @(100,149,237)
 
 
Function New-Wallpaper {
    Param(  [Parameter()]
            [string] $OverlayText,
 
            [Parameter()]
            [string] $OutFile= "$($env:temp)\backgroundDefault.jpg",
 
            [Parameter()]
            [ValidateSet("Center","Left","Right")]
            [string]$TextAlign="Center",
 
            [Parameter()]
            [ValidateSet("High","Low")]
            [string]$Position="High",
            
            [Parameter()]
            [string]$TextColor="White",
            
            [Parameter()]
            [string]$BGColor="Grey",
 
            [Parameter()]
            [string]$FontName="Arial",
            
            [Parameter()]
            [ValidateRange(9,45)]
            [int32]$FontSize = 12,
            
            [Parameter()]
            [ValidateSet($TRUE,$FALSE)]
            [Boolean]$ApplyHeader=$TRUE,
 
            [Parameter()]
            [string]$BGType
    )
    Begin {
 
        Switch ($TextColor) {
            Grey    {$TColor = $Grey}
            Black   {$TColor = $Black}
            White   {$TColor = $White}
            Red     {$TColor = $Red}
            Green   {$TColor = $Green}
            Yellow  {$TColor = $Yellow}
            Blue    {$TColor = $Blue}
            CornflourBlue {$TColor = $CornflourBlue}
            DEFAULT {
                Write-Warning "Text color not found. Please try again"
                exit
            }
        }
        
        Switch ($BGColor) {
            Existing {$BG = "Existing"}
            Grey    {$BG = $Grey}
            Black   {$BG = $Black}
            White   {$BG = $White}
            Red     {$BG = $Red}
            Green   {$BG = $Green}
            Yellow  {$BG = $Yellow}
            Blue    {$BG = $Blue}
            CornflourBlue {$BG = $CornflourBlue}
            DEFAULT {
                Write-Warning "Background color not found. Please try again"
                exit
            }
        }
 
        # Make first line a header (bigger)
        if ($ApplyHeader -eq $TRUE){
            $HeaderSize = $FontSize+1
            $TextSize = $FontSize-2
        }
        else {
            $HeaderSize = $FontSize
            $TextSize = $FontSize
        }
        
        Try {
            [system.reflection.assembly]::loadWithPartialName('system.drawing.imaging') | out-null
            [system.reflection.assembly]::loadWithPartialName('system.windows.forms') | out-null
     
            # Text alignment and position
            $sFormat = new-object system.drawing.stringformat
     
            Switch ($TextAlign) {
                Center {$sFormat.Alignment = [system.drawing.StringAlignment]::Center}
                Left {$sFormat.Alignment = [system.drawing.StringAlignment]::Near}
                Right {$sFormat.Alignment = [system.drawing.StringAlignment]::Far}
            }
     
            Switch ($Position) {
                High {$sFormat.LineAlignment = [system.drawing.StringAlignment]::Near}
                Low {$sFormat.LineAlignment = [system.drawing.StringAlignment]::Center}
            }
     
            Switch ($BGType) {
 
                Color {
                    #Create 
                    $SR = [System.Windows.Forms.Screen]::AllScreens | ? { $_.Primary} | Select -ExpandProperty Bounds | Select Width,Height
         
                    # Create Bitmap
                    $bmp = new-object system.drawing.bitmap($SR.Width,$SR.Height)
                    $image = [System.Drawing.Graphics]::FromImage($bmp)
             
                    # $image.FillRectangle(
                        # (New-Object Drawing.SolidBrush (
                            # [System.Drawing.Color]::FromArgb($BG[0],$BG[1],$BG[2])
                        # )),
                        # (new-object system.drawing.rectanglef(0,0,($SR.Width),($SR.Height)))
                    # )
					
										
					$p0 = New-Object System.Drawing.Point(0, 0)
					$p1 = New-Object System.Drawing.Point($bmp.width, $bmp.height)

					$c0 = [System.Drawing.Color]::FromArgb(255, 0, 128, 0)
					$c1 = [System.Drawing.Color]::FromArgb(255, 6, 78, 41)
					

					$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($p0, $p1, $c0, $c1)

					$image.FillRectangle($brush, 0, 0, $bmp.Width, $bmp.Height)
					
					
                    
                    if ($BG -ne "Existing"){
                        Set-ItemProperty 'HKCU:\Control Panel\Colors' -Name Background -Value $BG
                    }
                }
            }
        }
 
        Catch {
            Write-Warning -Message "$($_.Exception.Message)"
            break
        }
    }
    Process {
        # Split Text array
        $artext = ($OverlayText -split "`r`n")
    
        
        Try {
			$i = 1
			for ($i ; $i -le $artext.Count ; $i++) {
				$font2 = New-Object System.Drawing.Font($FontName,$TextSize,[System.Drawing.FontStyle]::Bold)
				$Brush2 = New-Object Drawing.SolidBrush (
					[System.Drawing.Color]::FromArgb(0,0,0)
				)
				$sz2 = [system.windows.forms.textrenderer]::MeasureText($artext[$i-1], $font2)
				$rect2 = New-Object System.Drawing.RectangleF (4,($i*$FontSize*2 + $sz2.Height + 4),$SR.Width,$SR.Height)
				$image.DrawString($artext[$i-1], $font2, $brush2, $rect2, $sFormat)
            }
			
			$i = 1
            for ($i ; $i -le $artext.Count ; $i++) {
				$font2 = New-Object System.Drawing.Font($FontName,$TextSize,[System.Drawing.FontStyle]::Bold)
				$Brush2 = New-Object Drawing.SolidBrush (
					[System.Drawing.Color]::FromArgb($TColor[0],$TColor[1],$TColor[2])
				)
				$sz2 = [system.windows.forms.textrenderer]::MeasureText($artext[$i-1], $font2)
				$rect2 = New-Object System.Drawing.RectangleF (0,($i*$FontSize*2 + $sz2.Height),$SR.Width,$SR.Height)
				$image.DrawString($artext[$i-1], $font2, $brush2, $rect2, $sFormat)
            }
			
			#top banner
			$sFormat.Alignment = [system.drawing.StringAlignment]::Center
			$font2 = New-Object System.Drawing.Font($FontName,36,[System.Drawing.FontStyle]::Bold)
			$Brush2 = New-Object Drawing.SolidBrush (
				[System.Drawing.Color]::FromArgb(0,0,0)
			)
			$sz2 = [system.windows.forms.textrenderer]::MeasureText("UNCLASSIFIED", $font2)
			$rect2 = New-Object System.Drawing.RectangleF (4,54,$SR.Width,$SR.Height)
			$image.DrawString("UNCLASSIFIED", $font2, $brush2, $rect2, $sFormat)
			
			$sFormat.Alignment = [system.drawing.StringAlignment]::Center
			$font2 = New-Object System.Drawing.Font($FontName,36,[System.Drawing.FontStyle]::Bold)
			$Brush2 = New-Object Drawing.SolidBrush (
				[System.Drawing.Color]::FromArgb($TColor[0],$TColor[1],$TColor[2])
			)
			$sz2 = [system.windows.forms.textrenderer]::MeasureText("UNCLASSIFIED", $font2)
			$rect2 = New-Object System.Drawing.RectangleF (0,50,$SR.Width,$SR.Height)
			$image.DrawString("UNCLASSIFIED", $font2, $brush2, $rect2, $sFormat)
			
			
			
			
			
			
			
			
			
			#bottom banner
			$sFormat.Alignment = [system.drawing.StringAlignment]::Center
			$font2 = New-Object System.Drawing.Font($FontName,36,[System.Drawing.FontStyle]::Bold)
			$Brush2 = New-Object Drawing.SolidBrush (
				[System.Drawing.Color]::FromArgb($TColor[0],$TColor[1],$TColor[2])
			)
			$sz2 = [system.windows.forms.textrenderer]::MeasureText("UNCLASSIFIED", $font2)
			$rect2 = New-Object System.Drawing.RectangleF (0,(([int]($SR.Height)) - 100),$SR.Width,$SR.Height)
			$image.DrawString("UNCLASSIFIED", $font2, $brush2, $rect2, $sFormat)
			
			#middle banner
			$sFormat.Alignment = [system.drawing.StringAlignment]::Center
			$font2 = New-Object System.Drawing.Font($FontName,16,[System.Drawing.FontStyle]::Bold)
			$Brush2 = New-Object Drawing.SolidBrush (
				[System.Drawing.Color]::FromArgb($TColor[0],$TColor[1],$TColor[2])
			)
			$sz2 = [system.windows.forms.textrenderer]::MeasureText("THIS INFORMATION SYSTEM IS ACCREDITED TO PROCESS", $font2)
			$rect2 = New-Object System.Drawing.RectangleF (0,(([int]($SR.Height)/2) - 65),$SR.Width,$SR.Height)
			$image.DrawString("THIS INFORMATION SYSTEM IS ACCREDITED TO PROCESS", $font2, $brush2, $rect2, $sFormat)
			
			
			
			$sFormat.Alignment = [system.drawing.StringAlignment]::Center
			$font2 = New-Object System.Drawing.Font($FontName,36,[System.Drawing.FontStyle]::Bold)
			$Brush2 = New-Object Drawing.SolidBrush (
				[System.Drawing.Color]::FromArgb($TColor[0],$TColor[1],$TColor[2])
			)
			$sz2 = [system.windows.forms.textrenderer]::MeasureText("UNCLASSIFIED DATA", $font2)
			$rect2 = New-Object System.Drawing.RectangleF (0,(([int]($SR.Height)/2) - 50),$SR.Width,$SR.Height)
			$image.DrawString("UNCLASSIFIED DATA", $font2, $brush2, $rect2, $sFormat)
			
				
			
			
			$sFormat.Alignment = [system.drawing.StringAlignment]::Center
			$font2 = New-Object System.Drawing.Font($FontName,16,[System.Drawing.FontStyle]::Bold)
			$Brush2 = New-Object Drawing.SolidBrush (
				[System.Drawing.Color]::FromArgb($TColor[0],$TColor[1],$TColor[2])
			)
			$sz2 = [system.windows.forms.textrenderer]::MeasureText("FOR AUTHORIZED PURPOSES ONLY", $font2)
			$rect2 = New-Object System.Drawing.RectangleF (0,(([int]($SR.Height)/2)),$SR.Width,$SR.Height)
			$image.DrawString("FOR AUTHORIZED PURPOSES ONLY", $font2, $brush2, $rect2, $sFormat)
			
			
			$sFormat.Alignment = [system.drawing.StringAlignment]::Center
			$font2 = New-Object System.Drawing.Font($FontName,16,[System.Drawing.FontStyle]::Bold)
			$Brush2 = New-Object Drawing.SolidBrush (
				[System.Drawing.Color]::FromArgb($TColor[0],$TColor[1],$TColor[2])
			)
			$sz2 = [system.windows.forms.textrenderer]::MeasureText("This System Should Be Locked (CTRL + ALT + DEL) When Left Unattended", $font2)
			$rect2 = New-Object System.Drawing.RectangleF (0,(([int]($SR.Height)/2) + 100),$SR.Width,$SR.Height)
			$image.DrawString("This System Should Be Locked (CTRL + ALT + DEL) When Left Unattended", $font2, $brush2, $rect2, $sFormat)
			
			
			
			
			
        } 
        
		
        Catch {
            Write-Warning -Message "Overlay Text error: $($_.Exception.Message)"
            break
        }
    }
    End {   
        Try { 
            # Close Graphics
            $image.Dispose();
     
            # Save and close Bitmap

	        $myEncoder = [System.Drawing.Imaging.Encoder]::Quality
			$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1) 
			$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($myEncoder, 90)
			$myImageCodecInfo = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|where {$_.MimeType -eq 'image/jpeg'}

			$bmp.Save($outfile,$myImageCodecInfo, $($encoderParams))

			
            # $bmp.Save($OutFile, [system.drawing.imaging.imageformat]::jpeg);
            $bmp.Dispose();
     
            # Output our file
            Get-Item -Path $OutFile
        } 
        
        Catch {
            Write-Warning -Message "Outfile error: $($_.Exception.Message)"
            break
        }
    }
}
 
 
Function Update-Wallpaper {
    Param(
        [Parameter(Mandatory=$true)]
        $Path,
         
        [ValidateSet('Center','Stretch','Fill','Tile','Fit')]
        $Style
    )
    Try {
        if (-not ([System.Management.Automation.PSTypeName]'Wallpaper.Setter').Type) {
            Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            using Microsoft.Win32;
            namespace Wallpaper {
                public enum Style : int {
                    Center, Stretch, Fill, Fit, Tile
                }
                public class Setter {
                    public const int SetDesktopWallpaper = 20;
                    public const int UpdateIniFile = 0x01;
                    public const int SendWinIniChange = 0x02;
                    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
                    private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);
                    public static void SetWallpaper ( string path, Wallpaper.Style style ) {
                        SystemParametersInfo( SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange );
                        RegistryKey key = Registry.CurrentUser.OpenSubKey("Control Panel\\Desktop", true);
                        switch( style ) {
                            case Style.Tile :
                                key.SetValue(@"WallpaperStyle", "0") ; 
                                key.SetValue(@"TileWallpaper", "1") ; 
                                break;
                            case Style.Center :
                                key.SetValue(@"WallpaperStyle", "0") ; 
                                key.SetValue(@"TileWallpaper", "0") ; 
                                break;
                            case Style.Stretch :
                                key.SetValue(@"WallpaperStyle", "2") ; 
                                key.SetValue(@"TileWallpaper", "0") ;
                                break;
                            case Style.Fill :
                                key.SetValue(@"WallpaperStyle", "10") ; 
                                key.SetValue(@"TileWallpaper", "0") ; 
                                break;
                            case Style.Fit :
                                key.SetValue(@"WallpaperStyle", "6") ; 
                                key.SetValue(@"TileWallpaper", "0") ; 
                                break;
}
                        key.Close();
                    }
                }
            }
"@ -ErrorAction Stop 
            } 
        } 
        Catch {
            Write-Warning -Message "Wallpaper not changed because $($_.Exception.Message)"
        }
    [Wallpaper.Setter]::SetWallpaper( $Path, $Style )
}
 
 
Function Build-TextOverlay {
    Param(  [Parameter()]
            [string] $TextOverlay
    )
    
    # Gather Text information
	$vars = @{}
	$vars.add('ip', ( gwmi win32_networkadapterconfiguration | ? { $_.IpAddress -ne $null } | select IPAddress, MACAddress, DefaultIPGateway, DNSServerSearchOrder, IPSubnet ) )
	$vars.add('domain', ( (gwmi win32_computerSystem | select domain -first 1).domain ) )
	$vars.add('hostname', ( $env:COMPUTERNAME ) )
	
	$vars.add('os', ( gwmi -Class Win32_OperatingSystem | select Caption -first 1).Caption )
	$vars.add('sp', (  gwmi -Class Win32_OperatingSystem | select ServicePackMajorVersion -first 1).ServicePackMajorVersion )
	$vars.add('role',  $(
		switch ( (gwmi win32_computerSystem | select domainRole -first 1).domainRole ){ 
			0 {"Standalone Workstation"}
			1 {"Member Workstation"}
			2 {"Standalone Server"}
			3 {"Member Server"}
			4 {"Backup Domain Controller"}
			5 {"Primary Domain Controller"}
		} 
		)
	)
    $vars.add('cpu', 	(gwmi win32_processor | select -first 1 Name).Name.replace("  ","")  )
	$vars.add('freeMem', [math]::round( (gwmi win32_operatingSystem | select FreePhysicalMemory).FreePhysicalMemory *1024 / 1MB ) )
	$vars.add('usedMem', [math]::round( (gwmi win32_operatingSystem | select TotalVisibleMemorySize).TotalVisibleMemorySize *1024 / 1MB ) )
	$vars.add('drives',"")
	gwmi win32_logicalDisk | % { $vars.drives += "$($_.DeviceId) $([math]::round( $_.FreeSpace / 1GB) ) GB / $([math]::round( $_.Size / 1GB) ) GB`r`n" } 
	$vars.add("lastLogon", (gwmi -class Win32_NetworkLoginProfile | Where {$_.Name -eq "$env:USERDOMAIN\$env:USERNAME" } | Select-Object  @{label='LastLogon';expression={$_.ConvertToDateTime($_.LastLogon)}}).LastLogon  )
	$vars.add("bootTime", [System.Management.ManagementDateTimeconverter]::ToDateTime( (gwmi -Class Win32_OperatingSystem).LastBootUpTime) )
	
	$vars.add("logonServer", $($env:LOGONSERVER) )
	$vars.add("dns","")
	$vars.add("update", $( get-date -f "MM/dd/yyyy HH:mm:ss" ) )
$networkMsg = ""
$vars.ip | % {
	if($_.IpAddress -ne ""){ $networkMsg += "IP: " + $_.IPAddress + "`r`n" }
	if($_.IpSubnet -ne ""){ $networkMsg += "Subnet Mask: " + $_.IPSubnet + "`r`n" }
	if($_.MACAddress -ne ""){$networkMsg += "MAC Address: " + $_.MACAddress + "`r`n"}
	if($_.DefaultIPGateway -ne ""){$networkMsg += "Default Gateway: " + $_.DefaultIPGateway + "`r`n"}
	if($_.DNSServerSearchOrder -ne ""){ $networkMsg += "DNS:`r`n"; $_.DNSServerSearchOrder | % { $networkMsg += "$($_ )`r`n" } }
	$networkMsg += "`r`n"
}
	
$oText = @"
Operating System: $($vars.os)
Service Pack: SP $($vars.sp)
Role: $($vars.role)
Boot Time: $( $vars.bootTime )
Last Logon: $( $vars.lastLogon )
Information Updated: $($vars.update)

CPU: $( $vars.cpu )
Memory: $( $vars.freeMem ) MB / $( $vars.usedMem ) MB
Free Space: $( $vars.drives	)
Hostname: $($vars.hostname)
Domain: $($vars.domain)
Logon Server: $($vars.logonServer)

Network Configurations:
$($networkMsg)
"@


$mdatver = Get-ItemProperty -path hklm:\software\wow6432node\mcafee\avengine -errorAction silentlyContinue
if($mdatver -ne $null){
$oText += @"
McAfee DAT Date: $($mdatver.AvDatDate)
McAfee DAT Version: $($mdatver.AvDatVersion)
McAfee Engine Version: $( $mtDatVer.Engine64Major).$( $mdatver.Engine64Minor)
"@
}



    
    Return $oText
}
 
 
Function Set-Wallpaper {
    
    Begin {
			$BGColor = $color
    }
    Process{
        $oText = Build-TextOverlay $TextOverlay
        $Overlay = @{
            OverlayText = $oText ;        
            TextColor = $TextColor ;  
            FontName = $FontName ;
            FontSize = $FontSize ;
            ApplyHeader = $ApplyHeader ;   
            TextAlign = $TextAlign ;
            Position = $Position    
        }
        
        $Background = @{
            BGType = 'Color' ;   
            BGColor = $color
        }
    }
    End{
        $WallPaper = New-Wallpaper @Overlay @Background
        Update-Wallpaper -Path $WallPaper.FullName -Style $Style
    }
}
 
Set-Wallpaper 