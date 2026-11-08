# LiteX-Closeout — закрытие шести проверок заводского LiteX

[← Tang Nano 20K](../README.md) · [Реестр проекта](../PROJECT_STATE.md)

**Цель:** закрыть ранее согласованные проверки и перейти к примерам HDMI, microSD, кнопок и звука. Новых исследовательских лабораторий здесь не создаём.

| № | Направление | Доказанное | Что ещё требует проверки |
|---|---|---|---|
| 1 | RAM | BIOS memtest 2 МиБ, полный 740/740 readback; **40/40 реальных проверок 8 слов на 5 шаблонах с RESTORE 8/8 PASS (13:29)** | Выборочная SDRAM-проверка закрыта как `BOARD PASS` для 32-байтного scratch, **не полные 8 МиБ**. [Квитанция](RAM_SCRATCH_BOARD_PASS_2026-11-08.md) |
| 2 | Wishbone / CSR | Реальный CPU UART MMIO, SDRAM reads/writes, **read-only 7-CSR PASS 2026-11-08 11:53** | Функциональная матрица и корреляция; отдельный WB waveform не заявлен — [протокол](BIOS_UART_READONLY_PASS_2026-11-08.md), `PARTIAL BOARD PASS` |
| 3 | IRQ | **BOARD RX ISR PASS** — счётчик `rx_produce` в SRAM увеличился на 22/22 и 27/27 байт при вводе команд по UART | Штатный обработчик подтверждён; пользовательский trap/mret отдельно не испытывали. [Квитанция](UART_RX_ISR_BOARD_PASS_2026-11-08.md) |
| 4 | Timer / Boot | RAM `boot 0x40010000` аппаратно работает; `mem_list` подтвердил окно CSR, но **не его устройства** | Timer `UNKNOWN`, требуется конфигурация/CSR-карта или отдельный ограниченный тест; [ответ mem_list](MEM_LIST_HARDWARE_PASS_2026-11-08.md) |
| 5 | Исходные тесты LiteX | **HOST UNITTEST PASS 17/17** на b05c3069 (CSR 4, Wishbone 5, Timer 3, Stream 5) | Пункт выбранного поднабора закрыт. [Фактический операторский вывод](UPSTREAM_UNITTEST_PASS_2026-11-08.md). `test_cpu` / другие тесты не проводились; никакого BOARD PASS это не даёт |
| 6 | Браузер | ROM Explorer v3.3, раздельные MODEL/SOURCE/BOARD, реальная страница Closeout; оператор подтвердил «Работает» | `BROWSER OPERATOR WORKS`; конкретные `help`, `mem_list`, UART CSR и выгрузка журнала ещё не подтверждены скриншотом/логом. [Квитанция](BROWSER_OPERATOR_CONFIRMATION_2026-11-08.md) |

## Выполняем сейчас — только безопасная диагностика BIOS

Закройте терминал COM25 и выполните в Windows PowerShell:

~~~powershell
Set-Location C:\GitHub\Sipeed-FPGA\Tang-Nano-20K\LiteX-Closeout
pwsh -NoProfile -File .\closeout_readonly.ps1 -PortName COM25
~~~

**Оператор подтвердил BOARD PASS 2026-11-08 11:53**, полная квитанция [здесь](BIOS_UART_READONLY_PASS_2026-11-08.md). Скрипт запрашивает приглашение LiteX, `mem_list`, семь уже идентифицированных **статусных** UART MMIO. Результаты сохраняются в `evidence`. **Нет записи RAM, IRQ, boot или Flash.** При ошибке нужен полный лог. Результат одной аппаратной проверки получен; повторно запускать ради этого PASS не требуется. **Полный вывод `mem_list` получен и сохранён:** [аппаратная карта](MEM_LIST_HARDWARE_PASS_2026-11-08.md).

## Выполняем на ПК отдельно от платы — тесты исходного LiteX

~~~powershell
pwsh -NoProfile -File .\run_upstream_tests.ps1
~~~

Создаёт отдельное рабочее дерево с **LiteX b05c30690854c462a2e704a22ff895c0055a8265**, отдельный Python venv, устанавливает LiteX/Migen и запускает upstream тесты **через `unittest discover`**, считая реально выполненные тесты: CSR 4, Wishbone 5, Timer 3, Stream 5. **Первый вариант runner ошибочно запускал файлы напрямую, получив четыре ложных `EXIT=0` (нулевое число выполненных тестов). Этот запуск не засчитывается.** После первой установки зависимостей можно повторить исправленный скрипт с параметром `-SkipInstall`. Если установка зависимостей или тесты падают — записывается `FAIL / ENVIRONMENT`, а не аппаратный PASS. `test_cpu` требует дополнительного `litex_sim`/Verilator и в этом коротком запуске не отмечается как пройденный.

