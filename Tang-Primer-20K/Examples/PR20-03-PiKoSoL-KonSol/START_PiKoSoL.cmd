@echo off
setlocal
cd /d "%~dp0"
echo PiKoSoL TP20 - GitHub ZIP startup - SRAM only - NO Flash
where py.exe >nul 2>nul
if not errorlevel 1 (
    py.exe -3 "%~dp0START_PiKoSoL.py" %*
) else (
    where python.exe >nul 2>nul
    if errorlevel 1 (
        echo ERROR: Python 3 is required. Install Python 3 with tkinter and pyserial.
        pause
        exit /b 2
    )
    python.exe "%~dp0START_PiKoSoL.py" %*
)
set "rc=%ERRORLEVEL%"
if not "%rc%"=="0" (
    echo.
    echo START FAILED. Inspect the error above; verified firmware was not overwritten.
    pause
)
exit /b %rc%
