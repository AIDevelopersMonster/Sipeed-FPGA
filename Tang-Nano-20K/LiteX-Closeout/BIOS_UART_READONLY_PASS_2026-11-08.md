# Tang Nano 20K — LiteX BIOS / UART read-only аппаратный PASS

**Дата/время:** 2026-11-08, 11:53:51 по имени файла, время локального ПК оператора.  
**Плата:** Tang Nano 20K, заводской LiteX BIOS / VexRiscv_Min, UART `COM25` 115200 8N1.  
**Скрипт:** [`closeout_readonly.ps1`](closeout_readonly.ps1), исходный Git SHA скрипта `0dae80932b67e4c7c208601183863503e1d82406`.  
**Исходный журнал на ПК:** `C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\BIOS_READONLY_20261108_115351.txt`.

## Фактический вывод, предоставленный оператором

```text
PS C:\Users\74095> pwsh -NoProfile -File "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\closeout_readonly.ps1" -PortName COM25
PASS BIOS prompt and COM link
PASS mem_list retrieved (inspect log for timer presence)
UART 0xF0003004 = 0x00000000
UART 0xF0003008 = 0x00000001
UART 0xF000300C = 0x00000001
UART 0xF0003010 = 0x00000000
UART 0xF0003014 = 0x00000003
UART 0xF0003018 = 0x00000000
UART 0xF000301C = 0x00000000
PASS UART status CSR seven read-only samples
NO RAM WRITES / NO IRQ ENABLE / NO BOOT / NO FLASH WRITES
Evidence saved: C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\BIOS_READONLY_20261108_115351.txt
```

Вывод был вставлен в сообщение дважды с **тем же именем evidence-файла и тем же временем**: учитываем как **одно** аппаратное испытание, а не две независимые повторные проверки.

## Объём доказанного

- **BOARD PASS:** соединение с заводским BIOS после физического RESET, получение ANSI-нормализованного `litex>`, успешный ответ на `mem_list`.
- **BOARD PASS:** чтение по MMIO семи конкретных адресов UART: `TXFULL=0`, `RXEMPTY=1`, `EV_STATUS=1`, `EV_PENDING=0`, `EV_ENABLE=3`, `TXEMPTY=0`, `RXFULL=0`.
- **Без записи:** в скрипте нет команд `mem_write`, `boot`, записи FPGA Flash или разрешения IRQ. Последовательное чтение MMIO само может влиять на периферийное состояние; `TXEMPTY=0` согласуется с UART-печатью BIOS и предыдущим опытом.
- **Не доказано этой операцией:** отдельные WB-транзакции по тактам, полный RAM boundary/write test, реальный вход в IRQ handler, работа таймера, работа нового браузерного инструмента, исходные Python/Migen тесты LiteX.
- **Таймер:** `mem_list` прочитан, но его полный текст содержится только в локальном файле оператора и в переписке не приведён; **состав таймерной периферии пока UNKNOWN**. Не угадывать MMIO-адрес таймера.

## Связь с существующими результатами

- [2026-11-08: 740/740 SDRAM readback PASS](../06-RV32-RAM-Diagnostics/SDRAM_HARDWARE_PASS_2026-11-08.md).
- [2026-11-08: собственный RISC-V код действительно исполнился](../06-RV32-RAM-Diagnostics/RV32_HARDWARE_EXECUTION_PASS_2026-11-08.md).

**Статус этого документа:** `LITEX_CLOSEOUT_BIOS_UART_READONLY_BOARD_PASS`.  
**Итог шести контрольных направлений:** Wishbone/CSR имеет дополнительный частичный аппаратный PASS, остальные направления продолжаются с их прежними критериями.

Следующий безопасный шаг: получить текст `mem_list` из сохранённого evidence-файла, без повторной диагностики и без записи в FPGA. Затем — выполнить изолированный исходный test suite LiteX на ПК и добавить отдельную квитанцию.
