# LAB-04: fetch ONLY the pinned PicoTiny HDMI RTL and Gowin clock wrappers.
# Does not clone/replace the Sipeed-FPGA repository or write to tracked paths.
# Third-party source remains under ignored 01-PicoRV32/vendor/picotiny_ref/.
param([string]$Archive = '')
$ErrorActionPreference = 'Stop'
$pin = 'c3b795799f23de91982be52db4273a8eea100cdb'
$lab = Split-Path -Parent $PSScriptRoot
$root = Split-Path -Parent $lab
$vendor = Join-Path $root 'vendor'
$dest = Join-Path $vendor 'picotiny_ref'
$required = @(
    'hw\hdmi\svo_defines.vh',
    'hw\hdmi\svo_enc.v', 'hw\hdmi\svo_hdmi_top.v',
    'hw\hdmi\svo_openldi.v', 'hw\hdmi\svo_tcard.v',
    'hw\hdmi\svo_term.v', 'hw\hdmi\svo_tmds.v',
    'hw\hdmi\svo_utils.v', 'hw\hdmi\svo_vdma.v',
    'gowin_ip\gowin_rpll\gowin_rpll.v',
    'gowin_ip\gowin_clkdiv\gowin_clkdiv.v'
)
if (Test-Path -LiteralPath $dest) {
    $pinfile = Join-Path $dest 'SOURCE_PIN.txt'
    if (-not (Test-Path -LiteralPath $pinfile) -or
        -not ((Get-Content -LiteralPath $pinfile -Raw).Contains($pin))) {
        throw "Existing vendor directory without expected provenance; NOT overwriting: $dest"
    }
    foreach ($r in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $dest $r))) {
            throw "Pinned vendor directory incomplete: $r (refusing automatic overwrite)"
        }
    }
    Write-Host "LAB04_PICOTINY_PIN_PRESENT: $pin"
    return
}
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
$temp = Join-Path ([IO.Path]::GetTempPath()) ("lab04_picotiny_" + [guid]::NewGuid().ToString('N'))
$zip = Join-Path $temp 'pinned_picotiny.zip'
$expand = Join-Path $temp 'unpack'
$stage = Join-Path $vendor ('.picotiny_pending_' + [guid]::NewGuid().ToString('N'))
try {
    foreach ($dir in @($temp, $expand, $stage)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if ($Archive) {
        if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) {
            throw "Local upstream ZIP not found: $Archive"
        }
        Copy-Item -LiteralPath $Archive -Destination $zip
    } else {
        $url = "https://codeload.github.com/sipeed/TangNano-9K-example/zip/$pin"
        Write-Host "Fetching Sipeed PicoTiny at pinned Git revision $pin ..."
        Invoke-WebRequest -Uri $url -OutFile $zip -ErrorAction Stop
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $expand -ErrorAction Stop
    $parents = @(Get-ChildItem -LiteralPath $expand -Directory)
    if ($parents.Count -ne 1) { throw 'Expected exactly one upstream archive root directory' }
    $src = Join-Path $parents[0].FullName 'picotiny'
    foreach ($r in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $src $r) -PathType Leaf)) {
            throw "Upstream pinned PicoTiny archive missing: $r"
        }
    }
    foreach ($dir in @((Join-Path $stage 'hw'), (Join-Path $stage 'gowin_ip'))) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Copy-Item -LiteralPath (Join-Path $src 'hw\hdmi') -Destination (Join-Path $stage 'hw') -Recurse
    Copy-Item -LiteralPath (Join-Path $src 'gowin_ip\gowin_rpll') -Destination (Join-Path $stage 'gowin_ip') -Recurse
    Copy-Item -LiteralPath (Join-Path $src 'gowin_ip\gowin_clkdiv') -Destination (Join-Path $stage 'gowin_ip') -Recurse
    $source = "Sipeed TangNano-9K-example / picotiny`nRevision: $pin`n" +
        "URL: https://github.com/sipeed/TangNano-9K-example/tree/$pin/picotiny`n" +
        "Licenses/notices: retain original upstream headers in every sourced file.`n"
    [IO.File]::WriteAllText((Join-Path $stage 'SOURCE_PIN.txt'),$source,[Text.UTF8Encoding]::new($false))
    $hashes = foreach ($r in $required) {
        $item = Join-Path $stage $r
        $hash = (Get-FileHash -LiteralPath $item -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $($r.Replace('\','/'))"
    }
    [IO.File]::WriteAllLines((Join-Path $stage 'SOURCE_SHA256.txt'),[string[]]$hashes,[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $stage -Destination $dest
    Write-Host "LAB04_PICOTINY_PINNED_FETCH_PASS: $dest; revision=$pin; files=$($required.Count)"
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
