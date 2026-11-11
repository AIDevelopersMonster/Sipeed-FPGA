#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$FsPath = 'C:\GitHub\Sipeed-FPGA-LAB05\boards\tang-nano-9k\experiments\sd07-pikosol-mmio\build\board_fat32_20261025_123935_295\sd08_pikosol_fat32_readonly.fs'
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = 'AIDevelopersMonster/Sipeed-FPGA'
$filename = 'sd08_pikosol_fat32_readonly.fs'
$expected = '37ddb2fb7d20f7e4ad610dad4160dc98ed38e5197221b62644642d32c8c09f4b'
$target = "docs/lab04/web-loader/firmware/$filename"
$tag = 'pikosol-sd08-fat32-ro'
if (-not (Test-Path -LiteralPath $FsPath -PathType Leaf)) {
  throw "Не найден проверенный файл: $FsPath. Укажите параметр -FsPath."
}
$fs = (Resolve-Path -LiteralPath $FsPath).Path
$actual = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) {
  throw "STOP: SHA256 FAIL. expected=$expected actual=$actual. Загрузка не выполнялась."
}
Write-Host "SD08_SHA256_PASS: $actual" -ForegroundColor Green
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Нужен GitHub CLI: gh auth login' }
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw 'Необходимо выполнить gh auth login' }
$payload = [ordered]@{
  message = 'release(sd08): publish hardware-verified FAT32 read-only SRAM bitstream'
  content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($fs))
  branch  = 'main'
}
$previous = & gh api "repos/$repo/contents/$target" --jq '.sha' 2>$null
if ($LASTEXITCODE -eq 0 -and $previous) { $payload['sha'] = $previous.Trim() }
$temp = Join-Path ([IO.Path]::GetTempPath()) ("sd08-upload-" + $PID + '.json')
try {
  [IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject $payload -Depth 4 -Compress), [Text.UTF8Encoding]::new($false))
  $commit = & gh api --method PUT "repos/$repo/contents/$target" --input $temp --jq '.commit.sha'
  if ($LASTEXITCODE -ne 0 -or -not $commit) { throw 'Ошибка публикации SD08 в main' }
  Write-Host "SD08_MAIN_PUBLISHED: $($commit.Trim())" -ForegroundColor Green
} finally { Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue }
& gh release view $tag --repo $repo *> $null
if ($LASTEXITCODE -eq 0) {
  & gh release upload $tag $fs --repo $repo --clobber
} else {
  & gh release create $tag $fs --repo $repo --target main --title 'PiKoSoL SD-08 - FAT32 Read-only - Tang Nano 9K' --notes 'Hardware demonstrated: FS, DIR, TYPE PIKO.TXT. SHA-256: 37ddb2fb7d20f7e4ad610dad4160dc98ed38e5197221b62644642d32c8c09f4b. WebUSB SRAM-only image.'
}
if ($LASTEXITCODE -ne 0) { throw 'Файл опубликован в main, но не в GitHub Release' }
Write-Host 'SD08_RELEASE_PUBLISHED' -ForegroundColor Green
Write-Host 'WebUSB: https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/'
