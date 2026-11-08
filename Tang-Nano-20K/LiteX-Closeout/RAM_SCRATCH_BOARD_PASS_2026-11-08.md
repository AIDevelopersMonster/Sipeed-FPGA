# Tang Nano 20K — RAM Scratch BOARD PASS (2026-11-08)

**Испытание:** ограниченная функциональная проверка заводской SDRAM через BIOS LiteX на реальной плате.  
**Локальное время теста:** 2026-11-08, 13:29:04 (имя файлов evidence).  
**COM:** COM25 · 115200 8N1.  
**Адреса:** `0x40012000–0x4001201F`, восемь 32-битных слов (32 байта).  
**Скрипт:** [`ram_scratch_test.py`](ram_scratch_test.py), запуск с явным `--run --port COM25`.

## Оригинальный консольный вывод оператора

```text
PS C:\Users\74095> & "C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe" "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\ram_scratch_test.py" --run --port COM25
SCRATCH: 0x40012000..0x4001201F, 8 words, 5 phases, saving originals before writes
Factory LiteX BIOS required; close other COM users. No Flash writes.
PASS BIOS prompt and expected SDRAM map
BACKUP SAVED BEFORE WRITE: C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\RAM_BACKUP_20261108_132904_001600.json
PASS RAM phase ZERO: 8/8 words
PASS RAM phase ONES: 8/8 words
PASS RAM phase ALT_A: 8/8 words
PASS RAM phase ALT_5: 8/8 words
PASS RAM phase ADDRESS: 8/8 words
RESTORE PASS: originals match 8/8
EVIDENCE: C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\RAM_SCRATCH_20261108_132904_001600.json
RAM SCRATCH BOARD PASS: 8 words x 5 patterns, full readback and original contents restored; NO FLASH / BOOT / IRQ
```

## Проверено и что не следует преувеличивать

- **BOARD PASS:** пять шаблонов `ZERO=0`, `ONES=0xFFFFFFFF`, `ALT_A=0xAAAAAAAA`, `ALT_5=0x55555555`, `ADDRESS=address ^ 0xA5A5A5A5`, каждый на восьми словах, всего **40/40 readback PASS**.
- **BOARD PASS:** исходное содержимое восьми слов восстановлено и считано **8/8**.
- **BOARD PASS:** BIOS prompt, совместимая карта `MAIN_RAM`, создание backup-файла **до** первой записи.
- **Не испытано:** полный объём 8 МиБ, стресс по длительности, IRQ, Timer, временные сигналы шины Wishbone. Результат не распространяется на все возможные SDRAM-адреса.
- **Не выполнялось:** запись FPGA Flash, RAM-boot, программирование FPGA, изменение MMIO/IRQ.
- **Сохранённые локально данные:** `RAM_BACKUP_20261108_132904_001600.json` и `RAM_SCRATCH_20261108_132904_001600.json`. Их содержимое не передавалось в разговор, поэтому в GitHub зафиксирован **представленный консольный вывод**, а не непросмотренный JSON.

**Заключение:** `RAM_SCRATCH_32B_5_PATTERNS_40_OF_40_BOARD_PASS_AND_RESTORE_8_OF_8_PASS`. В пределах согласованного минимального комплекта RAM направление закрыто. Далее — идентификация/испытание Timer и IRQ или запись документированного ограничения с переходом к примерам платы.
