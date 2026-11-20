@echo off
setlocal
cd /d "%~dp0"
echo PiKoSoL TP20 read-only PKD1 header audit / NO COM / NO FLASH
where py >nul 2>nul
if not errorlevel 1 (
    py -3 "%~dp0PiKoSoL_FileManager.py" --audit-header
) else (
    python "%~dp0PiKoSoL_FileManager.py" --audit-header
)
if errorlevel 1 echo AUDIT FAILED. Original files were not changed.
pause
endlocal
