# Авторский протокол предварительной проверки, 2026-10-19

## Выполнено в среде подготовки архива

- `python3 01-PicoRV32/tools/assemble.py` -> `ASSEMBLE PASS: 33 instructions, 1024 B ROM, labels=4`.
- `python3 01-PicoRV32/tools/test_firmware.py` -> `FIRMWARE MODEL PASS: UART=b'PICO\\n'; steps=45; STATUS=600dcafe; LED=15`.
- Статический контроль: проверено, что XML `.gprj` разбирается, ссылки на локальные HDL и ограничения существуют; единственный намеренно отсутствующий файл — внешний `vendor/picorv32/picorv32.v`.
- Источник CPU зафиксирован по полному SHA; файл ROM генерируется из `boot.S` детерминированно.
- Подписи SHA256 перечислены в `MANIFEST.sha256` для содержимого архива.

## Не выполнялось

- RTL-симуляция на Icarus: `NOT_RUN` — инструмент отсутствует в среде формирования архива.
- Gowin synthesis, place-and-route, STA: `NOT_RUN` — установленный Gowin на пользовательском ПК недоступен отсюда.
- Tang Nano 9K: `NOT_RUN` — физическая плата не подключена к среде формирования архива.
- Бенчмарки: `NOT_RUN` — никаких сравнительных ресурсов и частот нет.

**MODEL_PASS != RTL_PASS != PNR_PASS != BOARD_PASS.**
