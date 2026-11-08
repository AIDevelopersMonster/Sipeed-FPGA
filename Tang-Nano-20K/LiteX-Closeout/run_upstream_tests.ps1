# Offline LiteX upstream tests, pinned to factory BIOS-reported source commit.
[CmdletBinding()]
param([string]$WorkDir='C:\GitHub\litex-b05c3069-test',[string]$Python='python')
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
& $py -m pip install -e $repo migen
if($LASTEXITCODE -ne 0){throw 'Dependency installation failed'}
$folder=Join-Path $WorkDir 'results'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$log=Join-Path $folder ('SOURCE_TESTS_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt')
$rows=[System.Collections.Generic.List[string]]::new()
$rows.Add("SOURCE COMMIT: $commit")
foreach($name in @('test_csr','test_wishbone','test_timer','test_stream')) {
 $file=Join-Path $repo "test\$name.py"
 $output=(& $py $file 2>&1 | Out-String)
 $exit=$LASTEXITCODE
 $rows.Add("$name EXIT=$exit")
 $rows.Add($output)
 Write-Host "$name EXIT=$exit"
 if($exit -ne 0){Write-Warning "$name FAILED or environment incompatible"}
}
$rows.Add('test_cpu NOT EXECUTED (needs independent litex_sim / simulator setup)')
[System.IO.File]::WriteAllLines($log,$rows.ToArray())
Write-Host "Saved: $log"
Write-Host 'SOURCE TESTS ONLY; NO FPGA HARDWARE RESULTS.'
