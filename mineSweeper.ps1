<#
.SYNOPSIS
	This is a mine sweeper app
.DESCRIPTION
	This is a mine sweeper app
.PARAMETER side
	The number of cells per side, defaults to 16
.PARAMETER mines
	The number of mines to find, defaults to 40
.PARAMETER easy
	Sets the game to be an 8x8 grid, with 10 mines to find
.PARAMETER mediuam
	Sets the game to be an 16x16 grid, with 40 mines to find
.PARAMETER hard
	Sets the game to be an 24x24 grid, with 99 mines to find
.PARAMETER expert
	Sets the game to be an 32x32 grid, with 150 mines to find
.EXAMPLE
	C:\PS>.\minesweeper.ps1 
	This example will load the game
.EXAMPLE
	C:\PS>.\minesweeper.ps1 -hard
	This example will load the hard game
.INPUTS
	There are no inputs that can be directed to this script
.OUTPUTS  
	All outputs are sent to the console and logged in the log folder
.NOTES
	Author: Robert Weber
	Date:   June 12, 2015
#>
[CmdletBinding()]
param( $side = 16, $mines = 40, [switch]$easy, [switch]$medium, [switch]$hard, [switch]$expert)
clear
$error.clear()
. .\lib\PSClass.ps1
(gci .\lib) | % { . "$($_.FullName)" }

