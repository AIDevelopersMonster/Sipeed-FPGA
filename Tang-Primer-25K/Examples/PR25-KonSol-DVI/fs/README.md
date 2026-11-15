# Готовый SRAM-битстрим KonSol

**[Скачать pr25_konsol_trial.fs](pr25_konsol_trial.fs)** — 5 959 331 байт, Tang Primer 25K + Dock.

Опубликованный SHA256: `1a0ad8cdf8be6ed7ffffdbfe943d547f94fada6a63a7549ccb8825e2c50e9053` (см. [sha256.txt](sha256.txt)).

**BOARD VIDEO PASS** по наблюдению и фотографиям оператора от 15.11.2026: статический цветной KonSol 640×480. **PMOD DVI вставлен в разъём под USB-A**.

Для загрузки используйте Gowin Programmer CLI с `--device GW5A-25A --cable-index 1 --run 2 --fsFile <путь к скачанному .fs>`. **Только SRAM, не Flash.** Подробная команда и проверка SHA256: [README проекта](../README.md).

Содержит интегрированное проприетарное IP Gowin DVI_TX; перед дальнейшим распространением убедитесь в соблюдении применимых условий Gowin EULA.
