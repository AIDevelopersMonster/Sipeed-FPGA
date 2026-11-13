# Tang Primer 25K / PMOD0 (Dock J4) -- rebuild vendor SVO at 800x600.
# Source: sipeed/TangPrimer-25K-example/hdmi/svo
# Changes: 850 MHz PLL out -> 200 MHz; 1080p -> 800x600.
# Keeps vendor checkout untouched. -Program loads FPGA SRAM only.
param([switch]$Program)

$ErrorActionPreference = 'Stop'
$vendor = 'C:\GitHub\TangPrimer-25K-example\hdmi\svo'
$tag = Get-Date -Format 'yyyyMMdd_HHmmss'
$work = "C:\GitHub\TangPrimer25K_DVI_SVGA_$tag"

if (-not (Test-Path (Join-Path $vendor 'hdmi.gprj'))) {
  throw "Missing vendor project at $vendor"
}
New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item (Join-Path $vendor 'src') (Join-Path $work 'src') -Recurse
Copy-Item (Join-Path $vendor 'hdmi.gprj') (Join-Path $work 'hdmi.gprj')

function Patch-One([string]$path, [string]$old, [string]$new) {
  $txt = [System.IO.File]::ReadAllText($path)
  $matches = [regex]::Matches($txt, [regex]::Escape($old))
  if ($matches.Count -ne 1) {
    throw "Expected one occurrence in Tang-Primer-25K/PMOD/DVI/Build_DVI_800x600.ps1, found $($matches.Count): $old"
  }
  [System.IO.File]::WriteAllText($path, $txt.Replace($old, $new),
      [System.Text.UTF8Encoding]::new($false))
}

Patch-One (Join-Path $work 'src\gowin_pll\gowin_pll.v') 'defparam PLLA_inst.MDIV_SEL = 17;' 'defparam PLLA_inst.MDIV_SEL = 16;'
Patch-One (Join-Path $work 'src\gowin_pll\gowin_pll.v') 'defparam PLLA_inst.ODIV0_SEL = 1;' 'defparam PLLA_inst.ODIV0_SEL = 4;'
Patch-One (Join-Path $work 'src\svo_hdmi.v') 'parameter SVO_MODE             =   "1920x1080";' 'parameter SVO_MODE             =   "800x600";'

$roots = @('C:\Gowin', 'C:\Program Files\Gowin') | Where-Object { Test-Path $_ }
$gw = (Get-Command gw_sh.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
if (-not $gw -and $roots) {
  $gw = Get-ChildItem -Path $roots -Recurse -File -Filter gw_sh.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $gw) { throw "gw_sh.exe not found. Patched sources are in $work" }

$projectForTcl = (Join-Path $work 'hdmi.gprj').Replace('\','/')
$tcl = Join-Path $work 'build.tcl'
@("open_project {$projectForTcl}", 'run all') | Set-Content -Path $tcl -Encoding ascii

Write-Host "PROJECT: $work"
Write-Host "BUILD: $gw"
Write-Host "VIDEO: 800x600 @ 60 Hz; pixel 40 MHz, serializer 200 MHz"
Push-Location $work
try {
  & $gw $tcl 2>&1 | Tee-Object -FilePath (Join-Path $work 'build.log')
  $status = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($status -ne 0) { throw "Gowin build exit code $status, inspect $work\build.log" }

$fs = Join-Path $work 'impl\pnr\hdmi.fs'
if (-not (Test-Path $fs)) { throw "No built .fs found: $fs. Inspect build.log" }
Get-FileHash -Path $fs -Algorithm SHA256
Write-Host "BITSTREAM: $fs"

if ($Program) {
  $cli = (Get-Command programmer_cli.exe -ErrorAction SilentlyContinue |
          Select-Object -First 1 -ExpandProperty Source)
  if (-not $cli -and $roots) {
    $cli = Get-ChildItem -Path $roots -Recurse -File -Filter programmer_cli.exe -ErrorAction SilentlyContinue |
           Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not $cli) { throw 'programmer_cli.exe not found; build succeeded but FPGA not programmed' }
  & $cli --device GW5A-25A --run 2 --fsFile $fs --cable-index 1
  if ($LASTEXITCODE -ne 0) { throw "SRAM programming failed: $LASTEXITCODE" }
  Write-Host 'SRAM upload finished. DVI picture must be physically checked.'
}
