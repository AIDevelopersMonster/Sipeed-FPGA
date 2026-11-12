# PiKoSoL — черновые интерфейсные контракты модулей, v0.1

**Статус: предложенный общий ABI для новых проектов, а НЕ существующий RTL стандарт или аппаратный PASS.** Принцип: три независимые плоскости — регистры (WB Classic), байтовые потоки (valid/ready), видеопиксели (pixel-domain); SD LBA как отдельный блоковый сервис.

## 1. Управление: Wishbone B4 Classic, 32 бита

Для CPU-больших SoC:
- CLK, RST, CYC, STB, WE, ADR, DAT_W, DAT_R, SEL[3:0], ACK, ERR.
- Один запрос удерживается до ACK или ERR, **однократное побочное действие на принятую запись**. Без pipeline и без обязательного STALL на первом этапе.
- Каждый модуль имеет уникальный base/size; адреса не переносить автоматически между заводской LiteX и новой SoC.
- Не выполнять MMIO с неизвестного FPGA image: сначала прочитать уникальный регистр ID и VERSION. Для наших разработок пример: EX20-05 Video ID 0x56323031 по 0xB1000000 — только в идентифицированной EX20-05.16.
- В standalone-режиме FSM может напрямую подавать strobes периферии; WB-master нужен только там, где полезен единый регистровый map.
- Адаптеры: Z80 IORQ/RD/WR/WAIT ↔ WB; PicoRV32 mem_valid/mem_ready ↔ WB; LiteX native WB ↔ WB. **Адаптеры отдельные; сейчас не заявлены реализованными.**

## 2. Поток байтов (UART, файл, SD payload)

~~~text
byte_valid   producer -> consumer
byte_ready   consumer -> producer
byte_data[7:0]
byte_last    optional, end of sector/file/frame
~~~

Передача происходит на фронте clk при valid && ready. Producer удерживает byte_data, пока ready=0; при независимых clk используется async FIFO или подтверждённый bundled-data CDC, не непосредственное подключение. Особенности протокола (CRC16, seq, timeout, framing, escape, flow control) — над UART, но под прикладной командой.

UART-v1 имеет start/busy и RX valid; небольшой адаптер превращает их в указанную схему. Отдельный ring/FIFO должен иметь явные overflow и framing-error counters. nano-Z80 UART v0.x имеет 256-byte ring, но без явного full/error в проверенном участке; его не берем за гарантированно lossless интерфейс.

## 3. SD блоковый сервис

~~~text
rd_req_valid, rd_req_ready, rd_lba[31:0]
rd_busy, rd_done, rd_error[7:0]
rd_peek_addr[8:0] -> rd_peek_data[7:0] [sync BRAM]
~~~

Одна команда читает ровно 512 байт. Адрес LBA — физический сектор карты, не номер кластера FAT. Не подавать следующий запрос, пока не получен terminal status; дождаться pipeline-цикла синхронной BRAM. Драйвер SD SPI и native SD допускаются как альтернативные backends одного сервиса — **на FPGA подтверждён SPI/read-only**.

Запись является отдельным API и **отключена в общих сборках**; при появлении необходимости только транзакции с подтверждением старого сектора, ограничением разрешённых LBA и readback. Это не гарантия целостной FAT32.

## 4. Файловый сервис поверх SD

Рекомендуемый первый hardware-режим — только чтение, короткие имена FAT32 (8.3), один активный запрос, bounded resources:

~~~text
open_req(name_8_3[11]) -> open_done, found, file_size
read_request(count)   -> byte_valid / byte_ready / byte_last
close                  -> status
~~~

Проверять MBR/VBR (или отдельно разрешённый superfloppy-режим), геометрию раздела, BPB, FAT chain, EOC, cluster loops, выход за границы; запрещать запись каталога/FAT. Размер имени, поддержка вложенных каталогов, LFN и максимальные размеры должны быть явной спецификацией каждой версии. Не выдавать Python reader за RTL. Отдельно возможна CPU-реализация FAT32, вызывающая тот же LBA service.

Формат CP/M image и FUZIX filesystem являются **другими файловыми реализациями поверх блочного устройства**. Физические адреса их томов обязаны задаваться в менеджере разделов/образов, не хардкодить то, что видно на дисках A:/B: в CP/M.

## 5. Видео / HDMI

Внутренний контракт пиксельного тракта:

~~~text
pix_clk, pix_reset
pix_de, pix_hsync, pix_vsync
pix_r[7:0], pix_g[7:0], pix_b[7:0]
frame_start, pix_x, pix_y [for optional overlay]
~~~

Либо эквивалентный интерфейс SVO AXI-stream с valid/ready/tuser на источниках и композиторах. Вывод TMDS — последний **board-specific** слой, отделённый от генерации шрифта, текста, framebuffer или объектов. Нельзя использовать пиксельную шину для MMIO; обновления сцен — через staging + COMMIT + CDC + применение на начале кадра, как у EX20-05 video_wb_overlay.v.

Первый режим: встроенная test card + text/graphics overlay без внешнего SDRAM. Полноценный framebuffer или DMA в SDRAM — самостоятельный проект после оценки пропускной способности, доступа/арбитража и clock domains.

## 6. CPU не является частью периферийных модулей

CPU — optional plug-in:
- **TV80 Z80:** существующая nano-Z80 сохранена как рабочий учебный компьютер; оригинальные I/O ports 0x7f/0x70 и т.д. остаются ABI только этого проекта.
- **PicoRV32:** компактная система, CPU-native simple memory req/ack; собственный адаптер для общих регистров.
- **LiteX VexRiscv:** WB B4/CSR, SDRAM, BIOS, пригоден для большого SoC.
- **No CPU:** FSM, таймеры, ROM sequencing, fast paths. Ни одна команда UART, SD или видео не должна требовать CPU для базовой демонстрации.

## 7. Минимальные критерии перед объявлением общей версии v1

- UART: TX/RX loopback, короткие и длинные burst-потоки, framing error, overflow indication и непротиворечивый backpressure.
- WB: no duplicate write, удержание запроса до ACK/ERR, невалидный адрес/byte select, reset in-flight.
- CDC: независимые часы, backpressure, reset одного домена, тест потери/повтора событий.
- SD: CRC, LBA0 + несколько LBA, init/timeout, error paths, неизменность карточки для read-only.
- FS: двухуровневые каталоги если заявлены, chain crossing, EOC, недопустимые кластеры, проверка фактических байтов с внешним эталоном.
- HDMI: размеры поля, активный интервал, blanking, frame commit, точность тайминга, реальное изображение.
- Независимые тесты: CPU-driven demo и CPU-free demo потребляют один и тот же IP, а не переписанные копии.
- Физическая приемка только после отдельной реализации: Icarus → Gowin STA/PNR → SRAM (не Flash) → журнал и исходный хеш.

При несоответствии пусть сигнализируется ошибка; не замалчивать потерянные байты, выход за пределы файла/сектора, переполнение FIFO и незавершённый сброс.