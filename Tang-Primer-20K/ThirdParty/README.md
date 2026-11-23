# Сторонние разработки — Tang Primer 20K Dock

Каталог сторонних проектов, которые рассматриваются для испытаний на **Sipeed Tang Primer 20K + Dock (GW2A-18C)**. Это **ссылки и журнал оценки**, а не копии чужих исходников и не список наших аппаратно проверенных прошивок.

**Правила:** оригинальные исходники и лицензии остаются у авторов; не изменяем рабочие PiKoSoL/GPIO/SD-проекты; тестовое программирование FPGA — **только SRAM**, никогда Flash; **BUILD PASS**, **BOARD PASS**, **BUILD FAIL**, **NOT TESTED** различаются. При переходе к следующему проекту сохраняем точную причину остановки, без поспешных выводов об аппаратуре.

## Таблица проектов

| № | Сторонний проект | Назначение | Что доступно / требования | Наш результат |
| --- | --- | --- | --- | --- |
| 01 | [6502 SBC FPGA — rudolfstepan](https://github.com/rudolfstepan/6502-sbc-fpga) | Компьютер T65/6502, EhBASIC, HDMI, UART, microSD, DDR3-видеобуфер | VHDL/Verilog, проект Gowin, образ EhBASIC; `.fs` в проверенном `main` не найден | **BUILD FAIL — остановлен 23.11.2026**: Gowin 1.9.9 Beta-4, ошибка `EX4867`; аппаратного теста не было |
| 02 | [LogicAnalyzer / LA16 — vinhbui2430](LA16/README.md) | 16-канальный логический анализатор; Ethernet UDP; Python GUI PRISM | Готовая авторская `.fs` и открытый RTL; RJ45, PMOD2/3 | **BOARD PASS (Ethernet + GUI), 23.11.2026** — SRAM, ARP и реальный LIVE в PRISM; измерительные входы не проверялись. [Отдельный отчёт и установка](LA16/README.md) |
| 03 | [Tang Primer 20K Starter — terenceang](https://github.com/terenceang/tang-primer-20k-starter) | HDMI/аудио, WS2812, LED, документация распиновки | Открытый Verilog под MIT; наша неизменённая сборка `top.fs` | **BUILD PASS + BOARD PASS (HDMI VIDEO + слышимый AUDIO), 24.11.2026** — подтверждено оператором на TP20 Dock, Gowin 1.9.9 Beta-4, SRAM. [IP-аудит и статья](../../ip/hdmi/terenceang-tp20k-hdmi-audio/README.md); SHA/STA пока не зафиксированы |
| 04 | [Tang MP3 Player — kami4ka](https://github.com/kami4ka/tang_mp3_player) | Аппаратный MP3-декодер без CPU, FAT16/FAT32, PT8211 | microSD и PT8211 на Dock; для полного интерфейса требуется LCD 480×272; open-source Gowin flow | **CANDIDATE / NOT TESTED** |
| 05 | [Z8000 Test — tpaxia](https://github.com/tpaxia/z8000_test) | Z8001/Z8002, тестирование процессорного RTL и сравнение с эмуляторами | Gowin-проекты для Primer 20K; Git-submodules, тестовая среда и UART | **CANDIDATE / NOT TESTED** |
| 06 | [Tang Monitor — kami4ka](https://github.com/kami4ka/tang-monitor) | Приём HDMI и вывод на LCD | Нужны совместимый LCD и HDMI-источник | **CANDIDATE / NOT TESTED** |
| 07 | [Tang Computer — kami4ka](https://github.com/kami4ka/tang_computer) | VexRiscv-SMP / LiteX / Linux | Сложный проект с DDR3, LCD и клавиатурой | **CANDIDATE / NOT TESTED** |

**Примечание:** наличие в чужом репозитории `.fs`, исходников или заявления о работе на плате не означает наш `BOARD PASS`. Не переносить результаты на Tang Nano 20K или Tang Primer 25K.

## 01 — 6502 SBC FPGA: протокол остановки

- **Дата:** 23 ноября 2026 года.
- **Оригинальный репозиторий:** https://github.com/rudolfstepan/6502-sbc-fpga
- **Проверенный upstream-коммит:** `42c11dc941c23ff4b3f84fd606791d285b4311e9`.
- **Локальный проект:** `boards/tang_primer_20k/sbc/project/tang_sbc.gprj`.
- **Запуск сборки:** `gw_sh build.tcl` из `boards/tang_primer_20k/sbc/project/`.
- **Наш инструмент:** `C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_sh.exe`.
- **Требование документации автора:** GowinEDA версии 1.9.12 или новее.
- **Результат:** код возврата 1; `tang_sbc.fs` не получен; до аппаратного тестирования не дошли.
- **RTL не исправляли**, версию Gowin не обновляли, FPGA не перепрограммировали, Flash не трогали.

### Существенные строки журнала

```text
Processing 'vic_fb_ddr3(rtl)'(.../rtl/core/peripherals/vic_fb_ddr3.vhd:42)
ERROR (EX4867) : Left range bound is not constant
    (.../rtl/core/peripherals/vic_fb_ddr3.vhd:540)
ERROR (EX4844) : Netlist 'vic_fb_ddr3(rtl)' remains a black box
    (.../rtl/core/peripherals/vic_fb_ddr3.vhd:42)
GowinSynthesis finish
    while executing "run all" (file "build.tcl" line 64)
```

Оригинальная проблемная конструкция (строка 540):

```vhdl
ln := lane_of(to_integer(unsigned(blit_addr)));
wc_data(ln*8 + 7 downto ln*8) <= blit_data;
```

Переменная `ln` задаёт динамические границы VHDL-среза. **Установленный GowinSynthesis 1.9.9 Beta-4 эту конструкцию отверг**; имеются и другие динамические срезы в этом файле. `EX4844` — последствие ошибки `EX4867`. По этому журналу **нельзя** утверждать, что ошибка связана с неисправной DDR3, платой, UART или HDMI.

**Решение:** эксперименты с 6502 SBC на установленном инструменте прекращены, без подгонки чужого RTL и без установки новой Gowin. При необходимости к проекту можно вернуться отдельно, но сейчас переходим к следующему кандидату.

## 02 — LA16 / LogicAnalyzer: Ethernet + PRISM BOARD PASS (23.11.2026)

**[Отдельная страница проекта: результаты проверки, схема сети, установка и запуск на Windows](LA16/README.md).**

- Авторский `la16.fs` успешно загружен в SRAM, без изменения RTL и Flash.
- Получен ARP-ответ `192.168.15.14 → 06-00-AA-BB-16-16`; оригинальный GUI LA16 PRISM на CHUWI показал `LIVE` и 16 каналов.
- **Измерительные входы CH0–CH15 и декодеры не проверялись**; функция анализатора не заявляется полностью сертифицированной.
- Оператор отметил медленную работу GUI и отсутствие интереса к дальнейшим измерительным тестам. Главный исследовательский интерес — организация Ethernet/RMII, UDP и взаимодействия FPGA с хост-программой.
- Разногласие распиновки CH1 между `docs/WIRING.md` (`D10`) и `la16.cst` (`C12`) остаётся нерешённым: внешние сигналы не подключали.

## 03 — Terence Ang Starter: HDMI + Audio BOARD PASS (24.11.2026)

- [Исходники и закреплённый upstream](https://github.com/terenceang/tang-primer-20k-starter/tree/44674c38d9c10a306fe4a5a5ddf9332bad830847) — исходный HDL без изменений, лицензия MIT.
- Наш Gowin 1.9.9 Beta-4 Education собрал `hdmi/build.tcl` с exit code 0; `top.fs` размером **7 264 150 байт**.
- Пользователь подтвердил изображение с тестовой картинкой и **слышимый HDMI-тон**. Это **BOARD PASS конкретного теста исходной прошивки** (по наблюдению оператора), не универсального IP.
- [Технический разбор HDL и будущие направления](../../ip/hdmi/terenceang-tp20k-hdmi-audio/README.md) и [первый черновик статьи](../../ip/hdmi/terenceang-tp20k-hdmi-audio/ARTICLE_RU.md).
- SHA256 `.fs`, наш STA и отчёт ресурсов пока не сохранены; характеристики 1369 LUT/955 FF/7 BSRAM приводит автор. Без проверки совместного размещения нельзя включить блок в PiKoSoL.
- **Далее по исходному списку №04 — Tang MP3 Player**. Рабочая PiKoSoL, Flash и оригинальный проект не менялись.

---

**Никакие чужие исходники, неработающие сборки или экспериментальные `.fs` в этот каталог не копируются.** Каталог содержит только ссылки, статусы и воспроизводимый диагноз.
