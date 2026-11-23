# Tang Nano 9K — проверенные результаты и бинарные образы

Это только идентифицированные результаты, а не каталог всех когда-либо созданных файлов.

| Реализация | Аппаратное наблюдение | SHA256 точного файла .fs | Публичный образ |
| --- | --- | --- | --- |
| [PiKoSoL v0.2.0](docs/lab04/README.md) | **BOARD PASS 23.10.2026**: PicoRV32, UART/LED, HDMI | `6862C034715DBF557C93C8F8AF8D8AA856CA8F4E62997660CEA9740F3EFDA356` | [Да](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0) |
| [PONG RGB v1.2](games/pong-rgb/README.md) | Операторский BOARD PASS 26.10.2026, связь фотографии с SHA отдельно не доказана | `978D9BCFF7C1EF1350F88AF2C603A00B7D3BB6325EA39019CA57CF5091639F96` — локальный кандидат | **Нет** |
| [BREAKOUT RGB](games/breakout-rgb/README.md) | Операторский BOARD PASS 26.10.2026, сыгран выигранный раунд | `4CF80DBD008B0D41D4316BF63DB952190C03940A4FFB1FFC00CAB09210AE8789` | [Да](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/konsol-breakout-rgb-v0.1.0) |
| [NEORV32 LAB-06.1](02-NEORV32/README.md) | Ограниченный BOARD PASS 26.10.2026: `NEORV32 READY`, три LED, точная маска не проверена | `3E1DC3EB6DC464E3992C733078A564680D5F279E4D89BAA8A47CB9002246FC5F` | Не подтверждён публичный образ |

Другие подтверждённые *ограниченные* опыты: [LAB-02 UART+HTML](docs/lab02/README.md), [SD-02 четыре LBA с CRC16](boards/tang-nano-9k/experiments/sd-multilba/README.md), [SD-06 запись одного LBA на тестовой карте](boards/tang-nano-9k/experiments/sd06-cmd24/README.md). Их наличие не означает общий релиз бинарного образа.

**Новый LAB-00** — [только исходники](examples/00-led/README.md), **PREPARED / RTL NOT RUN / GOWIN NOT RUN / BOARD NOT RUN**. Не публиковать как релиз до подтверждения на плате.

Для следующего релиза обязательны: commit исходников, Gowin версия, SHA256 .fs, PnR/STA, команда SRAM Program, наблюдения оператора с датой и ограничениями. При другой SHA256 — другая сборка и отдельная приёмка.

[← На главную](README.md)
