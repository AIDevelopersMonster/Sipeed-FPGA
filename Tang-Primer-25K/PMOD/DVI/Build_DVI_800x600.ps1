# Tang Primer 25K + Dock, PMOD0/J4: prepare Sipeed SVO for 800x600 @ 60 Hz.
# Gowin V1.9.9Beta-4_Education has no open_project/create_project in gw_sh.exe.
# Therefore prepare a reversible project copy and open Gowin IDE for Run All.
# Programming is ALWAYS a separate programmer_cli.exe SRAM-only operation.
param([switch]$Program)

$ErrorActionPreference = 'Stop'
if ($Program) {
    throw 'Automatic build and -Program are unsupported on this Gowin 1.9.9 installation. Build in Gowin IDE first, then use programmer_cli.exe --run 2.'
}

$vendor = 'C:\GitHub\TangPrimer-25K-example\hdmi\svo'
$work = 'C:\GitHub\TangPrimer25K_DVI_SVGA_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
if (-not (Test-Path (Join-Path $vendor 'hdmi.gprj'))) {
    throw "Missing upstream hdmi.gprj: $vendor"
}

New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $vendor 'src') -Destination (Join-Path $work 'src') -Recurse
Copy-Item -LiteralPath (Join-Path $vendor 'hdmi.gprj') -Destination (Join-Path $work 'hdmi.gprj')

function Patch-One([string]$path, [string]$old, [string]$new) {
    $txt = [System.IO.File]::ReadAllText($path)
    $count = [regex]::Matches($txt, [regex]::Escape($old)).Count
    if ($count -ne 1) { throw "Expected one occurrence, found $count in $path" }
    [System.IO.File]::WriteAllText($path, $txt.Replace($old, $new), [System.Text.UTF8Encoding]::new($false))
}

Patch-One (Join-Path $work 'src\gowin_pll\gowin_pll.v') 'defparam PLLA_inst.MDIV_SEL = 17;' 'defparam PLLA_inst.MDIV_SEL = 16;'
Patch-One (Join-Path $work 'src\gowin_pll\gowin_pll.v') 'defparam PLLA_inst.ODIV0_SEL = 1;' 'defparam PLLA_inst.ODIV0_SEL = 4;'
Patch-One (Join-Path $work 'src\svo_hdmi.v') 'parameter SVO_MODE             =   "1920x1080";' 'parameter SVO_MODE             =   "800x600";'

$ide = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_ide.exe'
if (-not (Test-Path $ide)) {
    $ide = Get-ChildItem 'C:\Gowin' -Recurse -Filter 'gw_ide.exe' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
$project = Join-Path $work 'hdmi.gprj'
Write-Host "PROJECT: $project"
Write-Host 'MODE: 800x600 @ 60 Hz, 40 MHz pixel clock and 200 MHz TMDS serializer'
Write-Host 'PATCHES: PLL MDIV_SEL=16, ODIV0_SEL=4, SVO_MODE=800x600'
Write-Host 'STATUS: sources prepared; NO BUILD and NO FLASH write performed.'
Write-Host 'NEXT: in Gowin FPGA Designer open this hdmi.gprj and run Run All.'
Write-Host "EXPECTED: $work\impl\pnr\hdmi.fs"
if (-not $ide) { throw "gw_ide.exe not found; manually open $project in Gowin FPGA Designer" }
Start-Process -FilePath $ide -ArgumentList $project
Write-Host "Gowin IDE launched: $ide"
