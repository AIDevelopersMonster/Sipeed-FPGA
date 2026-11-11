@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>&1
if not errorlevel 1 (py -3 kx2_gui.py & goto END)
python kx2_gui.py
:END
if errorlevel 1 pause
endlocal
