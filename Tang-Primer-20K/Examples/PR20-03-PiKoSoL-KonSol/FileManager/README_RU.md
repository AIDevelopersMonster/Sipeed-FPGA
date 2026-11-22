# PiKoSoL File Manager v0.1.4 — ABI FIX / BOARD TEST NOT YET PERFORMED

## Быстрый запуск на Windows — Tang Primer 20K

**Это программа для ПК, а не FPGA-прошивка.** FileManager передаёт PKD1/RV32I `.bin` в RAM PiKoSoL через COM10 (115200 8N1). FPGA Flash не изменяется.

[Папка FileManager](./) · [Запуск START_PiKoSoL_FileManager.cmd](START_PiKoSoL_FileManager.cmd) · [Восстановление монитора](../SRAM-Startup/README.md).

**Если комплект PiKoSoL уже скачан**, откройте PowerShell в каталоге `PiKoSoL_TP20_From_GitHub` (с подпапками `FileManager/`, `firmware/`, `tools/`) и выполните:

```powershell
python .\FileManager\PiKoSoL_FileManager.py --root .
```

Или откройте `FileManager\START_PiKoSoL_FileManager.cmd`. Если отсутствует модуль `serial`: `python -m pip install pyserial`.

**Если комплекта нет**, используйте [скрипт синхронизации](../scripts/Sync-PiKoSoL-From-GitHub.ps1). Он скачивает и сверяет проверенные файлы, не программируя FPGA по умолчанию. Если `Downloads\PiKoSoL_TP20_From_GitHub` уже существует, скрипт откажется его перезаписывать; повторно скачивать не нужно. Синхронизация получает опубликованный базовый комплект, **не экспериментальную SD-прошивку**.

**Для загрузки `.bin`:** закройте MobaXterm и другие клиенты COM10. Убедитесь, что монитор `PiKoSoL>` запущен. В GUI выберите COM10, нажмите «Подключить терминал», затем «+ Выбрать файл», выберите локальный `.bin` и нажмите «Загрузить .bin + RUN». FileManager временно освобождает COM10 для XMODEM. Не вводите `LOAD` вручную. При `LOAD BAD ...` не отправляйте `RUN`.

**Текущий эксперимент PR20-SD-01:** диагностический `PR20_SD01_READ_LBA0.bin` берётся из локально распакованного FIX2, а FPGA `.fs` программируется отдельно в SRAM. Кандидат SD не опубликован как проверенный релиз.

**Статус:** опубликованная версия GUI обозначена как v0.1.4, не v0.2.0; аппаратный BOARD PASS новой SD-сборки пока не подтверждён.

---

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
