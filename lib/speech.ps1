$speechClass = New-PSClass Speech{
	note -private speaker
	
	method speak{
		param(
			[string] $msg
		)
		
		$private.speaker.speak($msg)
	}
	
	constructor{
		$private.speaker = new-object -com SAPI.SpVoice
	}
}