# U — одна команда загрузки CP/Mish по UART

[← Z80](../README.md) · [Проверенный запуск CP/Mish](../CPMISH_START_RU.md)

**Статус: исходный патч готов; новая FPGA-сборка и испытание ещё НЕ проводились.**
В заводском стороннем bitstream nano-Z80 команды U пока нет. Действующая проверенная последовательность:

```text
L
WF633,83
O007F,06
O0000,00
JF600
```

После сборки ROM с патчем одна команда `U` в мониторе должна выполнять те же действия:

```text
Ready
U
CP/Mish 2.2r0 for nanoZ80
A>
```

Патч изменяет **только** `romcode/nano-z80.z80` из [venomix666/nano-z80](https://github.com/venomix666/nano-z80), закреплённая исходная версия: `0e2692ad10da8cbc0351758fea0fffa2dcf30110`. Штатную команду `B` (загрузка с HDMI) он не меняет.

## Что делает U

1. Выполняет `DI`, выбирает банк PIC и снимает разрешение аппаратных IRQ.
2. Сбрасывает `BOOT_PAGE` в ноль, затем штатным `sd_boot` загружает образ microSD.
3. Проверяет известную загрузочную страницу `F6` и конфигурацию `F633` = `81` либо `83`.
4. Устанавливает IOBYTE `83` (UART A) и передаёт управление `F600`.
5. При несовпадении ожидаемого BIOS сообщает ошибку вместо перехода по непроверенному адресу.

Это **специальная команда для проверенного CP/Mish 2.2r0**, не универсальный загрузчик FUZIX/других ОС.

## Применение (на отдельном клоне)

```powershell
git clone https://github.com/venomix666/nano-z80.git C:\GitHub\nano-z80-u
Set-Location C:\GitHub\nano-z80-u
git checkout 0e2692ad10da8cbc0351758fea0fffa2dcf30110

# Путь к скрипту соответствует каталогу скачанного Sipeed-FPGA:
$Patch = 'C:\GitHub\Sipeed-FPGA\Tang-Nano-20K\ThirdParty\Z80\monitor-u\patch_monitor_u.py'
python $Patch .\romcode\nano-z80.z80
python $Patch .\romcode\nano-z80.z80 --apply
```

Скрипт проверяет конкретные места вставки, делает резервную копию `.pre-u.bak` и отказывается повторно накладывать патч. `python test_patch_monitor_u.py` запускают из каталога `monitor-u`.

Далее upstream использует `zasm` для ROM (`make -C romcode` — формирование `src/nano-z80.hex`) и Gowin EDA для `nano-z80.gprj`. **Проверить ROM не более 8192 байт**, синтез, PnR и STA. Новый bitstream разрешено испытывать **только в SRAM**; заводскую LiteX Flash и исходный рабочий `.fs` не перезаписывать. Готового проверенного `.fs` с командой U пока нет.

До аппаратного PASS используйте подтверждённые пять команд в [основной инструкции](../CPMISH_START_RU.md).
