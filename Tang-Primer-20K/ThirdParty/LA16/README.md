# LA16 LogicAnalyzer — Tang Primer 20K Dock

**Проверено на плате: 23 ноября 2026 года.**  
**Статус: BOARD PASS — запуск оригинальной прошивки в SRAM, Ethernet/ARP, приём потока и режим LIVE в оригинальном GUI.**  
**Не проверено:** физические входы CH0–CH15, точность дискретизации, реальное декодирование UART/I²C/SPI, долговременная устойчивость и пропускная способность при нагрузке.

**Это сторонний проект.** Автор — [vinhbui2430/LogicAnalyzer](https://github.com/vinhbui2430/LogicAnalyzer); исходники и права остаются у автора. В наш репозиторий не копируются его исходники, битстрим или сторонние бинарные сборки. Мы использовали готовую авторскую прошивку без изменения RTL и не записывали ничего во Flash.

## 1. Что представляет собой проект

LA16 — 16-канальный логический анализатор для Sipeed Tang Primer 20K с Dock. Архитектура по исходному коду автора:

```text
16 входов PMOD2 / PMOD3
         |
  sampler_rle (175,5 МГц — проектное значение)
         |
  async_fifo (переход 175,5 → 50 МГц)
         |
  packetizer (RLE + заголовки пакетов)
         |
  FPGA Ethernet UDP / RMII → RTL8201F → RJ45
         |
  коммутатор → ПК CHUWI (UDP 5001)
         |
  Python GUI LA16 PRISM: 16 дорожек / LIVE / декодеры
```

**Уточнение:** PRISM — **настольная программа Python**, а не веб-интерфейс в браузере. Ethernet организован непосредственно в FPGA; HTTP, веб-сервер и запрос GUI на начало передачи здесь не используются. Приёмник GUI слушает входящий UDP-порт `5001`; передатчик в RTL формирует собственные UDP-пакеты, включая периодические служебные пакеты (heartbeat).

## 2. Зафиксированная версия

| Параметр | Значение |
| --- | --- |
| Плата | Tang Primer 20K + Dock, GW2A-18C, JTAG ID `0x0000081B` |
| Исходный репозиторий | [vinhbui2430/LogicAnalyzer](https://github.com/vinhbui2430/LogicAnalyzer) |
| Проверенный коммит автора | `3ad9a7b6a9e54548326d3d261b2c1b3842412661` |
| Готовый bitstream автора | `fpga/impl/pnr/la16.fs` |
| Размер проверенного bitstream | **7 262 008 байт** |
| SHA256 | `91248EBB85B87E1FCF38FDC541DAA330708FE3B243DB8D75A69AE27255E36CD1` |
| Git blob SHA1 | `d34837a4e5263dc6a7704c72eba939764c64e7a6` |
| FPGA Ethernet IP | `192.168.15.14` (зашит в RTL) |
| FPGA MAC | `06-00-AA-BB-16-16` |
| IP компьютера CHUWI | `192.168.15.15/24` |
| Протокол | Ethernet / IPv4 / UDP, порт `5001` |
| GUI | `host/la_gui.py`, Python + customtkinter/matplotlib/numpy |

## 3. Результаты нашего испытания

| Проверка | Результат | Фактическое подтверждение |
| --- | --- | --- |
| Контроль оригинального `.fs` | **PASS** | Размер, SHA256, Git blob проверены |
| Предварительная проверка исходного ПО | Проведена | Просмотр скриптов и Python; Microsoft Defender не сообщил об обнаружении угроз (не абсолютная гарантия) |
| Host-тесты автора | **PASS** | `tests/run_all.py`: синтетические тесты пакетов, хранения и декодирования |
| Тест GUI без платы | **PASS** | `tests/gui_smoke.py` |
| Загрузка FPGA | **SRAM PROGRAM PASS** | `--run 2`: 100%, User Code `0x00007196`, Status Code `0x00006020` |
| Физическая сеть и ARP | **BOARD PASS** | Windows: `192.168.15.14 → 06-00-AA-BB-16-16`, `Reachable` |
| Работа Ethernet → GUI | **BOARD PASS (ограниченный)** | Фото оператора: LA16 PRISM запущен на CHUWI, в интерфейсе `LIVE`, показаны 16 каналов, счётчик переходов 16 |
| Измерение цифровых сигналов на PMOD | **NOT TESTED** | По решению оператора внешние тесты не выполнялись |
| Измеренная частота/точность/декодеры | **NOT TESTED** | Значение около 176 MS/s на экране — параметр прошивки, не наш независимый замер |

**Ход диагностики.** Первые попытки принять UDP пакеты PowerShell-приёмником завершались тайм-аутами. Позже успешный ARP-ответ показал работу двустороннего Ethernet на уровне кадров. Модуль FPGA частично смещался относительно Dock и был перепосажен при отключённом питании. После последующего запуска оригинального GUI оператор получил режим `LIVE`. Это подтверждает реальную работоспособность использованного сетевого пути, но не доказывает отсутствие потерь или безошибочность всех каналов.

На фотографии интерфейса виден ненулевой счётчик `DROPS`; причины потерь отдельно не исследовали.

## 4. Как установить и запустить на Windows

### 4.1. Подключение

```text
                 Wi-Fi / интернет
                         |
                      ПК CHUWI
                         |
              Ethernet 192.168.15.15/24
                         |
                   Коммутатор
                         |
               Tang Primer 20K Dock
                 192.168.15.14
                UDP → порт 5001
```

Коммутатор в нашем испытании был **отключён от домашнего роутера**. Для Ethernet не задаём шлюз; интернет остаётся на Wi-Fi. USB-JTAG можно подключить к отдельному компьютеру с Gowin Programmer.

### 4.2. Получить оригинальный проект конкретной версии

На CHUWI в обычном PowerShell:

```powershell
$commit = "3ad9a7b6a9e54548326d3d261b2c1b3842412661"
$root = Join-Path $env:USERPROFILE "Downloads\LA16_PRISM"
New-Item -ItemType Directory -Force -Path $root | Out-Null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$zip = Join-Path $root "LA16.zip"
Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/vinhbui2430/LogicAnalyzer/archive/$commit.zip" -OutFile $zip
Expand-Archive $zip -DestinationPath $root -Force

$src = Get-ChildItem $root -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "host\la_gui.py") } |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $src) { throw "Original LA16 sources not found" }
```

Для FPGA-программатора требуется тот же файл `la16.fs` из **этого коммита** (либо ранее полученная и проверенная копия).

### 4.3. Загрузить авторскую прошивку только в SRAM

На ПК с Gowin Programmer. Переменная `$src` должна указывать на распакованный там проект автора:

```powershell
$fs = Join-Path $src "fpga\impl\pnr\la16.fs"
$expected = "91248EBB85B87E1FCF38FDC541DAA330708FE3B243DB8D75A69AE27255E36CD1"
if ((Get-FileHash -Algorithm SHA256 $fs).Hash -ne $expected) {
    throw "LA16 HASH MISMATCH — DO NOT PROGRAM"
}

& "C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe" --device GW2A-18C --run 2 --fsFile $fs
```

Результат нашего программирования: `SRAM Program 100%`, User Code `0x00007196`, Status Code `0x00006020`. **Flash не трогать.** После полного выключения питания требуется повторная загрузка SRAM.

**Важная деталь:** однажды Windows `git clone` изменил байты `la16.fs` при checkout (переносы строк). Поэтому перед любым программированием обязательно проверять SHA256; повреждённый по сравнению с Git blob файл нельзя использовать.

### 4.4. Настроить CHUWI

Когда Wi-Fi уже обеспечивает интернет, в PowerShell **от администратора**:

```powershell
# Меняет конфигурацию только указанного Ethernet-адаптера
netsh interface ipv4 set address name="Ethernet" source=static address=192.168.15.15 mask=255.255.255.0 gateway=none
Get-NetIPConfiguration -InterfaceAlias "Ethernet"

# Разрешает только входящий UDP/5001 от LA16 на этом адаптере
if (-not (Get-NetFirewallRule -Name "LA16_FPGA_UDP5001" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "LA16_FPGA_UDP5001" -DisplayName "LA16 FPGA UDP 5001" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 5001 -LocalAddress 192.168.15.15 -RemoteAddress 192.168.15.14 -InterfaceAlias "Ethernet" -Profile Any
}
```

На другом компьютере имя сетевого адаптера может отличаться. Не отключать Windows Firewall целиком. Если впоследствии нужно вернуть проводной интерфейс к DHCP:

```powershell
netsh interface ipv4 set address name="Ethernet" source=dhcp
```

### 4.5. Запустить GUI LA16 PRISM на CHUWI

После шага 4.2 в обычном PowerShell:

```powershell
py -3 --version
py -3 -m venv (Join-Path $root ".venv")
$python = Join-Path $root ".venv\Scripts\python.exe"
& $python -m pip install -r (Join-Path $src "host\requirements.txt")
& $python -B (Join-Path $src "host\la_gui.py")
```

GUI запускает UDP-приём автоматически и не должен отправлять FPGA особых запросов. Признак приёма — `LIVE`; `NO SIGNAL` означает, что свежие корректные пакеты ещё не поступили. Пинги не являются достаточным тестом: ICMP-ответы стек FPGA может не поддерживать.

## 5. Практическая оценка и дальнейший интерес

- **Как логический анализатор:** проект интересен как демонстрация, но оператор не видит практической необходимости дополнительно проверять измерительные функции. По его наблюдению, **GUI работает медленно** (количественное измерение производительности не проводилось). Доступность недорогих готовых USB-анализаторов, по оценке оператора примерно **300–500 руб.**, снижает мотивацию повторять их функции на FPGA; это личная оценка, а не проверенный обзор рынка.
- **Как реализация Ethernet на FPGA:** проект заслуживает отдельного изучения. Уже подтверждены работа RMII/PHY RTL8201F, ARP и сквозная доставка UDP в приложение на Windows. Интерес представляют RTL Ethernet-стека, формат пакетов, буферизация, потоковая передача и возможности повторного использования в своих SoC.
- **Текущий статус работы:** испытание LA16 **завершено на уровне Ethernet + GUI**. Новые аппаратные проверки, перенос RTL и изменения собственных проектов **не запланированы без отдельного решения**.

**Важно по распиновке:** у автора в `docs/WIRING.md` для CH1 указан `D10`, а в `fpga/constraints/la16.cst` — `C12`. Поскольку PMOD-входы не тестировались, правильность внешнего подключения не сертифицирована.

## 6. Исходники автора

- [README оригинального проекта](https://github.com/vinhbui2430/LogicAnalyzer/tree/3ad9a7b6a9e54548326d3d261b2c1b3842412661)
- [Топ-модуль: la16_top.sv](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/fpga/rtl/la16_top.sv)
- [Ethernet UDP: udp.sv](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/fpga/rtl/eth/udp.sv)
- [Пакетизатор: packetizer.sv](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/fpga/rtl/packetizer.sv)
- [Приёмник UDP: source.py](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/host/la16/source.py)
- [GUI: la_gui.py](https://github.com/vinhbui2430/LogicAnalyzer/blob/3ad9a7b6a9e54548326d3d261b2c1b3842412661/host/la_gui.py)
