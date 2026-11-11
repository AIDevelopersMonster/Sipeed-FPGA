# LAB-03.4 v0.2: read-only source RTL simulation + offline hardware trace comparison.
# Does NOT assemble sources, open COM ports, program FPGA, or write Flash.
param(
    [string]$Evidence = "$HOME\Downloads\LAB03_3_EVIDENCE.zip",
    [string]$ExpectedRomSHA256 = '14B85BC20CE43CDF4CE09EF1DB7A20AF5677C1C728C64B71258F6C63AB5B8A3D',
    [string]$ExpectedBitstreamSHA256 = '62596847427F0258CB729A8B3C042AB7E0F39A8725990BA39A831B98C6554F13'
)
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $Evidence)) { throw "Missing evidence: $Evidence" }
$Evidence = (Resolve-Path -LiteralPath $Evidence).Path
foreach ($exe in @('python', 'iverilog', 'vvp')) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { throw "Missing tool in PATH: $exe" }
}
Push-Location $base
try {
    $rom = 'firmware/lab03_boot.hex'
    $vrom = 'rtl/lab03_boot_rom.v'
    $cpu = 'vendor/picorv32/picorv32.v'
    foreach ($p in @($rom, $vrom, $cpu,
        'rtl/uart_tx_8n1.v', 'rtl/uart_rx_8n1.v', 'rtl/lab03_trace_capture.v',
        'rtl/picorv32_soc_lab03.v', 'tests/tb_lab03_2_uart.v',
        'tools/lab03_4_analyze.py', 'tools/lab03_4_compare_rtl.py',
        'tools/lab03_trace_decode.py')) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Missing source: $p" }
    }
    $hashBefore = @{}
    foreach ($p in @($rom, $vrom)) { $hashBefore[$p] = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash }
    if ($hashBefore[$rom] -ne $ExpectedRomSHA256) {
        throw "Unexpected ROM hash $($hashBefore[$rom]); expected $ExpectedRomSHA256. Do not regenerate. Check version."
    }
    $fs = 'impl/pnr/picorv32_lab03_nano9k.fs'
    if (Test-Path -LiteralPath $fs) {
        if ((Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash -ne $ExpectedBitstreamSHA256) {
            throw 'Local bitstream differs from the board campaign SHA256.'
        }
    }
    $prov = 'build/lab03_4/rtl_compare_4'
    New-Item -ItemType Directory -Force -Path $prov | Out-Null
    $sourceFiles = @($rom, $vrom, $cpu, 'rtl/uart_tx_8n1.v', 'rtl/uart_rx_8n1.v', `
        'rtl/lab03_trace_capture.v', 'rtl/picorv32_soc_lab03.v', 'tests/tb_lab03_2_uart.v')
    Get-FileHash -Path $sourceFiles -Algorithm SHA256 |
        Select-Object Path, Hash | Export-Csv -NoTypeInformation -Encoding utf8 -Path "$prov/rtl_inputs_sha256.csv"
    if (Get-Command git -ErrorAction SilentlyContinue) {
        (& git rev-parse HEAD) | Out-File "$prov/git_head.txt" -Encoding utf8
        (& git status --short) | Out-File "$prov/git_status.txt" -Encoding utf8
    }
    New-Item -ItemType Directory -Force -Path build | Out-Null
    # The existing LAB-03.2 testbench writes fixed output filenames. Preserve older dumps.
    $prior = @('build/lab03_2_trace_4.txt', 'build/lab03_2_trace_4_repeat.txt', `
        'build/lab03_2_trace_1.txt', 'build/lab03_4_v02_iverilog.log', 'build/lab03_4_v02_vvp.log') |
        Where-Object { Test-Path -LiteralPath $_ }
    if ($prior.Count -gt 0) {
        $backup = 'build/lab03_4/previous_rtl_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff')
        New-Item -ItemType Directory -Force -Path $backup | Out-Null
        foreach ($p in $prior) { Copy-Item -LiteralPath $p -Destination $backup }
        Write-Host "Previous RTL artifacts backed up: $backup"
    }
    $rtlLog = 'build/lab03_4_v02_iverilog.log'
    $simLog = 'build/lab03_4_v02_vvp.log'
    & iverilog -g2012 -Wall -s tb_lab03_2_uart -o build/lab03_4_v02_uart.vvp `
        $cpu $vrom `
        rtl/uart_tx_8n1.v rtl/uart_rx_8n1.v `
        rtl/lab03_trace_capture.v rtl/picorv32_soc_lab03.v tests/tb_lab03_2_uart.v *> $rtlLog
    if ($LASTEXITCODE -ne 0) { throw "Icarus compile failed. See $rtlLog" }
    & vvp build/lab03_4_v02_uart.vvp *> $simLog
    if ($LASTEXITCODE -ne 0) { throw "Icarus simulation failed. See $simLog" }
    Get-Content $simLog | Select-Object -Last 10
    if (-not (Select-String -Path $simLog -Pattern '^LAB03_2_UART_TRACE_RTL_PASS:' -Quiet)) {
        throw "Expected RTL PASS marker absent: $simLog"
    }
    foreach ($generated in @('build/lab03_2_trace_4.txt', `
        'build/lab03_2_trace_4_repeat.txt', 'build/lab03_2_trace_1.txt')) {
        if (-not (Test-Path -LiteralPath $generated)) { throw "Simulation failed to produce: $generated" }
        Copy-Item -LiteralPath $generated -Destination $prov -Force
    }
    Copy-Item -LiteralPath $simLog -Destination $prov -Force
    Copy-Item -LiteralPath $rtlLog -Destination $prov -Force
    foreach ($p in @($rom, $vrom)) {
        if ((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne $hashBefore[$p]) {
            throw "SOURCE MUTATED DURING TEST: $p"
        }
    }
    & python tools/lab03_trace_decode.py build/lab03_2_trace_4.txt --expected-command 4 `
        --json-out build/lab03_4_v02_rtl_4.json
    if ($LASTEXITCODE -ne 0) { throw 'RTL trace decoder failed.' }
    & python tools/lab03_4_compare_rtl.py `
        --evidence $Evidence --rom $rom --rtl build/lab03_2_trace_4.txt --rtl-log $simLog `
        --expect-rom-sha256 $ExpectedRomSHA256 `
        --expect-bitstream-sha256 $ExpectedBitstreamSHA256 `
        --out build/lab03_4/rtl_compare_4
    if ($LASTEXITCODE -ne 0) { throw 'RTL vs board comparison did not PASS. See build/lab03_4/rtl_compare_4/report.md' }
    Write-Host 'LAB03_4_RTL_BUS_TRACE_CORE_EQUIVALENCE_PASS: command 4, bus signatures only; NOT instruction retirement / cycle match.'
} finally {
    Pop-Location
}
