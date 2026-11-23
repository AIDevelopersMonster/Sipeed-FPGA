# Ethernet/RMII/UDP: LA16 как референс IP для PiKoSoL

**Статус: SOURCE REVIEW + BOARD PASS оригинальной LA16 (ограниченный).**  
**Дата:** 23.11.2026. **Плата:** Sipeed Tang Primer 20K Dock (GW2A-18C).  
**Задача:** сохранить проверенный пример обмена FPGA → хост, оценить исходники для возможного двустороннего Ethernet IP и не вмешиваться в работающие прошивки.

> Этот каталог — инженерный референс, **не новая готовая FPGA-прошивка**. Программный мост, UDP-команды от ПК, управление исполнительными устройствами и перенос в PiKoSoL **не построены и не тестировались**.

## 1. Исходники и лицензии

- Автор исходного логического анализатора: Vinh Bui, [vinhbui2430/LogicAnalyzer](https://github.com/vinhbui2430/LogicAnalyzer).
- Зафиксированная версия: **3ad9a7b6a9e54548326d3d261b2c1b3842412661**.
- HDL: [la16_top.sv](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/fpga/rtl/la16_top.sv), [udp.sv](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/fpga/rtl/eth/udp.sv), [packetizer.sv](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/fpga/rtl/packetizer.sv), [sampler_rle.sv](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/fpga/rtl/sampler_rle.sv), [async_fifo.sv](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/fpga/rtl/async_fifo.sv).
- Хост: [source.py](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/host/la16/source.py), [packet.py](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/host/la16/packet.py), [store.py](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/host/la16/store.py).
- [Спецификация авторского UDP-пакета](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/docs/PROTOCOL.md).
- [Наш аппаратный журнал и инструкция для Windows](../../../Tang-Primer-20K/ThirdParty/LA16/README.md).

**Лицензии:** в корне проекта автора MIT © 2026 Vinh Bui. Внутри udp.sv имеется отдельный заголовок Apache-2.0 (LAKKA). При переносе кода надо проверить лицензии всех включённых файлов и сохранить соответствующие уведомления. Здесь публикуются ссылки и анализ, **не копии стороннего HDL**.

Проверенный bitstream автора: **7 262 008 байт**, SHA256 **91248EBB85B87E1FCF38FDC541DAA330708FE3B243DB8D75A69AE27255E36CD1**. Программирование **только SRAM**, не Flash.

## 2. Что в действительности проверено

| Узел | Статус | Доказательство |
| --- | --- | --- |
| Gowin SRAM programming | **BOARD PASS** | 100%, User Code 0x00007196 |
| RMII / RTL8201F / Ethernet ARP | **BOARD PASS** | Ответ 192.168.15.14 → 06-00-AA-BB-16-16 (Reachable) |
| FPGA → CHUWI, UDP/5001 | **BOARD PASS** | Оригинальный PRISM: LIVE, примерно **5 PKT/S** |
| Отключение/возврат Ethernet | **Наблюдалось** | NO SIGNAL при обрыве, LIVE после подключения |
| 16 физических измерительных входов | **NOT TESTED** | Дорожки GUI не являются измерением внешних сигналов |
| Частота 175,5 Мвыб/с | **Заявленная в RTL** | Не проверялась независимым генератором/прибором |
| FPGA принимает UDP-команды и управляет GPIO | **NOT IMPLEMENTED** | RX-сигналы в верхнем модуле не используются |
| Независимо перенесённый Ethernet IP | **NOT BUILT** | Не собран и не испытан отдельно от LA16 |
| Пропускная способность/потери под нагрузкой | **NOT TESTED** | У GUI был ненулевой счётчик DROPS; влияние отключения кабеля не отделено |

Стенд: FPGA 192.168.15.14 → коммутатор → CHUWI 192.168.15.15/24. Ethernet на ПК без шлюза, интернет отдельно через Wi-Fi. Служебные 5 пакетов/с согласуются с heartbeat **200 мс** в packetizer.sv.

## 3. Реальная архитектура LA16

~~~text
16 входов PMOD
   → sampler_rle @ 175.5 MHz (выделение изменений 16 каналов)
   → async_fifo, переход 175.5 → 50 MHz
   → packetizer (RLE, seq, overflow, heartbeat)
   → udp.sv (ARP, IPv4, UDP, RMII)
   → PHY RTL8201F → RJ45 → ПК
   → Python UDP receiver → LA16 PRISM
~~~

**Смысл идеи для наших устройств:** передавать изменения, события и статистику, а не копировать все сырые данные. FPGA генерирует события/временные метки; хост строит графики и интерфейс.

Формат UDP payload LA16 (little-endian):

| Offset | Поле | Размер |
| --- | --- | --- |
| 0 | Magic = LA16 | 4 байта |
| 4 | Version = 1 | 1 байт |
| 5 | Overflow flags | 1 байт |
| 6 | Число записей; 0 = heartbeat | u16 |
| 8 | Sequence, растёт и на heartbeat | u32 |
| 12 | Sample rate | u32 |
| 16 | Записи delta u32 + value u16 | по 6 байт |

Максимум **200 записей/UDP**, 1216 байт payload; flush после 5 мс ожидания, heartbeat примерно 200 мс. Это **только формат логического анализатора**, не будущая система команд PiKoSoL. Счётчик DROPS в Python store.py основан на пропуске sequence; команда CLEAR очищает осциллограммы, но не накопленную статистику.

## 4. Анализ возможности обратного канала

В udp.sv уже имеются **RX FIFO и интерфейсы** rx_head_o, rx_head_av_o, rx_head_rdy_i, rx_data_o, rx_data_av_o, rx_data_rdy_i, а также передающий TX интерфейс. При этом в la16_top.sv оба входных ready подключены к константе 1, а данные RX не участвуют ни в одном исполнительном процессе. Оригинальный GUI **пассивно слушает UDP 5001** и не обязан посылать запрос запуска.

**Вывод:** Ethernet RX — архитектурный кандидат, но в LA16 **нет** диспетчера команд, проверки прикладных прав, MMIO-моста, управления приводами или команды смены режима.

### Конкретный риск RX FIFO

В udp.sv около строки 399 находится проверка места в FIFO **заголовков**, использующая указатель FIFO **данных**:

~~~systemverilog
if ((rx_data_fifo_tail + 127 - rx_data_fifo_head_int) % 128 < 4)
    ethernet_resolve_status <= 100;
~~~

Здесь подозрительно использование rx_data_fifo_tail вместо rx_head_fifo_tail. Это **наблюдение статического аудита**, не аппаратно воспроизведённый дефект. До применения входящего UDP нужно проверить полный FIFO RX, граничные состояния, размер пакетов и корректность заголовков в симуляции. Исходящая передача LA16 эту часть не аттестует.

Другие ограничения: IP и MAC фиксированы в la16_top.sv; стек рассчитан на простой локальный Ethernet, а не защищённый сетевой сервис; ready в udp.sv означает готовность PHY, а не успешное принятие прикладной команды. Потери UDP возможны, поэтому удалённое действие должно требовать ACK/тайм-аут/контроль повторов.

## 5. Матрица переноса

| Блок | Интерес | Что предстоит |
| --- | --- | --- |
| RTL8201F RMII / MDIO | Физический Ethernet TP20 Dock | Изолировать board-specific пины, clock/reset |
| ARP / IPv4 / UDP TX | Телеметрия FPGA → ПК | Проверить вне LA16, параметризовать адреса |
| UDP RX | Приказы ПК → FPGA | Исправить/тестировать FIFO, ввести порт-фильтр и parser |
| async_fifo | Согласование периферии с Ethernet | Отдельные CDC/RTL тесты |
| packetizer | Sequence, heartbeat, batching | Новый формат команд и телеметрии, отдельный от LA16 |
| Python UDP receiver | Основа сервиса на Windows | Сделать bridge для HTTP/WebSocket, без прямого UDP из браузера |
| PRISM GUI | Пример красивого desktop UX | Использовать подход к интерфейсу, не обязательно сам GUI |

**Решение:** регистрируем как **REFERENCE / SOURCE REVIEW + исходный аппаратный BOARD PASS**. Ничего не называем готовым переносимым Ethernet IP до отдельной сборки и регрессии.

## 6. Перспективная система

См. [PiKoSoL Host Platform: HTML-приложения, удалённое управление, библиотека 32 ГБ](PIKOSOL_HOST_PLATFORM_RU.md).

Начать предлагается с безопасного аппаратного теста **UDP echo** на отдельной сборке: ПК → FPGA → ПК, затем ACK и только после этого — штатный LED. Существующие PiKoSoL GPIO/SD/HDMI прошивки не меняем; никаких релизов до BOARD PASS, только SRAM.
