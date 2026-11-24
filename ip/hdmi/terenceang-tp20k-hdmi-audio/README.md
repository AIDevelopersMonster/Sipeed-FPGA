# Открытый HDMI + Audio IP — Terence Ang / Tang Primer 20K Dock

**Наш результат 24.11.2026: BUILD PASS + BOARD PASS (VIDEO + слышимый HDMI AUDIO, по сообщению оператора).**  
**Стадия выделения повторно используемого IP: SOURCE REVIEW, не независимый интеграционный BUILD PASS.**

## Первоисточник и лицензия

- Репозиторий автора: [terenceang/tang-primer-20k-starter](https://github.com/terenceang/tang-primer-20k-starter).
- Зафиксированный upstream commit: [44674c38d9c10a306fe4a5a5ddf9332bad830847](https://github.com/terenceang/tang-primer-20k-starter/tree/44674c38d9c10a306fe4a5a5ddf9332bad830847).
- [README HDMI](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/README.md); [исходники HDMI](https://github.com/terenceang/tang-primer-20k-starter/tree/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/src); [авторская MIT лицензия](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/LICENSE).
- Автор отмечает происхождение части модулей `src/hdmi/` из собственного проекта Apple_TN20K (тоже MIT). Схемы Sipeed — сторонние материалы, лицензия автора на них не распространяется.
- [`vendor/`](vendor/) содержит **18 неизменённых текстовых файлов**: полную исходную HDL-цепочку HDMI + Audio, `top.v`, `build.tcl`, `.cst`, `.sdc`, оригинальные тестбенчи и `LICENSE`. Все **18/18 Git blob SHA-1 совпадают** с upstream на `44674c38d9c10a306fe4a5a5ddf9332bad830847`. Двоичные изображения `sim/frame.png` и схемы автора не переносились; для практической компиляции они не нужны.
- [**Прокомментированный `hdmi_tx.v` — полный код с 11 русскими разборами прямо внутри файла**](review/hdmi_tx_annotated_ru.v). **НЕ ИСПОЛЬЗОВАТЬ ДЛЯ СБОРКИ:** учебная копия; авторский исходник расположен в `vendor/src/hdmi/hdmi_tx.v`.
- [**Примеры подключения RGB/PCM и план превращения в встраиваемый IP**](INTEGRATION_EXAMPLES_RU.md) — объяснение границ и конкретных доработок для SoC; код не интегрирован и не тестировался.
- Физическая воспроизводимость исходного `vendor/` не означает ни перепроверенного STA для нашего локального `.fs`, ни готового собственного IP.

## Что действительно сделано нами

| Объект | Результат | Основание / ограничение |
| --- | --- | --- |
| Установленный Gowin | **1.9.9 Beta-4 Education** | Старее авторской 1.9.12.04 |
| Компиляция оригинального `hdmi/build.tcl` | **BUILD PASS** | Команда завершилась с exit code 0 |
| Выходной `hdmi/impl/pnr/top.fs` | **EXISTS** | Получен в отдельном временном каталоге |
| Изображение по HDMI на нашей Primer 20K Dock | **BOARD PASS (operator-reported)** | Пользователь подтвердил ожидаемую картинку |
| Слышимый тон через HDMI | **BOARD PASS (operator-reported)** | Пользователь 24.11.2026 подтвердил: «Да именно так и есть звук» |
| Анализатор PCM/ACR, измерение реальных 48 кГц | **NOT TESTED** | Частота известна по RTL/декларации автора, не по нашим измерениям |
| Проверенный SHA256 `top.fs` в журнале | **PENDING** | В присланном выводе значение хеша не видно |
| Собственный отчёт timing/STA и точные ресурсы | **PENDING REVIEW** | Exit 0 не заменяет чтение STA и использования BSRAM/PLL |
| Перенос HDMI IP в PiKoSoL | **NOT BUILT / NOT TESTED** | Не предпринимался |

Стенд: Tang Primer 20K Dock (GW2A-18C), исходники получены `git clone`, зафиксирован указанный коммит, сборка `gw_sh build.tcl` без правок RTL, `top.fs` собран во временном каталоге `%TEMP%\TP20_HDMI_AUDIO_20261124_015924\hdmi\impl\pnr\top.fs`. Программирование по принятой процедуре **FPGA SRAM-only** (`--run 2`); отдельный текстовый журнал успешного программатора пока не приложен. Flash не изменялась.

**Важно:** это аппаратное подтверждение исходного **целого проекта**, а не нашей независимо интегрированной HDL-библиотеки. Официальный релиз в Sipeed-FPGA не создавался и не создаётся без отдельного решения.

## Какие IP-модули особенно интересны

| Upstream | Функция |
| --- | --- |
| [hdmi_tx.v](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/src/hdmi/hdmi_tx.v) | Внешний интерфейс: RGB 24 бит, pixel_x/y, audio_valid, audio_l/r по 16 бит; пакеты HDMI |
| [hdmi_island_scheduler.v](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/src/hdmi/hdmi_island_scheduler.v) | Управление `data islands` в строчном гашении; очередь пакетов |
| [hdmi_data_island.v](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/src/hdmi/hdmi_data_island.v) | Преобразование BCH-защищённых пакетов в TERC4 и guard bands |
| [hdmi_packet_ecc.v](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/src/hdmi/hdmi_packet_ecc.v) | BCH для header и subpackets |
| [hdmi_packets.v](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/src/hdmi/hdmi_packets.v) | PCM audio sample, Audio Clock Regeneration, AVI/Audio InfoFrames |
| [hdmi_tmds_encoder.v](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/src/hdmi/hdmi_tmds_encoder.v) | TMDS-видео, контрольные символы, TERC4 |
| [top.v](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/src/top.v) | Зависящие от платы rPLL 27→135 МГц, CLKDIV /5, OSER10 и TLVDS_OBUF |
| [tone_1k.v](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/src/tone_1k.v) | Тестовый звук 1 кГц; дробное формирование 48 кГц |
| [tb_audio.v](https://github.com/terenceang/tang-primer-20k-starter/blob/44674c38d9c10a306fe4a5a5ddf9332bad830847/hdmi/sim/tb_audio.v) | У автора модель HDMI-приёмника проверяет аудиопакеты, ACR, ECC, синтез звука |

**Параметры авторского теста:** 720×480p/59.94 (CEA VIC 2), RGB + 16-bit stereo LPCM 48 кГц, тест 1 кГц, HDMI Audio Sample / ACR / AVI / Audio InfoFrames. 27 МГц пиксельный такт, 135 МГц сериализация, четыре дифференциальные TMDS-пары через `OSER10` и `TLVDS_OBUF`. Декларируемые автором ресурсы: **1369 LUT, 955 FF, 7 BSRAM**. Это не показатели нашей повторной сборки — собственный resource report ожидает изучения.

**Ценность для памяти:** тест формирует цветные полосы/надпись по координатам пикселей **без полноценного кадрового буфера и DDR3**. Это полезный приём экономии BSRAM для простых графических представлений, но не решение общей проблемы памяти PiKoSoL.

## Опубликованные материалы и аппаратное видео

- **Публикация о HDMI + Audio на Tang Primer 20K + Dock:** [DOI 10.5281/zenodo.24487961](https://doi.org/10.5281/zenodo.24487961) — DOI сообщён автором 24.11.2026; метаданные записи Zenodo отдельно не проверялись.
- **Видеодоказательство аппаратного испытания:** [YouTube Shorts — FPGA HDMI со звуком](https://youtube.com/shorts/_wJnUZaA3g4) — адрес предоставлен оператором 24.11.2026.
- Оба материала относятся к проверенному **оригинальному** проекту Terence Ang, а не к независимо интегрированному модулю PiKoSoL.

## Статья и возможная архитектура

[**HDMI с LPCM-звуком на FPGA: структура, аппаратное воспроизведение и направления модернизации (техническая статья, RU, v0.1 draft)**](ARTICLE_RU.md).

**Условия будущего собственного IP:** отдельная HDL-симуляция и анализ лицензии; раздельный RTL и Gowin-платный/платозависимый wrapper; независимые аудио/видео-потоки с FIFO и CDC; параметризация видеорежима и ACR; честная ресурсная оценка совместно с CPU/UART/GPIO/SD/DDR3; новая прошивка только после разрешения и исключительно **SRAM**.

**Видео:** оператор предоставил запись аппаратного теста в разговоре и сообщил публичную ссылку на [YouTube Shorts](https://youtube.com/shorts/_wJnUZaA3g4). На записи показано HDMI-изображение, пользователь подтвердил слышимый тон. Исходный видеофайл в GitHub не загружали. BOARD PASS привязан к конкретному испытанию и не переносится на другие платы/интеграции.
