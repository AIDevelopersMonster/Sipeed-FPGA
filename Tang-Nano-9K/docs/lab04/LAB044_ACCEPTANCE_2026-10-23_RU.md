# LAB-04.4 — PiKoSoL Browser Programming & Control
## Аппаратная приёмка · 23 октября 2026 года

**Статус: HARDWARE PASS (операторские испытания).** Пользователь подтвердил работу WebUSB-программирования и Web Serial-управления на реальной Tang Nano 9K; затем отдельно подтвердил исправленную автоматическую загрузку `.fs` с GitHub Pages. Это практические результаты испытания одной установки, **не** независимая проверка на любых компьютерах и не прохождение полного регрессионного тестирования.

Прошивка CPU/HDMI относится к **PiKoSoL v0.2.0 / LAB-04.3.2**. Браузерная среда управления и программирования — **LAB-04.4**. Версия сайта не изменяет двоичный файл FPGA.

## Рабочая система

| Компонент | Фактически использованное решение |
| --- | --- |
| FPGA | Sipeed Tang Nano 9K / Gowin GW1NR-9C |
| Процессор в FPGA | PicoRV32, RV32I |
| Видео | HDMI 640×480, режимы TERM и GFX |
| Испытательный ПК | CHUWI Intel N100, Windows 11, Chromium/Chrome |
| Программатор | браузерный WebUSB, FT2232 Interface A (JTAG), WinUSB |
| Терминал | браузерный Web Serial, FT2232 Interface B (UART), FTDI VCP, 115200 8N1 |
| Конфигурация FPGA | **SRAM only**; Flash не программируется |
| Браузерный движок | локальные в GitHub Pages `bundle.js` + `openFPGALoader.wasm`, пакет `@yowasp/openfpgaloader` версии `1.1.1-182.269` |

## Сценарий без локального Gowin Programmer

1. Открыть [PiKoSoL WebUSB Loader](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/).
2. Нажать **«Получить .fs с GitHub Pages»** или выбрать локальный проверенный `.fs`. Браузер вычисляет SHA-256 и сравнивает с эталоном.
3. Выбрать **JTAG Debugger (0403:6010)** в запросе WebUSB.
4. Нажать **«Загрузить PiKoSoL в SRAM»**. Используется профиль `-c ft2232 -b tangnano9k` без `--flash`. Проверить результат в журнале и на HDMI.
5. Открыть [PiKoSoL Web Control Center](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/). Подключить **USB Serial Port (COMx)**, а не JTAG Debugger.
6. Проверить настоящие ответы PicoRV32 (`INFO`, `LED ?`, `HELP`) и работу LED, `GFX`, `TERM`, `KEYS`, объектов A/B.

Важно: **COM-порт может удерживаться другой вкладкой или программой.** На N100 это было причиной отсутствия порта в списке браузера. Закрытие предыдущей страницы освободило порт; менять ОС или драйверы не потребовалось.

## Протокол подтверждения

| Этап | Итог | Основание |
| --- | --- | --- |
| HTTPS WebUSB / изоляция WebAssembly | PASS | Получен браузерный журнал `WebUSB: true; crossOriginIsolated: true` |
| Правильность локального `.fs` | PASS | Журнал `SHA-256 PASS (3558473 B)` |
| Выбор USB-JTAG | PASS | Журнал `JTAG Debugger (0403:6010)` |
| Загрузка FPGA из первой версии собственного сайта | PASS после исправления | Отзыв оператора о работе настоящего WebUSB-программатора; первая попытка с внешним CDN завершалась ошибкой импорта |
| Локальный WebAssembly на GitHub Pages | CI PASS | [GitHub Actions — vendor runtime](https://github.com/AIDevelopersMonster/Sipeed-FPGA/actions/runs/39922886452) |
| Автоматическое получение `.fs` с GitHub Pages | PASS (отзыв оператора) | После устранения CORS-зависимости пользователь подтвердил работу кнопки |
| Доставка `.fs` на GitHub Pages | CI PASS | [GitHub Actions — publish verified firmware](https://github.com/AIDevelopersMonster/Sipeed-FPGA/actions/runs/39927282490) |
| Web Serial → CPU / светодиоды / HDMI | HARDWARE PASS (отзыв оператора, фотоматериалы) | Реальные ответы `INFO`, `LED`, `GFX`, индикация и HDMI-графика |

**Различие уровней доказательства:** CI подтверждает публикацию файлов и проверки хэша на сервере, но не физическую работу JTAG. Аппаратный PASS относится к пользовательской установке; он не означает, что все сценарии, другие операционные системы или браузеры прошли испытания.

## Единственный подтверждённый образ FPGA

- Релиз: [pikosol-v0.2.0](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0).
- Файл: `picorv32_lab04_hdmi_nano9k.fs`.
- Размер: **3 558 473 байта**.
- SHA-256: `6862C034715DBF557C93C8F8AF8D8AA856CA8F4E62997660CEA9740F3EFDA356`.
- Копия для сайта: [web-loader/firmware](web-loader/firmware/); публикуется из **проверенного релиза**, а не из неопределённого последнего build.
- Трассируемость версии RTL, STA и firmware: [LAB-04.3.2](README.md).

## Что не утверждается

- PiKoSoL **не является** полноценной ОС: нет файловой системы, процессов и сетевого стека.
- Отсутствуют заявления о полном прохождении стресс-тестирования, всех версий Windows, всех браузеров и всех ревизий платы.
- Двигатель браузера программирует FPGA через USB-JTAG, **не** исполняет RV32I программно.
- Контроль SHA-256 подтверждает соответствие эталонным байтам; не заменяет оценку безопасности чужих битстримов.
- HDMI-заставка внутри образа исторически показывает `v0.1.8b`, несмотря на фактическую версию CPU firmware `v0.2.0`.

## Сохранение и дальнейшее сопровождение

- Основные страницы: [WebUSB Loader](web-loader/README.md) и [Web Serial Control](web-control/README.md).
- Модуль WASM и проверенный `.fs` **уже сохранены** на GitHub Pages и не требуют внешнего CDN при работе программы; внешний GitHub/npm нужен только для обновления соответствующих опубликованных файлов.
- [Workflow доставки WASM](../../.github/workflows/vendor-pikosol-webusb.yml) и [workflow доставки проверенной прошивки](../../.github/workflows/publish-pikosol-pages-firmware.yml) запускаются при изменении собственного файла workflow или вручную. Это не автоматическое слежение за новыми релизами.
- Исходники RTL/firmware в `01-PicoRV32/lab04` и релиз `v0.2.0` при документационной правке **не изменяются**.

