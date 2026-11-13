# P01 — tangyRiscVSOC (PicoRV32) на Tang Nano 20K

[← Общий каталог ThirdParty](../../README.md) · [Оригинальный проект qubeck78/tangyRiscVSOC](https://github.com/qubeck78/tangyRiscVSOC)

**Статус на 13.11.2026: SOURCE INSPECTED / BOARD NOT TESTED.**
Мы **не портируем**, не «улучшаем» и не сравниваем с PiKoSoL до воспроизведения наблюдаемого поведения автора. Это рабочая папка независимого исследования, а не копия его кода и не наш аппаратный релиз.

## Зафиксированный первоисточник

- Repository: `https://github.com/qubeck78/tangyRiscVSOC`
- Upstream `main` при регистрации: **`ff364a7d00d5bd830a844092d83aaa961b82bd39`**.
- [README конкретного коммита](https://github.com/qubeck78/tangyRiscVSOC/blob/ff364a7d00d5bd830a844092d83aaa961b82bd39/README.md), [проект Gowin](https://github.com/qubeck78/tangyRiscVSOC/blob/ff364a7d00d5bd830a844092d83aaa961b82bd39/tangyRiscVSOC.gprj), [основной VHDL](https://github.com/qubeck78/tangyRiscVSOC/blob/ff364a7d00d5bd830a844092d83aaa961b82bd39/src/tangyRiscVSOCTop.vhd).
- FPGA: `GW2AR-LV18QN88C8/I7` согласно оригинальному `.gprj`; плата Sipeed Tang Nano 20K.
- Лицензия всего репозитория **не подтверждена** отдельным LICENSE в просмотренном дереве; лицензии отдельных зависимостей требуют проверки до копирования.
- Исходники пока **не копируются** в наш GitHub — ссылки ведут на автора с точной ревизией.

## Что видно в исходниках и документации автора (ещё не наш BOARD PASS)

| Блок | Где смотреть | Что установить наблюдением |
|---|---|---|
| Процессор PicoRV32, шина и загрузчик | [`src/picorv32.v`](https://github.com/qubeck78/tangyRiscVSOC/blob/ff364a7d00d5bd830a844092d83aaa961b82bd39/src/picorv32.v), [`src/tangyRiscVSOCTop.vhd`](https://github.com/qubeck78/tangyRiscVSOC/blob/ff364a7d00d5bd830a844092d83aaa961b82bd39/src/tangyRiscVSOCTop.vhd), [`src/software/bootloader`](https://github.com/qubeck78/tangyRiscVSOC/tree/ff364a7d00d5bd830a844092d83aaa961b82bd39/src/software/bootloader) | UART banner и штатная загрузка программы, без конфигурационной Flash |
| Видео, текст, графика | `src/pixelGenTxt.vhd`, `pixelGenGfx.vhd`, `blitter.vhd`, `textureShader.vhd` | HDMI/видеорежим, 2D/3D пример, совместное отображение |
| Внутренняя SDRAM, DMA | `src/sdramController.vhd`, `src/SDRAM_controller_top_SIP/` | Реальная работа RAM, DMA и ресурсы PnR |
| SD/SPI | `src/spi.vhd` и `src/software/*/SD/` | Только чтение с тестовой FAT32 карты |
| Звук и HID | `src/i2sController.vhd`, `src/usbHost.vhd`, `usb_hid_host.v` | Проверять отдельно, с необходимой периферией |
| Выводы и часы | [`src/tangyRiscVSOC.cst`](https://github.com/qubeck78/tangyRiscVSOC/blob/ff364a7d00d5bd830a844092d83aaa961b82bd39/src/tangyRiscVSOC.cst) и `.sdc` | Проверить все IO, частоты, STA |

В `tangyRiscVSOCTop.vhd` есть переключатели `instBlitter3DAcceleration`, `instFastFloatingMath`, `instHidUSBHost`, `instI2SAudio`. Факт наличия в исходниках **не означает**, что все блоки одновременно разместились и работали в одной конкретной сборке.

## Критические особенности штатного запуска

1. **Внешний тактовый генератор**: автор требует входы `extPllClock25` (25 МГц, pin 10) и `extPllClock12` (12 МГц, pin 11). До настройки проверить текущую конфигурацию и способ её безопасного временного восстановления; не считать их присутствующими автоматически.
2. **UART**: в `tangyRiscVSOCTop.vhd` по умолчанию `useTangUART=false` — это *внешний* UART (TX pin 41, RX pin 42). Для встроенного COM требуется `useTangUART=true` и новый проверенный битстрим. Не путать отсутствие баннера с отказом ядра.
3. **Загрузка программ**: штатная инструкция `make send`; например, `src/software/frameBufferTest/Makefile` вызывает `srecsend prog.rec com3 230400`. Порт и скорость надо проверить на конкретной плате. Демонстрационный `frameBufferTest` выводит 320×240 и текст: это режим примера, не обязательно предел аппаратной платформы.
4. **Опасный пункт upstream**: инструкция second-stage bootloader предлагает `burn .bin` **в конфигурационную Flash по адресу `0x700000`**. **НАМ ЭТО ДЕЛАТЬ НЕЛЬЗЯ.** Только FPGA SRAM, никакой записи во Flash, никакого неизвестного SD-образа на рабочую карту.
5. Дополнительные USB HID и I2S требуют проверки подключения и согласования напряжений; подключать внешнюю периферию только по надёжной схеме.

## Дальнейшие документы

- **[OBSERVATION_PLAN_RU.md](OBSERVATION_PLAN_RU.md)** — максимум пять аппаратных ворот проверки, критерии PASS/FAIL и откат.
- **[AI_REVIEW_BRIEF_RU.md](AI_REVIEW_BRIEF_RU.md)** — единое задание нескольким независимым ИИ после исходного изучения.
- **[OBSERVATION_LOG_TEMPLATE.md](OBSERVATION_LOG_TEMPLATE.md)** — неизменяемая квитанция каждого фактического испытания.

**Сравнение с PiKoSoL отложено** до наблюдения исходного поведения и независимой проверки результатов.
