# LAB-03 Observatory v1.1.0 — установка, подключение FPGA и запуск HTML

**Одна лаборатория, один репозиторий**: `C:\GitHub\Sipeed-FPGA`. Вся работа выполняется из PowerShell 7. Для просмотра архивных трасс подключать Tang Nano 9K не требуется; для нового аппаратного опыта нужна плата, уже загруженная **LAB-03.2**.

## A. Установка на существующем лабораторном ПК

1. Скачать `LAB03_Observatory_v1.1.0.zip` в `%USERPROFILE%\Downloads` из сообщения с релизом.
2. Если сервер v1.0.1 уже работает, остановить его `Ctrl+C` в соответствующем терминале. **Существующую живую вкладку Web Serial предварительно отключить** кнопкой «Отключить UART».
3. Сделать безопасную резервную копию старой версии и распаковать пакет:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA

$dest = '.\01-PicoRV32\build\observatory_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
New-Item -ItemType Directory -Path $dest -Force | Out-Null
if (Test-Path '.\docs\lab03\observatory') {
    Copy-Item '.\docs\lab03\observatory' -Destination $dest -Recurse -Force
}

Expand-Archive `
  -LiteralPath "$HOME\Downloads\LAB03_Observatory_v1.1.0.zip" `
  -DestinationPath . -Force
```

Новые документы и расширение браузерного приложения находятся под `docs/lab03/observatory/`. **ROM/RTL исходники, в том числе LAB-02, не заменяются**. Без отдельного аудита не используйте `git add .`, не выполняйте `git restore .`.

4. Проверить файлы:

```powershell
& .\01-PicoRV32\tools\launch_lab03_observatory.ps1 -CheckOnly
python .\docs\lab03\observatory\tests\verify_observatory.py
python .\docs\lab03\observatory\tests\test_asset_delivery.py
```

Не должно быть `FAIL`. При наличии Node.js 22+ можно проверить код интерфейса:

```powershell
node --test `
  .\docs\lab03\observatory\tests\trace-core.test.mjs `
  .\docs\lab03\observatory\tests\instruction-catalog.test.mjs `
  .\docs\lab03\observatory\tests\ui-smoke.test.mjs
```

5. Запустить сервер и открыть страницу:

```powershell
& .\01-PicoRV32\tools\launch_lab03_observatory.ps1
```

Открывать: **http://127.0.0.1:8765/** в Chrome/Edge. `Ctrl+Shift+R` обновляет ресурсы страницы. Через `file://` запускать **не следует**.

## B. Чистая установка репозитория (для нового студента)

```powershell
New-Item -ItemType Directory -Force C:\GitHub | Out-Null
git clone --branch feature/picorv32-lab03-uart-trace `
  https://github.com/AIDevelopersMonster/Sipeed-FPGA.git `
  C:\GitHub\Sipeed-FPGA
Set-Location C:\GitHub\Sipeed-FPGA
# Затем пункты A.1, A.3–A.5.
```

Архив Observatory поставляется отдельно от Git-коммита LAB-03, пока изменения v1.1.0 не опубликованы самостоятельным коммитом. Студенту не требуется клонировать внешний PicoRV32 только для анализа архивных трасс.

## C. Работа без физической платы

Вкладка **01 Наблюдение** → выбор любого из 12 RAW-захватов → кнопка «Воспроизвести»/стрелки → журнал и инспектор. Вкладка **03 Команды RV32I** → «Архив FPGA» или «Полная программа ROM». Вкладка **02 Сопоставление** → сравнение №03 (24 FETCH) с №05 (28 FETCH). Вкладка **04 Протокол студента** → собственный вывод → `.md`.

Все числа в архиве — реальные ранее полученные аппаратные данные. Это **не новый физический эксперимент студента**.

## D. Работа с физической Tang Nano 9K

### D.1. Уже настроенная плата

Если ранее получали T3 через COM10 и управляли LED, **не прошивайте плату повторно**. Подключите USB, запустите Observatory, нажмите **«Подключить COM-порт»**, в системном окне Chrome/Edge выберите USB-UART платы. Для разных компьютеров номер COM может отличаться. Единственный владелец порта — браузер; закройте другие терминалы и вкладки, открывавшие тот же COM.

### D.2. Первичная аппаратная подготовка (только если требуется)

Сначала зафиксированное ядро, RTL-тест и отдельная сборка LAB-03:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
& .\01-PicoRV32\tools\fetch_picorv32.ps1
& .\01-PicoRV32\tools\test_lab03_2.ps1
& .\01-PicoRV32\tools\build_lab03_2.ps1
```

