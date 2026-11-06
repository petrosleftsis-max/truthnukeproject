# Puts the designer's sounds where the game uses them, as they are: no converting. The originals are
# kept off GitHub, on the designer's own drive, so this is what to run after fetching them on another
# machine, or after adding a new one to tools/sfx_list.txt.
#
#   powershell -ExecutionPolicy Bypass -File tools/place_sfx.ps1
#   powershell -ExecutionPolicy Bypass -File tools/place_sfx.ps1 -Only sword
#
# tools/sfx_list.txt says what goes where, one sound a line: <original> <copy> [raise]. The audio is not
# touched, with one exception: a file saved with the extended WAV header Godot refuses has that header's
# format tag set to plain PCM, which changes no sample. Cutting the silence at each end and raising a
# quiet sound are Godot import settings, written beside each copy as its .import file: edit/trim and
# edit/normalize, so they can be changed in the editor's Import dock.
param(
	[string]$List = "tools/sfx_list.txt",
	[string]$From = "audio/sfx/New folder",
	[string]$To = "audio/sfx",
	[string]$Only = ""
)
$ErrorActionPreference = "Stop"
$here = (Get-Location).Path
$placed = 0
$total = 0
foreach ($line in Get-Content $List) {
	$line = $line.Trim()
	if ($line -eq "" -or $line.StartsWith("#")) { continue }
	$bits = $line -split "\s+"
	if ($Only -ne "" -and -not $bits[0].Contains($Only)) { continue }
	$source = Join-Path $here (Join-Path $From $bits[0])
	$target = Join-Path $here (Join-Path $To $bits[1])
	New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
	$bytes = [System.IO.File]::ReadAllBytes($source)
	# Find the format chunk: an extended header with PCM inside is plain PCM to Godot.
	$at = 12
	$fixed = ""
	while ($at + 8 -le $bytes.Length) {
		$id = [System.Text.Encoding]::ASCII.GetString($bytes, $at, 4)
		$size = [BitConverter]::ToInt32($bytes, $at + 4)
		if ($id -eq "fmt ") {
			if ([BitConverter]::ToUInt16($bytes, $at + 8) -eq 0xFFFE) {
				$inner = [BitConverter]::ToUInt16($bytes, $at + 32)
				$bytes[$at + 8] = [byte]($inner -band 255)
				$bytes[$at + 9] = [byte](($inner -shr 8) -band 255)
				$fixed = "  (header made plain)"
			}
			break
		}
		$at += 8 + $size + ($size -band 1)
	}
	[System.IO.File]::WriteAllBytes($target, $bytes)
	$res = "res://audio/sfx/" + $bits[1]
	$normalize = if ($bits -contains "raise") { "true" } else { "false" }
	$import = $target + ".import"
	if (-not (Test-Path $import)) {
		$text = "[remap]`n`nimporter=`"wav`"`ntype=`"AudioStreamWAV`"`n`n[deps]`n`nsource_file=`"$res`"`n`n[params]`n`nforce/8_bit=false`nforce/mono=false`nforce/max_rate=false`nforce/max_rate_hz=44100`nedit/trim=true`nedit/normalize=$normalize`nedit/loop_mode=0`nedit/loop_begin=0`nedit/loop_end=-1`ncompress/mode=2`n"
		[System.IO.File]::WriteAllText($import, $text, (New-Object System.Text.UTF8Encoding($false)))
	}
	Write-Output ("{0,-34} {1,8:0.0} KB{2}" -f $bits[1], ($bytes.Length / 1024.0), $fixed)
	$placed += 1
	$total += $bytes.Length
}
Write-Output ("{0} placed, {1:0.0} MB" -f $placed, ($total / 1048576.0))
