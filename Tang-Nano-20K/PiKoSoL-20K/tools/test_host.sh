#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
"${CC:-cc}" -std=c99 -Wall -Wextra -Werror -pedantic -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer firmware/pikosol_shell.c tests/test_shell.c -o build/test_shell
ASAN_OPTIONS=detect_leaks=1 ./build/test_shell
python3 -m unittest discover -s tests -p 'test_*.py' -v
