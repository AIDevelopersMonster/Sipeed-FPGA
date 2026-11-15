#Requires -Version 7.0
# Run on the original Windows test PC only, AFTER confirming the exact working FS.
# Create-only upload of one bitstream; no Releases, no flash, no rewrites.
[CmdletBinding()]
param(
    [string]$Fs = "$env:TEMP\PR25_USB_Attach_Lite02\impl\pnr\pr25_usb_attach_lite02.fs",
    [string]$Repo = 'AIDevelopersMonster/Sipeed-FPGA'
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Fs -PathType Leaf)) { throw "Local verified .fs not found: $Fs" }
if (!(Get-Command gh -ErrorAction SilentlyContinue)) { throw 'gh CLI required (gh auth login)' }
$size = (Get-Item -LiteralPath $Fs).Length
if ($size -lt 100000) { throw "Unusually small FS: $size bytes" }
$hash = (Get-FileHash -LiteralPath $Fs -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "FILE: $Fs"
Write-Host "BYTES: $size"
Write-Host "SHA256: $hash"
$confirm = Read-Host 'Is this EXACTLY the tested BOARD VIDEO PASS file? Type YES'
if ($confirm -cne 'YES') { throw 'Cancelled: no upload' }

$dst = 'Tang-Primer-25K/Examples/PR25-USB-PHYSICAL-02/fs'
function CreateOnly([string]$path,[byte[]]$bytes,[string]$msg) {
    $payload = [ordered]@{message=$msg;content=[Convert]::ToBase64String($bytes);branch='main'}
    $tmp = Join-Path $env:TEMP ("pr25_usb_put_"+[Guid]::NewGuid().ToString('N')+".json")
    try {
        [IO.File]::WriteAllText($tmp,($payload | ConvertTo-Json -Depth 3 -Compress),[Text.UTF8Encoding]::new($false))
        & gh api --method PUT -H 'Accept: application/vnd.github+json' "/repos/$Repo/contents/$dst/$path" --input $tmp | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "GitHub create-only upload failed: $path" }
        Write-Host "UPLOADED: $dst/$path"
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
CreateOnly 'pr25_usb_attach_lite02.fs' ([IO.File]::ReadAllBytes($Fs)) 'pr25: save operator-verified USB physical attach SRAM FS'
CreateOnly 'sha256.txt' ([Text.Encoding]::ASCII.GetBytes("$hash  pr25_usb_attach_lite02.fs`n")) 'pr25: record verified USB attach bitstream SHA256'