$mineSweeperClass = new-PSClass mineSweeper{
	note -static PsScriptName "mineSweeper"
	note -static Description ( ($(((get-help .\mineSweeper.ps1).Description)) | select Text).Text)
	 
	note -private gui
	 
	note -private rows
	note -private cols
	note -private mines 
	 
	note -private map
	 
	note -private cleared 
	 
	method -private DoFlag{
		param($num)
 
		if( $private.map[$num].text -ne "M"){
			$private.map[$num].text = "M" 
			$private.map[$num].BackColor = "lightblue"
			$private.gui.controls.txtFlags.text = $([int]$private.gui.controls.txtFlags.text) - 1
		}else{
			$private.map[$num].text = "" 
			$private.map[$num].BackColor = "lightGray"
			$private.gui.controls.txtFlags.text = $([int]$private.gui.controls.txtFlags.text) + 1
		}
	}
 
	method -private DoClear {
		param($num)
		$private.cleared.add( $num )
 
		while($private.cleared.count -gt 0){
			$n = $private.cleared[0]
			$private.ExecClear($n)
			$private.cleared.remove($n)
		}
	}
 
	method -private ExecClear {
		param($num)
 
		$C = $num % $private.rows 
		$R = [math]::truncate($num/$private.rows) 
		If ($private.map[$num].enabled -eq $true) { 
			if ($private.map[$num].tag -eq "x") { 
				$uiClass.writeColor("$($uiClass.STAT_ERROR) Button #yellow#$num# contained a #red#mine#")
				$private.map[$num].text = "x" 
				$private.map[$num].BackColor = "red"
				$private.map | % {
					$_.enabled = $false

				}
			} Else {
				$private.map[$num].BackColor = "#FFC0C0C0" 
				$private.map[$num].FlatStyle = 'Flat' 
				
				if ($private.map[$num].tag -ne 0) {
					$private.map[$num].BackColor = "#FFC0C0C0"
					$private.map[$num].text = $private.map[$num].tag
					$private.map[$num].Enabled = $true
					switch($private.map[$num].tag){
						1 { $private.map[$num].backcolor = "#FF9999FF"; }
						2 { $private.map[$num].backcolor = "#FF99FF99"; }
						3 { $private.map[$num].backcolor = "#FFFF9999"; }
						
						4 { $private.map[$num].backcolor = "#FF9999CC"; }
						5 { $private.map[$num].backcolor = "#FF99CC99"; }
						6 { $private.map[$num].backcolor = "#FFCC9999"; }
						
						7 { $private.map[$num].backcolor = "#FF6666ff"; }
						8 { $private.map[$num].backcolor = "#FF66ff66"; }
						9 { $private.map[$num].backcolor = "#FFff6666"; }
					}
				} Else {
					$private.map[$num].BackColor = "#FFEEEEEE"
					if ($C -gt 0) { 
						$private.cleared.add(  $( $num - 1 ) ) 
 
						if ($R -gt 0) { 
							$private.cleared.add( $( $num - $private.Cols) - 1 ) 
						} 
					} 
					if ($C -lt ($private.Cols - 1)) { 
						$private.cleared.add($num + 1 ) 
						if ($R -gt 0) { 
							$private.cleared.add( ( $num - $private.cols) + 1 )
						} 
					} 
					if ($R -gt 0) { 
						$private.cleared.add( $num - $private.cols) 
					} 
					if ($R -lt ($private.rows -1)) { 
						$private.cleared.add($num + $private.cols) 
						if ($C -gt 0) { 
							$private.cleared.add( ($num + $private.Cols) - 1 ) 
						}
						if ($C -lt ($private.Cols - 1)) { 
							$private.cleared.add( ( $num + $private.Cols ) + 1 )
						} 
					} 
				} 
				$private.map[$num].Enabled = $false
			} 
		} 
	} 
 
	method -private DoRaise{ 
		param($cell)
 
		if ($private.map[$cell].tag -ne "x"){ 
			$n = [int]$private.map[$cell].tag 
			$n += 1 
			$private.map[$cell].tag = $n 
		} 
	} 
 
	constructor{
		param()

		$private.cols = $side
		$private.rows = $side

		if($mines -ne $null){
			$private.mines = $mines
		}

		if($easy){
			$private.cols = 8
			$private.rows = 8
			$private.mines = 10
		}
		if($medium){
			$private.cols = 16
			$private.rows = 16
			$private.mines = 40
		}
		if($hard){
			$private.cols = 24
			$private.rows = 24
			$private.mines = 99
		}
		if($expert){
			$private.cols = 32
			$private.rows = 32
			$private.mines = 150
		}
 
			
		$private.gui = $null
		$private.gui = $guiClass.New("mineSweeper.xml")
		$private.gui.generateForm();
		$private.gui.form.width = ($private.cols * 25) + 35 
		$private.gui.form.Height = ($private.rows * 25) + 90  
		 
		$private.gui.controls.txtFlags.text = $private.mines
			
		$private.map = [System.Windows.Forms.Control[]] @()
 
		for ($i = 0;$i -lt $private.rows;$i++){ 
			$row = @() 
			for ($j = 0;$j -lt $private.Cols;$j++){ 

				$Button = new-object System.Windows.Forms.Button 
				$Button.width = 25 
				$Button.Height = 25 
				$button.top = ($i * 25) + 40 
				$button.Left = $j * 25 + 10 
				$button.Name = $( ($i * $private.cols) + $j)
				$button.tabstop = $false
				$button.FlatStyle = 'Flat'
				$button.FlatAppearance.Bordersize = 1
				$Button.FlatAppearance.BorderColor = "#80808080"
				$button.backColor = "#FF999999"
 
				$Button.tag = "0" 
				$button.add_mouseDown({
					switch($_.Button){
						"Left" {
							$uiClass.writeColor("$($uiClass.STAT_OK) #green#Testing# button #yellow#$num#") 
							[int]$num = $this.name 
							$this.name 
							$private.cleared = new-object collections.arraylist
							$private.DoClear($num) 
						}
						"Right" {
							$uiClass.writeColor("$($uiClass.STAT_OK) #green#Setting Flag# on button #yellow#$num#")
							[int]$num = $this.name 
							$this.name 
							$private.DoFlag($num)
						}
					}
				}) 
				$row += $Button 
			}    
			$private.Map += $row 
		}
 
		$Random = new-object system.random([datetime]::now.Millisecond) 
		for ($i = 0 ; $i -lt $private.Mines) { 
			$num = $random.next($private.map.count) 
			if ( $private.map[$num].tag -ne "x") { 
				$private.map[$num].tag = "x" 
				$C = $num % $private.rows 
				$R = [math]::truncate($num/$private.rows) 

				if ($C -gt 0) { 
					$private.doRaise($num - 1) 
					if ($R -gt 0) { 
						$private.doRaise(($num - $private.Cols) - 1) 
					} 
				} 
				if ($C -lt ($private.Cols - 1)) { 
					$private.doRaise($num + 1) 
					if ($R -gt 0) { 
						$private.doRaise(($num - $private.Cols) + 1) 
					} 
				} 
				if ($R -gt 0) { 
					$private.doRaise($num - $private.cols) 
				} 
				if ($R -lt ($private.rows -1)) { 
					$private.doRaise($num + $private.cols) 
					if ($C -gt 0) { 
						$private.doRaise(($num + $private.Cols) - 1) 
					} 
					if ($C -lt ($private.Cols -1)) { 
						$private.doRaise(($num + $private.Cols) + 1) 
					} 
				}
				$i++ 
			} 
		}

		$private.gui.Form.controls.addrange($private.map) 
		
		$private.gui.Form.ShowDialog()| Out-Null
	}
	
}
$global:mineSweeper = $mineSweeperClass.New()