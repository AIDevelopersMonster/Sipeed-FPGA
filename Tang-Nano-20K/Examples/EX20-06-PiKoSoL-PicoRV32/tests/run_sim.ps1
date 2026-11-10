# Icarus renderer smoke simulation. No Gowin IP and no FPGA programming.
[CmdletBinding()]
param(
  [string]$Iverilog = '',
  [string]$Vvp = ''
)
$ErrorActionPreference = 'Stop'

# The project used MSYS2 UCRT64 Icarus Verilog 13.0 on the 9K labs.
# Worktrees and fresh PowerShell windows may not inherit the old PATH.
function Resolve-IcarusTool {
  param([string]$Name, [string]$Explicit)
  if ($Explicit) {
    if (-not (Test-Path -LiteralPath $Explicit -PathType Leaf)) {
      throw "Specified $Name does not exist: $Explicit"
    }
    return (Resolve-Path -LiteralPath $Explicit).Path
  }
  $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  $known = "C:\msys64\ucrt64\bin\$Name.exe"
  if (Test-Path -LiteralPath $known -PathType Leaf) { return $known }
  throw "Cannot find $Name.exe. Expected C:\msys64\ucrt64\bin\$Name.exe, or supply -$Name <full-path>."
}

$Compiler = Resolve-IcarusTool -Name 'iverilog' -Explicit $Iverilog
$Runner   = Resolve-IcarusTool -Name 'vvp' -Explicit $Vvp
Write-Host "ICARUS_COMPILER=$Compiler"
Write-Host "ICARUS_RUNNER=$Runner"
# Ensure MSYS2 dependencies are discoverable for both executables.
$env:Path = "$(Split-Path -Parent $Compiler);$(Split-Path -Parent $Runner);$env:Path"

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repo = (Resolve-Path (Join-Path $root '..\..\..')).Path
$font = Join-Path $repo '01-PicoRV32\lab04\rtl\lab04_font_8x12.hex'
$cdc = Join-Path $repo '01-PicoRV32\lab04\rtl\lab04_tty_byte_cdc.v'
foreach ($source in @($font, $cdc, (Join-Path $root 'tests\tb_renderer.v'), (Join-Path $root 'rtl\pikosol20k_renderer.v'))) {
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "RTL input missing: $source" }
}
$temp = Join-Path $root 'build\icarus'
New-Item -ItemType Directory -Force -Path $temp | Out-Null
Copy-Item -LiteralPath $font -Destination (Join-Path $temp 'lab04_font_8x12.hex') -Force
Push-Location $temp
try {
  $output = Join-Path $temp 'renderer.vvp'
  if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
  & $Compiler -g2012 -s tb_renderer -o $output `
      (Join-Path $root 'tests\tb_renderer.v') `
      (Join-Path $root 'rtl\pikosol20k_renderer.v') $cdc
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $output -PathType Leaf)) {
    throw 'Icarus compile failed; no successful simulation may be claimed'
  }
  & $Runner $output
  if ($LASTEXITCODE -ne 0) { throw 'Icarus RTL simulation failed' }
} finally { Pop-Location }
