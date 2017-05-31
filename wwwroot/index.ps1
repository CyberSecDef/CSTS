$PageClass = New-PSClass Page{
	note -private request
	constructor{
		param($request)
		$private.request = $request
	}
	
	method WebResponse{
		switch($private.request.Get.action){
			"test" { return "this is an inline test"} 
			"index" { return $this.index() }
			"top" { return $this.top() }
			default { return "<form method='post' action='index.ps1?action=index'><input name='input' type='text' /><input type='checkbox' name='c'><input type='submit'></form>this is a test using the new object $($private.request.Get.another) " }
		}	
	}
	
	method index{
		return $RequestClass.ParsePSPost( $private.request.Post, 'System.Text.ASCII' )
	}
	
	method top{
	
		$topProc = @()
		$procs = get-wmiobject Win32_PerfFormattedData_PerfProc_Process | ?{ $_.name -ne 'Idle' -and $_.name -ne 'Total' } | sort PercentProcessorTime -Descending | select -first 40

		foreach($p in $procs) {

			$info = get-wmiobject Win32_Process | ? { $_.ProcessId -eq $p.IDProcess }
			#$info | out-string | write-host

			if($info.CreationDate -ne $null){
			$t = (New-TimeSpan $($info.ConvertToDateTime($info.CreationDate)) $(Get-Date))
			$ts = "$([math]::floor($t.TotalMinutes)):$([math]::floor($t.seconds))"
			}else{
				$ts = 0
			}
			$proc = @{}	
			$proc.Add("ProcId", $info.ProcessId)
			$proc.Add("User", $info.getOwner().user);
			$proc.Add("Thr", $info.ThreadCount)
			$proc.Add("hnd", $p.HandleCount)
			$proc.Add("page", $p.PageFileBytes)
			$proc.Add("Pri", $info.Priority)
			$proc.Add("Mem", $info.WorkingSetSize)
			$proc.Add("Cpu", $p.PercentProcessorTime)
			$proc.Add("Time", $ts )
			$proc.Add("Cmd", $info.ProcessName)
			
			$topProc += $proc
		}
		
		$html = "<table>"
		$html += "<tr>`n"
		foreach($k in $topProc[0].Keys){
			$html += "<th>$($k)</th>`n"
		}
		$html += "</tr>`n"
		
		$topProc | %{
			$html += "<tr>`n"
			foreach($k in $_.Keys){
			$html += "<td>$($_.$k)</td>`n"
			}
			$html += "</tr>`n"
		}
		$html += "</table>"
		
		return $html
	}
}