# LiteX b05c3069 — подтверждённый запуск 17 upstream unit tests (HOST PASS)

**Дата:** 2026-11-08 12:38:11 (по имени файла журнала локального ПК).  
**Среда:** Windows PowerShell 7, Python 3.14 venv, Migen 0.10.0, пакет LiteX в editable-режиме.  
**Канонический LiteX:** `b05c30690854c462a2e704a22ff895c0055a8265` (фактически переключён локальный checkout).  
**Скрипт:** [`run_upstream_tests.ps1`](run_upstream_tests.ps1), запуск с `-SkipInstall`.  
**Локальный журнал:** `C:\GitHub\litex-b05c3069-test\results\SOURCE_TESTS_20261108_123811.txt`.

## Оригинальный результат, предоставленный оператором

```text
PS C:\Users\74095> pwsh -NoProfile -File "C:\GitHub\Sipeed-FPGA-LAB20-6\Tang-Nano-20K\LiteX-Closeout\run_upstream_tests.ps1" -SkipInstall
From https://github.com/enjoy-digital/litex
 * branch                b05c30690854c462a2e704a22ff895c0055a8265 -> FETCH_HEAD
HEAD is now at b05c30690 soc/cores/clock/gowin_gw2a: enable GW2AR support
Reusing existing virtualenv (-SkipInstall); no pip operation.
test_csr: PASS tests=4/4 exit=0
test_wishbone: PASS tests=5/5 exit=0
test_timer: PASS tests=3/3 exit=0
test_stream: PASS tests=5/5 exit=0
Saved: C:\GitHub\litex-b05c3069-test\results\SOURCE_TESTS_20261108_123811.txt
PASS 17/17 LiteX upstream unittest cases on pinned source (HOST SIMULATION ONLY).
NO FPGA HARDWARE RESULTS FROM THIS RUN.
```

| Набор исходных тестов | Число тестов | Итог |
|---|---:|---|
| `test_csr.py` | 4 | PASS |
| `test_wishbone.py` | 5 | PASS |
| `test_timer.py` | 3 | PASS |
| `test_stream.py` | 5 | PASS |
| **Всего** | **17** | **PASS** |

Исправленный runner вызывает `python -m unittest discover -s <test-dir> -p <имя файла> -v`, сверяет для каждого файла `Ran N tests`, `OK` и код процесса `0`. Таким образом, отличие от первого ложноположительного запуска (четыре `EXIT=0` при *нуле запущенных тестов*) устранено.

**Точно доказано:** эти 17 модульных тестов четырёх выбранных файлов исторического LiteX прошли в локальной Python/Migen-среде.

**Не доказано:** выполнение других upstream-тестов, включая `test_cpu.py` (требует отдельный `litex_sim`/Verilator), физические транзакции Wishbone на плате и наличие/работа таймера в заводском FPGA bitstream. Проведение тестов **не подключало FPGA**, не записывало RAM/Flash, не включало IRQ.

**Доказательная граница:** предоставлен консольный итог от оператора; полный файл журнала остался на его Windows-ПК, не вложен сюда. Его отсутствие не позволяет отдельно проанализировать длительности и подробные отчёты каждого testcase.

**Статус:** `LITEX_SOURCE_CSR_WISHBONE_TIMER_STREAM_UNITTEST_17_OF_17_HOST_PASS`; `TIMER_BOARD_UNKNOWN`.
