# PicoRV32 LAB-02 v0.1.0 — два способа запуска / Two operating modes

**Sipeed Tang Nano 9K · Gowin GW1NR-9C · PicoRV32 RV32I · 27 МГц · USB-UART 115200 8N1**

**Аппаратный результат (20.10.2026):** `MODEL_PASS` · `RTL_PASS` · `PNR_PASS` · `STA_PASS` · `BOARD_PASS` · `HTML_HARDWARE_PASS`. По Gowin STA расчётная Fmax составляет **52,522 МГц** при рабочей частоте 27 МГц; setup/hold TNS = 0.

> **ОБЯЗАТЕЛЬНО ПОСЛЕ ПРОГРАММИРОВАНИЯ FPGA: НАЖМИТЕ И ОТПУСТИТЕ КНОПКУ S2 НА TANG NANO 9K.**
>
> Нажимайте **S2 после успешной загрузки `.fs` в SRAM** (`PROGRAMMER_EXIT_CODE=0`), **до проверки UART и подключения браузерной HTML-модели**. Этот шаг нужен в проверенном порядке запуска LAB-02. Если его пропустить, возможен ответ браузера `ACK timeout (2000 ms)`. Успех загрузки битового потока не равен подтверждённой работе прошивки через UART.

## Выберите один из двух способов / Choose a mode

| | **Вариант 1: автономная HTML-модель** | **Вариант 2: HTML ↔ физическая FPGA** |
|---|---|---|
| Нужна плата Tang Nano 9K | Нет | Да |
| Нужен COM-порт | Нет | Да, не занят другими программами |
| Как открывать HTML | Файл `.html` на компьютере | `http://127.0.0.1:8765/...` в Chrome/Edge |
| Светодиод на шаге 14 | Виртуальный на экране | Настоящий на плате |
| Шаг 14 → 13 → 14 | Изменяет модель | Реальный LED гаснет и загорается снова |
| Главная цель | Объяснить 4 инструкции и 19 учебных шагов | Связать учебный шаг с подтверждённым действием PicoRV32 |

**Не путайте два файла:** `PicoRV32_LED1_Interactive_Demo_RU.html` предназначен для автономной модели; `PicoRV32_LED1_Linked_RU.html` — для связи с FPGA по USB-UART.

## Материалы / Documentation

| Материал | Русский | English |
|---|---|---|
| Полные методические указания и протокол | [RU Markdown](../LAB02_UART_RX_RU.md) | [EN Markdown](../LAB02_UART_RX_EN.md) |
| Методические указания, 7 страниц | [PDF RU](PicoRV32_LAB02_Methodical_RU_v1.0.pdf) | [PDF EN](PicoRV32_LAB02_Methodical_EN_v1.0.pdf) |
| Автономная учебная модель | [HTML RU](../interactive/picorv32-led1/PicoRV32_LED1_Interactive_Demo_RU.html) | [HTML EN](../interactive/picorv32-led1/PicoRV32_LED1_Interactive_Demo_EN.html) |
| Связь HTML с физической FPGA | [Linked HTML RU](../interactive/picorv32-led1/linked/PicoRV32_LED1_Linked_RU.html) | [Linked HTML EN](../interactive/picorv32-led1/linked/PicoRV32_LED1_Linked_EN.html) |
| RTL, прошивка, тесты, инструменты | [01-PicoRV32](../../01-PicoRV32/README.md) | [Project home](../../README.md) |

### Общая подготовка: обновите локальный репозиторий

На компьютере, где уже есть `C:\GitHub\Sipeed-FPGA`:

~~~powershell
Set-Location 'C:\GitHub\Sipeed-FPGA'
git switch main
git pull --ff-only origin main
git status -sb
~~~

На **новом** компьютере (только если папка отсутствует):

~~~powershell
git clone https://github.com/AIDevelopersMonster/Sipeed-FPGA.git C:\GitHub\Sipeed-FPGA
Set-Location 'C:\GitHub\Sipeed-FPGA'
~~~

Не очищайте рабочую папку командами `git clean -fd` или `git reset --hard`: они не нужны ни для одного маршрута. В исходной рабочей копии имеются другие неотслеживаемые файлы учебного комплекта; они не должны затрагиваться.

---

# Вариант 1 — автономная HTML-модель (без платы)

**Цель:** изучить последовательность `LUI → ADDI → SW → JAL`, регистры x5/x6, шину памяти, запись в `0x20000000` и активный низкий уровень выхода LED. Это **19 смысловых учебных шагов**, а не потактовая трасса RTL.

