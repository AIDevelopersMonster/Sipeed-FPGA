# TP20 — расширенный анализ сторонних проектов для Tang Nano 20K

**Дата анализа: 2026-11-10** · **Метод:** чтение upstream README и конкретных Verilog/VHDL/Z80/C++ файлов через GitHub. **Состояние:** SOURCE-CHECKED; никакая чужая FPGA-конфигурация пока не испытана на нашей плате. Основная LiteX/PiKoSoL не изменяется.

[← Главная TP20](README.md) · [Запуск nano-Z80](NANO_Z80_QUICK_DEMO_RU.md)

## 1. Цели и критерии

Мы изучаем **готовые альтернативные системы-на-кристалле**, не пытаясь немедленно интегрировать их в LiteX. Цель первой демонстрации — 5 проверяемых эффектов: ROM-monitor на HDMI, ROM-monitor на COM, ввод ASCII-команд с Windows, чтение машинных данных через монитор, изменение onboard LED. Никаких периферийных устройств на разъёмах (кроме HDMI, штатного USB-C/USB→UART). SD и USB-host не требуются.

**Критерии повторного использования источников:** автономность IP, документация интерфейса, соответствие нашей RISC-V Wishbone/CSR шине, доступность тестов, оценка CDC и частот, лицензия каждого заимствованного блока. Историческое наличие фичи не есть гарантия её исправности.

## 2. nano-Z80: реальная архитектура из исходников

Upstream: https://github.com/venomix666/nano-z80

