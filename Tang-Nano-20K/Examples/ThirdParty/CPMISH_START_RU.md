# TP20-02 — прямой путь к CP/Mish на Tang Nano 20K

**Завершённый результат: BOARD PASS / CP/Mish 2.2r0 / UART COM25 / команда `DIR`.** Настоящий процессор Z80 реализован в FPGA, операционная система загружается с физической microSD.

## 1. Старт из заводской LiteX

Вставлена microSD с полным RAW `nano-z80.img`, файл bitstream `nano-z80.fs` ранее скачан в `C:\GitHub\TP20-ThirdParty\downloads`. Закрыть MobaXterm. Выполнить:

```powershell
Set-Location C:\GitHub\TP20-ThirdParty
.\restore-nano-z80-after-powercycle.ps1 -Port COM25
```

Ответить `SRAM` и `CLOCKS`. Это временная загрузка, **заводская Flash с LiteX не изменяется**. После успешного выполнения нажать и отпустить **S2**, затем открыть **COM25, 115200, 8N1**, без управления потоком.

## 2. Запуск CP/Mish непосредственно в MobaXterm

После ROM Monitor `Ready`:

```text
L
WF633,83
O007F,06
O0000,00
JF600
```

Пояснение только по сути: `L` загружает ОС без запуска; `WF633,83` выбирает COM25; две команды `O...` блокируют PIC IRQ; `JF600` передаёт управление BIOS.

## 3. Ожидаемый результат — получен оператором

```text
CP/Mish 2.2r0 for nanoZ80

A>DIR
-README .TXT  |  DUMP    .COM  |  STAT    .COM  |  ASM     .COM
COPY    .COM  |  SUBMIT  .COM  |  BBCBASIC.COM  |  CAMEL80 .COM
QE      .COM  |  RAWDISK .COM  |  MKFS    .COM  |  BAUDRATE.COM
NANOTERM.COM  |  COLORFG .COM  |  COLORBG .COM  |  CLS     .COM
ARROWKEY.COM  |  IMGVIEW .COM  |  IMG320  .COM  |  IMG160  .COM
FUZIX   .COM
A>
```

Состояние: **CPU + ROM + UART + SD + BIOS + BDOS/CCP + DIR = аппаратно подтверждены.** Запуск каждой конкретной `.COM` пока не утверждается до эксперимента.

## 4. Дальнейший прямой маршрут

`STAT` → `BBCBASIC` → `CAMEL80` → `QE` по одному опыту за раз; инструменты `MKFS` и `RAWDISK` без отдельного задания **не запускать**. Новый [Nano Commander](NanoCommander/README.md) пока отдельный программный прототип, его не смешивать с уже подтверждённым CP/Mish BOARD PASS.

**Не требуется:** читать старые журналы и повторять тесты SD/PLL/RAM при штатном запуске. Архив диагностики трогать только по просьбе оператора «изучи».
