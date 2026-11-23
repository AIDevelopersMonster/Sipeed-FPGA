
## GitHub catalog in File Manager v0.2.0 (main)

The main-branch GUI now includes **Получить список** and **Скачать выбранный**. It reads the exact allowlist `verified-apps.json` from GitHub `main`, displays each binary's verification status, and downloads only upon an explicit click. A downloaded file is checked for exact length, SHA256, and the PiKoSoL PKD1 app header before it appears in the local list.

- The original `monitor.bin`, `demo.bin`, `.fs`, and launcher remain unchanged.
- Download only: nothing is automatically transferred to FPGA. For RAM execution, separately click **Загрузить .bin + RUN**.
- Cache: `%USERPROFILE%\Downloads\PiKoSoL_TP20_GitHub_BIN`. Existing different files are not overwritten.
- `BOARD_PASS` is per-binary evidence; `OPERATOR_REPORTED` is not independently demonstrated BOARD PASS. Preview applications do not drive the actual audio/LCD/RGB hardware.
- Legacy GUI v0.1.4 can be recovered from GitHub history; no release is created.

Offline test (does not access COM/FPGA or the network):

```powershell
python -m unittest discover -s tests -p test_github.py -v
python .\PiKoSoL_FileManager.py --check --root ..
```

**Status:** published to GitHub `main` for PC/user testing; GUI's updated remote-catalog route has not yet received a fresh BOARD PASS on the operator's machine.

---

# PiKoSoL File Manager v0.1.4 — ABI FIX / BOARD TEST NOT YET PERFORMED

Рабочие `tp20k_System_picorv32.fs`, `monitor.bin`, `demo.bin` не изменены.
Установщик не обращается к COM10. Приложение работает только с RAM через XMODEM.

**Подтверждённый оператором заголовок demo.bin (19.11.2026):**

- `0x00`: u32 LE `0x31444B50` — сигнатура PKD1;
- `0x04`: u32 LE `1292` — **точный размер всего файла**, не padded размер XMODEM;
- `0x08`: u32 LE `0x2000C010` — адрес входа;
- `0x0C`: u32 LE `0` — резерв.

Новые `.bin` создаются с тем же расположением полей и машинным кодом начиная с `0x2000C010`. Лимит `LOAD` — `0x3000` байт **с учётом padding**. Передача блокируется, если поля некорректны. После `LOAD BAD LENGTH` команда `RUN` **не** отправляется.

## Содержимое

- `PiKoSoL_FileManager.py` — Windows GUI с Live Keyboard;
- `pikosol_xmodem.py` — экспериментальная XMODEM-CRC передача новых приложений;
- `build_tp20_apps.py` — воспроизводимый генератор 5 программ;
- `build_hello_rv32i.py` — исправленный пример HELLO;
- `generated/*.bin` — пять пересобранных кандидатов.

Программы `LCD`, `RGB`, `AUDIO` выводят **превью на HDMI**, а не управляют физическими модулями (отсутствует MMIO для соответствующих периферийных устройств).

**OFFLINE PASS != BOARD PASS.** После успешной проверки `--check` и `--check-apps` испытывать сначала только `TP20_HDMI_GRID.bin`. Не переписывать работающие файлы, не делать Release на GitHub.

Пример для Windows PowerShell:

```powershell
$dir = "$env:USERPROFILE\Downloads\PiKoSoL_TP20_FileManager_CANDIDATE_v0.1.4"
python "$dir\PiKoSoL_FileManager.py" --check
python "$dir\PiKoSoL_FileManager.py" --check-apps
& "$dir\START_PiKoSoL_FileManager.cmd"
```


## Результат аппаратного испытания

Новая версия пока не имеет BOARD PASS. Зафиксируйте реальные ответы: XMODEM ACK, `LOAD OK` или отказ, `RUN 2000C010`, `RUN RETURNED TO PiKoSoL`, HDMI. Если `LOAD BAD ...`, больше ничего не передавать и приложить протокол.

Для подготовки пяти файлов использовано проверенное описание заголовка из оператора: `demo.bin` длина `1292`, SHA256 `BE20FB6EC6D1C7BFE1E9591F0C734649C61D200217F5EBF15800B4F4E681DE26`. Сторонний загрузчик THLN33 имеет другой формат и НЕ использован для наших `PKD1` приложений.

`FILE_MANAGER_PREPARE_PASS` подтверждает только исходные файлы; `FIVE APP ABI + RV32I EMULATION PASS` — только автономное исполнение на ПК. Никакой автоматической публикации в GitHub.
