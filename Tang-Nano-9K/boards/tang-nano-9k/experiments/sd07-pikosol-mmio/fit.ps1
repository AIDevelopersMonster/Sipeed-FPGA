# SD-07 FIT ONLY: CPU+HDMI+graphics+UART+SD CMD17/CMD24 on GW1NR-9C.
# NEVER programs hardware. Deletes .fs on success or failure. No Flash/SD writes.
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$root=(Resolve-Path (Join-Path $here '..\..\..\..')).Path
$lab=Join-Path $root '01-PicoRV32\lab04'
$base=Join-Path $root '01-PicoRV32'
$sd06=Join-Path $root 'boards\tang-nano-9k\experiments\sd06-cmd24'
$sd03=Join-Path $root 'boards\tang-nano-9k\experiments\sd-mbr-fat32'
$vendor=Join-Path $base 'vendor\picotiny_ref'
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not(Test-Path $gw)){throw "Gowin not installed at $gw"}
& python (Join-Path $here 'check_active_sources.py')
if($LASTEXITCODE -ne 0){throw 'SD07 active PiKoSoL input SHA256 verification failure'}
& python (Join-Path $lab 'tools\build_rom.py') --check
if($LASTEXITCODE -ne 0){throw 'PiKoSoL original firmware reproducibility failure'}
$must=@(
 (Join-Path $base 'vendor\picorv32\picorv32.v'),
 (Join-Path $vendor 'SOURCE_SHA256.txt'),
 (Join-Path $vendor 'SOURCE_PIN.txt'),
 (Join-Path $lab 'firmware\lab04_boot.hex'),
 (Join-Path $lab 'rtl\lab04_font_8x12.hex')
)
foreach($p in $must){if(-not(Test-Path -LiteralPath $p)){throw "Required source missing: $p"}}
$pin=Get-Content (Join-Path $vendor 'SOURCE_PIN.txt') -Raw
if(-not $pin.Contains('c3b795799f23de91982be52db4273a8eea100cdb')){throw 'Vendor pin mismatch'}
$vendorLines=@(Get-Content (Join-Path $vendor 'SOURCE_SHA256.txt'))
if($vendorLines.Count -ne 11){throw 'Pinned vendor manifest not exactly 11 files'}
foreach($line in $vendorLines){
 if($line -cnotmatch '^([a-f0-9]{64})  ([A-Za-z0-9_./-]+)$'){throw "Invalid pin: $line"}
 $hash=$Matches[1];$rel=$Matches[2]
 if($rel.Contains('..')){throw 'Vendor path traversal'}
 $file=Join-Path $vendor $rel
 if(-not(Test-Path $file) -or
    (Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hash){
   throw "Vendored source has changed: $file"
 }
}
$job=Join-Path $here ('build\fit_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
$work=Join-Path $job 'work'
foreach($d in @('lab04\rtl','lab04\constraints','rtl','vendor\picorv32','vendor\picotiny_ref',
    'sd\rtl')){
 New-Item -ItemType Directory -Force -Path (Join-Path $work $d)|Out-Null
}
Copy-Item (Join-Path $lab 'rtl\*.v') (Join-Path $work 'lab04\rtl')
Copy-Item (Join-Path $here 'rtl\lab04_cpu_soc.v') (Join-Path $work 'lab04\rtl\lab04_cpu_soc.v') -Force
Copy-Item (Join-Path $here 'rtl\lab04_cpu_hdmi_top.v') (Join-Path $work 'lab04\rtl\lab04_cpu_hdmi_top.v') -Force
Copy-Item (Join-Path $here 'rtl\sd07_sd_mmio.v') (Join-Path $work 'sd\rtl')
Copy-Item (Join-Path $sd06 'rtl\sd06_cmd24_engine.v') (Join-Path $work 'sd\rtl')
foreach($f in @('spi_byte.v','sd_read_sector.v')){
 Copy-Item (Join-Path $sd03 "rtl\$f") (Join-Path $work 'sd\rtl')
}
Copy-Item (Join-Path $base 'rtl\uart_tx_8n1.v') (Join-Path $work 'rtl')
Copy-Item (Join-Path $base 'rtl\uart_rx_8n1.v') (Join-Path $work 'rtl')
Copy-Item (Join-Path $base 'vendor\picorv32\picorv32.v') (Join-Path $work 'vendor\picorv32')
Copy-Item -Recurse (Join-Path $vendor 'hw') (Join-Path $work 'vendor\picotiny_ref')
Copy-Item -Recurse (Join-Path $vendor 'gowin_ip') (Join-Path $work 'vendor\picotiny_ref')
Copy-Item (Join-Path $vendor 'hw\hdmi\svo_defines.vh') (Join-Path $work 'svo_defines.vh')
Copy-Item (Join-Path $lab 'rtl\lab04_font_8x12.hex') (Join-Path $work 'lab04_font_8x12.hex')
Copy-Item (Join-Path $lab 'rtl\lab04_font_8x12.hex') (Join-Path $work 'lab04\rtl\lab04_font_8x12.hex')
Copy-Item (Join-Path $lab 'firmware\lab04_boot.hex') (Join-Path $work 'lab04_boot.hex')
Copy-Item (Join-Path $lab 'firmware\lab04_boot.hex') (Join-Path $work 'lab04\rtl\lab04_boot.hex')
Copy-Item (Join-Path $lab 'constraints\lab04_cpu_video_v018b.sdc') (Join-Path $work 'lab04\constraints')
Copy-Item (Join-Path $here 'constraints\sd07_cpu_hdmi_sd.cst') (Join-Path $work 'lab04\constraints')
Copy-Item (Join-Path $here 'gowin_fit.tcl') (Join-Path $work 'gowin_fit.tcl')
Get-ChildItem $work -Recurse -File|Sort-Object FullName|ForEach-Object{
 [pscustomobject]@{Path=$_.FullName.Substring($work.Length+1);SHA256=(Get-FileHash $_.FullName).Hash}
}|Export-Csv (Join-Path $job 'inputs.csv') -NoTypeInformation
Write-Host 'SD07_FIT_ONLY: PicoRV32+HDMI+graphics+UART+SD CMD17/CMD24; no board programming.'
Write-Host 'SD07_FIT_ONLY: write permission synthetic LBA FFFFFFFE. NEVER use bitstream.'
Push-Location $work
try{
 & $gw 'gowin_fit.tcl' *> (Join-Path $job 'gowin_cli.log')
 $code=$LASTEXITCODE
}finally{
 Pop-Location
 # Always delete all .fs files produced anywhere inside isolated job.
 Get-ChildItem $job -File -Recurse -Filter '*.fs' -ErrorAction SilentlyContinue |
   Remove-Item -Force -ErrorAction Stop
}
Write-Host "SD07_FIT_JOB: $job"
Write-Host "SD07_FIT_LOG: $(Join-Path $job 'gowin_cli.log')"
if($code -ne 0){Write-Host 'SD07_FIT_FAIL: Gowin did not complete; no bitstream retained.';throw "Gowin exit $code"}
$reports=@(Get-ChildItem $work -Recurse -Filter '*tr_content.html' -File)
if($reports.Count -ne 1){throw 'No unique post-route STA HTML'}
$html=Get-Content $reports[0].FullName -Raw
if($html -notmatch 'Numbers of Setup Violated Endpoints</td>\s*<td>0</td>' -or
   $html -notmatch 'Numbers of Hold Violated Endpoints</td>\s*<td>0</td>'){
 Write-Host 'SD07_FIT_STA_FAIL: inspect real clock/report'
 throw 'Setup/hold violations present or missing'
}
Write-Host "SD07_FIT_REPORT: $($reports[0].FullName)"
Write-Host 'SD07_PNR_PRELIM_PASS: no setup/hold violations in summary'
Write-Host 'SD07_NOT_HARDWARE_QUALIFIED. Check full CDC and recovery/removal separately.'
Write-Host 'SD07_FIT_ONLY_DONE: no .fs retained, no programming, no SD writes.'
