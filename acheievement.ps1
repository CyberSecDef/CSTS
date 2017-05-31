[CmdletBinding()]
param (	
	$text = "Test Accomplishment Goes Here", 
	$out = "achievement_$((get-date).ToString('yyyyMMddHHmmss')).png",
	$font = 14
) 

Begin{
	try{
		Add-Type -AssemblyName System.Drawing
		$bmp = new-object System.Drawing.Bitmap "$pwd\images\achievement.png"
		$headerFont = new-object System.Drawing.Font Consolas,22 
		$textFont = new-object System.Drawing.Font Consolas,$font
		$brushFg = [System.Drawing.Brushes]::White
		$graphics = [System.Drawing.Graphics]::FromImage($bmp) 
	}catch{
		write-error "Could Not Initialize Variables"
	}
}

Process{
	try{
		$graphics.DrawString('Achievement Unlocked',$headerFont,$brushFg,65,0) 
		$graphics.DrawString($text,$textFont,$brushFg,70,45) 
	}catch{
		Write-Error "Could not Add Text to Bitmap"
	}
}

End{
	try{
		$graphics.Dispose()
		$bmp.Save("$(pwd)\results\$($out)")
		Invoke-Item "$(pwd)\results\$($out)"
	}catch{
		Write-Error "Could not save Bitmap"
	}
}