| Подсистема | Исходник | Фактическая организация | Инженерная ценность |
|---|---|---|---|
| Z80 CPU | [src/TV80-verilog/tv80_core.v](https://github.com/venomix666/nano-z80/blob/main/src/TV80-verilog/tv80_core.v) | Процессор TV80 (Z80) | Сопоставление циклов шины, WAIT и IRQ с VexRiscv/PicoRV32 |
| Общая SoC | [src/nano-z80_top.v](https://github.com/venomix666/nano-z80/blob/main/src/nano-z80_top.v) | CPU, ROM, UART, MMU, SDRAM, видео, SD, PIC, таймер | Учебный разбор схемы связей без необходимости готового CPU-модуля |
| Декодер | [src/addr_decoder.v](https://github.com/venomix666/nano-z80/blob/main/src/addr_decoder.v) | Порт 0x7F выбирает bank I/O; фиксированные 0x70..0x77 остаются доступными | Пример «общих портов» отладки в банковом интерфейсе |
| MMU | [src/mmu.v](https://github.com/venomix666/nano-z80/blob/main/src/mmu.v) | Четыре окна по 16 KiB, каждое выбирает одну из 512 страниц по 16 KiB = 8 MiB | Учебная модель адресного отображения и банков |
| SDRAM | [src/sdram_z80.v](https://github.com/venomix666/nano-z80/blob/main/src/sdram_z80.v) | FSM команд SDRAM, WAIT генерация, теговый кэш чтения 32 бит | Как скрыть latency SDRAM у медленного CPU; изучить read/write coherence |
| UART | [src/UART/uart.v](https://github.com/venomix666/nano-z80/blob/main/src/UART/uart.v) | Два канала, у A 115200, кольцевые буферы RX по 256 байт, RX IRQ | Потоки ввода/вывода и применение FIFO |
| HDMI / terminal | [src/video/video.v](https://github.com/venomix666/nano-z80/blob/main/src/video/video.v) | 640×480@60, 80×30 текст, 4 экранных буфера, 160×120×8 и 320×200×8 | Приоритет №1 для будущего PiKoSoL HDMI terminal |
| DVI | [src/dvi_tx/dvi_tx.v](https://github.com/venomix666/nano-z80/blob/main/src/dvi_tx/dvi_tx.v) | Сборка TMDS выходов | Учебный разбор генератора видео и трансмиттера |
| Прерывания | [src/pic.v](https://github.com/venomix666/nano-z80/blob/main/src/pic.v) | 8 линий, статический приоритет, Z80 IM2 | Разобрать входные IRQ и vector acknowledge |
| SD | [src/sdcard/sd_rw.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sd_rw.v) | Низкоуровневый SD контроллер | Только анализ, в первой демонстрации отключён |
| ROM monitor | [romcode/nano-z80.z80](https://github.com/venomix666/nano-z80/blob/main/romcode/nano-z80.z80) | Монитор с M/W/J/O/I/B/L/F/T, баннер и интерпретатор | Прекрасный учебный пример ROM BIOS/Monitor |
| Ввод | [romcode/read.z80](https://github.com/venomix666/nano-z80/blob/main/romcode/read.z80) | Одновременно UART и keyboard (polling) | Показывает, что ПК заменяет физическую клавиатуру |
| Печать | [romcode/print.z80](https://github.com/venomix666/nano-z80/blob/main/romcode/print.z80) | Один ASCII вывод на UART A и HDMI TTY | Главный приём, прямо применимый в PiKoSoL терминале |
| TTY ROM | [romcode/tty.z80](https://github.com/venomix666/nano-z80/blob/main/romcode/tty.z80) | Ожидает busy=0, затем пишет символ в TTY порт | Разделение транспортного API и механизма отображения |

### Что подтвердилось

1. Наличие загрузочного монитора в ROM: старт с печатью `nano-Z80 monitor v0.3`, далее `Ready`; это не CP/M и для меню/памяти SD не нужен.
2. По исходникам команда `M0000,0040` должна выполнить ROM dump, `I7F,01` чтение IO-bank, `O7F,00` и `O00,xx` — управление светодиодами. Поскольку `romcode/print.z80` пишет в два канала, HDMI и COM должны показать одинаковые строки.
3. Изначальный `io_bank=0` после reset (при отсутствии последующих переключений). Текущий банк рекомендуется читать, а не предполагать.
4. По `memtest.z80` тест `T` не проверяет данные после записи: `mem_test_read: ret`. Поэтому рекламировать `T` как подтверждение RAM нельзя.
5. Upstream README предупреждает о glitchy direct access к видеопамяти в text mode (тайминг); последовательный ROM TTY — более безопасная линия демонстрации.
6. Верхний LICENSE — BSD-2-Clause; компоненты сторонних IP (TV80, USB-HID, SD, ROM font и т.д.) требуют своей лицензионной проверки.

### Чем nano-Z80 отличается от PiKoSoL 20K

Наш заводской LiteX использует **VexRiscv_Min @ 48 MHz**, системную шину **Wishbone/CSR** и собственные программы в SDRAM, а nano-Z80 использует 8-битный CPU, 16-битные адреса, банки I/O и 16 KiB MMU-окна. Прямой перенос RTL/регистров в Wishbone без адаптации невозможен. Идея **TTY API**, программный ROM monitor, организация текстовых буферов и SDRAM WAIT/cache подходят как учебные кейсы и возможные спецификации для нового модуля.

## 3. tangyRiscVSOC: наиболее богатая SoC для дальнейшей архитектурной ревизии

Upstream: https://github.com/qubeck78/tangyRiscVSOC

| Подсистема | Исходник | Что увидели | Потенциальное использование |
|---|---|---|---|
| Top-level | [src/tangyRiscVSOCTop.vhd](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/tangyRiscVSOCTop.vhd) | Структура SoC, generic выбора UART | Топология процессор–периферия |
| Blitter | [src/blitter.vhd](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/blitter.vhd) | Отдельные CPU- и DMA-интерфейсы, параметр inst3DAcceleration | Долгосрочный приоритет для PiKoSoL GPU |
| Видео | [src/pixelGenGfx.vhd](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/pixelGenGfx.vhd) | RGB generator, line buffering, DMA запросы, 320×240/640×480 modes | Архитектура графического пайплайна |
| Арбитраж SDRAM | [src/sdramController.vhd](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/sdramController.vhd) | Канал 0 видео, 1 audio DMA, 2 blitter, 3 CPU | Лучший учебный образец многоканального доступа к памяти |
| CPU-side API | [src/software/gfxLib/bsp.h](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/software/gfxLib/bsp.h) | MMIO структуры блиттера, UART, SPI, audio, FPALU | Контракт управления ускорителями из C/C++ |
| Demo | [src/software/fractal/main.cpp](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/software/fractal/main.cpp) | Mandelbrot на графической подсистеме | Учебный тест производительности |
| Boot | [src/software/bootloader/main.cpp](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/software/bootloader/main.cpp) | UART-загрузчик | Альтернативная модель загрузки приложений |

В **bsp.h** перечислены blitter modes: fill, copy, transparent mask, Gouraud triangle, textured triangle, textured+lighting, alpha copy, scale copy; среди регистров — source/destination, modulo, width/height, alpha, z-buffer и scaler delta. Это подтверждает **предусмотренные программные функции**; их производительность, корректность/ресурсы и аппаратный PASS нами не измерены.

Автор говорит, что **большинство приложений требуют данные на SD**, а для части нужны USB keyboard и загрузчик второй стадии. Установка должна начинаться с независимого UART-примера и контроля внешних PLL 25/12 MHz. Без проверки bitstream, bootloader и отсутствия SD-зависимостей **не делаем его первым demo**. Не предлагаем GPIO USB-host.

## 4. Каталог решений, которые можно применить позже

| Идея | Кандидат | Приоритет | Необходимая независимая проверка |
|---|---|---|---|
| Единый printf на UART и HDMI | nano-Z80 print.z80 + tty.z80 | P1 | Для LiteX реализовать слой putchar и busy timeout; собственная CDC |
| Текст 80×30, буферизация и scroll | nano-Z80 video.v | P1 | Видео тайминги, BSRAM бюджет, стабильность direct VRAM |
| Встроенный монитор и команды диагностики | nano-Z80 ROM code | P1 | Наш RV32 ISA, memory map, безопасные read/write ограничения |
| MMU окна и банковое адресование | nano-Z80 mmu.v | P2 (учебный) | Разница Z80 vs RV32, memory protection отсутствует |
| SDRAM 32-bit read caching + wait | nano-Z80 sdram_z80.v | P2 | coherence, refresh, CDC, измерение latency |
| 2D blitter / scaling | tangySOC blitter.vhd / bsp.h | P1 research, P3 integration | Wishbone bridge, отдельный DMA arbiter, resource & timing |
| Параллельный DMA видео/audio/CPU | tangySOC sdramController.vhd | P2 research | Приоритеты каналов, задержки видео, фреймбуфер |
| MMIO C API графики | tangySOC gfxLib | P1 research | Документировать регистры, оценить portability |
| IRQ/Timer | nano-Z80 pic.v/timer | P2 | Сравнить с LiteX EventManager и RISC-V IRQ |
| SD storage | nano-Z80 sd_rw, tangySOC SPI | P3 | Только при наличии поздней задачи, первая демонстрация без SD |

## 5. Риски / открытые вопросы

- **CLOCK**: nano-Z80 требует O0 25.175 MHz и O1 12 MHz; изменение генератора `pll_clk` надо оформлять отдельно от битстрима. Не сохранять PLL-команды в постоянные настройки без восстановления.
- **BITSTREAM**: мы изучили репозиторий, но файл релиза и его SHA-256 ещё не получены на стенде. Проверить с Windows-скриптом.
- **SRAM**: загружать только без `-f`, иначе перезапись Flash нарушает политику проекта.
- **BOARD TEST**: никаких скриншотов реальной платы / UART логов этого стороннего SoC от оператора нет; статус NOT TESTED.
- **TTY**: известная upstream проблема direct text video memory access; использовать стандартный монитор для теста.
- **RAM TEST**: `T` не годится как полноценная приёмка из-за отсутствия readback.
- **LICENSE**: BSD-2-Clause nano-Z80 на верхнем уровне не означает, что каждый включённый сторонний IP можно беспрепятственно перепубликовать без анализа исходных условий; не копируем сторонние файлы в наш repo.
- **INTEGRATION**: PiKoSoL 20K и сторонние Z80/6502/RISC-V bitstream несовместимы как одновременно запущенные FPGA образы. Замена SRAM-образа не объединяет подсистемы.
- **UPSTREAM CHANGES**: ссылки на main могут измениться; квитанция фиксирует полученный upstream commit и SHA256 .fs.

## 6. Вывод

**На сегодня практический выбор — nano-Z80 ROM monitor**: HDMI + PC UART без SD и клавиатуры. Для перспективных PiKoSoL разработок **tangySOC blitter/DMA** архитектурно интереснее, но это самостоятельная программа изучения, не входящая в быстрый запуск. Это не признание аппаратной исправности сторонних конфигураций.

**Урок для FPGA-разработки:** даже простая команда `M0000,0040` демонстрирует весь тракт «ПК → UART RX → ROM parser → шина CPU → ROM read → UART TX и HDMI text», а потому один короткий опыт проверяет множество функциональных блоков.

## 7. Источники и статус сохранения

- [nano-Z80 README](https://github.com/venomix666/nano-z80/blob/main/README.md), [LICENSE](https://github.com/venomix666/nano-z80/blob/main/LICENSE), [ROM monitor](https://github.com/venomix666/nano-z80/blob/main/romcode/nano-z80.z80), [video](https://github.com/venomix666/nano-z80/blob/main/src/video/video.v), [SDRAM](https://github.com/venomix666/nano-z80/blob/main/src/sdram_z80.v)
- [tangyRiscVSOC README](https://github.com/qubeck78/tangyRiscVSOC/blob/main/README.md), [blitter](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/blitter.vhd), [SDRAM DMA](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/sdramController.vhd), [BSP API](https://github.com/qubeck78/tangyRiscVSOC/blob/main/src/software/gfxLib/bsp.h)
- Проверенная по GitHub версия источника на дату анализа: nano-Z80 README blob `e9a5f3037abe96c16fe6a23687b4e24ee8e05ebe`; tangySOC README blob `2d7490e7d1ba430755b00b11894ec3c6bc05ccf9`.

Все результаты остаются в `Tang-Nano-20K/Examples/ThirdParty/` и **не меняют** исходную проверенную ветку PiKoSoL.
