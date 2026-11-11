@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>&1
if not errorlevel 1 (
    py -3 "%~dp0konsol_gui.py"
    goto END
)
where python >nul 2>&1
if not errorlevel 1 (
    python "%~dp0konsol_gui.py"
    goto END
)
echo Python 3 is required. Install Python 3 with Tkinter and pyserial.
:END
if errorlevel 1 pause
endlocal
