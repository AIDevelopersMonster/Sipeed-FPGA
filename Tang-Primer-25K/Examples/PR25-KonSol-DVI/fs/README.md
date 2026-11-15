# fs — подтверждённая прошивка KonSol

Рабочий файл с ПК оператора: `%TEMP%\PR25_KonSol_LocalTrial\impl\pnr\pr25_konsol_trial.fs`.

**Состояние: файл ещё не загружен на GitHub.** Из исходного ZIP его получить нельзя: в ZIP находятся только исходники и сценарий. На экране оператора это изображение уже получено (BOARD VIDEO PASS); SHA256 и размер `.fs` необходимо считать из локального оригинала.

После выполнения `../Upload_Trial_Artifacts.ps1` здесь появятся **один** `pr25_konsol_trial.fs` и `sha256.txt` (с контрольной суммой). Никаких архивов десятков промежуточных неудачных сборок, никаких Releases.

Программирование **только в SRAM**:

```powershell
$fs = 'C:\GitHub\PR25-KonSol-DVI\fs\pr25_konsol_trial.fs'
$cli = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
Get-FileHash -Algorithm SHA256 -LiteralPath $fs
& $cli --device GW5A-25A --cable-index 1 --run 2 --fsFile $fs
```

Для использования этого фрагмента сначала самостоятельно скачать `.fs` из GitHub в указанный локальный путь, либо заменить `$fs` на его реальный путь. **Не записывать во Flash.**

Дистрибуция файла, включающего GOWIN DVI_TX, должна соответствовать применимым условиям GOWIN EULA; см. [IP guide](../../../../ip/hdmi/gowin-dvi-tx/README.md).
