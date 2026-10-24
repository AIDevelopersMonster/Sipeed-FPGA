# SD-01: microSD на FPGA без PicoRV32

Самостоятельный аппаратный эксперимент: Tang Nano 9K, microSDHC, встроенный SPI, 115200 8N1. Ни CPU, ни HDMI в SD-зонд **не входят**.

## RTL / протокол

```powershell
& .\examples\peripherals\sd-card\01-sector-read\test.ps1
```

Ожидается `LAB05_SDHC_READ0_TB_PASS: CMD0/8/55/41/58/17, 512 bytes, CRC16`.

## Аппаратная сборка

```powershell
& .\examples\peripherals\sd-card\01-sector-read\build-nano9k.ps1
```

Создаётся `.fs` с отчётами Gowin. **Без автоматической прошивки.** После проверки PnR/STA вручную загружать только в SRAM. Вставьте microSDHC до подачи питания; UART 115200; физическая кнопка **S2** перезапускает зонд.

Реально получено оператором 24.10.2026:

```text
SD PASS SIG=55AA
SD PASS SIG=55AA
```

Последовательность: 80+ SPI clock в начальном состоянии → CMD0 (SPI idle) → CMD8 (check pattern) → CMD55/ACMD41 (ready) → CMD58 (SDHC) → CMD17 LBA0 → data token FE → 512 байт → CRC16 → UART. FPGA pins: CLK 36, MOSI 37, CS 38, MISO 39; интерфейс 3.3 В.

Подтверждено чтение **одного** сектора и CRC; `55AA` — данные из конца сектора, **не доказательство FAT32**. Драйвер multi-LBA и файловая система пока экспериментальные.

Зонд и проверенные исходники сохраняются в `01-PicoRV32/lab05/rtl`, сборочный сценарий — `lab05/tools/build_lab05_probe.ps1`. [Подробная инструкция](../../../../01-PicoRV32/lab05/HARDWARE_PROBE.md). **Зависимость от каталога историческая, CPU реально отсутствует.**
