# HDMI + Audio как встраиваемый IP: инженерные примеры (RU)

**Статус:** разбор проверенного авторского проекта. Примеры ниже — **проектный эскиз**, не отдельно собранная или испытанная IP-интеграция. Оригинальный замороженный RTL без правок — [vendor/src/hdmi/](vendor/src/hdmi/); полный учебный разбор непосредственно по коду — [review/hdmi_tx_annotated_ru.v](review/hdmi_tx_annotated_ru.v). Upstream © 2026 Terence Ang, MIT, commit `44674c38d9c10a306fe4a5a5ddf9332bad830847`.

## 1. Что это за IP по факту

Входы `hdmi_tx`: один `clk_pixel`, `rst_n`, `video_rgb[23:0]`, `audio_valid`, `audio_l[15:0]`, `audio_r[15:0]`. Выходы: `pixel_x/y` и 30-битная шина из трёх TMDS 10-битных символов. Физическая сериализация и дифференциальный вывод в отдельном `top.v`.

```text
video renderer --RGB24(pixel_x,y)----> hdmi_tx ---> 3x TMDS10 ---> OSER10 x3 ----> HDMI
PCM 48k      --audio_valid/L/R---->         |     clock symbol ---> OSER10 x1
                                            |
                ASP / ACR / AVI / Audio InfoFrames
                            | fifo / data island scheduler
                            | BCH / TERC4 / TMDS period select
```

### Пример А: подключить свой генератор RGB вместо цветных полос

**Существующий интерфейс, фрагмент, без самодостаточного testbench:**

```verilog
wire [9:0] x, y;
wire [23:0] rgb = (x < 360) ? 24'h003060 : 24'hD8D8D8;
wire [29:0] tmds_symbols;

hdmi_tx #(.RGB_QUANT(2'b10)) u_hdmi (
    .clk_pixel(clk_pixel), .rst_n(rst_n),
    .pixel_x(x), .pixel_y(y), .video_rgb(rgb),
    .audio_valid(audio_valid),
    .audio_l(audio_l), .audio_r(audio_r),
    .tmds(tmds_symbols)
);
```

Этот способ хорошо подходит для полос, примитивов и меню без DDR3: генератор возвращает RGB на текущий `(x,y)` комбинаторно **в ожидаемую фазу**. Для синхронного BRAM/DDR3-видео нужны согласованные задержки и буферы строки.

### Пример Б: PCM-генератор 48 кГц в пиксельном домене

Из авторского [tone_1k.v](vendor/src/tone_1k.v) получаем один тактовый импульс `audio_valid` на каждую стереопару, адресуя один семпл таблицы из 48 значений. `CLK_HZ=27_000_000`, `AUDIO_HZ=48_000`: средний интервал равен 562,5 pixel clocks. Ниже **только подключение оригинального генератора**, не новая реализация:

```verilog
wire sample_valid;
wire [15:0] sine_sample;
tone_1k #(.CLK_HZ(27000000), .AUDIO_HZ(48000)) u_tone (
    .clk(clk_pixel), .rst_n(rst_n),
    .valid(sample_valid), .sample(sine_sample)
);
// В hdmi_tx:
// .audio_valid(sample_valid), .audio_l(sine_sample), .audio_r(sine_sample)
```

В авторской системе **видео и audio_valid находятся в одном тактовом домене**. Это важное условие, а не второстепенная подробность.

## 2. Можно ли использовать только аудиочасть?

**Да, как подсистему аудиопакетизации при сохранении собственного совместимого HDMI-видеотракта. Нет, как отдельный источник HDMI-аудио без всего HDMI-транспорта.**

Можно выделить:
- генератор PCM/`tone_1k` или другой аудиоисточник;
- генераторы `hdmi_audio_sample_packet`, `hdmi_acr_packet`, Audio InfoFrame из `hdmi_packets.v`;
- BCH-контроль `hdmi_packet_ecc.v`;
- планировщик `hdmi_island_scheduler.v` и `hdmi_data_island.v`.

Но реальные аудиоданные **должны занять HDMI Data Islands того же TMDS-потока**, который несёт видео. Если в PiKoSoL установлен DVI-only encoder без Data Islands, отдельно скопированный `hdmi_acr_packet` **не создаст звук**. Возможны два инженерных пути:

**Путь 1 — заменить TX ядро целиком:** подать на этот `hdmi_tx` наши RGB-пиксели и PCM, сохранив физический сериализатор подходящей платы. Это наиболее понятный опытный вариант, но проверка ресурсоёмкости и фазирования нужна до реальной интеграции.

**Путь 2 — встроить аудиопланировщик в существующий HDMI TX:** возможно лишь если тот уже поддерживает HDMI control/data-island periods, правильные guard bands, TERC4/BCH и тайминги. Это сложнее и рискованнее, чем путь 1; смешивать нетождественные форки нельзя.

Отдельный `tone_1k` не нуждается в HDMI и может быть переиспользован для иных аудиовыходов, однако сам по себе это только генератор тестового PCM, **не IP аудиоконтроллера**.

## 3. Узкие места оригинала для универсального SoC IP

