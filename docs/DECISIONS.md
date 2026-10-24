# Architectural decisions (ADR)

### ADR-001 — one project repository

- Decision: single independent `AIDevelopersMonster/Sipeed-FPGA` monorepo, one implementation per numbered top-level folder.
- Rationale: common contracts/tests, easier comparison and atomic changes.
- Out of scope: modifying `DDF`, MAX 10 or unrelated repositories.
- Status: adopted for bootstrap; repository has not yet been created remotely by these files.

### ADR-002 — reference pinning, no copied CPU IP

- Pin reference commits in `sources.lock.json`; fetch only required CPU for local build.
- Preserve each upstream license and attribution.
- No large binary FPGA bitstreams committed by default.

### ADR-003 — verify claims separately

- Model / RTL simulation / PnR / physical board / benchmark each have separate exit criteria.
- No promised universal bitstream or direct CPU equivalence.

### ADR-004 — stages use actual available boards

- Nano 9K: PicoRV32, NEORV32; Primer 25K: LiteX/VexRiscv, Rocket feasibility.
- Primer 20K is reference material only, not assumed available for real tests.

### ADR-005 — board support без дублирования SoC (24.10.2026)

- **Решение:** оставить деление репозитория по процессорным архитектурам (01–04) и ввести независимый физический профиль в `boards/<board-id>/`. Первый — [Tang Nano 9K](../boards/tang-nano-9k/README.md).
- **Не переносить** аппаратно подтверждённые `01-PicoRV32/lab04/` и `lab05/` в каталог платы. Их пути, скрипты, доказательства и релизные хэши остаются воспроизводимыми.
- **Аппаратное разнообразие:** board top, pin/clock constraints, PLL, PHY, external RAM and available peripheral controllers — target-specific; portable CPU/bus/SPI/FAT32 source remains shared.
- **Программное разнообразие:** единые исходники firmware/FS, профиль сборки и, по мере интеграции, опрос аппаратных возможностей через стабильный MMIO. Не вшивать номер модели платы в драйвер FAT32.
- **Политика будущего переноса:** только для нового активного SoC создавать `targets/<board-id>/` с обёрткой и сборкой; старые лабораторные — неизменяемые этапы. Переключение target не меняет общие HDL и firmware.
- **Никаких ложных универсальных образов:** каждая FPGA получает свой `.fs` и проходит собственный PnR, STA, CDC и аппаратную приёмку. Точная 20K/25K-плата определяется отдельно.
- **Приоритет:** закончить текущий SD/FAT32 эксперимент в пределах выделенного времени. Полная перестройка директорий сейчас не выполняется.

### ADR-006 — peripheral-first educational examples (24.10.2026)

- Физическое чтение microSD можно выполнить без PicoRV32. Поэтому USB-UART, SPI, SD и HDMI должны быть доступны как **независимые учебные проекты** в `examples/peripherals/`.
- `ip/` — единые переносимые RTL-компоненты, `boards/` — физические платы, `systems/` — целые SoC и firmware, `examples/` — самостоятельные демонстрации и разборы. `common/` сохраняет MMIO-контракт.
- Проверенные HDL LAB-04/05 пока **не переносить** и **не дублировать**: примеры используют их напрямую. После завершения LAB-05 и отдельной регрессии можно вынести канонический переносимый RTL в `ip/rtl`.
- Отчёт по примеру обязан различать SIM PASS / PnR / STA / BOARD PASS. Самостоятельные команды компиляции никогда не программируют плату.

### ADR-007 — general method + independent particular implementations (24.10.2026)

- Общий подход и учебные объяснения — `examples/peripherals/`, переносимые блоки — `ip/`.
- Самостоятельные **частные реализации конкретной платы** — `boards/<board-id>/experiments/<experiment-id>/`: локальный RTL, CST/SDC, тесты, сборка, протокол. Не требуется CPU или PiKoSoL.
- Копирование RTL и скриптов между исторически связанными опытами **разрешается**, когда обеспечивает воспроизводимость и независимое исследовательское развитие. В таких случаях происхождение фиксируется в `experiment.json`; общий IP и аппаратный PASS не наследуются автоматически.
- Ранее принятое абсолютное запрещение копирования в ADR-005/006 **уточняется и отменяется для независимых исследовательских снимков**. Каноническая библиотека `ip/` по-прежнему предпочтительна для обычного повторного использования.
- Проверенные `lab04/` и `lab05/` сохраняются как исторические результаты. Новые приложения и опыты не обязаны храниться в папке конкретного CPU.
- Реализованный первый частный случай: [Tang Nano 9K SD-01](../boards/tang-nano-9k/experiments/sd-sector0/README.md).
