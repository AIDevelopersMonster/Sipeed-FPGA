# Tang Nano 20K — Timer0 READONLY PROBE BOARD PASS (2026-11-08)

**Тип доказательства:** физическая плата, заводской BIOS LiteX, COM25, чтение без записи `mem_write`.  
**Скрипт:** [`timer0_bios_test.py`](timer0_bios_test.py) с параметрами `--probe --port COM25`.  
**Локальное время по имени JSON:** 2026-11-08 23:03:52.  
**Журнал на компьютере оператора:** `C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\TIMER_TEST_20261108_230352_555688.json`.

## Точный консольный результат

```text
PS C:\EBAZ4205-Backup> & "C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe" "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\timer0_bios_test.py" --probe --port COM25
TIMER0: verified factory ROM, CSR 0xF0002800, 3-second one-shot
No Flash, SDRAM or IRQ_ENABLE writes. Close other COM users.
PASS factory ROM/CSR fingerprint 5/5
READ timer registers: load=0x00B71B00 reload=0x00000000 en=0x00000001 ev_pending=0x00000001 ev_enable=0x00000000
Evidence saved: C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\TIMER_TEST_20261108_230352_555688.json
READONLY PROBE PASS: NO TIMER WRITES / NO FLASH / NO BOOT
```

## Техническое заключение

- **BOARD PROBE PASS:** совпали 5/5 ROM fingerprint; адресная карта проверена до доступа к Timer0.
- `LOAD=0x00B71B00` = **12 000 000 тактов** (0,25 с при 48 МГц).
- `RELOAD=0`; `ENABLE=1`; `EVENT_PENDING=1`; `EVENT_ENABLE=0`. Это согласуется с завершённым однократным отсчётом, но **текущее значение VALUE в read-only probe не фиксировалось**, а потому непосредственно работа счётчика пока не доказана.
- **TIMER0 BOARD FUNCTIONAL TEST PENDING.** Нельзя выдавать успешное `--probe` за выполнение 3-секундного таймингового теста.
- Следующая операция `--run --port COM25` сама сначала фиксирует `VALUE` и отказывается от записи, если Timer0 всё ещё считает, если `RELOAD != 0` или разрешено Timer0 IRQ. При успехе должен появиться `TIMER0 BOARD PASS` и `RESTORE PASS`; в противном случае — `INCONCLUSIVE` и сохранённый локальный JSON.
- **NO FLASH, SDRAM, BOOT, IRQ ENABLE**. Данный протокол — только наблюдение регистров.

См. [анализ заводского ROM](TIMER_IRQ_ROM_AUDIT_2026-11-08.md).
