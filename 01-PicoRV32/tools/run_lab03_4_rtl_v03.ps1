# LAB-03.4 v0.3: additive command 0 + original LAB-03.2 RTL scenarios.
# Read-only with respect to tracked/untracked source; writes only ignored build/.
# Never opens COM, runs Gowin, regenerates ROM, programs FPGA or Flash.
param(
    [string]$Evidence = "$HOME\Downloads\LAB03_3_EVIDENCE.zip",
    [string]$ExpectedRomSHA256 = '14B85BC20CE43CDF4CE09EF1DB7A20AF5677C1C728C64B71258F6C63AB5B8A3D',
    [string]$ExpectedBitstreamSHA256 = '62596847427F0258CB729A8B3C042AB7E0F39A8725990BA39A831B98C6554F13'
)
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $Evidence)) { throw "Missing hardware campaign evidence: $Evidence" }
$Evidence = (Resolve-Path -LiteralPath $Evidence).Path
foreach ($exe in @('python', 'iverilog', 'vvp')) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { throw "Required CLI not found in PATH: $exe" }
}
Push-Location $base
try {
    $rom = 'firmware/lab03_boot.hex'
    $vrom = 'rtl/lab03_boot_rom.v'
    $tb = 'tests/tb_lab03_2_uart.v'
    $cpu = 'vendor/picorv32/picorv32.v'
    $src = @(
        $rom, $vrom, $tb, $cpu,
        'rtl/uart_tx_8n1.v', 'rtl/uart_rx_8n1.v',
        'rtl/lab03_trace_capture.v', 'rtl/picorv32_soc_lab03.v',
        'tools/lab03_trace_decode.py', 'tools/lab03_4_analyze.py',
        'tools/lab03_4_compare_rtl.py',
        'tools/lab03_4_extend_tb.py', 'tools/lab03_4_compare_dual.py'
    )
    foreach ($p in $src) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Required source missing: $p" }
    }
    $before = @{}
    foreach ($p in $src) { $before[$p] = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash }
    if ($before[$rom] -ne $ExpectedRomSHA256) {
        throw "LAB-03 ROM SHA256 changed: $($before[$rom]). Expected $ExpectedRomSHA256; do NOT regenerate automatically."
    }
    $fs = 'impl/pnr/picorv32_lab03_nano9k.fs'
    if (Test-Path -LiteralPath $fs) {
        $fsHash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
        if ($fsHash -ne $ExpectedBitstreamSHA256) {
            throw "Local bitstream SHA256 mismatch: $fsHash (campaign: $ExpectedBitstreamSHA256)"
        }
    } else {
        Write-Warning 'Local .fs file absent; only campaign-declared bitstream SHA256 will be checked.'
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $session = "build/lab03_4/rtl_compare_v03/run_$stamp"
    New-Item -ItemType Directory -Force -Path $session | Out-Null
    Write-Host "LAB03_4_V03_OUTPUT_DIR: $((Resolve-Path $session).Path)"

    $hashTable = foreach ($p in $src) {
        [PSCustomObject]@{ Source = $p; SHA256 = $before[$p] }
    }
    $hashTable | Export-Csv -Path "$session/source_sha256.csv" -Encoding utf8 -NoTypeInformation
    if (Get-Command git -ErrorAction SilentlyContinue) {
        (& git rev-parse HEAD) | Out-File "$session/git_head.txt" -Encoding utf8
        (& git status --short) | Out-File "$session/git_status.txt" -Encoding utf8
    }

    $generated = "$session/tb_lab03_2_uart_v03.generated.v"
    & python tools/lab03_4_extend_tb.py --source $tb --out $generated
    if ($LASTEXITCODE -ne 0) { throw 'Could not safely derive command-0 testbench; input source was not changed.' }
    Get-FileHash -LiteralPath $generated -Algorithm SHA256 |
        Select-Object Path, Hash | Export-Csv -Path "$session/generated_tb_sha256.csv" -Encoding utf8 -NoTypeInformation

    # Old fixed filenames are used by the original testbench. Move only generated
    # outputs to a unique archive before the new simulation (never touch sources).
    New-Item -ItemType Directory -Force -Path build | Out-Null
    $fixed = @(
        'build/lab03_2_trace_4.txt',
        'build/lab03_2_trace_4_repeat.txt',
        'build/lab03_2_trace_1.txt',
        'build/lab03_4_trace_0.txt'
    )
    $old = @($fixed | Where-Object { Test-Path -LiteralPath $_ })
    if ($old.Count -gt 0) {
        $previous = "$session/previous_generated"
        New-Item -ItemType Directory -Force -Path $previous | Out-Null
        foreach ($p in $old) { Move-Item -LiteralPath $p -Destination $previous }
        Write-Host "LAB03_4_V03_PREVIOUS_RTL_SAVED: $previous"
    }

    $compileLog = "$session/iverilog.log"
    $simLog = "$session/vvp.log"
    $outVvp = "$session/lab03_4_v03.vvp"
    & iverilog -g2012 -Wall -s tb_lab03_2_uart -o $outVvp `
        $cpu $vrom `
        rtl/uart_tx_8n1.v rtl/uart_rx_8n1.v `
        rtl/lab03_trace_capture.v rtl/picorv32_soc_lab03.v $generated *> $compileLog
    if ($LASTEXITCODE -ne 0) { throw "RTL compile failed: $compileLog" }
    & vvp $outVvp *> $simLog
    if ($LASTEXITCODE -ne 0) { throw "RTL simulation failed: $simLog" }
    Get-Content $simLog | Select-Object -Last 12
    foreach ($required in @('^LAB03_2_UART_TRACE_RTL_PASS:', '^LAB03_4_ZERO_UART_TRACE_RTL_PASS:')) {
        if (-not (Select-String -Path $simLog -Pattern $required -Quiet)) {
            throw "Required RTL marker absent ($required): $simLog"
        }
    }
    foreach ($p in $fixed) {
        if (-not (Test-Path -LiteralPath $p)) { throw "RTL simulation did not generate: $p" }
    }

    # Validate actual wire-format dumps through the existing LAB-03.2 decoder.
    $checks = @(
        @{ Name = 'lab03_2_trace_4.txt'; Command = 4; File = 'rtl_4_decode.json' },
        @{ Name = 'lab03_2_trace_4_repeat.txt'; Command = 4; File = 'rtl_4_repeat_decode.json' },
        @{ Name = 'lab03_2_trace_1.txt'; Command = 1; File = 'rtl_1_decode.json' },
        @{ Name = 'lab03_4_trace_0.txt'; Command = 0; File = 'rtl_0_decode.json' }
    )
    foreach ($t in $checks) {
        $file = 'build/' + $t.Name
        & python tools/lab03_trace_decode.py $file --expected-command $t.Command --json-out "$session/$($t.File)"
        if ($LASTEXITCODE -ne 0) { throw "RTL T3 decode failed for: $file" }
        Copy-Item -LiteralPath $file -Destination $session -Force
    }
    $a = (Get-FileHash -LiteralPath 'build/lab03_2_trace_4.txt' -Algorithm SHA256).Hash
    $b = (Get-FileHash -LiteralPath 'build/lab03_2_trace_4_repeat.txt' -Algorithm SHA256).Hash
    if ($a -ne $b) { throw 'Original repeated T snapshot is not byte-identical: command 4' }

    foreach ($p in $src) {
        $after = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
        if ($after -ne $before[$p]) { throw "SOURCE MUTATED DURING RTL SIMULATION: $p" }
    }

    & python tools/lab03_4_compare_dual.py `
        --evidence $Evidence --rom $rom `
        --rtl-4 'build/lab03_2_trace_4.txt' --rtl-0 'build/lab03_4_trace_0.txt' `
        --rtl-log $simLog --out $session `
        --expect-rom-sha256 $ExpectedRomSHA256 `
        --expect-bitstream-sha256 $ExpectedBitstreamSHA256
    if ($LASTEXITCODE -ne 0) { throw "RTL vs FPGA comparison did not PASS; inspect $session/report.md" }
    Write-Host 'LAB03_4_V03_RTL_DUAL_COMMAND_PASS: 0 and 4; accepted-bus core only; NOT retirement or cycle equivalence.'
    Write-Host "LAB03_4_V03_FINAL_REPORT: $((Resolve-Path "$session/report.md").Path)"
} finally {
    Pop-Location
}
