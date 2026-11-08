# Tang Nano 20K — `mem_list` аппаратная карта PASS (2026-11-08)

**Источник:** реальная заводская система LiteX BIOS, COM25, 115200 8N1.  
**Файл оператора:** `C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\BIOS_READONLY_20261108_115351.txt`.  
**Команда:** `mem_list`; скрипт [`closeout_readonly.ps1`](closeout_readonly.ps1) выполнял только чтение.

## Оригинальный ответ BIOS

```text
COMMAND: mem_list
mem_list

Available memory regions:

ROM       0x00000000 0x20000

SRAM      0x10000000 0x2000

MAIN_RAM  0x40000000 0x800000

CSR       0xf0000000 0x10000

litex>
```

| Регион | База | Размер | Последний адрес |
|---|---|---|---|
| ROM | `0x00000000` | `0x20000` = 128 КиБ | `0x0001FFFF` |
| SRAM | `0x10000000` | `0x2000` = 8 КиБ | `0x10001FFF` |
| MAIN_RAM | `0x40000000` | `0x800000` = 8 МиБ | `0x407FFFFF` |
| CSR | `0xF0000000` | `0x10000` = 64 КиБ адресного окна | `0xF000FFFF` |

**Подтверждено:** сообщённые BIOS размеры и базовые адреса; в частности, теперь установлен точный базовый адрес SRAM. Это не независимый физический тест всех 8 МиБ RAM.

**Не подтверждено:** наличие или отсутствие таймера. `mem_list` сообщает *регионы*, а не список периферийных блоков внутри `CSR`. В исходнике [LiteX SoCCore исторической версии](https://github.com/enjoy-digital/litex/blob/b05c30690854c462a2e704a22ff895c0055a8265/litex/soc/integration/soc_core.py) у `with_timer` значение по умолчанию `True`, но аргумент `--no-timer` позволяет его исключить. Это не доказательство состава заводского bitstream: для TIMER требуется CSR-карта исходной сборки или отдельная проверка по точно установленным адресам.

**Результат:** `LITEX20_MEMORY_REGION_MAP_BOARD_PASS / TIMER_HARDWARE_UNKNOWN`. Следующий шаг без FPGA: воспроизводимые исходные тесты LiteX; RAM/IRQ/TIMER проверяются отдельно.
