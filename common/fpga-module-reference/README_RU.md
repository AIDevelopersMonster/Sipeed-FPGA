# PiKoSoL / KonSol — выбор базовых FPGA-модулей
## Архитектурная ревизия 2026-11-12, v0.1 (решение, НЕ новая прошивка)

**Задача:** использовать одну библиотеку UART, межсоединений, видеотракта, блочного SD и файловых операций как в SoC с Z80/PicoRV32/VexRiscv, так и в самостоятельных логических автоматах без CPU. Не переписывать протестированные модули и не превращать каждую демонстрацию в новую SoC.

### Решение в одной таблице

| Подсистема | Рабочая модель (источник) | Модель для автономной логики | Состояние / границы |
|---|---|---|---|
| UART | [Наш UART-8N1 v1](../../cores/uart-8n1/v1/README.md): независимые TX/RX Verilog | Те же TX/RX + FIFO + кадровый протокол, без CPU | TX/RX из LAB-02 аппаратно проверены в составе; независимый v1 имеет RTL-тесты; **FIFO и протокол не входят в v1** |
| Регистровая шина | **Wishbone B4 Classic, 32 bit, byte strobes** как интерфейс SoC; первый подтверждённый WB-периферийный пример — [EX20-05.16](../../Tang-Nano-20K/Examples/EX20-05-CPU-HDMI/EX20-05-16_RELEASE.md) | FSM Wishbone-master, если нужны общие регистры; при 1–2 блоках допустим прямой ready/valid | WB Classic для управления, НЕ для каждого пикселя или каждого бита UART |
| Потоки данных | Byte/pixel valid-ready, отдельные FIFO / CDC | Точно так же | Не смешивать с транзакциями MMIO; для перехода часов нужны CDC-мосты |
| HDMI / видео | **SimpleVOut** как открытая модульная модель потока, плюс отдельный физический TMDS backend для конкретной Gowin-платы; на 20K также подтверждён [EX20-05.16 Wishbone/video](../../Tang-Nano-20K/Examples/EX20-05-CPU-HDMI/EX20-05-16_RELEASE.md) | Генератор пикселей / текст / спрайты / pattern -> video timing -> TMDS | [PiKoSoL LAB-04 SVO](../../Tang-Nano-9K/01-PicoRV32/lab04/rtl/lab04_svo_hdmi_top.v) — рабочая основа; SVO и vendor-IP НЕ полностью взаимозаменяемы без адаптера и проверки тактов |
| CPU | **CPU опционален**, Z80=TV80 для ретро; PicoRV32 для минимальных RISC-V демо; LiteX/VexRiscv для богатого SoC | CPU отсутствует; функциональные блоки запускает FSM | Нельзя делать Z80 I/O decode системным стандартом для всех проектов |
| SD физический уровень | Наш [SDHC SPI CMD17 v1](../../Tang-Nano-9K/boards/tang-nano-9k/cores/sdhc-spi-readonly/v1/README.md) как первый переносимый блок; отдельная аппаратная модель nano-Z80 SD-native в [sd_rw.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sd_rw.v) | Тот же read_sector(LBA)/512 B с FSM | CMD17 SPI на 9K BOARD_PASS (SD-02). Сравнение SD-native/SPI провести позже, не смешивать оба контроллера |
| Запись SD | [SD-06 CMD24](../../Tang-Nano-9K/boards/tang-nano-9k/experiments/sd06-cmd24/README_RW.md), только защитный ограниченный режим | По умолчанию отсутствует, включается только для тестовой карты | Аппаратный PASS был только для специально утверждённого сектора тестовой карты |
| Файловая система | **FAT32 read-only как основной переносимый формат**, референс [fat32_reader.py](../../cores/fat32-reader/v1/README.md) поверх read_sector(LBA); под CPU может выполняться программно | Для автономной FPGA требуется отдельный ROM/FSM reader: поиск 8.3 → FAT chain → byte stream | Python/PC FAT32 + FPGA LBA физически проверены (SD-05); отдельный ПОЛНЫЙ FAT32 hardware-file-reader не подтверждён |
| CP/M и FUZIX | Системы с собственными блочными драйверами и форматами томов | Не стандарт для других модулей | CP/M диски A:/B: и устройства FUZIX hda/hdb не приравнивать к FAT32 и друг к другу |

### Что в действительности сделано в nano-Z80

