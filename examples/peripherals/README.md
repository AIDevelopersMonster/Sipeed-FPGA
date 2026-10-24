# Периферийные лабораторные без CPU

| Тема | Входная точка | Фактический уровень подтверждения |
| --- | --- | --- |
| SPI Mode 0 | [SPI-01](spi/01-mode0-byte/README.md) | RTL loopback PASS |
| SDHC + microSD | [SD-01](sd-card/01-sector-read/README.md) | HARDWARE PASS на Tang Nano 9K, LBA0 + CRC16 |
| UART 8N1 | [UART-01](uart/01-8n1/README.md) | независимые RTL testbench; UART в системе аппаратно подтверждён |
| HDMI test card | [HDMI-01](hdmi/01-smoke/README.md) | независимый smoke top; для нового bitstream нужен отдельный hardware gate |

Эти проекты должны запускаться без PiKoSoL и RISC-V. Текущие скрипты обращаются к оригинальному RTL в исторических LAB-04/05; дублированных версий SPI/UART/HDMI мы не создаём. После проверки регрессий переносимый RTL будет физически выделен в `ip/`.

Архитектура: `ip/` — компоненты; `examples/peripherals/` — объяснения и самостоятельные опыты; `systems/` — составные компьютеры; `boards/` — конкретные платы, PLL, CST, SDC.
