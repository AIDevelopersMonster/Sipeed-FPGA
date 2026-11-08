# Offline LiteX upstream tests, pinned to factory BIOS-reported source commit.
[CmdletBinding()]
param([string]$WorkDir='C:\GitHub\litex-b05c3069-test',[string]$Python='python',[switch]$SkipInstall)
$ErrorActionPreference='Stop'
$commit='b05c30690854c462a2e704a22ff895c0055a8265'
$repo=Join-Path $WorkDir 'litex'
$venv=Join-Path $WorkDir 'venv'
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
if(-not(Test-Path(Join-Path $repo '.git'))) {
 git clone https://github.com/enjoy-digital/litex.git $repo
 if($LASTEXITCODE -ne 0){throw 'git clone failed'}
}
git -C $repo fetch origin $commit
if($LASTEXITCODE -ne 0){throw 'git fetch failed'}
git -C $repo switch --detach $commit
if($LASTEXITCODE -ne 0){throw 'git checkout failed'}
$head=(git -C $repo rev-parse HEAD).Trim()
if($head -ne $commit){throw "Pinned revision mismatch: $head"}
if(-not(Test-Path (Join-Path $venv 'Scripts\python.exe'))) {
 & $Python -m venv $venv
 if($LASTEXITCODE -ne 0){throw 'Failed to create virtualenv'}
}
$py=Join-Path $venv 'Scripts\python.exe'
if(-not $SkipInstall) {
 & $py -m pip install -e $repo migen
 if($LASTEXITCODE -ne 0){throw 'Dependency installation failed'}
} else {
 Write-Host 'Reusing existing virtualenv (-SkipInstall); no pip operation.'
}
$folder=Join-Path $WorkDir 'results'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$log=Join-Path $folder ('SOURCE_TESTS_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt')
$rows=[System.Collections.Generic.List[string]]::new()
$rows.Add("SOURCE COMMIT: $commit")
# The test_*.py files define unittest.TestCase methods but do NOT call
# unittest.main(). Direct 'python test_csr.py' falsely returned exit code 0
# without executing a single test. Discovery is mandatory.
$groups=[ordered]@{
 test_csr=4
 test_wishbone=5
 test_timer=3
 test_stream=5
}
$errors=[System.Collections.Generic.List[string]]::new()
$executed=0
$testDir=Join-Path $repo 'test'
# unittest prints its results to stderr; preserve both streams and each test count.
$PSNativeCommandUseErrorActionPreference=$false
foreach($name in $groups.Keys) {
 $pattern="$name.py"
 $output=(& $py -m unittest discover -s $testDir -p $pattern -v 2>&1 | Out-String)
 $exit=$LASTEXITCODE
 $match=[regex]::Match($output,'(?m)^\s*Ran\s+([0-9]+)\s+tests?\s+in\s+')
 $count=if($match.Success){[int]$match.Groups[1].Value}else{0}
 $expected=[int]$groups[$name]
 $ok=($exit -eq 0 -and $count -eq $expected -and $output -match '(?m)^OK\s*$')
 $verdict=if($ok){'PASS'}else{'FAIL'}
 $rows.Add("==== $name : $verdict; tests=$count/$expected; exit=$exit ====")
 $rows.Add($output)
 $executed+=$count
 Write-Host ('{0}: {1} tests={2}/{3} exit={4}' -f $name,$verdict,$count,$expected,$exit)
 if(-not $ok){$errors.Add("$name count=$count expected=$expected exit=$exit")}
}
$rows.Add("SUMMARY tests_observed=$executed expected=17 failures=$($errors.Count)")
$rows.Add('test_cpu NOT EXECUTED (needs independent litex_sim / simulator setup)')
[System.IO.File]::WriteAllLines($log,$rows.ToArray())
Write-Host "Saved: $log"
if($errors.Count -gt 0){
 throw "SOURCE TESTS NOT PASS ($($errors.Count) suites). Inspect $log . Details: $($errors -join '; ')"
}
if($executed -ne 17){throw "UNEXPECTED TOTAL: $executed != 17 (inspect $log)"}
Write-Host 'PASS 17/17 LiteX upstream unittest cases on pinned source (HOST SIMULATION ONLY).'
Write-Host 'NO FPGA HARDWARE RESULTS FROM THIS RUN.'
