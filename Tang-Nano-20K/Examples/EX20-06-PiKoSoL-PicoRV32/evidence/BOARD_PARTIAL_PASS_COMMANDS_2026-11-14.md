# EX20-06 — first hardware shell command session (operator evidence, 2026-11-14)

**Board:** Tang Nano 20K, PiKoSoL/PicoRV32, 720p Gowin DVI experiment. User confirms the interactive output is also displayed on the HDMI monitor. Observations from the serial/terminal transcript:

```text
PiKoSoL> help
HELP INFO MEM LED N|? GFX TERM CLS KEYS
OBJ A-H MOVE I|J|K|L COLOR R|G|U|W
SIZE +|- PANEL STATUS; single-key commands + Enter.
CTRL-P recall previous command. No file system yet.
PiKoSoL> INFO
PiKoSoL LAB-04.3.2 / PicoRV32 RV32I
Tang Nano 9K; 640x480 HDMI; UART 115200 8N1
MODE: TERMINAL
PiKoSoL> LED 3
C=3
PiKoSoL> LED 0
C=0
PiKoSoL> COLOR R
V
PiKoSoL> TERM
MODE: TERMINAL
PiKoSoL>
```

**Confirmed directly:** PicoRV32 firmware command loop running, UART terminal dialogue and video terminal output, HELP, INFO, LED 3 and LED 0 command acknowledgement, COLOR R acknowledgement, TERM response. The HDMI photograph also shows the PiKoSoL startup banner and prompt.

**Not yet observed:** physical LED changes, color change on graphics, actual full active raster timing verified from HDMI monitor OSD, eight independent objects behavior, full hardware reset recovery, Flash restoration after power-cycle. A serial `C=3` response is not physical LED evidence. This is BOARD **PARTIAL** PASS only.

**Identified firmware defect:** the generated `INFO` output retains a legacy string `Tang Nano 9K; 640x480 HDMI; UART 115200 8N1`. The `tools/stage.py` staging fix at commit `9a931519dfff223a2e7ddb617b7d68b2a08fd300` substitutes `Tang Nano 20K; 1280x720 HDMI; UART 115200 8N1` when the old ROM is next assembled. This fix does not retroactively change or revalidate the currently running FPGA image and **requires fresh simulation/STA/bitstream identity for a later programming experiment**.

**Follow-up:** operator wants larger text font; recommend preserving existing 160x60 8x12 mode as a compatibility baseline and evaluating 2x rendering at 80x30 in a future separate revision. No font scaling change is included in this evidence update.
