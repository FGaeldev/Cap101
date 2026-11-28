# Renders a tarp page to a 24 x 36 in PDF (vector text) and a PNG preview, using Microsoft Edge.
#   powershell -ExecutionPolicy Bypass -File docs\showcase-tarp\render.ps1                  # tarp.html    -> AkeanQuest-tarp-24x36.pdf, preview.png
#   powershell -ExecutionPolicy Bypass -File docs\showcase-tarp\render.ps1 -Version v2      # tarp-v2.html -> AkeanQuest-tarp-24x36-v2.pdf, preview-v2.png
# -Png300  also writes a flat 300 dpi PNG (7200 x 10800 px), the safest file for tarp printers.
# -Bleed   also writes a 300 dpi PNG + PDF with 0.5 in of mirrored bleed on every side (25 x 37 in;
#          the printer trims it back to 24 x 36). Needs Python + Pillow. Implies -Png300.
# Fonts load from Google Fonts: render while online.
param([string]$Version = '', [switch]$Png300, [switch]$Bleed)

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$suffix = if ($Version) { "-$Version" } else { '' }
$src    = Join-Path $here "tarp$suffix.html"
if (-not (Test-Path $src)) { throw "Not found: $src" }
$edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { $edge = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe" }
$url  = ([Uri]$src).AbsoluteUri
$hiResPng = Join-Path $here "AkeanQuest-tarp-24x36$suffix-300dpi.png"

# One Edge run at a time, each with its own throwaway profile, so runs can't collide.
function Invoke-Edge([string[]]$extra) {
  $profileDir = Join-Path $env:TEMP ("tarp-edge-" + [guid]::NewGuid())
  $edgeArgs = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--virtual-time-budget=15000',
            '--run-all-compositor-stages-before-draw', "--user-data-dir=$profileDir") + $extra + @($url)
  Start-Process $edge -ArgumentList $edgeArgs -Wait -NoNewWindow -RedirectStandardError "$profileDir.log" | Out-Null
  Remove-Item $profileDir, "$profileDir.log" -Recurse -Force -ErrorAction SilentlyContinue
}

Invoke-Edge @('--no-pdf-header-footer', "--print-to-pdf=$(Join-Path $here "AkeanQuest-tarp-24x36$suffix.pdf")")
Invoke-Edge @('--window-size=2304,3456', '--force-device-scale-factor=0.5', "--screenshot=$(Join-Path $here "preview$suffix.png")")
if ($Png300 -or $Bleed) {
  Invoke-Edge @('--window-size=2304,3456', '--force-device-scale-factor=3.125', "--screenshot=$hiResPng")
  if (-not (Test-Path $hiResPng)) { throw "300 dpi render failed: $hiResPng" }
}
if ($Bleed) {
  $py = "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe"
  if (-not (Test-Path $py)) { $py = 'py' }
  & $py (Join-Path $here 'make_bleed.py') $hiResPng (Join-Path $here "AkeanQuest-tarp-25x37-bleed$suffix")
}
Get-ChildItem $here -File | Where-Object { $_.Name -like "*$suffix.pdf" -or $_.Name -like "preview$suffix.png" -or $_.Name -like "*$suffix-300dpi.png" -or $_.Name -like "*bleed$suffix.*" } |
  Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}, LastWriteTime
