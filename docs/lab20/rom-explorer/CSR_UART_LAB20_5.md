# PiKoSoL LAB-20.5 — два вида CSR и восстановление UART из ROM

**Дата:** 2026-11-07. **Плата:** Sipeed Tang Nano 20K · заводской LiteX · VexRiscv_Min @ 48 МГц. **Вход:** неизменяемый дамп 128 КиБ (SHA-256 `fac8e6e6f39a22e2995de54c271646687d86ad9802e884b848bcf5b6ec4edb65`) и канонические 32 КиБ (SHA-256 `3347be74e9716744949e572229345c3ea9e74f1740001408b934c0d85c79c5bc`).

## 1. Главное: термин CSR обозначает два разных интерфейса

| Признак | RISC-V architectural CSR | LiteX peripheral CSR / MMIO |
|---|---|---|
| Где находится | Внутри ядра CPU / процессорной логики | Регистры периферийных блоков FPGA |
| Адрес | 12-битное поле внутри инструкции CSR, пример 0x305 | 32-битный адрес в памяти, пример 0xF0003010 |
| Как обращаться | `csrrw`, `csrrs`, `csrrc` и immediate-формы | `lw`, `sw` через обычный адрес данных |
| Тракт | CPU CSR logic | VexRiscv dBus → Wishbone → Wishbone2CSR bridge → UART |
| Функции | Привилегии, исключения, разрешения прерываний | Данные UART, FIFO, события и управление оборудованием |
| Взаимозаменяемость | **НЕТ** | **НЕТ** |

**Типичная ошибка:** `csrrw ..., 0xF0003010, ...` невозможна: аппаратная RISC-V инструкция содержит только **12 бит CSR-номера**, а `0xF0003010` — адрес памяти, требующий `lw/sw`.

## 2. Подтверждённые машинные CSR из заводского ROM

| Номер | Название | Доказательство в нашем ROM | Семантика |
|---|---|---|---|
| `0x305` | `mtvec` | `0x000000C0: csrrw zero,mtvec,a0` | Адрес обработчика trap: 0x00000020, режим direct |
| `0x304` | `mie` | `0x0000011C: csrrw zero,mie,a0` | `0x880` = MTIE (bit7) + MEIE (bit11) |
| `0x300` | `mstatus` | `0x000017C4: csrrsi zero,mstatus,8` | Установка глобального MIE (bit3) |
| `0xBC0` | `CSR_IRQ_MASK` | `0x000017C0`, `0x000047B4–0x000047BC` | Специальная маска входных внешних IRQ в LiteX/VexRiscv, **не стандартный CSR RISC-V ISA** |
| `0xFC0` | `CSR_IRQ_PENDING` | `0x000047DC: csrrs a4,0xFC0,zero` | Специальный регистр ожидающих внешних IRQ |

После сброса кода `mie=0x880`, `mstatus.MIE=1` и `IRQ_MASK bit0=1` одного этого **недостаточно** для прерывания: также должен появиться разрешённый IRQ от периферийного события, и выбранная реализация VexRiscv должна передать его на соответствующий вход.

## 3. Идентификация ранее неизвестного MMIO 0xF0003010

Команды в ROM:

```asm
0x00004780  lui    a5,0x10000          ; SRAM ring buffer state
0x00004784  sw     zero,376(a5)
0x0000478C  sw     zero,372(a5)
0x00004794  sw     zero,368(a5)
0x0000479C  sw     zero,364(a5)

0x000047A0  lui    a5,0xF0003          ; a5 = 0xF0003000 = UART MMIO base
0x000047A4  lw     a4,16(a5)           ; UART_EV_PENDING read
0x000047A8  sw     a4,16(a5)           ; acknowledge/clear currently pending events
0x000047AC  addi   a4,zero,3           ; TX|RX
0x000047B0  sw     a4,20(a5)           ; UART_EV_ENABLE = 3
0x000047B4  csrrs  a5,0xBC0,zero      ; processor-specific IRQ_MASK
0x000047B8  ori    a5,a5,1             ; set bit 0 (UART IRQ)
0x000047BC  csrrw  zero,0xBC0,a5      ; write mask
0x000047C0  jalr   zero,0(ra)
```

Эта последовательность **совпадает по смыслу и порядку** с `uart_init()` версии LiteX, указанной BIOS (`b05c3069`):

```c
uart_ev_pending_write(uart_ev_pending_read());
uart_ev_enable_write(UART_EV_TX | UART_EV_RX);
irq_setmask(irq_getmask() | (1 << UART_INTERRUPT));
```

В оригинальном `UART` два события создаются последовательно: `tx`, затем `rx`, что даёт битовые маски **TX=1, RX=2**.

### Восстановленная часть CSR-банка UART (SoC)

По исходникам и кодовым обращениям:

| Адрес | Название | Доступ и смысл | Основание |
|---|---|---|---|
| `0xF0003000` | `uart_rxtx` | Данные TX при записи, данные RX при чтении | LiteX UART + код ROM |
| `0xF0003004` | `uart_txfull` | Признак переполненной очереди передачи | LiteX UART + `lw` в ROM `0x4748` |
| `0xF0003008` | `uart_rxempty` | Признак пустой очереди приёма | LiteX UART, ожидаемый адрес |
| `0xF000300C` | `uart_ev_status` | Текущий уровень событий UART | LiteX EventManager, ожидаемый адрес |
| **`0xF0003010`** | **`uart_ev_pending`** | **Ожидающие события; запись единицы в бит подтверждает/сбрасывает соответствующее событие** | Прямое соответствие ROM и `uart_init()` |
| **`0xF0003014`** | **`uart_ev_enable`** | **Маска разрешённых событий UART, здесь записано `0x3`** | Прямое соответствие ROM и `uart_init()` |