### 1. Откройте HTML на русском языке

~~~powershell
Set-Location 'C:\GitHub\Sipeed-FPGA'
$html = (Resolve-Path '.\docs\interactive\picorv32-led1\PicoRV32_LED1_Interactive_Demo_RU.html').Path
Start-Process $html
~~~

Для английской версии вместо этого:

~~~powershell
$html = (Resolve-Path '.\docs\interactive\picorv32-led1\PicoRV32_LED1_Interactive_Demo_EN.html').Path
Start-Process $html
~~~

**Сервер Python, COM-порт и программирование FPGA здесь не используются.**

### 2. Проведите демонстрацию

1. Выберите виртуальный светодиод L1 и нажмите «Сброс».
2. Нажимайте «Шаг →», наблюдая загрузку инструкции из ROM, декодер, регистры и транзакцию MMIO.
3. На **шаге 14** виртуальный светодиод загорится; возвращайтесь назад и вперёд.
4. Проверьте «До свечения», «Авто», а затем L2–L6.

**Ожидаемый результат:** все изменения видны в учебной модели, но **физическая FPGA не управляется**.

---

# Вариант 2 — браузер + настоящая FPGA (Hardware Link)

**Цель:** связать смысловой шаг 14 в HTML с реальным изменением регистра LED в PicoRV32 на Tang Nano 9K. По USB-UART передаётся команда; прошивка выполняет MMIO-запись и чтение, отправляет `L=n`.

**Требуется:** Windows 10/11 с PowerShell 7, Tang Nano 9K с USB-кабелем, Chrome или Edge (Web Serial), установленный Python для HTTP-сервера. Для **новой** сборки дополнительно требуются Gowin Education, Icarus Verilog и скачанный зафиксированный PicoRV32.

## Шаг 1. Убедитесь, что загружена прошивка LAB-02

Если только что успешно запрограммировали плату LAB-02, **не нужно пересобирать проект**: перейдите сразу к **шагу 3 — S2**.

Если FPGA потеряла питание, SRAM-конфигурация могла исчезнуть. Если прошивка ещё не собрана, выполните:

~~~powershell
Set-Location 'C:\GitHub\Sipeed-FPGA'
& .\01-PicoRV32\tools\fetch_picorv32.ps1
& .\01-PicoRV32\tools\test_lab02.ps1 -ModelOnly
& .\01-PicoRV32\tools\test_lab02.ps1
& .\01-PicoRV32\tools\build_gowin.ps1
~~~

Дождитесь `MODEL_PASS`, `RTL_PASS` и успешной сборки Gowin. **Проверьте STA и отчёт PnR**, прежде чем программировать.

## Шаг 2. Программируйте только SRAM (если нужно)

Команды ниже используют проверенный CLI Gowin Education. Они **не записывают конфигурационную Flash**.

~~~powershell
Set-Location 'C:\GitHub\Sipeed-FPGA\01-PicoRV32'
$programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
$fs = (Resolve-Path '.\impl\pnr\picorv32_nano9k.fs').Path
Get-Item $fs | Select-Object FullName, Length, LastWriteTime

& $programmer --device GW1NR-9C --operation_index 2 --fsFile $fs --cable-index 1
if ($LASTEXITCODE -ne 0) { throw "PROGRAMMER_EXIT_CODE=$LASTEXITCODE" }
"PROGRAMMER_EXIT_CODE=$LASTEXITCODE"
~~~

Ожидаемый результат: `PROGRAMMER_EXIT_CODE=0`. Дождитесь полного завершения операции программирования.

## Шаг 3. ОБЯЗАТЕЛЬНО нажмите S2 на плате

**Нажмите и отпустите физическую кнопку `S2` на Tang Nano 9K после программирования SRAM.**

Это самостоятельное действие, которое нельзя заменить сообщением `PROGRAMMER_EXIT_CODE=0`. Именно такой порядок требуется для воспроизведения нашего LAB-02. После S2 прошивка должна перейти к запуску и обработке UART-команд. Её стартовое сообщение — `READY`; если COM откроют позже, увидеть этот баннер необязательно.

**Правильный порядок:**

~~~text
Gowin CLI: PROGRAMMER_EXIT_CODE=0
          ↓
Tang Nano 9K: нажать и отпустить S2
          ↓
Проверка UART: L=n
          ↓
Закрыть последовательный порт проверки
          ↓
Запустить локальный сервер HTML
          ↓
