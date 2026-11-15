# Видео: PR25 USB Physical Attach Lite 02

## Заголовок для YouTube

**USB на FPGA без контроллера! Tang Primer 25K определяет подключение устройств | DVI + Gowin**

## Описание

Продолжаем исследование Sipeed Tang Primer 25K + Dock. В этой демонстрации FPGA **без USB Host-контроллера, процессора и операционной системы** обнаруживает изменение электрического состояния USB D+ / D− и выводит его непосредственно на монитор через PMOD DVI и заводское IP-ядро Gowin DVI_TX.

На реальном аппаратном тесте получены два состояния:

- **D+ = 0, D− = 1** — подтяжка на D−, характерная для USB Low Speed (1,5 Мбит/с); на экране счётчик **0011**.
- **D+ = 0, D− = 0** — подтяжка не видна; счётчик **0012**.

Это **BOARD VIDEO PASS + USB PHYSICAL DETECTION PASS**. Видеотракт работает, входы FPGA отражают состояние линий USB, а счётчик реагирует на изменение. **Это не распознавание клавиатуры**: нет USB enumeration, VID/PID и HID-кодов. Кнопки пока не обрабатываются.

Подключение: Tang Primer 25K + Dock, штатный USB-A (D+ = L6, D− = K6), PMOD DVI, монитор HDMI. Среда Gowin EDA 1.9.9 Beta-4 Education. SDRAM и COM-порт не требуются.

Исходники, воспроизводимый PowerShell-скрипт и фотографии аппаратного результата:
https://github.com/AIDevelopersMonster/Sipeed-FPGA/tree/main/Tang-Primer-25K/Examples/PR25-USB-PHYSICAL-02

IP Gowin DVI_TX — описание и ограничения:
https://github.com/AIDevelopersMonster/Sipeed-FPGA/blob/main/ip/hdmi/gowin-dvi-tx/README.md

Следующая задача: реальный USB HID Host с выводом клавиш на работающий видеотракт.

#FPGA #TangPrimer25K #Gowin #USB #SystemVerilog #DVI #HDMI #PiKoSoL

## Материалы

- [Обложка 9:16](video_cover_9x16.jpg).
- [Фотографии измерительного опыта](../evidence/).
- **YouTube URL:** пока не предоставлен.
- **Видеофайл:** отсутствует среди файлов беседы; ссылку и файл не выдумываем.
