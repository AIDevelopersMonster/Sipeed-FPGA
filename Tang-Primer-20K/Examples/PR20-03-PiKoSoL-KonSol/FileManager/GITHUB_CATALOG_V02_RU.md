# PiKoSoL TP20 File Manager v0.2 — GitHub catalog candidate

**STATUS: SOURCE PREPARED / OFFLINE TESTS NOT YET EXECUTED / BOARD TEST NOT YET PERFORMED.**
This is an isolated development branch. Do not create a release or merge before operator validation.

## Changes

- Existing local catalog and COM10 XMODEM-CRC path remain intact.
- New GUI buttons: `Получить список` and `Скачать выбранный`.
- Remote list is strictly drawn from `verified-apps.json`, not arbitrary repository binaries.
- All six published BIN files are offered. `BOARD_PASS` indicates individually documented confirmation; `OPERATOR_REPORTED` indicates collectively reported functionality, not independently evidenced for that binary.
- Downloads go to `%USERPROFILE%\\Downloads\\PiKoSoL_TP20_GitHub_BIN`.
- Hash, exact byte length, and existing PKD1 ABI validation are mandatory.
- Existing differing destination files are never replaced. No transmission occurs as part of download.
- No FPGA Flash writes, no automatic board programming, no publish workflow.

## Windows operator check

Use a separate ZIP or clone of this branch. First close any program that owns COM10.

```powershell
cd .\\Tang-Primer-20K\\Examples\\PR20-03-PiKoSoL-KonSol\\FileManager
python -m unittest discover -s tests -p "test_github.py" -v
python .\\PiKoSoL_FileManager.py --check
python .\\PiKoSoL_FileManager.py --check-apps
python .\\PiKoSoL_FileManager.py
```

In the GUI:
1. Click **Получить список**. Expect six listed applications with verification status.
2. Select **TP20_HDMI_GRID.bin**, click **Скачать выбранный**.
3. Confirm SHA256 + PKD1 PASS, verify the downloaded file is selected.
4. Only when the board is ready, click the existing **Загрузить .bin + RUN**.
5. Record UART XMODEM ACK, LOAD OK, RUN, return to PiKoSoL, and actual HDMI output.
6. Do not mark this version BOARD PASS without the actual operator result.

The GitHub manifest is an explicit list of published BINs, not independent proof of electrical behavior. HDMI preview programs do not drive external peripherals. Promote to `BOARD_PASS` only after individually documented operator results.