Chrome/Edge: «Подключить COM»
~~~

Если предыдущая попытка закончилась `ACK timeout (2000 ms)`, закрывайте старую вкладку Web Serial, **нажмите S2** и только после этого повторяйте проверку UART.

## Шаг 4. Определите COM-порт

Подключение платы остаётся через её штатный USB-UART, **дополнительный USB-TTL адаптер не нужен**.

~~~powershell
Set-Location 'C:\GitHub\Sipeed-FPGA'
[System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
Get-PnpDevice -Class Ports -PresentOnly -ErrorAction SilentlyContinue |
    Select-Object FriendlyName, Status
~~~

На нашем стенде использовался **COM10**. На другом ПК номер может быть иным. В следующих командах замените COM10 своим.

Перед проверкой COM закройте Serial Monitor, PuTTY/Tera Term, старые вкладки HTML с Web Serial и программы, удерживающие последовательный порт. GUI программатора после прошивки также лучше закрыть, но не следует утверждать без проверки, что он обязательно держит именно COM10.

## Шаг 5. Проверьте UART без браузера

~~~powershell
Set-Location 'C:\GitHub\Sipeed-FPGA'
& .\01-PicoRV32\tools\probe_lab02_serial.ps1 -PortName COM10
~~~

**Ожидаемый вывод:**

~~~text
Connecting to COM10 (115200 8N1), no extra USB-TTL adapter...
  '0' -> L=0  [PASS]
  '1' -> L=1  [PASS]
  '4' -> L=4  [PASS]
  '?' -> L=4  [PASS]
  '6' -> L=6  [PASS]
  '0' -> L=0  [PASS]
LAB02_SERIAL_ACK_PASS
~~~

Этот скрипт быстро переключает светодиоды и **сам закрывает COM** при завершении. Для визуального наблюдения удобно перейти к HTML. Если здесь `ACK timeout`, не переходите к браузеру: сначала проверьте, что вы нажали **S2**, выбрали правильный COM, питание платы не пропадало и действительно загружена LAB-02 (не ранняя прошивка `PICO`).

## Шаг 6. Запустите сервер HTML (окно PowerShell № 1)

~~~powershell
Set-Location 'C:\GitHub\Sipeed-FPGA'
& .\01-PicoRV32\tools\launch_lab02_html.ps1 -Language RU
~~~

Для английской версии используйте `-Language EN`. Ожидается:

~~~text
Open in Chrome or Edge: http://127.0.0.1:8765/PicoRV32_LED1_Linked_RU.html
Serving HTTP on 127.0.0.1 port 8765 ...
~~~

**Не закрывайте это окно:** в нём работает Python HTTP-сервер. Он **не захватывает COM10** и не программирует FPGA. `127.0.0.1:8765` — адрес локального HTTP-сервера, а не COM-порт.

## Шаг 7. Откройте правильную страницу в Chrome/Edge

Откройте браузер Chrome или Edge и **вставьте в адресную строку**:

- **RU:** http://127.0.0.1:8765/PicoRV32_LED1_Linked_RU.html
- **EN:** http://127.0.0.1:8765/PicoRV32_LED1_Linked_EN.html

Альтернативно во **втором** PowerShell (если браузер по умолчанию — Chrome/Edge):

~~~powershell
Start-Process 'http://127.0.0.1:8765/PicoRV32_LED1_Linked_RU.html'
~~~

**Не используйте** вместо локального адреса `file://`, страницу GitHub `blob/main` или автономную модель из варианта 1.

Сообщение сервера `GET /PicoRV32_LED1_Linked_RU.html HTTP/1.1" 200` означает, что файл HTML открыт правильно. `GET /favicon.ico ... 404` — безвредное отсутствие иконки сайта и **не причина ошибки UART**.

## Шаг 8. Подключите COM из HTML

1. Нажмите **«Подключить COM»**.
2. В окне разрешения Chrome/Edge выберите USB-UART вашей платы (в нашем опыте **COM10**).
3. Браузер открывает порт на **115200 8N1** без управления потоком.
4. HTML отправляет символ `?` и ждёт `L=0` … `L=6` от прошивки PicoRV32; при необходимости выставляет LED согласно текущему шагу.
5. После ответа на странице появится сообщение о подтверждённом состоянии MMIO LED.

**Важно:** при сообщении `ACK timeout (2000 ms)` порт **уже открылся**. Это не то же самое, что отказ открыть COM. Следуйте диагностике ниже: в первую очередь проверьте **нажатие S2** и ответ прошивки на запрос `?`.

## Шаг 9. Проведите аппаратный опыт 13 → 14 → 13 → 14

1. Выберите LED L4 (либо другой L1–L6).
2. «Сброс», затем вручную пройдите до **шага 13**: LED ещё выключен.
3. **Шаг 14:** HTML отправит ASCII `4`, PicoRV32 запишет MMIO `0x20000000`, считает состояние обратно, вернёт `L=4`. После подтверждения L4 должен гореть на настоящей плате.
4. **«Назад»** к шагу 13: браузер отправляет `0` и ожидает `L=0`; LED гаснет.
5. **«Шаг →»** опять на шаг 14: команда `4` / ответ `L=4`, LED загорается повторно.
6. Повторите с несколькими LED и проверьте автоматическое выполнение.

**Проверенный результат:** ручной и автоматический режимы, в том числе обратный переход с физическим выключением и повторным включением выбранных светодиодов. Остальные 18 шагов — **учебная реконструкция**, а не чтение реальной трассы CPU.

## Шаг 10. Правильно завершите работу

1. Вернитесь в начало модели, чтобы отправить `0` и получить `L=0` (если нужно выключить все светодиоды).
2. Нажмите в HTML **«Отключить»**, чтобы освободить COM-порт.
3. Закройте вкладку браузера с Hardware Link.
4. В окне PowerShell с сервером нажмите **Ctrl+C**.

Само «Отключить» закрывает COM и **не гарантирует выключения** LED, если перед этим не было отправлено `0`.

---

# Диагностика неполадок

### 1. `ACK timeout (2000 ms)` из HTML

**О чём говорит ошибка:** браузер **уже открыл порт**, но не получил ответ `L=n` за 2 секунды после отправки команды (при подключении — `?`).

**Последовательность действий:**

1. Закройте прежнюю вкладку с аппаратной HTML, чтобы освободить COM.
2. **Если только что запрограммировали FPGA — обязательно нажмите и отпустите S2 на плате.**
3. Проверьте правильный COM и питание Tang Nano 9K; не отключайте плату от USB после SRAM-программирования.
4. Выполните `probe_lab02_serial.ps1 -PortName COM10` из шага 5.
5. Если аппаратный тест прошёл, откройте HTML по адресу `http://127.0.0.1:8765/...` и подключите COM снова.
6. Если тест не прошёл, проверьте, действительно ли загружена **LAB-02**. Старая прошивка LAB-01 передавала `PICO` и не обслуживает запрос `?`.

**Не нужно** из-за одного `ACK timeout` пересоздавать весь проект, менять Verilog или начинать с перепрошивки, пока не проверены S2 и прямой UART.

### 2. «Failed to open serial port» / «Access denied» / «порт занят»

Это **ошибка открытия COM**, отличная от `ACK timeout`. Закройте последовательные терминалы и старые вкладки Web Serial. Для проверки, что Windows позволяет открывать COM10, выполните **без запущенного браузерного соединения**:

~~~powershell
$PortName = 'COM10'
$testPort = [System.IO.Ports.SerialPort]::new(
    $PortName, 115200,
    [System.IO.Ports.Parity]::None, 8,
    [System.IO.Ports.StopBits]::One
)
try {
    $testPort.Open()
    Write-Host "COM_OPEN_PASS: $PortName"
}
catch {
    Write-Host "COM_OPEN_FAIL: $($_.Exception.Message)"
}
finally {
    if ($testPort.IsOpen) { $testPort.Close() }
    $testPort.Dispose()
}
~~~

При `COM_OPEN_PASS` пробный порт тут же закрыт — возвращайтесь в браузер. При `COM_OPEN_FAIL` проверьте, что устройство существует, номер COM верен и никакая другая программа его не удерживает. Если в текущем PowerShell оставлен ранее открытый объект `$com`, его можно закрыть:

~~~powershell
if ($null -ne $com) {
    if ($com.IsOpen) { $com.Close() }
    $com.Dispose()
}
~~~

**Gowin Programmer** иногда является кандидатом при проблемах совместного доступа к USB, но без проверки нельзя утверждать, что программатор и USB-UART удерживают один и тот же COM-порт.

### 3. `Web Serial недоступен`

Используйте Chrome/Edge и адрес `http://127.0.0.1:8765/PicoRV32_LED1_Linked_RU.html`. Проверьте, что сервер ещё работает и HTML не открыт как `file://`.

### 4. `GET /favicon.ico ... 404`

Это только отсутствие иконки веб-страницы; на открытие HTML, COM10 и исполнение прошивки оно не влияет.

### 5. Python сообщает «Port 8765 is already in use»

Речь о **TCP-порте 8765 HTTP-сервера**, а не о COM10. Возможно, предыдущий сервер ещё работает. Остановите лишний экземпляр в его терминале нажатием Ctrl+C.

### 6. После отключения USB плата не отвечает

Вариант SRAM-программирования не записывает постоянную Flash, поэтому конфигурация могла быть потеряна. При необходимости повторите шаг 2 и **снова нажмите S2** после успешного программирования.

---

# Принцип работы и границы эксперимента

- **Реальное FPGA-устройство:** PicoRV32 исполняет 118 инструкций RV32I в ROM (1 KiB), принимает `0`…`6` и `?` по UART RX, изменяет MMIO-регистр LED, читает его обратно и передаёт `L=n` через UART TX. `0` выключает все LED, `1`…`6` выбирают один.
- **Учебная HTML-модель:** отдельная концептуальная программа из четырёх инструкций `LUI / ADDI / SW / JAL`, представленная в 19 смысловых шагах.
- **Связь двух систем:** на шаге 14 браузер отправляет команду, ждёт подтверждение регистра MMIO и только затем обновляет показ. При возвращении на шаг 13 посылает `0`.
- **Граница подтверждения:** `L=n` удостоверяет чтение MMIO-регистра, но не заменяет самостоятельную проверку света на физических LED. Связанный HTML **не является** потактовым RTL-симулятором PicoRV32.

**Экспериментальные результаты:** прошивка и RTL — PASS, Gowin PnR и STA — PASS; при 27 МГц Fmax по STA 52,522 МГц; физическая Tang Nano 9K — команды `0/1/4/?/6/0` с правильным `L=n`, визуальная проверка LED и HTML в ручном, автоматическом и обратимом режимах — PASS.

**Источники:** [Sipeed-FPGA](https://github.com/AIDevelopersMonster/Sipeed-FPGA), [PicoRV32](https://github.com/YosysHQ/picorv32) (Claire Xenia Wolf, ISC; зафиксированный commit `ef203c2b0a3fb793280f5114941416c425c5b461`). **Автор учебного эксперимента:** А. А. Малачевский / A. A. Malachevsky; [ORCID 0009-0008-6009-3196](https://orcid.org/0009-0008-6009-3196).

---

## English quick start

**Mode A — standalone HTML (no FPGA):**

~~~powershell
Set-Location 'C:\GitHub\Sipeed-FPGA'
$html = (Resolve-Path '.\docs\interactive\picorv32-led1\PicoRV32_LED1_Interactive_Demo_EN.html').Path
Start-Process $html
~~~

**Mode B — real Tang Nano 9K hardware / Web Serial:**

1. Confirm LAB-02 firmware is configured in FPGA SRAM. If not, assemble/test, build in Gowin and program SRAM (`--operation_index 2`).
2. **After successful SRAM programming (`PROGRAMMER_EXIT_CODE=0`), briefly press and release the Tang Nano 9K S2 button. This step is required for the validated LAB-02 start-up sequence.**
3. Close all serial terminals and other Web Serial tabs; probe the board:

~~~powershell
Set-Location 'C:\GitHub\Sipeed-FPGA'
& .\01-PicoRV32\tools\probe_lab02_serial.ps1 -PortName COM10
~~~

4. Once the probe exits (releasing COM), start the local HTML server:

~~~powershell
& .\01-PicoRV32\tools\launch_lab02_html.ps1 -Language EN
~~~

5. Keep that PowerShell window open, and visit **http://127.0.0.1:8765/PicoRV32_LED1_Linked_EN.html** in Chrome/Edge. Select **Connect COM**, choose the Tang Nano 9K USB-UART device, and verify steps **13 → 14 → 13 → 14**.
6. Click **Disconnect** before opening the COM port in any other tool. Stop the HTTP server with Ctrl+C.

**Troubleshooting:** `ACK timeout (2000 ms)` means the browser opened COM successfully, but the FPGA UART did not acknowledge its request; first close the Web Serial page, **press S2**, and run the direct UART probe. `Failed to open serial port` means COM could not be opened; check competing serial applications instead. `favicon.ico 404` is harmless. For complete methodical guidance consult the [English lab instructions](../LAB02_UART_RX_EN.md) and [PDF](PicoRV32_LAB02_Methodical_EN_v1.0.pdf).
