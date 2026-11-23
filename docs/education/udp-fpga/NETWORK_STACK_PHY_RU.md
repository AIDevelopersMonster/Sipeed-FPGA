# Как UDP связан с TCP/IP и физическим Ethernet в FPGA

**Техническое дополнение к статье**, не изменение опубликованного PDF.  
**Публикация:** A. A. Malachevsky, *UDP: From the Transport Protocol to an FPGA Hardware Implementation*, DOI [10.5281/zenodo.24482348](https://doi.org/10.5281/zenodo.24482348) (указан автором 24.11.2026).  
**Статус:** учебная архитектура и пояснения. Не новый аппаратно подтверждённый IP.

## 1. Где находится UDP

**UDP и TCP — два альтернативных протокола транспортного уровня**, оба передают данные посредством IP. Выражение TCP/IP обозначает **семейство протоколов**, а не требование использовать TCP для работы UDP. UDP *не работает через TCP*.

| Уровень / пример | Функция | Кто выполняет на типичной FPGA + Ethernet PHY |
| --- | --- | --- |
| Приложение: команда, датчик, игра | Определяет содержимое сообщения | Наши RTL/PicoRV32/host-приложения |
| **UDP** (L4), либо **TCP** (L4) | Порты, длина, контрольная сумма (UDP); для TCP также соединение, повторы, управление потоком | Логика FPGA или стек CPU |
| **IPv4** (L3) | IP-адреса, маршрутизация, TTL, Protocol=17 для UDP / 6 для TCP, IPv4 header checksum | FPGA/CPU |
| **ARP** (в локальном Ethernet) | Соответствие IPv4-адреса и Ethernet MAC-адреса в одном L2 сегменте | FPGA/CPU (не подмодуль UDP) |
| **Ethernet MAC** (L2) | MAC DA/SA, EtherType, кадр, FCS CRC32, preamble/SFD и межкадровый интервал | Обычно FPGA RTL |
| **RMII** (цифровой интерфейс MAC↔PHY) | Выдача/приём битовых пар с опорной частотой | Пины и RTL FPGA + внешний PHY |
| **Ethernet PHY** (L1) | Линейное кодирование/декодирование, аналоговые передатчик и приёмник, autonegotiation/link | Внешняя микросхема RTL8201F |
| Магнитная развязка, RJ45, кабель | Электрическое соединение и передача дифференциальных сигналов | Плата и кабель |

Для UDP по IPv4 в Ethernet: **EtherType=0x0800**, поле IP **Protocol=17 (0x11)**. Для TCP значение IP Protocol=6. Для ARP отдельный тип Ethernet **0x0806**; ARP не передаётся внутри IP/UDP.

**Вывод:** FPGA не обязан реализовывать TCP, чтобы обмениваться UDP-пакетами с Windows/Linux. Но нужны корректные нижние уровни Ethernet MAC, ARP (для локальной IPv4-сети), IPv4 и UDP.

## 2. Практическая граница цифровой и физической частей

~~~text
                   FPGA (GW2A-18C)
  Application → UDP TX/RX → IPv4 → Ethernet MAC
                             |          |
                             ARP        |
                                        v
                             RMII: TXD[1:0], TX_EN
                                   RXD[1:0], CRS_DV
                                   REF_CLK 50 MHz
                             MDIO/MDC, PHY RESET
                                        |
                        RTL8201F (Ethernet PHY)
                                        |
                      Line coding / analog front end
                                        |
                       Ethernet magnetics → RJ45
                                        |
                       Twisted-pair cable → switch
                                        |
                             PC Ethernet adapter
                                        |
                          Windows IP/UDP stack
                                        |
                        Python GUI / host service
~~~

**RMII — ещё не физический сигнал на витой паре.** Это параллельный *цифровой* интерфейс (Reduced Media Independent Interface) между MAC и PHY. При 100 Мбит/с биты передаются парами: 2 бита за такт 50 МГц ⇒ 100 Мбит/с на направление. Два направления независимы. При 10 Мбит/с PHY и MAC используют предусмотренный RMII режим 10M; ошибочно просто считать любую скорость равной 100 Мбит/с.

- **REF_CLK/TXC:** 50 МГц; направление задаётся конфигурацией PHY/платы.
- **TXD[1:0] и TX_EN:** данные и признак передачи от MAC к PHY.
- **RXD[1:0] и CRS_DV:** данные и признак активности приёма от PHY к MAC.
- **MDC и MDIO:** управляющий интерфейс PHY для регистров, состояния линка, автоопределения скорости, диагностики; **не** поток пользовательских UDP-байтов.
- **PHY RESET:** запуск PHY из определённого состояния.
- Дополнительный **RX_ER** может существовать в PHY; его наличие в реальной схеме и разводке нужно устанавливать по документации платы.

Даташит RTL8201F: [Realtek RTL8201F-VD-CG](https://www.realtek.com/Product/Index?id=3969). В конкретной версии модуля также нужно сверять вариант корпуса/режим RMII, разводку и источники тактовой частоты.

### Что физически делает PHY

Для **100BASE-TX** PHY выполняет кодирование 4B/5B, соответствующую сериализацию, формирование линейных сигналов MLT-3, приём и восстановление тактовой информации, а также согласование параметров линка. Для **10BASE-T** применяется другой способ кодирования, в частности Manchester. Преобразование в сигналы витой пары — не задача UDP и не обязанность обычного MAC. Настоящее подключение к разъёму проходит через трансформаторы/магнитные компоненты согласно схеме платы.

## 3. Что происходит при передаче короткого UDP-сообщения

Пусть FPGA отправляет ASCII-полезные данные PING на IPv4-адрес ПК 192.168.15.15 и UDP-порт 5001.

1. **Приложение** формирует 4 байта PING.
2. **UDP TX** добавляет 8-байтовый заголовок: source/destination port, UDP length=12, checksum. Контрольная сумма UDP учитывает IP pseudo-header (адреса источника/получателя, Protocol=17, UDP length), UDP-заголовок и payload.
3. **IPv4 TX** добавляет обычно 20 байт заголовка без опций: source/destination IP, Protocol=17, Total Length=32, IPv4 header checksum.
4. **ARP** узнаёт Ethernet MAC-адрес ПК для локальной доставки (при отсутствии действующей записи в ARP-таблице).
5. **Ethernet MAC** добавляет destination/source MAC и EtherType=0x0800. Короткий payload Ethernet (здесь 32 байта IPv4-пакета) дополняется **padding до 46 байт**, затем вычисляется Ethernet FCS CRC32. Также формируются preamble, SFD и interframe gap на линии MAC/PHY.
6. **RMII** передаёт поток кадра через 2-битную цифровую шину к PHY.
7. **PHY и трансформаторы** выполняют физическую передачу на RJ45; коммутатор ретранслирует кадр по назначению.
8. **ПК** проверяет Ethernet FCS и IP/UDP заголовки, выбирает UDP-порт 5001, передаёт PING получателю.

Важно: **три разные проверки** — CRC32 Ethernet FCS, IPv4 header checksum и UDP checksum. Они не заменяют друг друга. Отправка UDP не требует TCP-соединения или подтверждения доставки. Если приложению нужен ACK, его придётся спроектировать поверх UDP.

## 4. Что реализуется в RTL

Функциональные блоки предлагаемого минимального аппаратного endpoint:

~~~text
TX:
application FIFO → UDP header/checksum → IPv4 header/checksum
→ ARP next-hop lookup → Ethernet MAC frame/FCS/padding
→ RMII TX → PHY

RX:
PHY → RMII RX → MAC preamble/SFD/frame/FCS check
→ EtherType filter → ARP responder OR IPv4 validation
→ UDP length/checksum/port filter → application FIFO
~~~

Служебные компоненты: конфигурация IP/MAC, PHY MDIO, статус link, RX/TX FIFO, CDC, counters, packet timestamps, ошибки, ARP timeout/retry. На первом этапе допускается фиксированный IPv4, MAC, одна локальная подсеть и один порт. Неподдерживаемые IPv4-фрагменты следует явно отбрасывать, а не пытаться декодировать как полноценные UDP-пакеты.

### Пояснение о 2-битной передаче RMII

Следующая строка — **только концептуальная часть сериализации одного байта**, не готовый Ethernet MAC:

~~~systemverilog
// dibit_index = 0..3; на каждом такте 50 MHz выдаются
// последовательно пары бит [1:0], [3:2], [5:4], [7:6].
assign rmii_txd = tx_byte[2*dibit_index +: 2];
assign rmii_tx_en = frame_active;
~~~

Полноценный передатчик дополнительно содержит FSM потока байтов, preamble, SFD, CRC32 FCS, Ethernet padding, IFG, обработку FIFO, реальное соблюдение RMII таймингов и режима 10/100M. Показанные 2 строки **недостаточны** для получения валидных Ethernet-кадров.

## 5. Связь со стеком TCP/IP на компьютере

**Windows уже содержит полный сетевой стек.** FPGA может выдавать минимально корректный UDP/IPv4/Ethernet пакет, и Windows доставит его Python-программе, слушающей порт. Не нужно реализовывать на FPGA TCP, HTTP или веб-сервер. Точно так же обычный браузерный HTML/JS **не имеет доступа к произвольному UDP-сокету**, поэтому для HTML-панели понадобится host bridge HTTP/WebSocket ↔ UDP.

Для сетей за маршрутизатором нужны дополнительные функции (например, маршрутизация через gateway MAC, адресация подсетей), а для динамического адреса — DHCP; это уже не минимальный локальный endpoint. Для веб-сервера по HTTP/1.1 или HTTP/2 обычным транспортом является TCP. HTTP/3 использует QUIC поверх UDP, но реализация QUIC несоизмеримо сложнее простого UDP-движка.

## 6. Где будут размещены новые компоненты

- **Статья и DOI:** [публикационная карточка](README.md) и [Zenodo 10.5281/zenodo.24482348](https://doi.org/10.5281/zenodo.24482348).
- **Реальный прототип другого автора:** [LA16 Ethernet/UDP](../../../ip/ethernet/la16-udp-reference/README.md), аппаратно проверен **только** FPGA→ПК, не двустороннее управление.
- **Наш будущий самостоятельный UDP IP:** проектирование от L2/L3/L4 и независимые тесты, пока **NOT BUILT / NOT BOARD TESTED**.
- **FPGA прошивки / релизы:** не изменялись в связи с этой публикацией.

## 7. Источники

1. [RFC 768: User Datagram Protocol](https://www.rfc-editor.org/rfc/rfc768).
2. [RFC 791: Internet Protocol](https://www.rfc-editor.org/rfc/rfc791).
3. [RFC 826: Address Resolution Protocol](https://www.rfc-editor.org/rfc/rfc826).
4. [RFC 1071: Computing the Internet Checksum](https://www.rfc-editor.org/rfc/rfc1071).
5. [Realtek RTL8201F family documentation](https://www.realtek.com/Product/Index?id=3969).
6. [Опубликованная статья по UDP на Zenodo](https://doi.org/10.5281/zenodo.24482348).
