$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$iverilog=(Get-Command iverilog -ErrorAction Stop).Source
$vvp=(Get-Command vvp -ErrorAction Stop).Source
foreach($item in @('spi','sdhc')) {
    $out=Join-Path ([IO.Path]::GetTempPath()) ('sd01_'+[guid]::NewGuid().ToString('N')+'.vvp')
    try {
        if($item -eq 'spi') {
            $top='tb_lab05_spi_byte'
            $sources=@('rtl\lab05_spi_byte.v','tests\tb_lab05_spi_byte.v')
            $expected='LAB05_SPI_BYTE_TB_PASS'
        } else {
            $top='tb_lab05_sd_init_read0'
            $sources=@('rtl\lab05_spi_byte.v','rtl\lab05_sd_init_read0.v','tests\tb_lab05_sd_init_read0.v')
            $expected='LAB05_SDHC_READ0_TB_PASS'
        }
        $paths=@($sources | ForEach-Object { Join-Path $here $_ })
        & $iverilog -g2012 -s $top -o $out $paths
        if($LASTEXITCODE -ne 0){ throw "Compile failed: $item" }
        $lines=@(& $vvp $out)
        $exitCode=$LASTEXITCODE
        $lines | ForEach-Object { Write-Host $_ }
        if($exitCode -ne 0 -or -not (($lines -join [char]10).Contains($expected))) {
            throw "Simulation failed: $item"
        }
    } finally {
        Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
    }
}
Write-Host 'NANO9K_SD_SECTOR0_RTL_PASS'
