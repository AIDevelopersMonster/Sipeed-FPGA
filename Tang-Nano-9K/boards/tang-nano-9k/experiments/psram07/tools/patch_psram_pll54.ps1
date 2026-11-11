#requires -Version 7.0
<#
LAB-07.2: change one active vendor PLL value ONLY on a staged local copy.
Preserve LF/CRLF and fail closed if upstream settings differ.
No Gowin, JTAG, USB, FPGA, or PSRAM actions.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$path = (Resolve-Path -LiteralPath $InputPath -ErrorAction Stop).Path
$source = [System.IO.File]::ReadAllText($path)
$requiredLines = @(
    'defparam rpll_inst.FCLKIN = "27";',
    'defparam rpll_inst.FBDIV_SEL = 2;',
    'defparam rpll_inst.IDIV_SEL = 0;',
    'defparam rpll_inst.ODIV_SEL = 8;',
    'defparam rpll_inst.PSDA_SEL = "0100";'
)
foreach($line in $requiredLines) {
    # With (?m), $ matches before LF but not before CR in CRLF.
    # Explicit optional \r is required for Windows native source.
    $pattern = '(?m)^' + [regex]::Escape($line) + '[ \t]*\r?$'
    $hits = [regex]::Matches($source, $pattern).Count
    if($hits -ne 1) {
        throw "LAB07_CLOCK54_PLL_FINGERPRINT_MISMATCH: $line (matches=$hits)"
    }
}
# Only active FBDIV line; commented-out alternatives cannot match.
# Lookahead deliberately preserves the original whitespace and line endings.
$from = '(?m)^defparam rpll_inst\.FBDIV_SEL = 2;(?=[ \t]*\r?$)'
$to = 'defparam rpll_inst.FBDIV_SEL = 1;'
$changed = [regex]::Replace($source, $from, $to)
if($changed -ceq $source) {
    throw 'LAB07_CLOCK54_PLL_PATCH_NO_CHANGE'
}
$checkNew = '(?m)^defparam rpll_inst\.FBDIV_SEL = 1;[ \t]*\r?$'
if([regex]::Matches($changed, $checkNew).Count -ne 1) {
    throw 'LAB07_CLOCK54_PLL_PATCH_VERIFY_FAIL'
}
$reversed = [regex]::Replace($changed,
    '(?m)^defparam rpll_inst\.FBDIV_SEL = 1;(?=[ \t]*\r?$)',
    'defparam rpll_inst.FBDIV_SEL = 2;')
if($reversed -cne $source) {
    throw 'LAB07_CLOCK54_PLL_UNINTENDED_CHANGE'
}
[System.IO.File]::WriteAllText($path, $changed,
    [System.Text.UTF8Encoding]::new($false))
Write-Output 'LAB07_CLOCK54_PLL_PATCH_PASS: FCLKIN=27, FBDIV_SEL=1, IDIV_SEL=0, ODIV_SEL=8, PSDA_SEL=0100'
