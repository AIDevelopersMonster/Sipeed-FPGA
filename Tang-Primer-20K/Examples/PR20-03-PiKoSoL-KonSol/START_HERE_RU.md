# PiKoSoL TP20 — запуск после скачивания GitHub ZIP

**Плата:** Tang Primer 20K Dock (GW2A-18C). **ОС:** Windows. **Режим:** FPGA SRAM only; Flash не записывается.

## Для нового пользователя

1. Скачать [ZIP репозитория](https://github.com/AIDevelopersMonster/Sipeed-FPGA/archive/refs/heads/main.zip) и распаковать его. Не запускать файлы непосредственно из окна ZIP.
2. Открыть каталог `Tang-Primer-20K/Examples/PR20-03-PiKoSoL-KonSol`.
3. Установить Python 3 с Tkinter, пакет `pyserial` (`python -m pip install pyserial`), Gowin Programmer. Подключить Tang Primer 20K Dock, HDMI и USB-UART. Закрыть MobaXterm и другие программы, занимающие COM-порт.
4. Запустить **`START_PiKoSoL.cmd`** двойным щелчком; указать COM-порт (например, COM10) и выбрать режим:
   - **1 — полный запуск:** программирование только SRAM проверенным исходным `.fs`, затем XMODEM-загрузка `monitor.bin` и открытие File Manager.
   - **2 — загрузка монитора:** если HDMI показывает `Waiting for downloader ...`, FPGA повторно не программируется. Передаётся `monitor.bin`, затем открывается File Manager.
   - **3 — только File Manager:** если монитор уже работает и показывает `PiKoSoL>`. COM-порт не открывается до действия пользователя в GUI.
5. В режиме 1 `START_PiKoSoL.py` **при отсутствии эталонного `.fs` в каталоге** скачивает фиксированный исходный bitstream из THLN33; перед программированием проверяет его размер и Git blob SHA1. Никакие произвольные `.fs` не принимаются автоматически. В режиме 2/3 FPGA-прошивка не затрагивается.
6. При ожидании `Waiting for stock bootloader C` **один раз нажать кнопку сброса Dock S0**, если загрузчик уже послал символ `C` до открытия ПК-порта. После `MONITOR_BOOT_PASS` COM закрывается и запускается графический менеджер.

**Проверка без аппаратных операций:**

```powershell
python .\START_PiKoSoL.py --check
```

**Запуск с явными параметрами (например, для диагностики):**

```powershell
python .\START_PiKoSoL.py --port COM10 --mode boot
python .\START_PiKoSoL.py --port COM10 --mode gui
```

Номер порта не универсален: COM10 — лишь пример. Выбранный COM передаётся в File Manager. Скорость UART — 115200 8N1.

**Ограничения и сохранность.** После RAM-загрузки монитор не сохраняется при полном отключении питания. Известные `monitor.bin` и `demo.bin` проверяются по SHA256, не перезаписываются. Программирование `--run 2` меняет только текущую энергозависимую конфигурацию FPGA, поэтому при проверке экспериментальной DDR3-сборки используйте режим 2 или 3, а не 1. GUI и приложения остаются отдельно от встроенной в FPGA файловой системы: файлы передаются в RAM; FAT32 и DDR3 в основном проекте пока не заявлены как испытанные.

**Статус:** состав и предварительная проверка путей на GitHub подтверждены; полный сценарий на другом Windows-ПК и File Manager с актуальным launcher **требуют аппаратной проверки**. Выпуск GitHub Release не создавался.

Подробная процедура и контрольные суммы: [SRAM-Startup/README.md](SRAM-Startup/README.md). Исходные файлы: [START_PiKoSoL.py](START_PiKoSoL.py), [START_PiKoSoL.cmd](START_PiKoSoL.cmd), [FileManager](FileManager/).