Исходники [nano-Z80](https://github.com/venomix666/nano-z80) просмотрены на уровне RTL:
- [TV80](https://github.com/venomix666/nano-z80/blob/main/src/TV80-verilog/tv80s.v) выдаёт классические Z80 сигналы адреса/данных/IORQ/MREQ/RD/WR/WAIT; [addr_decoder.v](https://github.com/venomix666/nano-z80/blob/main/src/addr_decoder.v) выбирает периферию по IO_BANK (порт 0x7F). Это простая эффективная шина **данной Z80-системы**, а не универсальная архитектура IP.
- [uart.v](https://github.com/venomix666/nano-z80/blob/main/src/UART/uart.v) содержит два UART, программные регистры и входные 256-байтные кольцевые буферы. В коде RX-index 8-битный, условие availability — r != w; отдельной проверки заполнения / явного счётчика потерь в этом участке не обнаружено. Поэтому хорошая практическая работа с терминалом — причина **изучить**, но не копировать эту FIFO-обвязку как готовый безусловно lossless контракт.
- [sd_interface.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sd_interface.v) реализует регистры номера сектора, busy и доступ к 512-байтному буферу; [sd_rw.v](https://github.com/venomix666/nano-z80/blob/main/src/sdcard/sd_rw.v) обеспечивает native SD CMD17/CMD24, причём код прямо говорит «not use sddat1~sddat3». **Файловую систему не реализует RTL**: каталоги/файлы — задача софта CP/Mish/FUZIX.
- [video.v](https://github.com/venomix666/nano-z80/blob/main/src/video/video.v) реализует raster 640x480, текст 80x30, символьную память, пиксельную RAM, палитру и регистры; вывод в TMDS через Gowin DVI_TX_Top, зависимый от стороннего/сгенерированного IP. Это рабочий функциональный пример, но не универсальный конструктор видео.
- [mmu.v](https://github.com/venomix666/nano-z80/blob/main/src/mmu.v) делает банковую память Z80; не нужен без CPU.

**Оценка:** nano-Z80 — эталон *интеграции работающего компьютера*, но не канонический репозиторий общих UART/SD/HDMI/FS-модулей.

### Почему именно Wishbone + streams

1. **Wishbone B4 Classic**: открытый стандарт интерфейса регистров. Использован в нашем работающем LiteX/VexRiscv + HDMI overlay на Tang Nano 20K. Позже можно добавить Z80-bus-to-WB и PicoRV32-mem-to-WB. Примитивной логике не нужен CPU: FSM задаёт те же WB-транзакции.
2. **Видеопиксели, UART-байты и SD-байты лучше передавать потоком с valid/ready.** Полноценная MMIO-шина для массовой передачи данных создаёт лишние транзакции. Файловый сервис возвращает поток данных или секторный буфер, а не «заставляет каждый модуль знать FAT32».
3. **Частотные домены отдельно:** системный clk, pixel clk, 5x TMDS, возможная SDRAM. FIFO/handshake и сбросы — обязательные независимые модули.
4. **Блоки не знают тип CPU:** сам UART не знает о Wishbone, программах и SD; свой интерфейс UART-MMIO получает через адаптер. Аналогично HDMI знает о RGB+timing, а не о LiteX; FAT32 знает о read_sector, а не о ногах SD.

Wishbone specification: https://opencores.org/howto/wishbone .
Open SimpleVOut: https://github.com/cliffordwolf/SimpleVOut (ISC); его src содержит svo_enc, svo_tmds, svo_term, svo_tcard, svo_pong; для видео — AXI-stream стилистика.

### Выделенная дорожная карта, без лишних перепрошивок

**A. Уже сейчас (CPU-free/Standalone):** штатный UART v1 + отдельный RX/TX FIFO, маленький автомат команд, SDHC CMD17; после UART демонстрировать фиксированные LBA / MBR / BPB; выводить диагностику в COM. Без CPU/OS.
**B. Затем (CPU-free video):** заменить источник видеоданных тестовой картой, текстовым терминалом и генератором графики; сохранять интерфейс pixel stream, подключать SVO и нужный Gowin backend. Здесь и аналог PicoRV32, и чистая логика работают одинаково.
**C. Файлы:** использовать референс fat32_reader.py для эталонных тестовых образов; разрабатывать *узкий* независимый RTL FAT32-RO с именами 8.3, ограничением размера и цепочкой кластеров, отрицательными тестами; только затем расширять до VFAT LFN.
**D. SoC:** подключить те же IP через Wishbone LiteX или CPU-native адаптер. Для ретро-Z80 сохранить существующий рабочий nano-Z80 и использовать Z80-to-WB адаптер только когда появится конкретная задача.

### Не принимать как доказанный результат

- Нет единого аппаратно проверенного bitstream, где одновременно реализованы все перечисленные слои на 9K или 20K.
- SD-05 FAT32-файлы читаются **программой на компьютере**, получающей физические сектора от FPGA. Это не аппаратный FAT32 reader.
- HDL SD-06 write PASS ограничен одним тестовым scratch-сектором, нельзя разрешать запись метаданных FAT32.
- SVO 9K и 720p Gowin 20K реализуют разные тактовые/video backends. Нельзя просто подменить файлы.
- Любая новая комбинация потребует RTL sim, CDC/STA/PnR и проверки реальной платы. Работающие заводские Flash и карты не изменять.

### Исходные аппаратные протоколы

- [LAB-02 UART TX/RX аппаратная проверка](../../Tang-Nano-9K/docs/LAB02_UART_RX_RU.md).
- [EX20-05.16 LiteX/VexRiscv + UART + HDMI + Wishbone BOARD_PASS](../../Tang-Nano-20K/Examples/EX20-05-CPU-HDMI/EX20-05-16_RELEASE.md).
- [SD-02 LBA без CPU](../../Tang-Nano-9K/README_SD01.md).
- [SD-03 аппаратный MBR/BPB FAT32](../../Tang-Nano-9K/boards/tang-nano-9k/experiments/sd-mbr-fat32/acceptance/SD03_HARDWARE_ACCEPTANCE_2026-10-24.md).
- [SD-05 FAT32 read-through-host, 131073 bytes over five contiguous clusters](../../Tang-Nano-9K/boards/tang-nano-9k/experiments/sd05-lba-bridge/acceptance/SD052_HARDWARE_MULTI_CLUSTER_2026-10-25.md).
- [SD-06 CMD24 limited scratch BOARD_PASS](../../Tang-Nano-9K/boards/tang-nano-9k/experiments/sd06-cmd24/README_RW.md).
- [nano-Z80 BSD-2-Clause](https://github.com/venomix666/nano-z80/blob/main/LICENSE); [TV80 permission](https://github.com/venomix666/nano-z80/blob/main/src/TV80-verilog/tv80s.v); [SVO ISC](https://github.com/cliffordwolf/SimpleVOut). Для сгенерированного DVI/Gowin IP проверить самостоятельные условия распространения.

**Решение:** стандартизировать интерфейсы, а не жестко фиксировать одну реализацию CPU/HDMI/SD. Рабочее ядро периферии должно выполнять полезную функцию при отключённом процессоре.