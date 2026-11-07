# Offline regression for the real functions in upload.ps1.
# Never opens COM port, never writes FPGA memory, never boots the CPU.
$ErrorActionPreference = 'Stop'
$loader = Join-Path $PSScriptRoot 'upload.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($loader, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw "PowerShell parser error(s): $($errors -join '; ')" }
foreach ($functionName in @('Remove-LiteXAnsi', 'Read-Until', 'Verify-Chunk')) {
  $node = $ast.Find({
    param($n)
    ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($n.Name -eq $functionName)
  }, $true)
  if ($null -eq $node) { throw "Loader function not found: $functionName" }
  . ([scriptblock]::Create($node.Extent.Text))
}
$esc = [char]27
$raw = "`r`n${esc}[92;1mlitex${esc}[0m> "
$plain = Remove-LiteXAnsi -RawText $raw
if (-not $plain.Contains('litex>')) { throw 'FAIL: colored PROMPT normalization' }
if ($plain.Contains([string]$esc)) { throw 'FAIL: ESC remains after normalization' }
$chunks = [System.Collections.Generic.Queue[string]]::new()
foreach ($part in @("`r`n${esc}[92", ';1mlit', 'ex', "${esc}[0m", '> ')) { $chunks.Enqueue($part) }
$script:Port = [pscustomobject]@{ Chunks = $chunks }
$script:Port | Add-Member -MemberType ScriptMethod -Name ReadExisting -Value {
  if ($this.Chunks.Count -gt 0) { return $this.Chunks.Dequeue() }
  return ''
}
$prompt = Read-Until 'litex>' 800
if (-not $prompt.Contains('litex>')) { throw 'FAIL: prompt not found across ANSI chunks' }
if ($prompt.Contains([string]$esc)) { throw 'FAIL: escape bytes leaked to normalized transcript' }
Write-Host 'PASS: byte-stream ANSI colored LiteX prompt recognized across 5 chunks.'

# Verify real Verify-Chunk function against synthetic BIOS dump, with a negative control.
$script:LoadAddress = 0x40010000L
$script:Image = [byte[]](0..15)
$script:FakeReadback = '0x40010000  ' + (($script:Image | ForEach-Object { '{0:X2}' -f $_ }) -join ' ') + '   ........' + "`r`n"
function Invoke-Bios([string]$Command) {
  if ($Command -ne 'mem_read 0x40010000 16') { throw "Unexpected BIOS command in test: $Command" }
  return "Memory dump:`r`n" + $script:FakeReadback + "`r`n${esc}[92;1mlitex${esc}[0m> "
}
Verify-Chunk 0 16
Write-Host 'PASS: 16-byte SDRAM dump readback parsed and verified.'
$script:FakeReadback = $script:FakeReadback.Replace('00 01 02', 'FF 01 02')
$rejected = $false
try { Verify-Chunk 0 16 } catch { $rejected = $_.Exception.Message -match 'READBACK MISMATCH' }
if (-not $rejected) { throw 'FAIL: mismatch not rejected by Verify-Chunk' }
Write-Host 'PASS: corrupt readback rejected before boot.'
Write-Host 'PASS: uploader regression completed without serial access or writes.'