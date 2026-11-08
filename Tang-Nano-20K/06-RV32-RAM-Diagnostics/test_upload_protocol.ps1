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
  # The early synthetic test uses a single fixed 16-byte read.
  # Later fixtures also exercise the last 4-byte block at 0x400102E0.
  # Validate the actual requested command against the fixture's expected command,
  # not against the early test's fixed address.
  if ($null -ne $script:FakeResponse) {
    if ($Command -ne $script:ExpectedCommand) {
      throw "Unexpected BIOS command in test: $Command (expected: $script:ExpectedCommand)"
    }
    return $script:FakeResponse
  }
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

# Actual flattened board output observed after 185 uploaded words.
$script:Image = [System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'snapshot.bin'))
$script:ExpectedCommand = 'mem_read 0x40010000 16'
$script:FakeResponse = 'mem_read 0x40010000 16 Memory dump: 0x40010000  37 34 00 f0 b7 14 01 40 b7 02 10 00 93 82 f2 ff  74.....@........  litex>'
Verify-Chunk 0 16
Write-Host 'PASS: real flattened board response matched canonical BIN.'

function Make-BiosDump([int]$Offset, [int]$Count, [string]$Separator) {
  $addr = 0x40010000L + $Offset
  $hex = ((($Offset..($Offset+$Count-1)) | ForEach-Object { '{0:x2}' -f [int]$script:Image[$_] }) -join ' ')
  $line = '0x{0:x8}  {1}   ................' -f $addr, $hex
  $script:ExpectedCommand = 'mem_read 0x{0:X8} {1}' -f $addr, $Count
  return $script:ExpectedCommand + $Separator + 'Memory dump:' + $Separator + $line + $Separator + 'litex>'
}
foreach ($sep in @([string][char]13, [string][char]10, ([string][char]13+[string][char]10), ' ')) {
  $script:FakeResponse = Make-BiosDump 0 16 $sep
  Verify-Chunk 0 16
}
$script:FakeResponse = Make-BiosDump 736 4 ([string][char]13)
Verify-Chunk 736 4
Write-Host 'PASS: CR-only, LF-only, CRLF, flattened and final 4-byte block.'
$bad = Make-BiosDump 0 16 ([string][char]13)
foreach ($malformed in @($bad.Replace('Memory dump:', 'Other output:'), $bad.Replace('0x40010000  ', '0x40020000  '))) {
  $script:FakeResponse = $malformed
  $rejected = $false
  try { Verify-Chunk 0 16 } catch { $rejected = $true }
  if (-not $rejected) { throw 'FAIL: malformed readback accepted' }
}
Write-Host 'PASS: wrong address and missing header rejected.'


# Negative control: mock must reject a read command inconsistent with the selected fixture.
$badCommandRejected = $false
try { Invoke-Bios 'mem_read 0x400102E0 4' | Out-Null } catch {
  $badCommandRejected = $_.Exception.Message -match 'Unexpected BIOS command in test'
}
if (-not $badCommandRejected) { throw 'FAIL: mock accepted unexpected readback request' }
Write-Host 'PASS: mock rejects a request inconsistent with the fixture.'

Write-Host 'PASS: uploader v0.1.3 protocol regression finished, no COM or writes.'