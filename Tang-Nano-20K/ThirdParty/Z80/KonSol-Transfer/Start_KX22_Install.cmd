@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>&1
if not errorlevel 1 (
  py -3 kx2_install.py --port COM25 --yes
) else (
  python kx2_install.py --port COM25 --yes
)
if errorlevel 1 pause
endlocal
