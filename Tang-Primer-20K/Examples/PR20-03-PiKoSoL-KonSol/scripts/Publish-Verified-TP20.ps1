#requires -Version 7.0
<#
One-time publication of the exact BOARD-tested PiKoSoL TP20 package.
Reads the operator's LOCAL files. GitHub main only; no releases, no Flash.
Requires: git, gh (authenticated), python.
#>
[CmdletBinding()]
param(
    [string]$Repository = 'AIDevelopersMonster/Sipeed-FPGA',
    [string]$Baseline = "$env:USERPROFILE\Downloads\TP20_PiKoSoL_PicoRV32_UART_HDMI_TEST",
    [string]$Manager = "$env:USERPROFILE\Downloads\PiKoSoL_TP20_FileManager_CANDIDATE_v0.1.4"
)
$ErrorActionPreference = 'Stop'
$relRoot = 'Tang-Primer-20K/Examples/PR20-03-PiKoSoL-KonSol'
$fsBlob = '5bb54a84311a62e1b0aadd11671c399561838b24'
$monitorSha = '414d8b9859ce95826e9a0ba12a26e820af2942cd4fd964ea9ff75ac28ae135c7'
$demoSha = 'be20fb6ec6d1c7bfe1e9591f0c734649c61d200217f5ebf15800b4f4e681de26'
$appHashes = [ordered]@{
    'TP20_HDMI_GRID.bin'            = '44aef01cd15bc6bd2dcf874d4077479d8df34d88d767c13a85360d917532cf4a'
    'TP20_HDMI_COLOR16.bin'         = '70966589f8a7736e894404345e69268eb010247264901819910a5d3b2ef8abf4'
    'TP20_LCD_20X4_PREVIEW.bin'     = '9491e7993b6cce427725d356c63576ec0bc94e1737b3e7bce269be8a473f7011'
    'TP20_RGB_WS2812_PREVIEW.bin'   = '40c94a636c6777b3f9e287542765fc3e04f9715e58bbdf776aca774e79f6a124'
    'TP20_AUDIO_PT8211_PREVIEW.bin' = 'ef503d25ff03119ee5f34ce1d0569e2182bc553ce2140c46111b42d5505d6e70'
}
function Need-File([string]$file) {
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "MISSING FILE: $file" }
}
function Check-Hash([string]$file, [long]$bytes, [string]$sha) {
    Need-File $file
    $item = Get-Item -LiteralPath $file
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($item.Length -ne $bytes -or $actual -ne $sha) {
        throw "FILE HASH/SIZE MISMATCH: $file actual=$actual bytes=$($item.Length)"
    }
    Write-Host "SHA256 PASS: $($item.Name)" -ForegroundColor Green
}
foreach ($tool in @('git', 'gh', 'python')) {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Install $tool first" }
}
$fpga = Join-Path $Baseline 'tp20k_System_picorv32.fs'
$monitor = Join-Path $Baseline 'firmware/monitor.bin'
$demo = Join-Path $Baseline 'firmware/demo.bin'
$hostTool = Join-Path $Baseline 'tools/host_console.py'
$runScript = Join-Path $Baseline 'TP20_PiKoSoL_Run.ps1'
Need-File $fpga
if ((Get-Item $fpga).Length -ne 7262004) { throw 'Unexpected FPGA .fs size' }
$actualBlob = ((& git hash-object --no-filters $fpga) | Select-Object -First 1).Trim()
if ($LASTEXITCODE -ne 0 -or $actualBlob -ne $fsBlob) {
    throw "Working FPGA .fs Git blob mismatch: $actualBlob"
}
Write-Host "FPGA FS GIT SHA1 PASS: $actualBlob" -ForegroundColor Green
Check-Hash $monitor 18560 $monitorSha
Check-Hash $demo 1292 $demoSha
Need-File $hostTool
Need-File $runScript
$managerMain = Join-Path $Manager 'PiKoSoL_FileManager.py'
Check-Hash $managerMain 45281 '4148e0902ad4ec423537eeb7b94924bd0d8bacaa88eaab943693096d48c2c05d'
foreach ($item in $appHashes.GetEnumerator()) {
    $file = Join-Path $Manager ("generated/" + $item.Key)
    Need-File $file
    $data = [IO.File]::ReadAllBytes($file)
    Check-Hash $file $data.Length $item.Value
    if ([BitConverter]::ToUInt32($data, 0) -ne 0x31444B50 -or
        [BitConverter]::ToUInt32($data, 4) -ne $data.Length -or
        [BitConverter]::ToUInt32($data, 8) -ne 0x2000C010 -or
        [BitConverter]::ToUInt32($data, 12) -ne 0 -or
        ([math]::Ceiling($data.Length / 128.0) * 128) -gt 0x3000) {
        throw "Wrong PKD1 header: $file"
    }
}
& python $managerMain --check-apps
if ($LASTEXITCODE -ne 0) { throw 'FileManager offline APP ABI check failed' }
Write-Host 'VERIFIED LOCAL FILES; cloning GitHub into an isolated temp folder.' -ForegroundColor Cyan
$clone = Join-Path $env:TEMP ('TP20_GITHUB_PUBLISH_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
& gh repo clone $Repository $clone -- --depth 1
if ($LASTEXITCODE -ne 0) { throw 'gh repo clone failed; try gh auth status' }
$dstRoot = Join-Path $clone $relRoot
$inventory = [Collections.Generic.List[string]]::new()
function Add-Package([string]$source, [string]$relative) {
    Need-File $source
    $dst = Join-Path $dstRoot $relative
    $parent = Split-Path -Parent $dst
    if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item -LiteralPath $source -Destination $dst -Force
    $inventory.Add($relative.Replace('\','/'))
}
Add-Package $fpga 'firmware/tp20k_System_picorv32.fs'
Add-Package $monitor 'firmware/monitor.bin'
Add-Package $demo 'firmware/demo.bin'
Add-Package $hostTool 'tools/host_console.py'
Add-Package $runScript 'TP20_PiKoSoL_Run.ps1'
$managerFiles = @(
    'AUDIT_HEADERS.cmd', 'PiKoSoL_FileManager.py', 'README_RU.md',
    'START_PiKoSoL_FileManager.cmd', 'build_hello_rv32i.py',
    'build_tp20_apps.py', 'pikosol_catalog.py', 'pikosol_core.py',
    'pikosol_xmodem.py', 'generated/SHA256SUMS.txt',
    'tests/test_abi_v014.py', 'tests/test_catalog.py',
    'tests/test_offline.py', 'tests/test_protocol.py'
)
foreach ($relative in $managerFiles) {
    Add-Package (Join-Path $Manager $relative) ('FileManager/' + $relative)
}
foreach ($name in $appHashes.Keys) {
    Add-Package (Join-Path $Manager ('generated/' + $name)) ('FileManager/generated/' + $name)
}
$license = Join-Path $dstRoot 'firmware/LICENSE_THLN33.txt'
$sourceLicense = 'https://raw.githubusercontent.com/THLN33/System_picoRV32/d3e24d9176c9361cb583111775f39a9a08cabf52/LICENSE'
Invoke-WebRequest -Uri $sourceLicense -OutFile $license -TimeoutSec 60
Need-File $license
$inventory.Add('firmware/LICENSE_THLN33.txt')
$notes = @'
# PiKoSoL TP20 — verified working files

Board: Tang Primer 20K Dock, GW2A-18C, PicoRV32 RV32I, HDMI, COM10 115200 8N1.
FPGA .fs source: THLN33/System_picoRV32 at commit d3e24d9176c9361cb583111775f39a9a08cabf52 (MIT).
Verified FPGA Git blob SHA1: 5bb54a84311a62e1b0aadd11671c399561838b24.
FPGA image programmed to SRAM only; no Flash.

Board results: original bitstream SRAM PASS; monitor XMODEM-CRC 145/145 ACK;
demo.bin RUN -> RULE30 checksum 0xD2A3C779 -> returned to PiKoSoL;
Live Keyboard typed directly on HDMI; operator reported File Manager v0.1.4
and custom PKD1 applications working (2026-11-20).
Individual video screenshots/logs of each new app are not included.

Apps named LCD_20X4_PREVIEW, RGB_WS2812_PREVIEW and AUDIO_PT8211_PREVIEW
display previews on HDMI. They DO NOT drive external LCD, WS2812 or PT8211.
This is a bare-metal PicoRV32 computer, not a standalone filesystem.
Use scripts/Sync-PiKoSoL-From-GitHub.ps1 to download/verify the exact files.

No untested candidate versions, GitHub Release, branch or tag.
'@
$notesFile = Join-Path $dstRoot 'BOARD_PASS_FILES.md'
[IO.File]::WriteAllText($notesFile, $notes, [Text.UTF8Encoding]::new($false))
$inventory.Add('BOARD_PASS_FILES.md')
$entries = @(
    foreach ($rel in ($inventory | Sort-Object -Unique)) {
        $file = Join-Path $dstRoot $rel
        $item = Get-Item -LiteralPath $file
        [ordered]@{
            path = $rel
            bytes = [long]$item.Length
            sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
)
$manifest = [ordered]@{
    schema = 1
    project = 'PiKoSoL TP20 / Tang Primer 20K Dock'
    fpga_git_blob_sha1 = $fsBlob
    app_abi = 'PKD1 / RV32I / entry 0x2000C010'
    files = $entries
}
$manifestFile = Join-Path $dstRoot 'working-manifest.json'
[IO.File]::WriteAllText($manifestFile, ($manifest | ConvertTo-Json -Depth 6) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Write-Host ("MANIFEST COMPLETE: {0} files" -f $entries.Count) -ForegroundColor Green
# The repository .gitignore intentionally ignores *.fs and *.bin.
# Force-add ONLY the exact allowlisted, hashed files copied above.
foreach ($rel in $inventory) {
    $repoPath = ($relRoot + '/' + $rel).Replace('\\','/')
    & git -C $clone add -f -- $repoPath
    if ($LASTEXITCODE -ne 0) { throw "git add failed: $repoPath" }
}
& git -C $clone add -- ($relRoot + '/working-manifest.json')
if ($LASTEXITCODE -ne 0) { throw 'git add manifest failed' }
& git -C $clone diff --cached --quiet -- $relRoot
if ($LASTEXITCODE -eq 0) {
    Write-Host 'Identical files already on GitHub; no commit necessary.' -ForegroundColor Green
    exit 0
}
if ($LASTEXITCODE -ne 1) { throw 'git diff failed' }
& git -C $clone -c user.name=AIDevelopersMonster -c user.email=182814026+AIDevelopersMonster@users.noreply.github.com commit -m 'PR20-03: store working FPGA bitstream, monitor, File Manager and RV32I apps'
if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
& git -C $clone push origin HEAD:main
if ($LASTEXITCODE -ne 0) { throw "git push failed; temporary checkout retained at $clone" }
Write-Host 'GITHUB PUSH PASS: real working files uploaded; no release or FPGA programming.' -ForegroundColor Green
Write-Host ("https://github.com/" + $Repository + "/tree/main/" + $relRoot)