Проверьте в PnR/STA-отчётах корректность реализации, ограничение 27 MHz, неотрицательные запасы временных параметров и нужное устройство `GW1NR-9C`. **Код возврата сборщика сам по себе недостаточен**, а собранный локально `.fs` не обязан иметь хеш старой кампании. После успешной проверки можно загрузить **только SRAM** штатным Gowin Programmer:

```powershell
$prog = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
$fs = (Resolve-Path '.\01-PicoRV32\impl\pnr\picorv32_lab03_nano9k.fs').Path
& $prog --device GW1NR-9C --operation_index 2 --fsFile $fs --cable-index 1
$LASTEXITCODE
```

Ожидается код 0 и успешное завершение операции SRAM; **не выбирайте Flash**. Нажмите и отпустите S2 (reset), затем откройте UART через браузер. Сборку и загрузку FPGA выполнять необязательно для уже проверенной платы.

### D.3. Один захват

1. Chrome/Edge, `http://127.0.0.1:8765/`, вкладка **Наблюдение**.
2. В Web Serial нажать **«Подключить COM-порт»**, выбрать порт.
3. Выбрать `0 — все выключены` или `4 — L4`.
4. Нажать **«● Захватить»**. Приложение самостоятельно отправит три ASCII-символа `C` → выбранная цифра → `T`; прочитает ответы `C`, `L=n`, затем `T3:… E:… Z`.
5. Увидеть статус проверки, число FETCH, MMIO-запись и реальный светодиод. Количество FETCH **измеряется**, а не задаётся наперёд.
6. Кнопка **«T · Повторить чтение»** читает предыдущий снимок; **«? · Состояние»** читает LED-регистр. Для нового снимка всегда нужна последовательность с `C`.
7. По окончании нажать **«Отключить UART»** — освободить COM-порт.

### D.4. Безопасность и неполадки

| Проявление | Первая проверка |
|---|---|
| «COM-порт занят» | Другой терминал/вкладка Chrome удерживает последовательный порт; закройте владельца |
| «Web Serial недоступен» | Chrome/Edge и адрес `http://127.0.0.1`, а не `file://` |
| Программа не выдаёт `T3` | FPGA содержит другую конфигурацию (LAB-02), не была сброшена S2 или UART занят |
| Нет стилей / пустые списки | Остановите старый сервер, `-CheckOnly`, `test_asset_delivery.py`, перезапустите и `Ctrl+Shift+R` |
| В событии `LED_WRITE` правильная маска, LED не светится | Проверьте физическое наблюдение отдельно; запись по шине не является фотометрией |
| `FETCH` различается по количеству | Рассмотрите UART polling; не диагностируйте неисправность по одному счётчику |

## E. Где лежат данные и отчёт

- Программа и стили: `docs/lab03/observatory/src/`.
- Истинный ROM LAB-03: `docs/lab03/observatory/data/lab03_boot.hex`.
- Встроенные 12 трасс и их хеши: `docs/lab03/observatory/data/campaign.json`.
- Первичный архив измерений: `docs/lab03/observatory/evidence/LAB03_3_EVIDENCE.zip`.
- Методические указания: `docs/lab03/observatory/methodics/`.
- Живые измерения **не сохраняются автоматически на сервер**: кнопкой `↓` экспортируйте T3 в Downloads. Отчёт студента экспортируется через вкладку 04 в `.md`.

**Граница:** HTML не заменяет Gowin, не программирует FPGA, не меняет USB-драйверы и не подтверждает instruction retirement.
