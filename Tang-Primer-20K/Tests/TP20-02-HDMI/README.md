# TP20-02 — HDMI 1280x720 / Tang Primer 20K Dock

**Назначение:** документировать готовый HDMI-тест Sipeed и видеодемонстрацию на плате Tang Primer 20K + Dock.

**Происхождение:** это **оригинальный пример производителя Sipeed**, а не прошивка, разработанная или собранная в PiKoSoL. Исходный `dk_video.fs` не изменялся и не публикуется повторно в нашем репозитории.

## Видео

- **Демонстрация пользователя (YouTube Shorts):** https://youtube.com/shorts/-JyNlnzaJZ0
- Видео предоставлено автором лаборатории 18.11.2026. Отдельный журнал программирования и независимая проверка содержания ролика в этом протоколе отсутствуют.

## Оригинальная прошивка и исходный код

- **Скачать готовый оригинал `dk_video.fs` непосредственно у Sipeed:** [dk_video.fs — pinned source revision](https://raw.githubusercontent.com/sipeed/TangPrimer-20K-example/e469df4c0c9c41824f405a8515decf24ef1e8e6f/HDMI/dk_video.fs)
- **Просмотреть оригинальный проект Verilog, ограничения и файл проекта:** [HDMI / Sipeed](https://github.com/sipeed/TangPrimer-20K-example/tree/e469df4c0c9c41824f405a8515decf24ef1e8e6f/HDMI)
- **Исходный файл проекта Gowin:** [dk_video.gprj](https://github.com/sipeed/TangPrimer-20K-example/blob/e469df4c0c9c41824f405a8515decf24ef1e8e6f/HDMI/dk_video.gprj)
- **Точка входа RTL:** [src/video_top.v](https://github.com/sipeed/TangPrimer-20K-example/blob/e469df4c0c9c41824f405a8515decf24ef1e8e6f/HDMI/src/video_top.v)
- **Генератор тестовых изображений:** [src/testpattern.v](https://github.com/sipeed/TangPrimer-20K-example/blob/e469df4c0c9c41824f405a8515decf24ef1e8e6f/HDMI/src/testpattern.v)

### Проверяемая идентичность оригинала

| Характеристика | По официальному GitHub Sipeed |
| --- | --- |
| Репозиторий | `sipeed/TangPrimer-20K-example` |
| Ревизия (commit) | `e469df4c0c9c41824f405a8515decf24ef1e8e6f` |
| Файл | `HDMI/dk_video.fs` |
| Размер файла | **4 619 255 байт** |
| Git blob SHA-1 | `e8610a8363010de098d0b80ac9c7d91d5ec91149` |
| FPGA в `dk_video.gprj` | `GW2A-LV18PG256C8/I7` |
| Входной тактовый сигнал в RTL | 27 МГц |
| Формат тестового видео по RTL | 1280×720, проектные 60 Гц |

**Примечание к контрольной сумме:** приведён Git *blob* SHA-1 из дерева производителя. Это не обычный SHA-1 или SHA-256 скачанного файла. SHA-256 файла, реально загруженного оператором в плату, здесь не зафиксирован.

## Что делает проект

`video_top.v` формирует видеосигнал через тестовый генератор RGB и передатчик DVI/TMDS. `testpattern.v` предусматривает четыре режима: цветные полосы, сетка, градации серого и однотонный цвет. Выход используется через разъём HDMI Dock.

Проект демонстрирует аппаратный видеовывод **без процессора RISC-V, без операционной системы и без обращения к DDR3**. Наличие DDR3 на плате не означает её проверку данным тестом.

## Связанные материалы

- [TP20-01 — JTAG SCAN PASS](../TP20-01-JTAG/README.md)
- [Главная страница Tang Primer 20K](../../README.md)
- [Официальный репозиторий Sipeed](https://github.com/sipeed/TangPrimer-20K-example)
