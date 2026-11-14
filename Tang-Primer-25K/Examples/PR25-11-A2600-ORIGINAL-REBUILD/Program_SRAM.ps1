#Requires -Version 7.0
# A/B program A2600Nano v2.5 original release or rebuild. SRAM only.
[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateSet('Golden','Rebuilt')][string]$Variant,
 [int]$CableIndex=1,
 [string]$Programmer='C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$art=Join-Path $PSScriptRoot 'artifacts'
$ev=Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Force -Path $art,$ev | Out-Null
if (!(Test-Path -LiteralPath $Programmer)){throw "Missing Programmer: $Programmer"}
$goldenSha='531b786061cc3b428d829e9f445787d20c6f847645031e3a0a57f64d58ba4aff'
if ($Variant -eq 'Golden') {
    $fs=Join-Path $art 'a2600nano_tp25k_GOLDEN.fs'
    if (!(Test-Path -LiteralPath $fs)){
        $tmp=$fs+'.part'
        if (Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Force}
        Invoke-WebRequest -Uri 'https://github.com/MiSTle-Dev/A2600Nano/releases/download/v2.5/a2600nano_tp25k.fs' -OutFile $tmp
        Move-Item -LiteralPath $tmp -Destination $fs -Force
    }
    $size=(Get-Item -LiteralPath $fs).Length
    $hash=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($size -ne 4700888 -or $hash -ne $goldenSha){
        throw 'GOLDEN .fs does not match official GitHub Release SHA256 and size'
    }
}
else {
    $fs=Join-Path $art 'a2600nano_tp25k_REBUILT.fs'
    $manifestPath=Join-Path $art 'rebuild_manifest.json'
    if (!(Test-Path -LiteralPath $manifestPath)){throw 'Run Build_Original.ps1 first'}
    $m=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($m.status -ne 'BUILD_PASS_NOT_BOARD_TESTED' -or
        $m.source_commit -ne '705bf787675579721d339806cb522905dec73ed3'){
        throw 'Unverified or failed build manifest: cannot program Rebuilt'
    }
    if (!(Test-Path -LiteralPath $fs)){throw 'Missing rebuilt bitstream'}
    $size=(Get-Item -LiteralPath $fs).Length
    $hash=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($size -ne [int64]$m.bitstream_size -or $hash -ne [string]$m.bitstream_sha256){
        throw 'Rebuilt bitstream differs from build manifest'
    }
}
$log=Join-Path $ev ('PR25_11_SRAM_'+$Variant+'_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff')+'.txt')
Start-Transcript -LiteralPath $log | Out-Null
try {
    Write-Host "Variant: $Variant"
    Write-Host "FS: $fs"
    Write-Host "Length: $size"
    Write-Host "SHA256: $hash"
    Write-Host 'Volatile FPGA SRAM --run 2. NO FLASH WRITES.'
    Write-Host ('GW5A-25A cable {0}' -f $CableIndex)
    & $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $fs
    $code=$LASTEXITCODE
    Write-Host "SRAM PROGRAM EXIT: $code"
    if ($code -ne 0){throw "Gowin Programmer failed: $code"}
    Write-Host 'Observe VIDEO and audible AUDIO on SAME cable/monitor/game/MCU configuration.'
    Write-Host 'Software programming EXIT 0 is NOT audio BOARD PASS.'
}
finally {
    Stop-Transcript | Out-Null
    Write-Host "Evidence: $log"
}