| Проблема | Что уже есть в коде | Что нужно для зрелого IP | Статус |
| --- | --- | --- | --- |
| Приём PCM | `audio_valid, audio_l/r`, буфер на четыре стереопары | Контракт ready/valid, подсчёт потерь, корректный underflow | NOT IMPLEMENTED |
| Источник из другого clock domain | Всё внутри `clk_pixel` | CDC: dual-clock FIFO, reset synchronizers, стационарный sample clock | NOT IMPLEMENTED |
| Форматы видео | Параметры H/V, VIC, N/CTS | Конфигурации с согласованными clock, blanking, ACR и InfoFrames; режимные TB | NOT VERIFIED |
| Экономия памяти | RGB по координатам, **нет framebuffer** | Внешняя DDR3/SDRAM, DMA/line FIFO для произвольного изображения | NOT IMPLEMENTED |
| Планирование HDMI пакетов | Очередь `QDEPTH=8`, `MAX_PACKETS=3`, src_ready | Проверки при переполнении, конфликтах ACR/ASP/InfoFrames и новых видеорежимах | NOT FULLY VERIFIED |
| Электрический вывод | Gowin `OSER10`, `TLVDS_OBUF`, PLL | Изолированный `board_adapter` для конкретной платы и STA/constraints | PARTIALLY SEPARATED |
| Работа CPU + HDMI | Отдельный RTL-демо | Bus bridge, video registers, DMA, IRQ и ресурсный бюджет | NOT IMPLEMENTED |

### Важное наблюдение по исходному `hdmi_tx.v`

При `acount == 4` дополнительные PCM-семплы больше не записываются; внешний сигнал `audio_ready` отсутствует. Это **ограничение интерфейса, обнаруживаемое статически**, а не подтверждённая потеря на аппаратном тесте. Один раз в каждой строке приёмный пакет освобождает буфер при `src_ready`, а частота 48 кГц в штатном режиме подобрана достаточно низко. Но при произвольном источнике аудио без flow control нельзя гарантировать отсутствие потерь.

Отдельно необходимо тестировать **одновременный** `audio_valid` и `push_audio`, сброс, заполненную очередь, начало/конец горизонтального гашения, смену режимов.

### Размеры буферов и честный ресурсный вывод

- Только образцы `abuf_l/r`: **128 бит** (4×2×16).
- Очередь планировщика содержит 8 записей по 24+224 = 248 бит, то есть **1984 бита полезного хранилища** без учёта служебных регистров.
- Дополнительные три слота Data Island по 24+224 = 248 бит = **744 бита**.
- Числа здесь — **логические ёмкости данных**, не физический состав BSRAM после синтеза. Расход 7 BSRAM, 1369 LUT, 955 FF заявлен автором для целого проекта. Наш `top.fs` имеет размер 7 264 150 байт, но это не оценка используемой RAM.

В PiKoSoL, где доступность BSRAM/PLL уже ограничивает развитие, нужен **полный netlist utilization и STA**, а не предположение, что «аудио занимает мало».

## 4. Предлагаемая архитектура нашей будущей интеграции (НЕ собрана)

```text
            PiKoSoL PicoRV32 / program
                   | MMIO/CSR
                   v
              audio control
      PCM producer --async FIFO-----+
                                   |
    video text/gen + optional line FIFO ---> HDMI AV core
                  |                |        RGB, PCM, status
           framebuffer only       v
           if actually needed   Gowin adapter (rPLL, CLKDIV, OSER10, TLVDS)
                                    |
                                HDMI monitor
```

**Минимальный контракт будущего `pikosol_hdmi_av`** (предложение, не проверенная реализация):
- `video_x[11:0], video_y[11:0], video_rgb[23:0], video_valid` и документированная задержка;
- `audio_sample_valid, audio_sample_ready, audio_left[15:0], audio_right[15:0]` в определённом домене;
- `status: pll_lock, packets_sent, fifo_overflow, fifo_underflow, audio_clock_error`;
- профили 480p и иной подтверждённый HDMI mode, привязанные к тактовым и ACR-константам.

Только после отдельного прохода `simulation → build/STA → SRAM BOARD PASS` он может войти в готовый IP-реестр. Ни одной новой `.fs` сейчас не создавалось, PiKoSoL и Flash не менялись.

## 5. Контрольный маршрут повторного использования

1. Удержать pinned upstream и MIT заголовки — **выполнено**, файлы ниже `vendor/` не редактируются.
2. Сверить blob SHA с upstream для каждого файла — **проверить в manifest** (см. README).
3. Провести регрессию `tb_audio.v` и новые corner-case TB в изолированном проекте.
4. Убрать зависимость от глобальных путей `src/hdmi/hdmi_defs.vh` через чёткую структуру IP/include paths.
5. Измерить ресурсы и STA для **нашей** сборки и затем вместе с PiKoSoL.
6. Только после одобрения — отдельная интеграционная сборка и аппаратный тест SRAM-only.

**Граница claims:** оригинальная HDMI Audio демо на нашей плате — **BOARD PASS**. Предложенный универсальный SoC IP — **NOT BUILT**, статья — инженерный анализ, не заявление о новой реализации.
