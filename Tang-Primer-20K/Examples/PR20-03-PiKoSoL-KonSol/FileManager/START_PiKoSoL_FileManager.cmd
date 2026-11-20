@echo off
setlocal
cd /d "%~dp0"
echo PiKoSoL TP20 File Manager / RAM ONLY / no Flash
where py >nul 2>nul
if not errorlevel 1 (
    py -3 "%~dp0PiKoSoL_FileManager.py" --check
    if errorlevel 1 goto fail
    py -3 "%~dp0PiKoSoL_FileManager.py"
) else (
    python "%~dp0PiKoSoL_FileManager.py" --check
    if errorlevel 1 goto fail
    python "%~dp0PiKoSoL_FileManager.py"
)
if errorlevel 1 goto fail
goto done
:fail
(
    echo.
    echo CHECK FAILED. See the exact path and SHA256 above.
    echo No board operation was performed by the preflight check.
    pause
)
:done
endlocal
