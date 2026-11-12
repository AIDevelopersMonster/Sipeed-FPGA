@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 "%~dp0fuzix_terminal.py" --port COM25
) else (
  python "%~dp0fuzix_terminal.py" --port COM25
)
if errorlevel 1 (
  echo.
  echo If pyserial is missing, use: py -3 -m pip install pyserial
  pause
)
endlocal