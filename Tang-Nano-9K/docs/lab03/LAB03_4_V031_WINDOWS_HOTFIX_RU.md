# LAB-03.4 v0.3.1 — Windows CRLF hotfix

Дата: 21 октября 2026 года. Репозиторий: `AIDevelopersMonster/Sipeed-FPGA`.

## Назначение

Исправление двух ошибок автоматических тестов v0.3 на Windows 10/PowerShell 7:

1. `test_no_source_overwrite`: на Windows исходный testbench имел CRLF, а якорь `case(which) / 3:fd=$fopen(...)` искался с LF-ориентированным регулярным выражением. Теперь входная строка нормализуется *только в создаваемой копии*, а исходный TB не изменяется.
2. `test_order_error_with_valid_rom_words_is_mismatch`: тест использовал `Path.write_text` для строки с уже сформированным CRLF. На Windows происходило преобразование CRLF -> CR CR LF; T3-парсер правильно отвергал испорченные входные данные. Теперь тест использует `Path.write_bytes` и отдельно подтверждает, что намеренно изменённая трасса остаётся корректным T3-кадром.

Новые регрессионные тесты: CRLF testbench, LF trace. Итого 15 тестов v0.3.1.

## Содержимое исправления

- `01-PicoRV32/tools/lab03_4_extend_tb.py`
- `01-PicoRV32/tests/test_lab03_4_v03.py`
- `docs/lab03/LAB03_4_V031_WINDOWS_HOTFIX_RU.md`

Остальные файлы v0.3 и LAB-03.2 не изменяются.

## Установка в PowerShell 7

Перед установкой исходный v0.3 должен быть уже установлен:

```powershell
cd C:\GitHub\Sipeed-FPGA
$backup = '.\01-PicoRV32\build\lab03_4\backup_before_v031'
New-Item -ItemType Directory -Force $backup | Out-Null
Copy-Item '.\01-PicoRV32\tools\lab03_4_extend_tb.py' $backup -Force
Copy-Item '.\01-PicoRV32\tests\test_lab03_4_v03.py' $backup -Force
Expand-Archive "$HOME\Downloads\LAB03_4_Windows_Hotfix_v0.3.1.zip" -DestinationPath . -Force
python .\01-PicoRV32\tests\test_lab03_4_v03.py
```

**Ожидается** `Ran 15 tests ... OK`. Это офлайн-проверка, не физическое доказательство RTL ↔ FPGA.

После этого:

```powershell
& .\01-PicoRV32\tools\run_lab03_4_rtl_v03.ps1 -Evidence "$HOME\Downloads\LAB03_3_EVIDENCE.zip"
```

Скрипт использует уже существующую RTL-модель LAB-03.2 (через Icarus) и не обращается к COM10 или FPGA. Для v0.3.1 PASS сравнения двух команд будет установлен **только при фактическом успешном завершении** этого запуска.

## Выполненная проверка пакета (локальная среда разработки)

- 15/15 тестов v0.3.1 PASS с архивом LAB03_3_EVIDENCE.zip;
- 8/8 тестов `test_lab03_4_analyze.py` PASS;
- 8/8 тестов `test_lab03_4_compare_rtl.py` PASS;
- отдельная проверка нормализации CRLF выполнялась на точных байтовых данных;
- RTL-симуляция Icarus на Windows не выполнялась.

## Граница утверждений

Этот hotfix исправляет тесты и генератор testbench. Он не изменяет ядро PicoRV32, логическую схему, ROM или .fs, а также не доказывает эквивалентность для команды `0` до реального RTL-прогона.
