# Tang Nano 9K — PiKoSoL, лаборатории, процессоры и игры

**Главный каталог всех наших работ с платой Sipeed Tang Nano 9K (GW1NR-9C).** Исходники и документы сгруппированы **в этой папке**; браузерные прошивки, WebUSB, Web Serial и публикация на GitHub Pages остаются также в прежнем `docs/` без единого изменения.

[← Главная Sipeed FPGA](../README.md) · [Отдельный проект Tang Nano 20K](../Tang-Nano-20K/README.md)

## Основные проекты

| Проект | Папка | Состояние |
|---|---|---|
| **PiKoSoL / PicoRV32 / LAB-01—05** | [01-PicoRV32](01-PicoRV32/README.md) · [LAB-04](docs/lab04/README.md) | CPU+HDMI+UART, TERM/GFX, **BOARD PASS** |
| **NEORV32 / LAB-06** | [02-NEORV32](02-NEORV32/README.md) · [CPU сравнение](docs/cpu-comparison/README.md) | Минимальный NEORV32 и W01, **BOARD PASS в указанной области** |
| **LAB-02: светодиоды / HTML** | [LAB-02](docs/lab02/README.md) | UART/LED, **BOARD PASS** |
| **LAB-03: трассировка PicoRV32** | [Bus Trace Observatory](docs/lab03/observatory/README_RU.md) · [QuizLab](docs/lab03/quizlab/README.md) | Аппаратные трассы, 50 учебных вопросов |
| **PiKoSoL v0.2.0 / LAB-04.3.2** | [Документация](docs/lab04/README.md) · [RTL/сборка](01-PicoRV32/lab04/README_v0200_LAB0432_RU.md) | HDMI и WebUSB, **BOARD PASS** |
| **SD-01…SD-08 / LAB-05** | [Все SD-лаборатории](boards/tang-nano-9k/experiments/README.md) · [SD-08](docs/lab04/web-loader/README_SD08_WEB_LAB.md) | Уровни аппаратной готовности различаются |
| **PSRAM / LAB-07** | [Эксперимент PSRAM](boards/tang-nano-9k/experiments/psram07/README.md) | Оценка по отдельной документации |
| **PONG RGB** | [Исходники, сборка, управление](games/pong-rgb/README.md) | **BOARD PASS** |
| **BREAKOUT RGB** | [Исходники, сборка, управление](games/breakout-rgb/README.md) | **BOARD PASS**, опубликован релиз |
| **HOST-00…02** | [HOST-00](experiments/host00-hello/README.md) · [HOST-01](experiments/host01-sector-read/README.md) · [HOST-02](experiments/host02-fat32/README.md) | Отдельные аппаратные работы |
| **Инженерные компоненты** | [Ядра](cores/) · [IP](ip/) · [Общие контракты](common/README.md) · [Периферийные примеры](examples/peripherals/README.md) | Сохранены также исходные общие копии, где нужны другим проектам |

## Действующие браузерные прошивки — НЕ ПЕРЕНОСИЛИСЬ

- **[WebUSB Loader — рабочий адрес](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/)** — FPGA программируется только во временную SRAM
- **[Web Serial — рабочий адрес](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/)** — терминал PiKoSoL
- [Pong — браузерное управление](https://aidevelopersmonster.github.io/Sipeed-FPGA/pong-rgb/)
- [PiKoSoL v0.2.0](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0)

**Защищённое дерево:** старые `docs/` и `.github/workflows/publish-*`, `vendor-pikosol-webusb.yml`. Внутри `Tang-Nano-9K/docs/` находится **копия документации**, а не новый сайт. В новых документах могут оставаться ссылки на прежние GitHub пути; браузерные опубликованные маршруты пока канонические.

## Структура

```text
Tang-Nano-9K/
├── 01-PicoRV32/           CPU и PiKoSoL
├── 02-NEORV32/            второй RISC-V и сравнение
├── boards/tang-nano-9k/   SD-01…08, PSRAM
├── docs/                  копия проектной документации 9K
├── games/                 PONG RGB и BREAKOUT RGB
├── experiments/           HOST-00…02
├── examples/              интерфейсы
├── systems/               PiKoSoL
├── cores/, common/, ip/   собственные и общие модули
├── benchmarks/            измерения
└── tools/                 проверки и подготовка
```

## Границы переноса

`Tang-Nano-20K/`, `03-LiteX-VexRiscv/`, `04-Rocket/`, общие источники для других плат и **вся публикационная инфраструктура GitHub Pages** не затрагиваются. Перестройка путей сама по себе не является новым аппаратным или сборочным PASS; сценарии сборки с жёстко прописанными старыми директориями требуют повторной проверки.
