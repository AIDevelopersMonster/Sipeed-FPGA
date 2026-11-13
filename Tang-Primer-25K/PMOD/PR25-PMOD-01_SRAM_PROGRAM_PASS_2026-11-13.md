# PR25-PMOD-01 — JTAG + SRAM programming PASS

**Date:** 2026-11-13  
**Hardware:** Sipeed Tang Primer 25K + Dock  
**PMOD:** BTN left / DT center / LED right  
**Image:** upstream `sipeed/TangPrimer-25K-example/pmod_digitalTube-2bit/pmod_digitalTube-2bit.fs.7z` (extracted `.fs`); local binary hash not yet recorded.  
**Tool:** Gowin `programmer_cli.exe`; exact installed version not recorded.

## Operator-provided evidence (PowerShell)

```text
Scanning!
 Target Cable: Gowin USB Cable(FT2CH)/0/0/null@2.5MHz
Device Info:
        Family: GW5A
        Name: GW5A-25A
        ID: 0x0001281B
 1 device(s) found!
 Cost 0.6 second(s)

& $cli --device GW5A-25A --run 2 --fsFile $fs --cable-index 1
 Target Cable: Gowin USB Cable(FT2CH)/0/0/null@2.5MHz
 Target Device: GW5A-25A(0x0001281B)
 Operation "SRAM Program" for device#1...
 Frequency Updated: "15MHz"
Programming...: [#########################] 100%
 User Code: 0x00005848
 Status Code: 0x70026020
 Cost 5.28 second(s)
EXIT CODE: 0
```

## Verified / outstanding

- **JTAG DETECT PASS:** GW5A-25A ID 0x0001281B.
- **SRAM PROGRAM PASS:** `--run 2`, 100%, exit code 0.
- **PMOD functional BOARD PASS: PENDING.** Operator has not yet reported DT digits, BTN increment and LED/DIP behavior.
- **FPGA Flash:** no Flash operation was requested; operation type explicitly reports SRAM Program.
- No synthesis/STA result asserted for the prebuilt vendor image.

## Immediate functional acceptance (operator)

1. DT displays decimal value 0 after initialization.
2. BTN 1..4 change the DT value by +1, +2, +4, +8 respectively.
3. DIP switch changes LED selection; highest DIP enables running LED effect.

The expected behavior is taken from [Sipeed's reference README](https://github.com/sipeed/TangPrimer-25K-example/tree/main/pmod_digitalTube-2bit). For connector order, check [upstream issue #17](https://github.com/sipeed/TangPrimer-25K-example/issues/17).

**Next only after functional confirmation:** PMOD DVI display test.

## Subsequent visual observation (operator photo, 2026-11-13)

After SRAM programming, the operator reported that the seven-segment display initially showed `8`, then `0`. In the supplied photograph, the right digit visibly illuminates `0`; the left digit appears dark with passive outlines of the seven segments. This is consistent with successful initialization of the DT display and **confirms a basic displayed output on real hardware**. The reason for the transient `8` has not been established.

**BTN function:** not yet reported.  
**LED PMOD function:** not yet reported.  
**Whole PMOD example BOARD PASS:** pending BTN and LED checks.  
This observation does not imply verification of all digital-tube segments or all PMOD signals.
