@echo off
setlocal
cd /d "%~dp0"
where gcc >nul 2>nul
if not errorlevel 1 (
  gcc -std=c90 -O2 -Wall -Wextra -o demos.exe src\main.c src\terminal.c src\platform_stdio.c src\mandel.c src\life.c src\maze.c src\sort.c src\cube.c src\ulam.c src\cpuinfo.c
) else (
  where clang >nul 2>nul
  if errorlevel 1 (
    echo No GCC or Clang in PATH. Install a C compiler, or compile for your target CPU.
    exit /b 2
  )
  clang -std=c90 -O2 -Wall -Wextra -o demos.exe src\main.c src\terminal.c src\platform_stdio.c src\mandel.c src\life.c src\maze.c src\sort.c src\cube.c src\ulam.c src\cpuinfo.c
)
if errorlevel 1 exit /b 1
echo Built demos.exe
.\demos.exe