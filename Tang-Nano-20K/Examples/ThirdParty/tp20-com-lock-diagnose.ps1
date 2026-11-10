# TP20 COM24/COM25 diagnose: read-only host-side inspection. NO serial data sent,
# NO JTAG/SRAM/Flash operations, NO PLL changes, NO process termination.
# -FindOwner downloads Microsoft's signed Sysinternals Handle tool (if missing) to inspect open handles.
[CmdletBinding()]
param(
    [string[]]$Ports = @('COM24','COM25'),
    [switch]$FindOwner
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if ($PSVersionTable.PSVersion.Major -le 5) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
$evidence = Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$log = Join-Path $evidence ("TP20_COM_LOCK_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".txt")
$lines = New-Object System.Collections.Generic.List[string]
function Out([string]$s) {
    Write-Host $s
    [void]$lines.Add($s)
}
function Safe([scriptblock]$action) {
    try { & $action } catch { Out "NONFATAL: $($_.Exception.Message)" }
}
Out "TP20: Windows USB-UART diagnosis -- NO serial writes, FPGA writes, or PLL commands."
Out "TIME=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'); USER=$env:USERNAME"
Safe {
    Add-Type -AssemblyName System.IO.Ports -ErrorAction SilentlyContinue
    $found = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object)
    Out "ENUMERATED: $($found -join ', ')"
}
$devpaths = @{}
Safe {
    $reg = Get-Item -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\HARDWARE\DEVICEMAP\SERIALCOMM'
    foreach ($n in $reg.GetValueNames()) {
        $value = [string]$reg.GetValue($n)
        if ($Ports -contains $value) {
            $devpaths[$value] = $n
            Out "NT DEVICE: $value => $n"
        }
    }
}
Safe {
    foreach ($pnp in @(Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.Name -match '\(COM[0-9]+\)'
    })) {
        Out "PNP: $($pnp.Name) | $($pnp.DeviceID) | STATUS=$($pnp.Status)"
    }
}
Safe {
    $matches = @(Get-CimInstance Win32_Process |
        Where-Object {
            ($_.Name -match 'putty|tterm|moba|arduino|python|serial|jtag|programmer|gowin|openfpgaloader|terminal|code|pwsh') -or
            ($_.CommandLine -match 'COM24|COM25')
        } |
        Sort-Object ProcessId)
    if ($matches.Count -eq 0) { Out "CANDIDATE PROCESSES: (none found; this does NOT prove no locks)" }
    foreach ($x in $matches) {
        $cmd = [string]$x.CommandLine
        if ($cmd.Length -gt 220) { $cmd = $cmd.Substring(0,220) + '...' }
        Out "PROCESS PID=$($x.ProcessId) NAME=$($x.Name) CMD=$cmd"
    }
}
# Try to open and immediately close each port. Do not send any bytes.
foreach ($port in $Ports) {
    $serial = $null
    try {
        $serial = [System.IO.Ports.SerialPort]::new(
            $port,115200,[System.IO.Ports.Parity]::None,
            8,[System.IO.Ports.StopBits]::One
        )
        $serial.Handshake = [System.IO.Ports.Handshake]::None
        $serial.ReadTimeout = 300
        $serial.WriteTimeout = 300
        $serial.DtrEnable = $false
        $serial.RtsEnable = $false
        $serial.Open()
        Out "OPEN $port = PASS (immediately closed; no bytes transmitted)"
    } catch {
        Out "OPEN $port = FAIL $($_.Exception.GetType().Name): $($_.Exception.Message)"
    } finally {
        if ($null -ne $serial) {
            try { if ($serial.IsOpen) { $serial.Close() } } catch {}
            $serial.Dispose()
        }
    }
}
if ($FindOwner) {
    Safe {
        $bin = Join-Path $PSScriptRoot 'tools'
        $zip = Join-Path $bin 'Handle.zip'
        $exe = Join-Path $bin 'handle64.exe'
        New-Item -ItemType Directory -Force -Path $bin | Out-Null
        if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
            $url = 'https://download.sysinternals.com/files/Handle.zip'
            Out "GET MICROSOFT SYSINTERNALS: $url"
            Invoke-WebRequest -Uri $url -OutFile $zip -ErrorAction Stop
            Expand-Archive -LiteralPath $zip -DestinationPath $bin -Force
        }
        $sig = Get-AuthenticodeSignature -LiteralPath $exe
        Out "HANDLE SIGNATURE: $($sig.Status) SIGNER=$($sig.SignerCertificate.Subject)"
        if ($sig.Status -ne 'Valid') {
            Out "STOP: Handle executable has not passed signature validation, not executing."
        } else {
            $patterns = New-Object System.Collections.Generic.List[string]
            foreach ($p in $Ports) {
                [void]$patterns.Add($p)
                if ($devpaths.ContainsKey($p)) {
                    [void]$patterns.Add($devpaths[$p])
                }
            }
            foreach ($pattern in @($patterns | Select-Object -Unique)) {
                Out "HANDLE SEARCH: $pattern"
                $output = & $exe -accepteula -nobanner -a $pattern 2>&1
                foreach ($line in $output) { Out ([string]$line) }
            }
            Out "Handle is diagnostic only. 'No matching handles' does not prove the device is free."
        }
    }
}
$lines | Set-Content -LiteralPath $log -Encoding UTF8
Write-Host "EVIDENCE: $log"
Write-Host "NEXT: paste diagnostics. Do NOT kill processes until their purpose is identified."
