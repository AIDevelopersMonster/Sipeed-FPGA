# Tang Nano 20K — аппаратная корреляция UART RX ISR, BOARD PASS

**Дата по локальному журналу:** 2026-11-08 14:24:54.  
**Стенд:** Tang Nano 20K, заводской LiteX BIOS/VexRiscv_Min, UART `COM25`, 115200 8N1.  
**Скрипт:** [`irq_rx_bios_counter.py`](irq_rx_bios_counter.py) `--run --port COM25`.  
**Локальный JSON:** `C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\IRQ_RX_COUNTER_20261108_142454_736714.json`.

## Дословный вывод оператора

```text
PS C:\Users\74095> & "C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe" "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\irq_rx_bios_counter.py" --run --port COM25
Factory ROM ISR SRAM counter 0x10000178; commands are read-only
PASS BIOS UART RX ISR counter: 22/22 and 27/27 bytes
Evidence saved: C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\evidence\IRQ_RX_COUNTER_20261108_142454_736714.json
```

## Интерпретация и границы

- В уникальном 32-КиБ заводском BIOS ROM процедура ISR около PC `0x4610..0x4634` читает `rx_produce` из SRAM `0x10000178`, увеличивает по кольцу modulo 128 и подтверждает UART RX event через `0xF0003010`. См. [ROM-анализ](TIMER_IRQ_ROM_AUDIT_2026-11-08.md) и исходный LiteX [`libbase/uart.c`](https://github.com/enjoy-digital/litex/blob/b05c30690854c462a2e704a22ff895c0055a8265/litex/soc/software/libbase/uart.c).
- Входные последовательности из команд BIOS вызвали два приращения кольцевого producer-индекса **22/22** и **27/27**. Указанные интервалы и размеры вычислены непосредственно тестером по длине отправленных команд включая CR.
- **Подтверждено:** реальные UART RX события обрабатываются штатным механизмом BIOS; счётчик в SRAM изменяется ожидаемым образом. Статус `UART_RX_ISR_CORRELATION_BOARD_PASS`.
- **Не подтверждено отдельно:** собственный написанный нами trap handler, независимая запись `mcause` внутри trap, измерение конкретной инструкции `mret`/тактовой трассы, аппаратная работа Timer и HDMI/SD.
- **Безопасность:** оператор не запускал `mem_write`, `boot`, программирование Flash и не изменял IRQ_MASK. BIOS штатно выполнял свои внутренние операции.
- **Доказательственная граница:** в переписке есть консольный вывод; содержимое локального JSON не предоставлено и не скопировано в GitHub.

В пределах текущего этапа проверку **работы штатного UART RX IRQ** можно закрыть. Отдельный собственный IRQ handler — будущая разработка единого SoC, не обязательное условие перехода к примерам Tang Nano 20K.
