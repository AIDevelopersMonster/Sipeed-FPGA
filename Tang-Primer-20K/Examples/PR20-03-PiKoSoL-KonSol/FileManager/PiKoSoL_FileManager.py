#!/usr/bin/env python3
"""PiKoSoL TP20 File Manager v0.1 — independent PC-only Windows GUI candidate.

Works with previously board-tested files installed in Downloads/
TP20_PiKoSoL_PicoRV32_UART_HDMI_TEST:
    tools/host_console.py + firmware/monitor.bin + firmware/demo.bin

No Gowin Programmer calls, NO writes to FPGA Flash, NO changes to any .fs,
monitor.bin or demo.bin. Unlike an FPGA file system, every app is sent to RAM.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import os
from pathlib import Path
from queue import Empty, Queue
import subprocess
import sys
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from pikosol_core import (
    Paths, APP_CAPACITY, APP_ORIGIN, APP_ENTRY,
    auto_paths, check_baseline, inspect_binary, command_for_host,
    parse_transfer_output, save_transfer_log, TransferResult, sha256_file, DEMO_SHA256,
)
from pikosol_xmodem import send_binary, TransferError
from pikosol_catalog import make_catalog, find_generated
from pikosol_github import list_verified, download_verified
from pikosol_core import audit_headers
from build_hello_rv32i import build as build_hello, BANNER

APP_VERSION = '0.2.0 — GITHUB CATALOG CANDIDATE'
BG = '#0B1020'
PANEL = '#131D31'
PANEL2 = '#18243A'
LINE = '#273650'
WHITE = '#EDF5FF'
MUTED = '#9AAEC7'
AQUA = '#28D7CB'
BLUE = '#58AEFF'
GREEN = '#60D996'
YELLOW = '#F8C86E'
RED = '#FF7F86'
MONO = 'Consolas'
FONT = 'Segoe UI'


def label(master, text, size=10, color=WHITE, weight='normal', **kwargs):
    return tk.Label(master, text=text, font=(FONT, size, weight),
                    fg=color, bg=kwargs.pop('bg', PANEL), **kwargs)


def button(master, title, command, primary=False, danger=False, size=10):
    color = AQUA if primary else (RED if danger else PANEL2)
    foreground = BG if primary else WHITE
    b = tk.Button(master, text=title, command=command,
                  bg=color, fg=foreground, activebackground=BLUE,
                  activeforeground=BG, relief='flat', bd=0,
                  font=(FONT, size, 'bold'), padx=13, pady=8,
                  cursor='hand2', highlightthickness=0)
    return b


class PiKoSoLGUI(tk.Tk):
    def __init__(self, paths: Paths, *, smoke: bool = False, port: str = 'COM10'):
        super().__init__()
        self.paths = paths
        self.smoke = smoke
        self.title('PiKoSoL TP20 / File Manager — CANDIDATE / NO FLASH')
        self.geometry('1230x820')
        self.minsize(990, 690)
        self.configure(bg=BG)
        self.protocol('WM_DELETE_WINDOW', self.close_app)
        self.jobs = Queue()
        self.serial = None
        self.serial_thread = None
        self.serial_stop = threading.Event()
        self.child = None
        self.cancelled = False
        self.busy = False
        self.monitor_ok = False
        self.attached = False
        self.files: dict[str, Path] = {}
        self.pinned_files: dict[str, Path] = {}
        self.hidden_names: set[str] = set()
        self.remote_apps = []
        self.remote_requires = {}
        self.remote_choice = tk.StringVar(value='')
        self.remote_busy = False
        self.selected = None
        self.pending_line = ''
        self.port_var = tk.StringVar(value=port)
        self.hdmi_only_var = tk.BooleanVar(value=False)
        self.status_var = tk.StringVar(value='Отключено')
        self.run_info_var = tk.StringVar(value='Программа не передавалась')
        self.filename_var = tk.StringVar(value='Программа не выбрана')
        self._configure_style()
        self._build_ui()
        self.refresh_files()
        self._check_initial()
        self.after(60, self._poll_jobs)

    def _configure_style(self):
        style = ttk.Style(self)
        style.theme_use('clam')
        style.configure('Dark.Treeview', background=PANEL2, fieldbackground=PANEL2,
                        foreground=WHITE, borderwidth=0, rowheight=30,
                        font=(FONT, 10))
        style.configure('Dark.Treeview.Heading', background=PANEL, foreground=AQUA,
                        font=(FONT, 9, 'bold'), borderwidth=0)
        style.map('Dark.Treeview', background=[('selected', '#175D7F')],
                  foreground=[('selected', WHITE)])
        style.configure('Dark.TNotebook', background=BG, borderwidth=0)
        style.configure('Dark.TNotebook.Tab', background=PANEL2, foreground=MUTED,
                        font=(FONT, 10, 'bold'), padding=(20, 9))
        style.map('Dark.TNotebook.Tab', background=[('selected', PANEL)],
                  foreground=[('selected', AQUA)])
        style.configure('Dark.Horizontal.TProgressbar', background=AQUA,
                        troughcolor=PANEL2, bordercolor=PANEL2)

    def _build_ui(self):
        header = tk.Frame(self, bg=BG, padx=22, pady=16)
        header.pack(fill='x')
        tk.Label(header, text='PiKoSoL', fg=WHITE, bg=BG,
                 font=(FONT, 28, 'bold')).pack(side='left')
        tk.Label(header, text='TP20  /  FILE MANAGER', fg=AQUA, bg=BG,
                 font=(FONT, 12, 'bold')).pack(side='left', padx=(15, 0), pady=(13, 0))
        tk.Label(header, text='КАНДИДАТ  •  RAM ONLY  •  NO FLASH',
                 fg=YELLOW, bg=BG, font=(FONT, 10, 'bold')).pack(side='right', pady=14)

        toolbar = tk.Frame(self, bg=PANEL, padx=18, pady=12)
        toolbar.pack(fill='x', padx=20)
        label(toolbar, 'UART').pack(side='left', padx=(0, 7))
        self.port_entry = tk.Entry(toolbar, textvariable=self.port_var, width=8,
                                   bg=PANEL2, fg=WHITE, insertbackground=WHITE,
                                   relief='flat', font=(MONO, 12), justify='center')
        self.port_entry.pack(side='left', ipady=7)
        self.connect_button = button(toolbar, 'Подключить терминал', self.toggle_serial)
        self.connect_button.pack(side='left', padx=(10, 10))
        self.upload_button = button(toolbar, 'Загрузить .bin + RUN', self.start_app_transfer, primary=True)
        self.upload_button.pack(side='left', padx=(0, 10))
        button(toolbar, 'Восстановить монитор', self.start_recovery).pack(side='left')
        self.cancel_button = button(toolbar, 'Прервать ПК-процесс', self.cancel_transfer, danger=True)
        self.cancel_button.pack(side='right', padx=(10, 0))
        self.cancel_button.config(state='disabled')

        statuses = tk.Frame(self, bg=BG)
        statuses.pack(fill='x', padx=20, pady=(12, 8))
        cards = [
            ('FPGA / RISC-V', 'GW2A-18C • PicoRV32', GREEN),
            ('ПРОГРАММЫ', 'LOAD 0x2000C000 / <= 12 KiB', AQUA),
            ('TRANSPORT', 'COM10 • 115200 • XMODEM-CRC', BLUE),
            ('СОХРАННОСТЬ', 'Без записи Flash / .fs', YELLOW),
        ]
        for i, (heading, content, shade) in enumerate(cards):
            card = tk.Frame(statuses, bg=PANEL, padx=14, pady=9, highlightthickness=1,
                            highlightbackground=LINE)
            card.grid(row=0, column=i, sticky='nsew', padx=(0, 9) if i < 3 else 0)
            statuses.columnconfigure(i, weight=1)
            label(card, heading, 9, shade, 'bold').pack(anchor='w')
            label(card, content, 10, WHITE).pack(anchor='w', pady=(4, 0))

        main = tk.PanedWindow(self, bg=BG, bd=0, sashwidth=8, orient='horizontal',
                              sashrelief='flat')
        main.pack(fill='both', expand=True, padx=20, pady=(0, 10))
        left = tk.Frame(main, bg=PANEL, padx=14, pady=12, highlightthickness=1,
                        highlightbackground=LINE)
        right = tk.Frame(main, bg=BG)
        main.add(left, minsize=320, width=385)
        main.add(right, minsize=560)
        self._make_library(left)
        self._make_workspace(right)

        bottom = tk.Frame(self, bg=BG, padx=20, pady=9)
        bottom.pack(fill='x')
        label(bottom, 'СОСТОЯНИЕ:', 9, MUTED, 'bold', bg=BG).pack(side='left')
        tk.Label(bottom, textvariable=self.status_var, font=(FONT, 10, 'bold'),
                 fg=AQUA, bg=BG).pack(side='left', padx=(8, 0))
        tk.Label(bottom, textvariable=self.run_info_var, font=(FONT, 9),
                 fg=MUTED, bg=BG).pack(side='right')
        self.progress = ttk.Progressbar(self, style='Dark.Horizontal.TProgressbar',
                                        orient='horizontal', mode='indeterminate')
        # Reserve footer space before the resizable middle pane. In Tk pack
        # order this avoids a tall Treeview consuming the entire window.
        main.pack_forget()
        bottom.pack_forget()
        self.progress.pack(side='bottom', fill='x', padx=20, pady=(0, 8))
        bottom.pack(side='bottom', fill='x', padx=20, pady=9)
        main.pack(side='top', fill='both', expand=True, padx=20, pady=(0, 10))

    def _make_library(self, parent):
        label(parent, 'ЛОКАЛЬНЫЕ .BIN', 14, WHITE, 'bold').pack(anchor='w')
        label(parent, 'Файлы на ПК. Это не файловая система FPGA.', 9, MUTED).pack(anchor='w', pady=(4, 10))
        cloud = tk.Frame(parent, bg=PANEL)
        cloud.pack(fill='x', pady=(9, 2))
        label(cloud, 'GitHub: доступные BIN / статус проверки', 9, AQUA, 'bold').pack(anchor='w')
        self.remote_select = ttk.Combobox(cloud, textvariable=self.remote_choice, state='readonly')
        self.remote_select.pack(fill='x', pady=(5, 5))
        remote_buttons = tk.Frame(cloud, bg=PANEL)
        remote_buttons.pack(fill='x')
        button(remote_buttons, 'Получить список', self.fetch_remote_catalog).pack(side='left', fill='x', expand=True)
        button(remote_buttons, 'Скачать выбранный', self.fetch_remote_app).pack(side='left', padx=(6, 0), fill='x', expand=True)
        label(parent, 'Локальные программы:', 9, MUTED).pack(anchor='w', pady=(6, 3))
        list_area = tk.Frame(parent, bg=PANEL)
        list_area.pack(fill='both', expand=True)
        self.tree = ttk.Treeview(list_area, columns=('name', 'size'), show='headings', height=7,
                                 selectmode='browse', style='Dark.Treeview')
        self.tree.heading('name', text='Имя программы')
        self.tree.heading('size', text='байт')
        self.tree.column('name', width=232, stretch=True)
        self.tree.column('size', width=80, anchor='e', stretch=False)
        self.tree.pack(fill='both', expand=True, side='left')
        sb = tk.Scrollbar(list_area, orient='vertical', command=self.tree.yview,
                          bg=PANEL2, troughcolor=PANEL)
        sb.pack(side='right', fill='y')
        self.tree.configure(yscrollcommand=sb.set)
        self.tree.bind('<<TreeviewSelect>>', self._on_select)
        row1 = tk.Frame(parent, bg=PANEL)
        row1.pack(fill='x', pady=(10, 6))
        button(row1, '+ Выбрать файл', self.add_file, primary=True).pack(side='left', fill='x', expand=True)
        button(row1, 'Обновить', self.refresh_files).pack(side='left', padx=(8, 0))
        row2 = tk.Frame(parent, bg=PANEL)
        row2.pack(fill='x')
        button(row2, 'Открыть папку', self.open_selected_folder).pack(side='left', fill='x', expand=True)
        button(row2, 'Убрать из списка', self.drop_selected).pack(side='left', padx=(8, 0), fill='x', expand=True)
        self.file_details = tk.Text(parent, height=5, wrap='word', state='disabled',
                                    bg=PANEL2, fg=WHITE, font=(MONO, 9), relief='flat',
                                    highlightthickness=0, padx=12, pady=12)
        self.file_details.pack(fill='x', pady=(11, 0))
        note = ('RAM only; формат PKD1/RV32I.\n'
                'XMODEM <= 12 KiB с padding.\n'
                'Запуск — только отдельной кнопкой.')
        label(parent, note, 9, MUTED, justify='left').pack(anchor='w', pady=(10, 0))

    def _make_workspace(self, right):
        actions = tk.Frame(right, bg=PANEL, padx=15, pady=13,
                           highlightthickness=1, highlightbackground=LINE)
        actions.pack(fill='x')
        label(actions, 'СВОИ ПРОГРАММЫ НА RISC-V', 12, WHITE, 'bold').pack(anchor='w')
        label(actions, 'Создать пример HELLO для HDMI без GCC. Не заменяет проверенный demo.bin.',
              9, MUTED).pack(anchor='w', pady=(4, 8))
        b = button(actions, 'Создать HELLO PKD1', self.make_hello, primary=True)
        b.pack(side='left')
        label(actions, 'PKD1 проверен по demo.bin; аппаратный запуск нового кода пока неизвестен',
              9, YELLOW).pack(side='left', padx=(12, 0))

        notebook = ttk.Notebook(right, style='Dark.TNotebook')
        notebook.pack(fill='both', expand=True, pady=(11, 0))
        term_page = tk.Frame(notebook, bg=PANEL)
        log_page = tk.Frame(notebook, bg=PANEL)
        help_page = tk.Frame(notebook, bg=PANEL)
        notebook.add(term_page, text='⌨  Терминал Live')
        notebook.add(log_page, text='↔  Протокол передачи')
        notebook.add(help_page, text='?  Инструкция')
        self._make_terminal(term_page)
        self._make_protocol(log_page)
        self._make_help(help_page)
        self.notebook = notebook

    def _make_terminal(self, page):
        bar = tk.Frame(page, bg=PANEL, padx=12, pady=10)
        bar.pack(fill='x')
        label(bar, 'Нажми в окно ниже и печатай: символы сразу отправляются на HDMI',
              9, AQUA).pack(side='left')
        commands = tk.Frame(page, bg=PANEL, padx=12)
        commands.pack(fill='x')
        for command in ('HELP', 'INFO', 'CLS'):
            button(commands, command, lambda cmd=command: self.send_command(cmd), size=9).pack(side='left', padx=(0, 7), pady=(0, 8))
        h = tk.Frame(page, bg=PANEL)
        h.pack(fill='both', expand=True, padx=12, pady=(0, 9))
        self.terminal = tk.Text(h, bg='#071224', fg='#D1F4E7', insertbackground=AQUA,
                                font=(MONO, 11), wrap='word', undo=False,
                                relief='flat', padx=12, pady=12, highlightthickness=1,
                                highlightbackground=LINE)
        self.terminal.pack(side='left', fill='both', expand=True)
        scroll = tk.Scrollbar(h, command=self.terminal.yview)
        scroll.pack(side='right', fill='y')
        self.terminal.configure(yscrollcommand=scroll.set)
        self.terminal.bind('<KeyPress>', self.on_terminal_key)
        self.terminal.insert('end',
            'PiKoSoL TP20 / Live HDMI terminal\n'
            'Нажмите «Подключить терминал». Затем печатайте здесь.\n'
            'LOAD вручную не вводите — используйте «Загрузить .bin + RUN».\n\n')
        self.terminal.tag_configure('rx', foreground='#BFEAE2')
        self.terminal.tag_configure('meta', foreground=YELLOW)
        self.terminal.mark_set('insert', 'end')
        foot = tk.Frame(page, bg=PANEL, padx=12, pady=6)
        foot.pack(fill='x')
        chk = tk.Checkbutton(foot, text='HDMI only (не показывать копию UART в окне)',
                             variable=self.hdmi_only_var, bg=PANEL, fg=MUTED,
                             activebackground=PANEL, activeforeground=WHITE,
                             selectcolor=PANEL2, font=(FONT, 9))
        chk.pack(side='left')

    def _make_protocol(self, page):
        label(page, 'СЛУЖЕБНЫЙ ПРОТОКОЛ  /  XMODEM-CRC', 11, AQUA, 'bold').pack(anchor='w', padx=12, pady=(12, 6))
        self.protocol_text = tk.Text(page, bg='#071224', fg=WHITE, insertbackground=WHITE,
                                     font=(MONO, 10), wrap='word', relief='flat',
                                     padx=12, pady=12)
        self.protocol_text.pack(fill='both', expand=True, padx=12, pady=(0, 12))
        self.protocol_text.insert('end', 'Проверка исходных файлов и история операций:\n\n')
        self.protocol_text.configure(state='disabled')

    def _make_help(self, page):
        helptext = '''КАК РАБОТАЕТ PiKoSoL File Manager

1. Плата уже должна содержать штатный System_picoRV32.fs и PiKoSoL monitor.bin.
2. Нажмите «Подключить терминал», затем печатайте в зелёном окне.
3. Выберите локальный .bin. demo.bin — ранее проверен на плате.
4. Кнопка «Загрузить .bin + RUN» временно освобождает COM10.
   Для demo.bin использует host_console.py (уже проверен на плате);
   для СВОЕГО .bin — отдельный экспериментальный XMODEM-CRC.
   При подтверждённом возврате RUN включается Live-клавиатура.
5. Конфигурация FPGA и Flash никогда не программируются этим приложением.

ИЗГОТОВЛЕНИЕ СОБСТВЕННЫХ БИНАРНИКОВ

Кнопка «Создать HELLO» строит без GCC компактный RV32I-код, который
записывает цветной текст в экранную память 0x30000000 и делает RET.
Использует сигнатуру из рабочего demo.bin. Новый пример ещё не имеет
аппаратного PASS, поэтому сначала испытайте его как отдельного кандидата.

РАЗНИЦА ФОРМАТОВ

.fs — конфигурация FPGA для Gowin, загружается отдельным программатором.
.bin — программа RV32I с заголовком PiKoSoL, передаётся в RAM по UART.
.elf — контейнер разработки, передавать напрямую через XMODEM нельзя.

ЕСЛИ ПРОИЗОШЁЛ СБОЙ LOAD

Не посылайте клавиатурой LOAD без бинарного передатчика. Если после
перезапуска на HDMI видно «Waiting for downloader ...», используйте
«Восстановить монитор». После выключения питания может потребоваться
отдельная SRAM-загрузка .fs штатным TP20_PiKoSoL_Run.ps1 -BoardTest.

Проверка .bin по формату и сигнатуре НЕ доказывает его корректность.
Произвольный код может повиснуть; перезагрузка FPGA выполняется
ТОЛЬКО явно оператором, не данным GUI.
'''
        t = tk.Text(page, wrap='word', bg=PANEL, fg=WHITE, relief='flat',
                    font=(FONT, 11), padx=18, pady=15)
        t.pack(fill='both', expand=True)
        t.insert('end', helptext)
        t.configure(state='disabled')

    def _check_initial(self):
        try:
            for check in check_baseline(self.paths):
                self.log(check, 'good')
            self.log('FPGA НЕ изменена; подключение UART будет только по кнопке.', 'info')
            self.status_var.set('Базовые файлы: PASS / FPGA не проверена')
        except Exception as exc:
            self.log(f'Проверка комплекта: {exc}', 'warn')
            self.log(f'Выбранная папка: {self.paths.root}', 'warn')
            self.status_var.set('Проверка файлов: FAIL — проверьте вкладку Протокол')

    def log(self, msg: str, level: str = 'info'):
        now = datetime.now().strftime('%H:%M:%S')
        self.protocol_text.configure(state='normal')
        self.protocol_text.insert('end', f'[{now}] {msg}\n')
        self.protocol_text.see('end')
        if int(self.protocol_text.index('end-1c').split('.')[0]) > 1200:
            self.protocol_text.delete('1.0', '200.0')
        self.protocol_text.configure(state='disabled')

    def _append_terminal(self, s: str, tag: str = 'rx'):
        if not s:
            return
        self.terminal.insert('end', s, tag)
        self.terminal.see('end')
        if int(self.terminal.index('end-1c').split('.')[0]) > 1500:
            self.terminal.delete('1.0', '250.0')


    def refresh_files(self):
        previous_name = self.selected.name.casefold() if self.selected else 'demo.bin'
        self.files = make_catalog(self.paths.root / 'firmware',
                                  find_generated(Path(__file__).resolve().parent),
                                  demo=self.paths.demo, pinned=self.pinned_files.values(),
                                  hidden=self.hidden_names)
        for iid in self.tree.get_children():
            self.tree.delete(iid)
        chosen = None
        for path in sorted(self.files.values(), key=lambda p: (p.name.casefold() != 'demo.bin', p.name.casefold())):
            iid = str(path)
            self.tree.insert('', 'end', iid=iid, values=(path.name, f'{path.stat().st_size:,}'))
            if path.name.casefold() == previous_name:
                chosen = iid
        if chosen is None and str(self.paths.demo) in self.files:
            chosen = str(self.paths.demo)
        if chosen is None and self.files:
            chosen = next(iter(self.files))
        if chosen:
            self.tree.selection_set(chosen)
            self.tree.focus(chosen)
            self.tree.see(chosen)
            self.selected = self.files[chosen]
            self._on_select()
        else:
            self.selected = None
            self._show_file('No programs found')

    @staticmethod
    def _remote_label(entry):
        req = entry.get("requires", "BASE_TP20")
        label = f"{entry['name']} [{entry['status']}]"
        return label if req == "BASE_TP20" else label + " / " + req + " REQUIRED"

    def fetch_remote_catalog(self):
        if self.remote_busy or self.busy:
            return
        self.remote_busy = True
        self.status_var.set('Получаем список проверенных BIN из GitHub...')
        def task():
            try:
                entries = list_verified()
                self.jobs.put(('github_catalog', entries))
            except Exception as exc:
                self.jobs.put(('github_error', str(exc)))
        threading.Thread(target=task, daemon=True).start()

    def fetch_remote_app(self):
        if self.remote_busy or self.busy:
            return
        choice = self.remote_choice.get()
        match = next((a for a in self.remote_apps if self._remote_label(a) == choice), None)
        if match is None:
            messagebox.showinfo('GitHub', 'Сначала получите каталог и выберите программу.')
            return
        self.remote_busy = True
        self.status_var.set('Скачивание и проверка SHA256...')
        def task():
            try:
                # Re-read the signed-by-hash allowlist before each download:
                # changes to the remote catalog cannot silently bypass approval.
                entries = list_verified()
                fresh = next((a for a in entries if a == match), None)
                if fresh is None:
                    raise ValueError('Каталог изменился: заново получите список')
                cache = Path.home() / 'Downloads' / 'PiKoSoL_TP20_GitHub_BIN'
                saved = download_verified(fresh, cache, self.paths.demo, inspect=inspect_binary)
                self.jobs.put(('github_download', saved, fresh))
            except Exception as exc:
                self.jobs.put(('github_error', str(exc)))
        threading.Thread(target=task, daemon=True).start()

    def add_file(self):
        p = filedialog.askopenfilename(title='Выберите RISC-V raw .bin',
                                       initialdir=str(self.paths.root / 'firmware'),
                                       filetypes=[('PiKoSoL RV32I binary', '*.bin'), ('Все файлы', '*.*')])
        if not p:
            return
        path = Path(p).resolve()
        if path == self.paths.monitor.resolve():
            messagebox.showerror('Не программа', 'monitor.bin — системный монитор; его используют только через кнопку «Восстановить монитор».')
            return
        try:
            inspect_binary(path, self.paths.demo)
        except Exception as exc:
            messagebox.showerror('Неподходящий файл', str(exc))
            return
        self.pinned_files[path.name.casefold()] = path
        self.hidden_names.discard(path.name.casefold())
        self.refresh_files()
        self.tree.selection_set(str(path))
        self._on_select()
        self.log(f'Добавлен локальный файл: {path}')

    def drop_selected(self):
        if self.selected is None:
            return
        self.hidden_names.add(self.selected.name.casefold())
        self.pinned_files.pop(self.selected.name.casefold(), None)
        iid = str(self.selected)
        if self.tree.exists(iid):
            self.tree.delete(iid)
        self.selected = None
        self.refresh_files()
        self._show_file('File hidden in this session; original PC file was not deleted.')

    def open_selected_folder(self):
        folder = self.selected.parent if self.selected else self.paths.root
        try:
            if sys.platform == 'win32':
                os.startfile(str(folder))  # type: ignore[attr-defined]
            else:
                subprocess.Popen(['xdg-open', str(folder)])
        except Exception as exc:
            messagebox.showerror('Открыть папку', str(exc))

    def _show_file(self, text: str):
        self.file_details.configure(state='normal')
        self.file_details.delete('1.0', 'end')
        self.file_details.insert('end', text)
        self.file_details.configure(state='disabled')

    def _on_select(self, event=None):
        sel = self.tree.selection()
        if not sel:
            return
        self.selected = self.files.get(sel[0])
        if not self.selected:
            return
        self.filename_var.set(self.selected.name)
        try:
            info = inspect_binary(self.selected, self.paths.demo)
            self._show_file('PKD1 header/size/entry check PASS; BOARD TEST STILL REQUIRED.\n\n'+info.summary())
        except Exception as exc:
            self._show_file(f'ФОРМАТ НЕ ПРОШЁЛ ПРОВЕРКУ\n\n{exc}')

    def _get_port(self):
        port = self.port_var.get().strip().upper()
        if not port.startswith('COM') or not port[3:].isdigit():
            raise ValueError('Порт должен иметь вид COM10')
        return port

    def toggle_serial(self):
        if self.busy:
            return
        if self.attached:
            self._disconnect()
        else:
            self._connect()

    def _connect(self):
        if self.busy:
            return False
        try:
            import serial
            port = self._get_port()
            s = serial.Serial()
            s.port, s.baudrate, s.timeout, s.write_timeout = port, 115200, 0.1, 1.0
            s.bytesize, s.parity, s.stopbits = serial.EIGHTBITS, serial.PARITY_NONE, serial.STOPBITS_ONE
            s.dtr, s.rts = False, False
            s.open()
            self.serial = s
            self.serial_stop = threading.Event()
            self.serial_thread = threading.Thread(target=self._serial_reader,
                                                  args=(s, self.serial_stop), daemon=True)
            self.serial_thread.start()
            self.attached = True
            self.monitor_ok = True  # COM open != proven firmware. Be clear in status.
            self.connect_button.config(text='Отключить терминал')
            self.status_var.set(f'{port} подключён • живой ввод на HDMI')
            self.log(f'COM OPEN: {port}, 115200 8N1; клавиши передаются сразу')
            self._append_terminal(f'\n[PC] COM OPEN {port}. Печатайте здесь для HDMI.\n', 'meta')
            self.notebook.select(0)
            self.terminal.focus_set()
            return True
        except ImportError:
            messagebox.showerror('Не найден pyserial', 'В PowerShell установите: python -m pip install pyserial')
        except Exception as exc:
            self.status_var.set('COM не открыт')
            self.log(f'COM OPEN FAILED: {exc}', 'warn')
            messagebox.showerror('Ошибка UART', str(exc))
        return False

    def _serial_reader(self, serial_device, stop):
        try:
            while not stop.is_set():
                part = serial_device.read(4096)
                if part:
                    clean = bytes(b for b in part if b not in (0x0e, 0x0f, 0x1c, 0x1d))
                    if clean:
                        self.jobs.put(('uart', clean))
        except Exception as exc:
            if not stop.is_set():
                self.jobs.put(('uart_error', str(exc)))

    def _disconnect(self):
        if self.attached and self.serial is not None:
            self.serial_stop.set()
            if self.serial_thread:
                self.serial_thread.join(timeout=1.25)
            try:
                self.serial.close()
            except Exception:
                pass
            self.serial = None
        self.attached = False
        self.connect_button.config(text='Подключить терминал')
        self.status_var.set('COM закрыт • FPGA продолжает работать')
        self.log('COM закрыт на ПК; FPGA не сброшена')

    def on_terminal_key(self, event):
        # Default Text editing is always blocked; all keys go to UART immediately.
        if self.busy or not self.attached or self.serial is None:
            return 'break'
        if event.keysym in ('Return', 'KP_Enter'):
            if self.pending_line.strip().upper() == 'LOAD':
                try:
                    self.serial.write(b'\x08' * len(self.pending_line))
                except Exception:
                    pass
                self.pending_line = ''
                self.log('Команда LOAD не отправлена: используйте кнопку передачи .bin', 'warn')
                self._append_terminal('\n[PC] LOAD запрещён в ручном режиме: используйте загрузчик GUI.\n', 'meta')
                return 'break'
            data = b'\r'
            self.pending_line = ''
        elif event.keysym == 'BackSpace':
            data = b'\x08'
            self.pending_line = self.pending_line[:-1]
        elif event.keysym == 'p' and (event.state & 0x4):
            # Avoid unverified Ctrl-P handling as a default shortcut.
            return 'break'
        elif event.char and len(event.char) == 1 and 32 <= ord(event.char) <= 126:
            data = event.char.encode('ascii')
            self.pending_line += event.char
        else:
            return 'break'
        try:
            self.serial.write(data)
        except Exception as exc:
            self.log(f'UART TX error: {exc}', 'warn')
        return 'break'

    def send_command(self, command: str):
        if self.busy or not self.attached or self.serial is None:
            self.log('Команда не отправлена: COM10 должен быть подключён', 'warn')
            return
        if self.pending_line:
            self.log('Сначала завершите текущую строку Enter', 'warn')
            return
        try:
            self.serial.write(command.encode('ascii') + b'\r')
            self.log(f'UART TX: {command}')
            self.terminal.focus_set()
        except Exception as exc:
            self.log(f'UART TX error: {exc}', 'warn')

    def make_hello(self):
        try:
            check_baseline(self.paths)
            folder = Path(__file__).resolve().parent / 'generated'
            destination = folder / 'HELLO_PiKoSoL_TP20.bin'
            data = build_hello(self.paths.demo, destination)
            info = inspect_binary(destination, self.paths.demo)
            self.files[str(destination)] = destination
            self.refresh_files()
            self.tree.selection_set(str(destination))
            self._on_select()
            self.notebook.select(1)
            self.log(f'BUILD (offline) PASS: {destination} ({len(data)} bytes, magic 0x{info.demo_magic:08X})', 'good')
            self.log('Это НОВЫЙ BIN, BOARD PASS пока отсутствует; проверьте на плате отдельно.', 'warn')
            messagebox.showinfo('Сборка завершена',
                f'{destination.name}\n{len(data)} байт / {info.blocks} XMODEM блоков\n\n'
                'Готовый RV32I бинарник создан без GCC.\n'
                'Аппаратная проверка ещё не выполнена.')
        except Exception as exc:
            self.log(f'BUILD FAILED: {exc}', 'warn')
            messagebox.showerror('Сборка не выполнена', str(exc) + '\n\nВыбранная папка: ' + str(self.paths.root))

    def start_app_transfer(self):
        if self.busy:
            return
        if not self.selected:
            messagebox.showwarning('Не выбрана программа', 'Выберите локальный .bin')
            return
        try:
            check_baseline(self.paths)
            info = inspect_binary(self.selected, self.paths.demo)
        except Exception as exc:
            messagebox.showerror('Проверка перед XMODEM', str(exc) + '\n\nВыбранная папка: ' + str(self.paths.root))
            return
        requirement = self.remote_requires.get(self.selected.resolve(), '')
        if not requirement:
            name = self.selected.name.upper()
            if (name.endswith('__GPIO_V3714_ONLY.BIN')
                    or name.startswith(('TP20_GPIO_', 'TP20_PMOD'))
                    or name in ('TP20_ALL_LED_OFF.BIN', 'TP20_RGB_VIA_PMOD0_SOFTWARE_TEST.BIN')):
                requirement = 'GPIO_V3714'
        if requirement and requirement != 'BASE_TP20':
            warning = (
                f'Эта программа требует FPGA-конфигурацию {requirement}.\n'
                'Файловый менеджер не может подтвердить, какой .fs активен.\n'
                'Стандартная THLN33 (режим 1) несовместима с GPIO V3714.\n\n'
                'Убедитесь, что в FPGA действительно загружена нужная конфигурация.\n'
                'При несовместимом MMIO программа может зависнуть.\n\n'
                'Вы подтверждаете совместимость и хотите продолжить?'
            )
            if not messagebox.askyesno('Требование к FPGA — перед RUN', warning):
                return
        custom = info.sha256.lower() != DEMO_SHA256
        method = ('Экспериментальный XMODEM для собственного .bin; аппаратный тест еще НЕ PASS.\n'
                  if custom else 'Проверенный host_console.py передаст demo.bin.\n')
        ask = (f'{info.path.name}\n{info.size} байт / {info.blocks} XMODEM блоков\n'
               f'Адрес 0x{APP_ORIGIN:08X}; точка входа ожидается 0x{APP_ENTRY:08X}.\n\n'
               + method
               + 'Если новый код зависнет, нужен ручной сброс/восстановление.\n'
               + 'FPGA .fs и Flash не изменяются.\n\n'
               + 'Передавать?')
        if not messagebox.askyesno('Загрузить в RAM и запустить?', ask):
            return
        self._start_transfer('app', self.selected, direct=custom)

    def start_recovery(self):
        if self.busy:
            return
        try:
            check_baseline(self.paths)
        except Exception as exc:
            messagebox.showerror('Нужны рабочие файлы', str(exc) + '\n\nВыбранная папка: ' + str(self.paths.root))
            return
        if not messagebox.askyesno('Восстановить монитор?',
            'Это загрузка monitor.bin в RAM штатным UART-загрузчиком.\n'
            'Используйте, только если HDL-загрузчик на HDMI пишет\n'
            '«Waiting for downloader ...».\n\n'
            'Если FPGA показывает другую систему, сначала отдельно\n'
            'загрузите оригинальный .fs в SRAM.\n\n'
            'Выполнять?'):
            return
        self._start_transfer('monitor', self.paths.demo)

    def _start_transfer(self, operation: str, program: Path, *, direct: bool = False):
        self._disconnect()  # serial COM must be free for the tested sender
        self.pending_line = ''
        self.busy = True
        self.cancelled = False
        self.cancel_button.config(state='normal')
        self.upload_button.config(state='disabled')
        self.connect_button.config(state='disabled')
        self.progress.start(12)
        self.status_var.set('Передача по XMODEM-CRC через штатный host_console.py')
        self.run_info_var.set('Программа запущена на ПК; статус BOARD ещё неизвестен')
        self.notebook.select(1)
        self.log(f'START {operation}: {program.name} -> UART RAM, никогда не Flash')
        if direct:
            self.log('НОВЫЙ BIN: экспериментальный универсальный XMODEM-CRC; demo.bin не изменён', 'warn')
            worker = threading.Thread(target=self._run_direct, args=(program,), daemon=True)
        else:
            cmd = command_for_host(self.paths, program,
                                   port=self.port_var.get().strip().upper(),
                                   operation=operation)
            worker = threading.Thread(target=self._run_host, args=(cmd, operation, program), daemon=True)
        worker.start()

    def _run_host(self, cmd: list[str], operation: str, program: Path):
        # The *only* host process allowed to own COM while transferring.
        # Sending :EXIT to stdin ahead of time is accepted by Python input()
        # once the verified host_console.py reaches its PC> prompt.
        try:
            child = subprocess.Popen(cmd, stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     cwd=str(self.paths.root), text=True,
                                     encoding='utf-8', errors='replace', bufsize=1)
            self.child = child
            try:
                out, _ = child.communicate(input=':EXIT\n', timeout=130)
                rc = child.returncode or 0
                result = parse_transfer_output(out, rc, operation)
                if self.cancelled:
                    result = TransferResult(rc=rc, out=out, xmodem_ack=result.xmodem_ack,
                                            ran=result.ran, returned=result.returned,
                                            loader_pass=result.loader_pass, cancelled=True)
            except subprocess.TimeoutExpired:
                child.kill()
                out, _ = child.communicate()
                result = TransferResult(rc=-9, out=out+'\nTIMEOUT after 130s',
                                        xmodem_ack=False, ran=False, returned=False,
                                        loader_pass=False, timed_out=True)
            file = save_transfer_log(operation, program, result)
            self.jobs.put(('transfer_done', operation, program, result, file))
        except Exception as exc:
            self.jobs.put(('transfer_exception', operation, str(exc)))
        finally:
            self.child = None

    def _run_direct(self, program: Path):
        log = []
        serial_device = None
        try:
            import serial
            serial_device = serial.Serial()
            serial_device.port = self.port_var.get().strip().upper()
            serial_device.baudrate = 115200
            serial_device.timeout = 0.12
            serial_device.write_timeout = 2
            serial_device.dtr = False
            serial_device.rts = False
            serial_device.open()
            image = program.read_bytes()

            def report(stage, done, total):
                msg = f'XMODEM [{done}/{total}]: {stage}'
                log.append(msg)
                self.jobs.put(('transfer_progress', msg))

            r = send_binary(serial_device, image, report)
            full = '\n'.join(log) + '\n' + r.output
            result = TransferResult(rc=0 if r.returned and r.acked == r.blocks else 4,
                                    out=full, xmodem_ack=r.ended and r.acked == r.blocks,
                                    ran=r.ran, returned=r.returned, loader_pass=False)
        except Exception as exc:
            log.append(f'UNCONFIRMED: {type(exc).__name__}: {exc}')
            result = TransferResult(rc=3, out='\n'.join(log), xmodem_ack=False,
                                    ran=False, returned=False, loader_pass=False)
        finally:
            if serial_device is not None:
                try:
                    serial_device.close()
                except Exception:
                    pass
            if self.cancelled:
                result = TransferResult(rc=3, out=result.out + '\nOPERATOR CANCEL',
                                        xmodem_ack=result.xmodem_ack, ran=result.ran,
                                        returned=result.returned, loader_pass=False,
                                        cancelled=True)
            file = save_transfer_log('app_generic', program, result)
            self.jobs.put(('transfer_done', 'app', program, result, file))

    def cancel_transfer(self):
        if not self.busy:
            return
        if messagebox.askyesno('Прервать передачу?',
            'Прерывание ПК-процесса может оставить монитор FPGA в ожидании XMODEM.\n'
            'Возможно, потребуется аппаратный сброс и восстановление монитора.\n\n'
            'Прервать?'):
            self.cancelled = True
            if self.child is not None:
                try:
                    self.child.kill()
                except Exception:
                    pass
            self.log('Отмена оператора: состояние программы в FPGA НЕИЗВЕСТНО', 'warn')

    def _finish_transfer(self, operation: str, program: Path, result, log_file: Path):
        self.busy = False
        self.progress.stop()
        self.cancel_button.config(state='disabled')
        self.upload_button.config(state='normal')
        self.connect_button.config(state='normal')
        self.log(f'ВЫВОД host_console.py / {program.name}:\n{result.out}', 'info')
        self.log(f'Протокол: XMODEM ACK={result.xmodem_ack}, RUN={result.ran}, '
                 f'RETURN={result.returned}, exit={result.rc}.', 'info')
        self.log(f'Локальный протокол: {log_file}', 'info')
        success = (result.pass_app if operation == 'app' else
                   result.rc == 0 and result.loader_pass and result.xmodem_ack)
        if success and not result.cancelled:
            self.status_var.set('HOST LOG PASS — требуется визуальная проверка HDMI')
            self.run_info_var.set('Загрузка завершена, возвращаем Live Keyboard')
            self.log('HOST LOG PASS; изображение на HDMI подтвердите визуально', 'good')
            self._connect()
        else:
            self.status_var.set('НЕ ПОДТВЕРЖДЕНО — состояние FPGA требует проверки')
            self.run_info_var.set('Не делаем BOARD PASS без проверки')
            self.log('Не запускаем авто-команды на FPGA. Проверьте фото/логи и при необходимости восстановите монитор.', 'warn')
            messagebox.showwarning('Загрузка не подтверждена',
               'Штатный XMODEM клиент не выдал полный подтверждённый результат.\n'
               'Работающей системе не присвоен новый BOARD PASS.\n'
               'Протокол сохранён во временной папке.\n\n'
               'Не отправляйте LOAD с клавиатуры.')

    def _poll_jobs(self):
        try:
            for _ in range(150):
                job = self.jobs.get_nowait()
                if job[0] == 'uart':
                    if not self.hdmi_only_var.get():
                        self._append_terminal(job[1].decode('ascii', errors='replace'))
                elif job[0] == 'uart_error':
                    self.log(f'RX ERR: {job[1]}', 'warn')
                elif job[0] == 'github_catalog':
                    self.remote_busy = False
                    self.remote_apps = job[1]
                    names = [self._remote_label(a) for a in self.remote_apps]
                    self.remote_select['values'] = names
                    self.remote_choice.set(names[0] if names else '')
                    self.status_var.set(f'GitHub: {len(names)} программ; статус каждой указан')
                    self.log('GitHub BIN catalog: ' + ', '.join(names), 'good')
                elif job[0] == 'github_download':
                    self.remote_busy = False
                    saved = Path(job[1])
                    self.remote_requires[saved.resolve()] = job[2].get('requires', 'BASE_TP20')
                    self.pinned_files[saved.name.casefold()] = saved
                    self.hidden_names.discard(saved.name.casefold())
                    self.refresh_files()
                    self.tree.selection_set(str(saved.resolve()))
                    self._on_select()
                    self.status_var.set('SHA256 + PKD1 PASS; аппаратный статус см. в каталоге')
                    self.log(f'GitHub BIN verified: {saved} (not sent to FPGA)', 'good')
                elif job[0] == 'github_error':
                    self.remote_busy = False
                    self.status_var.set('Ошибка GitHub: нет изменений FPGA')
                    self.log('GitHub download rejected: ' + job[1], 'warn')
                    messagebox.showerror('GitHub', job[1])
                elif job[0] == 'transfer_progress':
                    self.log(job[1])
                elif job[0] == 'transfer_done':
                    self._finish_transfer(*job[1:])
                elif job[0] == 'transfer_exception':
                    self.busy = False
                    self.progress.stop()
                    self.cancel_button.config(state='disabled')
                    self.upload_button.config(state='normal')
                    self.connect_button.config(state='normal')
                    self.status_var.set('Ошибка ПК-процесса')
                    self.log(f'Ошибка передачи: {job[2]}', 'warn')
        except Empty:
            pass
        if self.winfo_exists():
            self.after(60, self._poll_jobs)

    def close_app(self):
        if self.busy:
            messagebox.showwarning('Идёт передача',
                'Сначала дождитесь результата или нажмите «Прервать ПК-процесс».')
            return
        self._disconnect()
        self.destroy()


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', default='', help='Path to verified PiKoSoL root folder')
    ap.add_argument('--port', default='COM10', help='UART port, e.g. COM10')
    ap.add_argument('--check', action='store_true', help='Verify local working files without COM/GUI')
    ap.add_argument('--audit-header', action='store_true', help='Read only: print demo and custom .bin header words')
    ap.add_argument('--check-apps', action='store_true', help='Offline check all 5 candidates and verified demo; no COM or FPGA')
    ap.add_argument('--smoke', action='store_true', help='GUI startup smoke test without UART')
    args = ap.parse_args(argv)
    paths = auto_paths(Path(__file__).parent, args.root)
    if args.audit_header:
        return audit_headers(paths, find_generated(Path(__file__).resolve().parent))
    if args.check_apps:
        from build_tp20_apps import emulate, APPS, COLS, ROWS
        print('=== PIKOSOL TP20 APP ABI CHECK / PC ONLY / NO COM ===')
        try:
            check_baseline(paths)
            base = Path(__file__).resolve().parent/'generated'
            for name in APPS:
                app = base/name
                info = inspect_binary(app, paths.demo)
                pixels, steps = emulate(app.read_bytes())
                if len(pixels) != COLS*ROWS:
                    raise AssertionError(f'{name}: only {len(pixels)} video cells')
                print(f'APP ABI PASS {name} len={info.size} entry=0x{info.header[2]:08X} steps={steps} SHA256={info.sha256}')
            print('FIVE APP ABI + RV32I EMULATION PASS / BOARD UNKNOWN')
            return 0
        except Exception as exc:
            print('APP_ABI_FAIL:', exc, file=sys.stderr)
            return 2
    if args.check:
        print('SELECTED WORKING ROOT:', paths.root)
        try:
            for item in check_baseline(paths):
                print(item)
            print('FILE_MANAGER_PREPARE_PASS — no COM, no FPGA changes')
            return 0
        except Exception as exc:
            print(f'FILE_MANAGER_PREPARE_FAIL: {exc}', file=sys.stderr)
            return 2
    gui = PiKoSoLGUI(paths, smoke=args.smoke, port=args.port)
    if args.smoke:
        gui.after(900, gui.destroy)
    gui.mainloop()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
