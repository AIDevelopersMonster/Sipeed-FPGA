# EX20-06 / STA-5: operator report (2026-11-14)

**Source:** direct PowerShell log provided by the operator. Head `80395e6`, candidate `candidate_20261114_062849_118`, tested on Windows. This log is evidence of completed synthesis/PnR/STA and sim, but the full **latest STA-5 pin.html and clock report have not yet been supplied**. Do not confuse this with board confirmation.

## Reproduced checks

- Static contracts `12/12 PASS`.
- Icarus `PIKOSOL20K_RENDERER_PIPELINE_SIM_PASS`, `PIKOSOL20K_RESET_SIM_PASS`.
- ROM assembler `LAB04_ROM_BUILD_PASS`, 2736 instructions, ROM SHA256 `B8DF2620DE1EE11CD075ED98AB4AD99A363BBF7B88F3F3B6C0793B45D5629AE5`.
- Gowin `STA_GATE_EXIT=0`, `PASS_FOR_IO_REVIEW_NOT_BOARD`; setup and hold violated endpoints **0/0**, per-clock setup/hold TNS **0.0** for CPU, pixel and PLL fast clock.
- Pixel Fmax **100.363 MHz**, required **74.25 MHz**; listed Setup **+0.387 ns**, Hold **+0.208 ns**, Recovery **+12.116 ns**, Removal **+0.925 ns**.
- All six first-stage CDC exceptions **Actived**; **PR1014 remains** in routing log.
- `.fs` 7,264,150 bytes; SHA256 **1841025391F82868B50B2BDF54B0C2D1152392767B76D6F185B1A82162E31AE2** (case-insensitive). This is a different artifact than STA-4 due to CST pin constraint update.

## Outstanding IO/clock inspection

STA-5 changed `reset_btn` pin 88 to explicit `LVCMOS33 PULL_MODE=DOWN SINGLE_RESISTOR=ON BANK_VCCIO=3.3`, based on [official Sipeed Tang Nano 20K HDMI CST](https://github.com/sipeed/TangNano-20K-example/blob/main/hdmi/src/hdmi.cst). Prior PnR showed `reset_btn` at pin 88 but `BankVccio=1.2`, and other 3.3V ports correct. The STA-5 **STA_GATE JSON contains no pin report values**, so the pin-bank discrepancy remains **UNVERIFIED** until examination of *this* candidate's `pikosol20k_picorv32_candidate.pin.html`.

The upstream `PR1014` message warns that `clk27_d` may use generic routing with excessive delay/skew. Prior report's Global Clock Signals section nevertheless listed `clk27_d` as PRIMARY across TR/TL/BR/BL and `pix_clk` as PRIMARY. Re-examine `gowin.log`, PnR global clock usage and STA-5 report; do not suppress the warning or overinterpret it.

## Read-only PowerShell inspection (no new synth/flash)

From EX20-06 folder:

```powershell
$Job = ".\\build\\candidate_20261114_062849_118"
$Pin = Join-Path $Job "work\\impl\\pnr\\pikosol20k_picorv32_candidate.pin.html"
$Rpt = Join-Path $Job "work\\impl\\pnr\\pikosol20k_picorv32_candidate.rpt.txt"
$Log = Join-Path $Job "gowin.log"
$html = Get-Content -LiteralPath $Pin -Raw
foreach ($name in @('reset_btn','clk27','uart_rx','uart_tx','led_n[0]','tmds_clk_p')) {
    $pattern = '(?is)<tr\\b[^>]*>\\s*<td[^>]*>\\s*' + [regex]::Escape($name) + '\\s*</td>(.*?)</tr>'
    $m = [regex]::Match($html,$pattern)
    if (!$m.Success) { Write-Host "MISSING $name"; continue }
    $cells = @([regex]::Matches($m.Value,'(?is)<td\\b[^>]*>(.*?)</td>') | ForEach-Object {
        [System.Net.WebUtility]::HtmlDecode(([regex]::Replace($_.Groups[1].Value,'<[^>]+>','')).Trim())
    })
    [pscustomobject]@{ Port=$name; PinBank=$cells[2]; IOType=$cells[6]; BankVccio=$cells[-1] }
}
Select-String -LiteralPath $Log -Pattern 'PR1014' -Context 2,2
Select-String -LiteralPath $Rpt -Pattern '6. Global Clock Signals' -Context 0,15
```

**Gate:** no SRAM/Flash programming yet; review pin 88 bank VCCIO, full clock report and the warnings. The source branch itself is intact; preserve the SHA of the STA-5 `.fs`.
