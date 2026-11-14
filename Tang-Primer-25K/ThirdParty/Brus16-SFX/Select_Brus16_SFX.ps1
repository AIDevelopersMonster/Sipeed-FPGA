#Requires -Version 7.0
# Brus-16 sfx: switch between original Tang Primer 25K .fs images.
# Verifies the upstream ZIP SHA256 before any extraction.
# Only volatile FPGA SRAM with explicit -Program; never writes Flash.
[CmdletBinding()]
param(
    [switch]$Program,
    [string]$Game = '',
    [int]$Index = 0,
    [int]$CableIndex = 1,
    [string]$Programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedBytes = [int64]4214200
$expectedHash = 'a8c0e4e096656b89d8b74c4929abbe8d601da996e1ac6d2b1f78480a8a270e69'
$archiveUri = 'https://github.com/Papr1ka/brus16/releases/download/sfx/tp25k.zip'
$firmware = Join-Path $PSScriptRoot 'firmware'
$evidence = Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Force -Path $firmware, $evidence | Out-Null
$archive = Join-Path $firmware 'tp25k_sfx.zip'

if (!(Test-Path -LiteralPath $archive)) {
    $tmp = "$archive.part"
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    Write-Host 'Downloading original Brus-16 TP25K SFX release ZIP...'
    Invoke-WebRequest -Uri $archiveUri -OutFile $tmp
    Move-Item -LiteralPath $tmp -Destination $archive -Force
}

$len = (Get-Item -LiteralPath $archive).Length
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "ZIP size: $len bytes"
Write-Host "ZIP SHA256: $hash"
if ($len -ne $expectedBytes -or $hash -ne $expectedHash) {
    throw 'Original release archive SHA256/length mismatch. No programming allowed.'
}

Add-Type -AssemblyName System.IO.Compression.ZipFile
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
$logPath = Join-Path $evidence ('BRUS16_SELECT_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
Start-Transcript -LiteralPath $logPath | Out-Null
try {
    $files = @($zip.Entries |
        Where-Object { $_.Name.EndsWith('.fs', [StringComparison]::OrdinalIgnoreCase) } |
        Sort-Object -Property FullName)
    if ($files.Count -eq 0) {
        Write-Host 'ZIP entries:'
        foreach ($e in $zip.Entries) { Write-Host ("  {0}" -f $e.FullName) }
        throw 'No Gowin .fs files in this ZIP. Nothing to program.'
    }

    Write-Host ''
    Write-Host 'BRUS-16 ORIGINAL TP25K SFX FIRMWARES:'
    for ($i = 0; $i -lt $files.Count; $i++) {
        Write-Host ('[{0,2}] {1} ({2} bytes)' -f ($i + 1), $files[$i].FullName, $files[$i].Length)
    }
    Write-Host ''
    Write-Host 'IMPORTANT: Only Gerion is documented as having title music in the upstream game source.'
    Write-Host 'A silent Pong/Logo/Tower is NOT a proof that HDMI sound is broken.'
    Write-Host 'No SDRAM, SD-card or Flash writing is used.'
    Write-Host ''

    if (-not $Program) {
        Write-Host 'LIST ONLY. The FPGA has not been touched.'
        Write-Host 'To choose firmware interactively: .\Select_Brus16_SFX.ps1 -Program'
        Write-Host 'To load named firmware directly:  .\Select_Brus16_SFX.ps1 -Game pong -Program'
    }
    else {
        if (!(Test-Path -LiteralPath $Programmer)) {
            throw "Gowin Programmer not found: $Programmer"
        }
        $selection = $null
        if ($Index -gt 0) {
            if ($Index -gt $files.Count) { throw "Index must be between 1 and $($files.Count)." }
            $selection = @($files[$Index - 1])
        }
        elseif ($Game.Trim().Length -gt 0) {
            if ($Game -notmatch '^[A-Za-z0-9_-]+$') {
                throw 'Game must contain only letters, numbers, _ or -'
            }
            $selection = @($files | Where-Object {
                [IO.Path]::GetFileNameWithoutExtension($_.Name).Equals(
                    $Game, [StringComparison]::OrdinalIgnoreCase)
            })
            if ($selection.Count -eq 0) {
                # Exact game names are preferred; substring is only accepted if unique.
                $selection = @($files | Where-Object {
                    $_.Name.IndexOf($Game, [StringComparison]::OrdinalIgnoreCase) -ge 0
                })
            }
            if ($selection.Count -ne 1) {
                throw "Name '$Game' matches $($selection.Count) .fs files; choose -Index instead."
            }
        }

        while ($true) {
            if ($null -ne $selection) {
                $entry = $selection[0]
            }
            else {
                $choice = (Read-Host 'Enter firmware NUMBER (or Q to exit)').Trim()
                if ($choice -match '^(q|quit|exit)$' -or $choice.Length -eq 0) { break }
                $number = 0
                if (!([int]::TryParse($choice, [ref]$number)) -or
                    $number -lt 1 -or $number -gt $files.Count) {
                    Write-Host 'Invalid number; enter an index from the list.' -ForegroundColor Yellow
                    continue
                }
                $entry = $files[$number - 1]
            }

            if ($entry.Length -lt 100000 -or $entry.Length -gt 30000000) {
                throw "Unexpected .fs size $($entry.Length). Refusing to program."
            }
            # Use only the ZIP entry basename, never archive directories.
            $name = [IO.Path]::GetFileName($entry.Name)
            $fs = Join-Path $firmware $name
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $fs, $true)
            $fsHash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
            Write-Host ''
            Write-Host "SELECTED: $($entry.FullName)"
            Write-Host "SHA256: $fsHash"
            Write-Host 'PROGRAMMING: volatile FPGA SRAM (--run 2) ONLY. External Flash untouched.'
            & $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $fs
            $exitCode = $LASTEXITCODE
            if ($exitCode -ne 0) { throw "Gowin Programmer exit $exitCode" }
            Write-Host "Programmer EXIT 0: $name"
            Write-Host 'Reconnect HDMI cable if the monitor kept the previous HDMI/DVI mode.'
            $video = Read-Host 'Observed VIDEO? (yes/no/not-tested)'
            $audio = Read-Host 'Observed audible AUDIO? (yes/no/not-tested)'
            $record = [ordered]@{
                test = 'Brus16-SFX firmware selection'
                utc = (Get-Date).ToUniversalTime().ToString('o')
                release = $archiveUri
                release_sha256 = $hash
                image_entry = $entry.FullName
                image_size = $entry.Length
                image_sha256 = $fsHash
                programmer_exit = $exitCode
                video = $video
                audio = $audio
                note = 'The original A2600Nano v2.5 is the known AUDIO+VIDEO BOARD PASS baseline.'
            }
            $outName = 'BRUS16_RESULT_' + [IO.Path]::GetFileNameWithoutExtension($name) +
                '_' + (Get-Date -Format 'yyyyMMdd_HHmmssfff') + '.json'
            $outPath = Join-Path $evidence $outName
            $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outPath -Encoding utf8
            Write-Host "Result saved: $outPath"
            if ($null -ne $selection) { break }
            Write-Host ''
            Write-Host 'Select the next firmware, or Q to stop.'
        }
    }
}
finally {
    $zip.Dispose()
    Stop-Transcript | Out-Null
    Write-Host "Log saved: $logPath"
}
