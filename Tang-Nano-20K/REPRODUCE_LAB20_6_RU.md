# Как повторить LAB-20.6 — от чистого ПК до собственной RISC-V программы

**Испытано 2026-11-08 на Sipeed Tang Nano 20K с заводским LiteX BIOS, VexRiscv_Min @ 48 МГц.** Цель: загрузить собственную программу **только в SDRAM**, проверить каждую запись и запустить её через BIOS. Конфигурационную Flash не прошиваем.

[Главная папка платы](README.md) · [Исходники и бинарник](06-RV32-RAM-Diagnostics/README.md) · [Аппаратный протокол](06-RV32-RAM-Diagnostics/RV32_HARDWARE_EXECUTION_PASS_2026-11-08.md)

## 0. Что понадобится

- Плата **Sipeed Tang Nano 20K** с **заводской FPGA-конфигурацией LiteX** и работающим UART BIOS. Если нет `litex>`, **остановитесь**: адреса и файл могут быть неприменимы.
- Windows 10/11, **PowerShell 7** (`pwsh`) и установленный **Git**.
- Подключённый USB-UART и любой терминал (Tera Term, PuTTY и т. п.), **115200 бод, 8N1, без аппаратного flow control**.
- На нашем стенде UART — **COM25**, но на другом компьютере номер COM будет иным. Проверить можно в диспетчере устройств Windows.

## 1. Скачать готовый проект

В PowerShell:

```powershell
git clone https://github.com/AIDevelopersMonster/Sipeed-FPGA.git C:\FPGA\Sipeed-FPGA
Set-Location C:\FPGA\Sipeed-FPGA\Tang-Nano-20K\06-RV32-RAM-Diagnostics
Get-ChildItem
```

Должны быть файлы **`snapshot.bin`**, **`snapshot.S`**, **`upload.ps1`** и **`test_upload_protocol.ps1`**. Компилировать ничего не нужно: бинарник уже подготовлен.

Проверить оригинальный файл:

```powershell
(Get-FileHash .\snapshot.bin -Algorithm SHA256).Hash.ToLowerInvariant()
```

Ожидаемый SHA-256: `def94e225021f654258cd2760a32c63343a0ade98b4f770882e63a2f17255a0e`.

## 2. Убедиться, что BIOS действительно LiteX

Откройте терминал на своём COM-порту, `115200 8N1`. При штатном запуске платы должно появиться приглашение **`litex>`**. Можно ввести `help` и, например, прочитать UART CSR: 

```text
litex> mem_read 0xF0003014
```

На нашем стенде `ev_enable = 03 00 00 00`. Значения иных регистров зависят от момента чтения. **Не используйте `mem_write` по адресам периферии и Flash.**

## 3. Сначала проверить скрипты без платы

Закройте терминал и вернитесь в PowerShell в папку LAB-20.6.

```powershell
pwsh -NoProfile -File .\test_upload_protocol.ps1
```

Ожидается завершение строкой `PASS: uploader v0.1.3 protocol regression finished, no COM or writes.`. Если есть ошибка — остановитесь, не записывайте память.

## 4. Проверить реальную связь с BIOS без записи

Убедитесь, что терминал **закрыт**, COM-порт свободен. Подставьте свой номер вместо COM25:

```powershell
pwsh -NoProfile -File .\upload.ps1 -PortName COM25 -Probe
```

Должно появиться `PROBE PASS: ANSI-colored LiteX BIOS prompt recognized on serial COM port.`. Это **не изменяет память**.

## 5. Загрузить проверенный образ в SDRAM, но пока не запускать

```powershell
pwsh -NoProfile -File .\upload.ps1 -PortName COM25 -Upload
```

Скрипт отправит **185 команд `mem_write` в SDRAM начиная с `0x40010000`**, а затем прочитает все **740 байт обратно** и сравнит их с файлом. Это не запись Flash.

Требуемая заключительная строка:

```text
PASS: 740 bytes SDRAM load/readback verified against SHA256-controlled binary.
```

**Если нет PASS — не выполняйте `boot`.** Посмотрите на адрес и ошибку, исправьте связь и повторите загрузку при необходимости.

## 6. Дополнительная проверка уже загруженного образа без записи

Не сбрасывая плату и закрыв терминал:

```powershell
pwsh -NoProfile -File .\upload.ps1 -PortName COM25 -VerifyOnly
```

Требуемое подтверждение:

```text
PASS: 740 bytes SDRAM readback match SHA256-controlled binary; NO WRITES / NO BOOT.
```

Если плата уже перезагружалась, старая программа в SDRAM могла исчезнуть — выполните загрузку заново.

## 7. Запустить СВОЮ программу на процессоре

Закройте PowerShell-загрузчик (он уже завершился). Откройте терминал COM, `115200 8N1`. Если на шаге 5/6 был полный PASS и плату не перезагружали:

```text
litex> boot 0x40010000
```

Начало ожидаемого отчёта:

```text
Executing booted program at 0x40010000
--============= Liftoff! ===============--
PiKoSoL LAB20.6 RAM-only snapshot BEFORE UART output
TXEMPTY    = 0x00000001
...
TXEMPTY_AFTER_PRINT = 0x00000000
LAB20.6 HOLD - press physical RESET to return to BIOS
```

Эти числа — **значения нашего аппаратного эксперимента**, а не гарантия того, что у каждого повторяющего будут те же байты CSR. Для признания исполнения PASS необходим **реальный отчёт программы**, а не только сообщение `Liftoff!` от BIOS.

## 8. Как безопасно закончить

Программа остаётся в бесконечном цикле **HOLD**, **сама в BIOS не возвращается**. Чтобы вернуться к `litex>`, нажмите **аппаратную кнопку RESET**. Это штатно: RAM-only опыт не меняет конфигурационную Flash. После RESET SDRAM может быть переинициализирована.

## Типичные ошибки

- **`upload.ps1` не найден:** сначала `Set-Location` в папку `Tang-Nano-20K\06-RV32-RAM-Diagnostics`.
- **`COM25` занят:** закройте PuTTY/Tera Term, прежде чем запускать PowerShell-загрузчик.
- **`PROBE` не проходит:** проверьте номер COM, скорость и наличие заводского `litex>`.
- **`readback mismatch`:** не выполняйте `boot`, пока все 740 байт не совпадут.
- **Команды PowerShell склеились:** вставляйте **каждую команду отдельно**, проверяйте приглашение `PS>`.
- **После `boot` нет приглашения:** это ожидаемое поведение. Нажмите физический RESET.

## Чего эта инструкция не делает

Не синтезирует процессор в Gowin, не загружает FPGA bitstream, не меняет Flash/SD, не устанавливает Linux, не утверждает аппаратную поддержку иных плат. Это **воспроизводимый эксперимент запуска RV32I приложения на существующем заводском LiteX SoC**.

Подробности исходного кода и анализа: [LAB-20.6](06-RV32-RAM-Diagnostics/README.md), [полный протокол испытаний](06-RV32-RAM-Diagnostics/RV32_HARDWARE_EXECUTION_PASS_2026-11-08.md).