[Оригинальные тесты LiteX](https://github.com/enjoy-digital/litex/tree/b05c30690854c462a2e704a22ff895c0055a8265/test).

## Отложенные действия, требующие отдельного согласованного теста

**RAM запись:** нельзя выбирать произвольный адрес для теста памяти без сведений о занятых BIOS и пользовательских областях. Подготовить scratch-резерв с сохранением слова и его восстановлением. Первое автоматическое сканирование — только чтение.

**IRQ:** не включать прерывания без собственной работающей таблицы обработчиков, ограничителя повторов и восстановления состояния.

**Timer:** `mem_list` уже получен — **четыре области ROM/SRAM/MAIN_RAM/CSR**, таймер там не назван, поскольку команда не перечисляет CSR-периферию. В историческом `SoCCore` таймер включён по умолчанию (`with_timer=True`), но есть `--no-timer`; это предпосылка, не аппаратный PASS. Не читать случайные CSR-адреса и не помечать таймер PASS. [Точный ответ BIOS](MEM_LIST_HARDWARE_PASS_2026-11-08.md).

## Отладка GAO/GVIO в будущем собственном SoC

**Gowin Analyzer Oscilloscope (GAO)** — JTAG-внутрисхемный логический анализатор. **Gowin Virtual Input Output (GVIO)** — виртуальные сигналы управления/наблюдения. Требуют интеграции в собственную FPGA-конфигурацию: к заводскому LiteX нельзя произвольно подключить GAO без такой логики. Документация: [SUG114 / SUG1189](https://www.gowinsemi.com/en/document/main/database/1871/).

## Финиш

Каждый пункт закрываем `PASS`, `FAIL с документом` либо `NOT PRESENT`. Затем — **[Examples](../Examples/README.md)**, без новой цепочки технических лабораторий.

## Коррекция тестового runner (2026-11-08)

В предоставленном оператором протоколе `test_csr EXIT=0`, `test_wishbone EXIT=0`, `test_timer EXIT=0`, `test_stream EXIT=0` фиксируют **успешную установку/импорт модулей, а не PASS тестов**: исторические тестовые файлы содержат классы `unittest.TestCase` без входной точки. Исправленный скрипт использует `python -m unittest discover -s <test-dir> -p test_*.py -v` для каждого файла, проверяет число тестов и строку `OK`, отклоняет `Ran 0 tests`, сохраняет полный stderr/stdout, требует ровно 17 тестов. Исправленный runner **успешно выполнен** на ПК оператора 2026-11-08: `HOST PASS 17/17`; [квитанция и границы](UPSTREAM_UNITTEST_PASS_2026-11-08.md). Python 3.14 и зависимости Migen 2023 года могут выявить ошибки совместимости, которые нужно документировать отдельно.

## Результат реального запуска upstream тестов (2026-11-08 12:38)

`run_upstream_tests.ps1 -SkipInstall` действительно запустил 4 + 5 + 3 + 5 = **17 тестов unittest**, все `PASS`, `exit=0`. Локальный журнал оператора: `C:\GitHub\litex-b05c3069-test\results\SOURCE_TESTS_20261108_123811.txt`. [Квитанция](UPSTREAM_UNITTEST_PASS_2026-11-08.md). Программный пункт закрыт без подключения платы. Остальные пункты RAM, IRQ, Timer и Browser остаются в своих статусах.

## Браузерный стенд — подтверждение пользователя (2026-11-08)

Оператор после предложенного испытания ответил «Работает». Не было предоставлено точных команд, ответов или скачанного лог-файла: отмечаем **доступность и работоспособность по сообщению оператора**, а не бездоказательный полный Web Serial test PASS. [Квитанция](BROWSER_OPERATOR_CONFIRMATION_2026-11-08.md). Для полного закрытия нужен экспорт журнала после read-only `help`, `mem_list`, `UART status`, без каких-либо записей.

## Следующий аппаратный шаг: ограниченный тест RAM с восстановлением

Новый скрипт [`ram_scratch_test.py`](ram_scratch_test.py) проверен **на автономной имитации BIOS — 5/5 SELF TEST PASS**; **реальный `BOARD PASS` получен 2026-11-08 13:29**. [Протокол](RAM_SCRATCH_BOARD_PASS_2026-11-08.md).

- Адреса временной записи: **`0x40012000..0x4001201F`**, восемь слов по 4 байта. Это SDRAM за пределами известных областей LAB-20.6 `0x40010000` и `0x40011000`, но нельзя обещать, что здесь нет каких-либо иных пользовательских данных. Скрипт **сначала сохраняет все восемь слов в отдельный JSON на диске**, проверяет `mem_list` и лишь затем пишет.
- Пять шаблонов: ZERO, ONES, ALT_A, ALT_5, ADDRESS. На каждой фазе пишутся все восемь слов, затем все восемь считываются и сверяются. При любой ошибке скрипт пытается восстановить исходные слова и отдельно проверяет восстановление; при сбое питания автоматическое восстановление невозможно, но **исходный backup JSON сохранён на диске до первой записи**.
- `--self-test` выполняет 5 автономных тестов без COM и без доступа к плате; `--run --port COM25` включает **реальную запись только этих восьми слов SDRAM**, не Flash, не ROM, не CSR, не запуск `boot`, не IRQ.
- Результаты сохраняются в `LiteX-Closeout/evidence/RAM_SCRATCH_*.json` и `RAM_BACKUP_*.json`. **PASS следует признавать только при `hardware_pass=true` и `restore_pass=true`.** Это функциональная выборочная проверка 32 байт, не испытание полного объёма 8 МиБ.

Команды на Windows (при закрытом UART-терминале и заводском LiteX BIOS):

~~~powershell
git -C C:\GitHub\Sipeed-FPGA fetch origin main
git -C C:\GitHub\Sipeed-FPGA-LAB20-6 switch --detach origin/main
& "C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe" "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\ram_scratch_test.py" --self-test
& "C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe" "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\ram_scratch_test.py" --run --port COM25
~~~

Аппаратный PASS получен от оператора: 40/40 шаблонов, полное восстановление 8/8. [Протокол](RAM_SCRATCH_BOARD_PASS_2026-11-08.md). Следующее направление — Timer/IRQ. Для нового запуска нужен полный текст результата. Поскольку это реальная запись RAM, сценарий запускается только **явным `--run`**. Не запускайте его при другой прошивке или работающей RAM-программе.

## ROM-аудит Timer/IRQ и ограниченная аппаратная проверка IRQ

[Результаты дизассемблирования заводского ROM и карта регистров](TIMER_IRQ_ROM_AUDIT_2026-11-08.md). Установлено, что `0xF0002000` используется контроллером/PHY SDRAM, а `0xF0002800` — адрес таймингового блока (возможный Timer); **до подтверждения по generated CSR карте никакие записи по новому адресу не выполняем**.

Следующий тест: [`irq_rx_bios_counter.py`](irq_rx_bios_counter.py), **3/3 mock tests PASS** в изолированной среде, **физический PASS получен 2026-11-08 14:24: 22/22 + 27/27**, [протокол](UART_RX_ISR_BOARD_PASS_2026-11-08.md). Скрипт только отправляет BIOS-команды `mem_list`, `mem_read 0x10000178 4`, `help`, сравнивает два увеличения `rx_produce` на 22 и 27 байт. При наличии точной корреляции — подтверждение работы штатного UART RX ISR с реальной UART, но **не** отдельного пользовательского trap handler / `mret`. В противном случае — `INCONCLUSIVE`, без вывода об отсутствии IRQ.

```powershell
git -C C:\GitHub\Sipeed-FPGA fetch origin main
git -C C:\GitHub\Sipeed-FPGA-LAB20-6 switch --detach origin/main
& "C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe" "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\irq_rx_bios_counter.py" --self-test
& "C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe" "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\irq_rx_bios_counter.py" --run --port COM25
```

## UART RX ISR — BOARD PASS 2026-11-08

Физический запуск `irq_rx_bios_counter.py --run --port COM25` подтвердил два приращения ISR producer-счётчика **22/22 и 27/27 байт**, при этом Flash/MMIO/IRQ_MASK операторским скриптом не изменялись. [Квитанция, точный вывод и ограничения](UART_RX_ISR_BOARD_PASS_2026-11-08.md). **Для штатного UART RX закрыто как BOARD PASS;** персональный обработчик `mret` не заявляем.
