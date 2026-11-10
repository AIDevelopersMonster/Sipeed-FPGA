# TP20-01: configure the Nano 20K MS5351 for nano-Z80 WITHOUT persistent save.
# VERSION 2.1 (2026-11-11): tolerant clock status parsing and corrected S2 reset guidance.
# Requires an existing nano-Z80 FPGA SRAM image and access to BL616 at COM25.
# Safe default: read-only. Explicit -Apply sets O0/O1 temporarily.
# NEVER sends pll_clk -s, never writes FPGA configuration Flash and never programs bitstream.
[CmdletBinding()]
param(
    [string]$Port = 'COM25',
    [int]$Baud = 115200,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
$evidence = Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path $evidence "TP20_PLL_ENABLE_$stamp.txt"
$transcript = New-Object System.Collections.Generic.List[string]
function Log([string]$s) {
    Write-Host $s
    [void]$transcript.Add($s)
}
function Read-Response([System.IO.Ports.SerialPort]$Serial,[int]$Ms,[string]$Label) {
    $b = [System.Text.StringBuilder]::new()
    $steps = [Math]::Max(1, [int][Math]::Ceiling($Ms / 100))
    for ($i=0;$i -lt $steps;$i++) {
        Start-Sleep -Milliseconds 100
        [void]$b.Append($Serial.ReadExisting())
    }
    $response = $b.ToString()
    Log "[$Label]"
    if ($response.Length -gt 0) {
        Log $response
    } else {
        Log "(no response)"
    }
    return $response
}
function Send-Line([System.IO.Ports.SerialPort]$Serial,[string]$Line,[int]$Ms = 1100) {
    Log "TX: $Line"
    $Serial.Write($Line + [char]13)
    return (Read-Response $Serial $Ms $Line)
}
Log "== TP20-01 MS5351 configuration v2.1 =="
Log "PORT=$Port BAUD=$Baud APPLY=$Apply"
Log "O0 TARGET: 25175000 Hz / pin 10; O1 TARGET: 12000000 Hz / pin 11"
Log "NO -s; no BL616 config save; no FPGA flash program."
$serial = $null
$enteredShell = $false
$success = $false
try {
    Add-Type -AssemblyName System.IO.Ports -ErrorAction SilentlyContinue
    $serial = [System.IO.Ports.SerialPort]::new($Port,$Baud,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
    $serial.Handshake = [System.IO.Ports.Handshake]::None
    $serial.DtrEnable = $false
    $serial.RtsEnable = $false
    $serial.ReadTimeout = 600
    $serial.WriteTimeout = 600
    $serial.Open()
    Log "SERIAL OPEN: PASS"
    $initial = Send-Line $serial '' 650
    if ($initial -notmatch 'TangNano20K\s*/>') {
        Log "Trying BL616 escape: Ctrl+X, Ctrl+C, Enter"
        $serial.Write([byte[]](0x18),0,1)
        Start-Sleep -Milliseconds 120
        $serial.Write([byte[]](0x03),0,1)
        Start-Sleep -Milliseconds 120
        $serial.Write([byte[]](0x0D),0,1)
        $initial = Read-Response $serial 1100 'BL616 SHELL'
    }
    if ($initial -notmatch 'TangNano20K\s*/>') { throw "No BL616 prompt found. No PLL modifications attempted. Check port and BL616 shell." }
    $enteredShell = $true
    $before = Send-Line $serial 'pll_clk' 1400
    if ($before -notmatch 'Curr States:') { throw "Could not read PLL current states. No PLL modifications attempted." }
    Log "PLL STATE BEFORE: parsed successfully."
    if (-not $Apply) {
        Log "READ ONLY COMPLETE. Use -Apply to set O0/O1 temporarily after reviewing current state."
        $success = $true
    } else {
        Log "SAFETY: commands will change clock outputs temporarily. No persistent -s."
        $answer = Read-Host 'Type exactly CLOCKS to enable O0=25.175MHz and O1=12MHz'
        if ($answer -cne 'CLOCKS') { throw "Cancelled by operator; no PLL modifications attempted." }
        $null = Send-Line $serial 'pll_clk O0=25175K' 1300
        $null = Send-Line $serial 'pll_clk O1=12M' 1300
        $after = Send-Line $serial 'pll_clk' 1600
        # Parse the exact response to the final pll_clk query, not pre-change state.
        # BL616 prints "[ EN]O0: 25175000", including a space after "[".
        $afterText = ($after | Out-String)
        $afterLines = $afterText -split "[\r\n]+"
        $o0ok = $false
        $o1ok = $false
        foreach ($line in $afterLines) {
            $lineClean = [regex]::Replace($line, '\x1b\[[0-9;]*[A-Za-z]', '').Trim()
            if ($lineClean -match '^\[\s*EN\s*\]\s*O0:\s*25175000\s*
        Log "VERIFY O0=25.175MHz ENABLED: $o0ok"
        Log "VERIFY O1=12MHz ENABLED: $o1ok"
        if (-not ($o0ok -and $o1ok)) {
            throw "PLL verification did not show both enabled output frequencies. Inspect log before doing anything else."
        }
        Log "TP20 PLL VOLATILE PASS. Now returning BL616 serial bridge to FPGA."
        $success = $true
    }
} catch {
    Log "ERROR: $($_.Exception.GetType().Name): $($_.Exception.Message)"
    $success = $false
} finally {
    if ($null -ne $serial) {
        if ($serial.IsOpen) {
            if ($enteredShell) {
                try {
                    $null = Send-Line $serial 'choose uart' 950
                    Log "Requested BL616 -> FPGA UART bridge (choose uart)."
                } catch {
                    Log "WARNING: choose uart failed. Restore bridge manually via BL616 shell."
                    $success = $false
                }
            }
            $serial.Close()
        }
        $serial.Dispose()
    }
    $transcript | Set-Content -LiteralPath $log -Encoding UTF8
    Write-Host "EVIDENCE: $log"
}
if (-not $success) { throw "TP20 PLL diagnostic/configuration incomplete; see $log" }
if ($Apply) {
    Write-Host "PLL outputs verified. FPGA SRAM image was not reprogrammed."
    Write-Host "NEXT: press/release physical S2 RESET (board-verified) (NOT USB power-cycle),"
    Write-Host "then open COM25 115200 8N1 and look for 'nano-Z80 monitor v0.3' on UART/HDMI."
    Write-Host "If there is no monitor, re-run Gowin SRAM Program; do not write Flash."
}
) { $o0ok = $true }
            if ($lineClean -match '^\[\s*EN\s*\]\s*O1:\s*12000000\s*
        Log "VERIFY O0=25.175MHz ENABLED: $o0ok"
        Log "VERIFY O1=12MHz ENABLED: $o1ok"
        if (-not ($o0ok -and $o1ok)) {
            throw "PLL verification did not show both enabled output frequencies. Inspect log before doing anything else."
        }
        Log "TP20 PLL VOLATILE PASS. Now returning BL616 serial bridge to FPGA."
        $success = $true
    }
} catch {
    Log "ERROR: $($_.Exception.GetType().Name): $($_.Exception.Message)"
    $success = $false
} finally {
    if ($null -ne $serial) {
        if ($serial.IsOpen) {
            if ($enteredShell) {
                try {
                    $null = Send-Line $serial 'choose uart' 950
                    Log "Requested BL616 -> FPGA UART bridge (choose uart)."
                } catch {
                    Log "WARNING: choose uart failed. Restore bridge manually via BL616 shell."
                    $success = $false
                }
            }
            $serial.Close()
        }
        $serial.Dispose()
    }
    $transcript | Set-Content -LiteralPath $log -Encoding UTF8
    Write-Host "EVIDENCE: $log"
}
if (-not $success) { throw "TP20 PLL diagnostic/configuration incomplete; see $log" }
if ($Apply) {
    Write-Host "PLL outputs verified. FPGA SRAM image was not reprogrammed."
    Write-Host "NEXT: press/release physical S1 RESET on the board (NOT USB power-cycle),"
    Write-Host "then open COM25 115200 8N1 and look for 'nano-Z80 monitor v0.3' on UART/HDMI."
    Write-Host "If there is no monitor, re-run Gowin SRAM Program; do not write Flash."
}
) { $o1ok = $true }
        }
        Log 'VERIFY FORMAT: supports [ EN] and [EN] clock status lines.'
        Log "VERIFY O0=25.175MHz ENABLED: $o0ok"
        Log "VERIFY O1=12MHz ENABLED: $o1ok"
        if (-not ($o0ok -and $o1ok)) {
            throw "PLL verification did not show both enabled output frequencies. Inspect log before doing anything else."
        }
        Log "TP20 PLL VOLATILE PASS. Now returning BL616 serial bridge to FPGA."
        $success = $true
    }
} catch {
    Log "ERROR: $($_.Exception.GetType().Name): $($_.Exception.Message)"
    $success = $false
} finally {
    if ($null -ne $serial) {
        if ($serial.IsOpen) {
            if ($enteredShell) {
                try {
                    $null = Send-Line $serial 'choose uart' 950
                    Log "Requested BL616 -> FPGA UART bridge (choose uart)."
                } catch {
                    Log "WARNING: choose uart failed. Restore bridge manually via BL616 shell."
                    $success = $false
                }
            }
            $serial.Close()
        }
        $serial.Dispose()
    }
    $transcript | Set-Content -LiteralPath $log -Encoding UTF8
    Write-Host "EVIDENCE: $log"
}
if (-not $success) { throw "TP20 PLL diagnostic/configuration incomplete; see $log" }
if ($Apply) {
    Write-Host "PLL outputs verified. FPGA SRAM image was not reprogrammed."
    Write-Host "NEXT: press/release physical S1 RESET on the board (NOT USB power-cycle),"
    Write-Host "then open COM25 115200 8N1 and look for 'nano-Z80 monitor v0.3' on UART/HDMI."
    Write-Host "If there is no monitor, re-run Gowin SRAM Program; do not write Flash."
}