С учётом типового `csr_paging=0x800` банк имеет индекс `(0xF0003000-0xF0000000)/0x800=6`. В исходниках 2023 также имеются дополнительные статусные регистры TXEMPTY/RXFULL, но конкретный полный автоматически сгенерированный `csr.csv` заводской сборки **пока не получен**.

## 4. Как прерывание UART доходит до ядра

```text
UART PHY / FIFO
       |
       v
EventManager: tx=bit0, rx=bit1
       |
       v
ev_pending & ev_enable         (LiteX MMIO CSR)
       |
       v
UART_INTERRUPT = 0            (назначение линии SoC, подтверждено кодом BIOS)
       |
       v
VexRiscv CSR_IRQ_MASK=0xBC0   (бит 0)
       |
       v
mie.MEIE (bit 11) и mstatus.MIE (bit 3)
       |
       v
Прерывание CPU → mtvec = 0x00000020
```

Отдельные условия могут быть разрешены, но аппаратное IRQ не возникнет без события. Временные задержки, FIFO и автоматическое повторное возникновение событий в программной модели не воспроизводятся.

## 5. Точность модели и запреты

- **Доказано файлом ROM:** конкретные команды, числа и адреса.
- **Высоко подтверждено первичными исходниками:** `0xF0003010` — `uart_ev_pending`; `0xF0003014` — `uart_ev_enable`; TX=bit0 и RX=bit1.
- **Аппаратно проверено 2026-11-07:** `txfull=0`, `rxempty=1`, `ev_status=1`, `ev_pending=0`, `ev_enable=3`, `txempty=0`, `rxfull=0` при семи отдельных чтениях. [См. точный протокол](UART_CSR_HARDWARE_2026-11-07.md). **Остаётся проверить:** полную таблицу `csr.csv`, сигналы IRQ и динамику событий.
- **Не делать:** запись `mem_write` в UART-CSR на заводской плате ради поиска устройства, поскольку это меняет состояние событий и может повлиять на консоль.
- Основная модель ROM Explorer по-прежнему **останавливается перед MMIO**, пока его реальное значение не подтверждено. Отдельный учебный сценарий UART использует *явно выбираемые гипотетические значения*, не выдавая их за аппаратную трассу.

## 6. Безопасная проверка непосредственно на плате (read-only)

В терминале LiteX по COM25 115200:

```text
mem_read 0xF0003004
mem_read 0xF0003008
mem_read 0xF0003010
mem_read 0xF0003014
```

Не читать автоматически блоком весь банк: `rxtx` может иметь побочные эффекты. И не делать `mem_write` на этих адресах. Важно: значения `pending` зависят от текущей активности UART и могут изменяться между чтениями.

## 7. Аппаратное подтверждение CSR (2026-11-07)

Прямые чтения с Tang Nano 20K подтверждают:

| Адрес | Регистры и реальные значения |
|---|---|
| `0xF0003004` | `uart_txfull=0` (очередь не заполнена) |
| `0xF0003008` | `uart_rxempty=1` (очередь приёма пуста в момент чтения) |
| `0xF0003010` | `uart_ev_pending=0` (нет ожидающих событий в момент чтения) |
| `0xF0003014` | `uart_ev_enable=3` (TX/RX разрешены) |

Дополнительные адреса: `0xF000300C` → `ev_status=1`; `0xF0003018` → `txempty=0`; `0xF000301C` → `rxfull=0`. Важное ограничение: `txempty=0` **отличается от прогноза**. По исходникам UART это означает, что при чтении FIFO TX ещё содержала данные. `txfull=0` означает лишь наличие свободного места, а не пустоту очереди. Все значения считаны последовательно, не атомарно.

Результат записан отдельно: [аппаратный протокол и точная расшифровка](UART_CSR_HARDWARE_2026-11-07.md). Нельзя трактовать `txfull=0` как `txempty=1` или `pending=0` как отсутствие событий в прошлом.

## 8. Источники

Исторические исходники ровно той версии LiteX, что указана BIOS (2023-03, `b05c3069`):

- [libbase/uart.c: uart_init()](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/libbase/uart.c)
- [cores/uart.py: регистры и EventManager](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/cores/uart.py)
- [csr_eventmanager.py: события, pending и W1C](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/interconnect/csr_eventmanager.py)
- [Wishbone2CSR bridge](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/interconnect/wishbone.py)
- [RISC-V VexRiscv-specific IRQ mask](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/cores/cpu/vexriscv/csr-defs.h)
- [VexRiscv ExternalInterruptArrayPlugin](https://github.com/SpinalHDL/VexRiscv/blob/master/src/main/scala/vexriscv/plugin/ExternalInterruptArrayPlugin.scala)
- [CPU bus integration](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/cores/cpu/vexriscv/core.py)

**LAB-20.5 result:** `UART_CSR_7_READBACK_PASS / TXEMPTY_ZERO_OBSERVED / FULL_CSR_CSV_PENDING`.
