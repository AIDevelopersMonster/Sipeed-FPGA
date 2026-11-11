#!/usr/bin/env python3
"""KonSol File Commander v0.3: one window for Windows <-> Z80 / CP/Mish.

Extends the original KX1 Transfer GUI. Uses the existing KX1 P/G transport
and KX22's KX2 V/L/R/D management commands; no FPGA bitstream changes.
"""
from __future__ import annotations

import datetime as dt
import os
import queue
import re
import subprocess
import threading
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk
from tkinter.scrolledtext import ScrolledText

import konsol_transfer as kx
import kx2_client as kx2
import kx_gui_backend as backend

APP_NAME = 'KonSol File Commander v0.3'
BG = '#0d1628'
SURFACE = '#17253b'
TEXT = '#e9f1fb'
MUTED = '#a8bbd1'
ACCENT = '#47d5bf'
BLUE = '#438aff'
WARNING = '#ffcf7a'
MAX_LOG_LINES = 500


def size_label(n: int) -> str:
    if n >= 1048576:
        return f'{n / 1048576:.1f} МиБ'
    if n >= 1024:
        return f'{n / 1024:.1f} КиБ'
    return f'{n} Б'


def avail_ports() -> list[str]:
    try:
        from serial.tools import list_ports
        return sorted({p.device for p in list_ports.comports()}) or ['COM25']
    except ImportError:
        return ['COM25']


class KonSolApp(tk.Tk):
    """Reworked original Transfer GUI, not a second management application."""

    def __init__(self):
        super().__init__()
        self.title(APP_NAME + '  |  Tang Nano 20K')
        self.geometry('1210x800')
        self.minsize(950, 690)
        self.configure(bg=BG)
        self.protocol('WM_DELETE_WINDOW', self._close)
        self.events: queue.Queue[tuple] = queue.Queue()
        self.busy = False
        self.port = tk.StringVar(value='COM25')
        self.drive = tk.StringVar(value='B')
        self.send_name = tk.StringVar()
        self.get_name = tk.StringVar()
        self.length_mode = tk.StringVar(value='auto')
        self.exact_length = tk.StringVar()
        self.status = tk.StringVar(value='Запустите KX22 на FPGA и закройте терминал COM25')
        self.remote_hint = tk.StringVar(value='↻ Нажмите «Каталог FPGA» для чтения реального диска')
        self.folder = backend.KX1_SIBLING if backend.KX1_SIBLING.is_dir() else Path(__file__).resolve().parent
        self.local_items: dict[str, Path] = {}
        self.remote_items: dict[str, str] = {}
        self.remote_names: set[str] = set()
        self.list_ok = False
        self.statefile = backend.state_path()
        self._style()
        self._build()
        self.refresh_local()
        self._clear_remote()
        self.after(90, self._process_events)
        self._log('Одна программа: загрузка, скачивание, каталог, переименование и удаление.')
        self._log('COM25 / 115200 · приёмник B:KX22.BBC · FPGA Flash не изменяется.')

    def _style(self):
        style = ttk.Style(self)
        if 'clam' in style.theme_names():
            style.theme_use('clam')
        style.configure('K.TButton', padding=(10, 8), background='#273a57', foreground=TEXT,
                        font=('Segoe UI', 10))
        style.map('K.TButton', background=[('active', '#365376'), ('disabled', '#1a2740')],
                  foreground=[('disabled', '#74849a')])
        style.configure('Accent.TButton', padding=(13, 9), background=BLUE,
                        foreground='white', font=('Segoe UI Semibold', 10))
        style.map('Accent.TButton', background=[('active', '#286de0'), ('disabled', '#263a60')])
        style.configure('K.TEntry', padding=5, fieldbackground='#eff6ff', foreground='#16233b')
        style.configure('K.TCombobox', padding=5, fieldbackground='#eff6ff', foreground='#16233b')
        style.configure('K.Treeview', background='#101d32', fieldbackground='#101d32',
                        foreground=TEXT, rowheight=27, font=('Consolas', 10), borderwidth=1)
        style.configure('K.Treeview.Heading', background='#223654', foreground='#dae9f9',
                        relief='flat', font=('Segoe UI Semibold', 9), padding=7)
        style.map('K.Treeview', background=[('selected', '#266e86')], foreground=[('selected', 'white')])
        style.configure('K.Horizontal.TProgressbar', troughcolor='#1f324b',
                        background=ACCENT, borderwidth=0)
        style.configure('K.TRadiobutton', background=SURFACE, foreground=TEXT, font=('Segoe UI', 9))
        style.map('K.TRadiobutton', background=[('active', SURFACE)], foreground=[('active', TEXT)])

    def _btn(self, parent, title, callback, *, accent=False, width=None):
        return ttk.Button(parent, text=title, command=callback,
                          style='Accent.TButton' if accent else 'K.TButton', width=width)

    def _build(self):
        head = tk.Frame(self, bg=BG)
        head.pack(fill='x', padx=20, pady=(13, 8))
        tk.Label(head, text='KonSol File Commander', bg=BG, fg=TEXT,
                 font=('Segoe UI Semibold', 21)).pack(side='left')
        tk.Label(head, text='v0.3  ·  Windows ↔ FPGA / Z80', bg=BG, fg=ACCENT,
                 font=('Segoe UI', 11)).pack(side='left', padx=15, pady=(9, 0))

        bar = tk.Frame(self, bg=SURFACE, padx=15, pady=9)
        bar.pack(fill='x', padx=18, pady=(0, 8))
        tk.Label(bar, text='COM-порт', bg=SURFACE, fg=TEXT).pack(side='left')
        self.ports = ttk.Combobox(bar, textvariable=self.port, values=avail_ports(),
                                  width=11, style='K.TCombobox')
        self.ports.pack(side='left', padx=(7, 6))
        self.port_refresh_btn = self._btn(bar, '↻', self._refresh_ports, width=3)
        self.port_refresh_btn.pack(side='left')
        tk.Label(bar, text='115200 8N1', bg=SURFACE, fg=MUTED).pack(side='left', padx=11)
        self.boot_btn = self._btn(bar, 'Запустить KX22', self._boot_receiver)
        self.boot_btn.pack(side='right')

        bottom = tk.Frame(self, bg=BG)
        bottom.pack(side='bottom', fill='x', padx=18, pady=(0, 10))
        row = tk.Frame(bottom, bg=BG)
        row.pack(fill='x', pady=(0, 6))
        tk.Label(row, textvariable=self.status, bg=BG, fg=MUTED, anchor='w',
                 font=('Segoe UI', 9)).pack(side='left', fill='x', expand=True)
        self.progress = ttk.Progressbar(row, style='K.Horizontal.TProgressbar',
                                        length=195, maximum=100, mode='determinate')
        self.progress.pack(side='right')
        self.log = ScrolledText(bottom, bg='#081221', fg='#cfe1f5', insertbackground='white',
                                font=('Consolas', 9), height=5, relief='flat', bd=1, wrap='word')
        self.log.pack(fill='both')
        self.log.configure(state='disabled')

        main = tk.PanedWindow(self, orient='horizontal', sashwidth=8, bg=BG, bd=0, relief='flat')
        main.pack(fill='both', expand=True, padx=18, pady=(0, 8))
        left = tk.Frame(main, bg=SURFACE, padx=12, pady=12)
        right = tk.Frame(main, bg=SURFACE, padx=12, pady=12)
        main.add(left, stretch='always', minsize=420)
        main.add(right, stretch='always', minsize=420)
        self._build_local(left)
        self._build_remote(right)

        self.bind('<F2>', lambda _: self.refresh_remote())
        self.bind('<F5>', self._f5)
        self.bind('<F6>', lambda _: self.rename_remote())
        self.bind('<F8>', lambda _: self.delete_remote())

    def _build_local(self, p):
        tk.Label(p, text='WINDOWS  ·  локальные файлы', bg=SURFACE, fg=TEXT,
                 font=('Segoe UI Semibold', 13)).pack(anchor='w')
        tk.Label(p, text='Выберите файл и нажмите «Загрузить →»', bg=SURFACE, fg=MUTED,
                 font=('Segoe UI', 9)).pack(anchor='w', pady=(2, 9))
        folder_row = tk.Frame(p, bg=SURFACE)
        folder_row.pack(fill='x', pady=(0, 8))
        self.folder_label = tk.Label(folder_row, text='', bg=SURFACE, fg='#d1e4fb', anchor='w',
                                     font=('Consolas', 9))
        self.folder_label.pack(side='left', expand=True, fill='x')
        self._btn(folder_row, 'Папка…', self.choose_folder).pack(side='right', padx=(5, 0))
        self._btn(folder_row, '↻', self.refresh_local, width=3).pack(side='right')

        treebox = tk.Frame(p, bg=SURFACE)
        treebox.pack(fill='both', expand=True)
        self.local_tree = ttk.Treeview(treebox, columns=('name', 'size', 'date'),
                                       show='headings', selectmode='browse', height=3, style='K.Treeview')
        for col, title, width, anchor in [
            ('name', 'Имя', 220, 'w'), ('size', 'Размер', 82, 'e'), ('date', 'Дата', 100, 'w')
        ]:
            self.local_tree.heading(col, text=title)
            self.local_tree.column(col, minwidth=60, width=width, anchor=anchor,
                                   stretch=col == 'name')
        scroll = ttk.Scrollbar(treebox, orient='vertical', command=self.local_tree.yview)
        self.local_tree.configure(yscrollcommand=scroll.set)
        scroll.pack(side='right', fill='y')
        self.local_tree.pack(fill='both', expand=True)
        self.local_tree.bind('<<TreeviewSelect>>', self._select_local)
        self.local_tree.bind('<Double-1>', self._open_local_item)

        line = tk.Frame(p, bg=SURFACE)
        line.pack(fill='x', pady=(11, 4))
        tk.Label(line, text='Имя файла на FPGA (8.3):', bg=SURFACE, fg=TEXT).pack(side='left')
        self.send_entry = ttk.Entry(line, textvariable=self.send_name, style='K.TEntry', width=20)
        self.send_entry.pack(side='left', padx=(8, 0), fill='x', expand=True)
        self.send_btn = self._btn(p, 'Загрузить на FPGA  →', self._send, accent=True)
        self.send_btn.pack(fill='x', pady=(5, 0))
        tk.Label(p, text='Загрузка не перезаписывает существующий файл.', bg=SURFACE,
                 fg=MUTED, font=('Segoe UI', 9)).pack(anchor='w', pady=(8, 0))

    def _build_remote(self, p):
        tk.Label(p, text='FPGA / Z80  ·  реальный каталог CP/Mish', bg=SURFACE, fg=TEXT,
                 font=('Segoe UI Semibold', 13)).pack(anchor='w')
        tk.Label(p, textvariable=self.remote_hint, bg=SURFACE, fg=WARNING,
                 font=('Segoe UI', 9), anchor='w').pack(fill='x', pady=(2, 7))
        drive_row = tk.Frame(p, bg=SURFACE)
        drive_row.pack(fill='x', pady=(0, 7))
        tk.Label(drive_row, text='Диск:', bg=SURFACE, fg=TEXT).pack(side='left')
        self.drive_select = ttk.Combobox(drive_row, textvariable=self.drive, values=['A', 'B'],
                                         width=4, state='readonly', style='K.TCombobox')
        self.drive_select.pack(side='left', padx=(8, 8))
        self.drive_select.bind('<<ComboboxSelected>>', self._drive_changed)
        self.refresh_btn = self._btn(drive_row, '↻ Каталог FPGA (F2)', self.refresh_remote)
        self.refresh_btn.pack(side='right')

        # Reserve controls FIRST at the bottom. The growing file list must never
        # push Download / Rename / Delete outside a 768px-tall Windows desktop.
        controls = tk.Frame(p, bg=SURFACE)
        controls.pack(side='bottom', fill='x')
        tk.Label(controls, text='Выбранный файл FPGA:', bg=SURFACE, fg=TEXT).pack(
            anchor='w', pady=(6, 3))
        self.get_entry = ttk.Entry(controls, textvariable=self.get_name, style='K.TEntry')
        self.get_entry.pack(fill='x')
        modes = tk.Frame(controls, bg=SURFACE)
        modes.pack(fill='x', pady=(6, 4))
        ttk.Radiobutton(modes, text='Точная длина, если файл ранее загружали из Windows',
                        variable=self.length_mode, value='auto', style='K.TRadiobutton',
                        command=self._length_toggle).pack(anchor='w')
        ttk.Radiobutton(modes, text='Полный размер CP/M (дополнение до 128 байт)',
                        variable=self.length_mode, value='full', style='K.TRadiobutton',
                        command=self._length_toggle).pack(anchor='w')
        exact_row = tk.Frame(modes, bg=SURFACE)
        exact_row.pack(fill='x')
        ttk.Radiobutton(exact_row, text='Указать длину:', variable=self.length_mode,
                        value='exact', style='K.TRadiobutton',
                        command=self._length_toggle).pack(side='left')
        self.exact_entry = ttk.Entry(exact_row, textvariable=self.exact_length,
                                     width=12, style='K.TEntry', state='disabled')
        self.exact_entry.pack(side='left', padx=7)
        tk.Label(exact_row, text='байт', bg=SURFACE, fg=MUTED).pack(side='left')
        self.get_btn = self._btn(controls, '←  Скачать с FPGA', self._get, accent=True)
        self.get_btn.pack(fill='x', pady=(4, 5))
        cmd = tk.Frame(controls, bg=SURFACE)
        cmd.pack(fill='x')
        self.rename_btn = self._btn(cmd, 'F6  Переименовать', self.rename_remote)
        self.rename_btn.pack(side='left', fill='x', expand=True, padx=(0, 4))
        self.delete_btn = self._btn(cmd, 'F8  Удалить', self.delete_remote)
        self.delete_btn.pack(side='left', fill='x', expand=True, padx=(4, 0))
        tk.Label(controls, text='*Размер из истории Windows; у остальных файлов неизвестен.',
                 bg=SURFACE, fg=MUTED, font=('Segoe UI', 8)).pack(anchor='w', pady=(7, 0))

        treebox = tk.Frame(p, bg=SURFACE)
        treebox.pack(fill='both', expand=True)
        self.remote_tree = ttk.Treeview(treebox, columns=('name', 'size'), show='headings',
                                        selectmode='browse', height=3, style='K.Treeview')
        self.remote_tree.heading('name', text='Файл на диске FPGA')
        self.remote_tree.heading('size', text='Размер*')
        self.remote_tree.column('name', width=265, minwidth=130, anchor='w')
        self.remote_tree.column('size', width=90, minwidth=65, anchor='e', stretch=False)
        scroll = ttk.Scrollbar(treebox, orient='vertical', command=self.remote_tree.yview)
        self.remote_tree.configure(yscrollcommand=scroll.set)
        scroll.pack(side='right', fill='y')
        self.remote_tree.pack(fill='both', expand=True)
        self.remote_tree.bind('<<TreeviewSelect>>', self._select_remote)
        self.remote_tree.bind('<Double-1>', lambda _: self._get())

    def _drive_changed(self, _event=None):
        self._clear_remote()
        if not self.busy:
            self.refresh_remote()

    def _f5(self, _event=None):
        if self.focus_get() == self.remote_tree:
            self._get()
        else:
            self._send()

    def _refresh_ports(self):
        values = avail_ports()
        port = self.port.get().strip()
        if port and port not in values:
            values.append(port)
        self.ports['values'] = values

    def choose_folder(self):
        path = filedialog.askdirectory(initialdir=str(self.folder), title='Папка Windows')
        if path:
            self.folder = Path(path)
            self.refresh_local()

    def refresh_local(self):
        try:
            items = list(self.folder.iterdir())
        except OSError as exc:
            messagebox.showerror('Папка Windows', str(exc))
            return
        self.folder_label.configure(text=str(self.folder))
        self.local_tree.delete(*self.local_tree.get_children())
        self.local_items.clear()
        if self.folder.parent != self.folder:
            item = self.local_tree.insert('', 'end', values=('..  [выше]', '', ''))
            self.local_items[item] = self.folder.parent
        for item in sorted(items, key=lambda p: (not p.is_dir(), p.name.casefold())):
            try:
                if not item.is_file() and not item.is_dir():
                    continue
                s = item.stat()
                when = dt.datetime.fromtimestamp(s.st_mtime).strftime('%d.%m %H:%M')
                size = '<DIR>' if item.is_dir() else size_label(s.st_size)
                prefix = '▸ ' if item.is_dir() else '  '
                row = self.local_tree.insert('', 'end', values=(prefix + item.name, size, when))
                self.local_items[row] = item
            except OSError:
                continue

    def _clear_remote(self):
        self.remote_tree.delete(*self.remote_tree.get_children())
        self.remote_items.clear()
        self.remote_names.clear()
        self.list_ok = False
        self.remote_hint.set('↻ Нажмите «Каталог FPGA» для чтения реального диска')

    def _selected_remote(self) -> str | None:
        row = self.remote_tree.selection()
        return self.remote_items.get(row[0]) if row else None

    def _select_local(self, _event=None):
        row = self.local_tree.selection()
        item = self.local_items.get(row[0]) if row else None
        if item and item.is_file():
            name = backend.filename_83(item.name)
            self.send_name.set(name or '')
            if name is None:
                self.status.set('Для FPGA введите имя латиницей в формате 8.3')

    def _open_local_item(self, _event=None):
        row = self.local_tree.selection()
        item = self.local_items.get(row[0]) if row else None
        if item and item.is_dir():
            self.folder = item
            self.refresh_local()

    def _select_remote(self, _event=None):
        name = self._selected_remote()
        if name:
            self.get_name.set(name)
            self.length_mode.set('auto')
            self._length_toggle()

    def _length_toggle(self):
        self.exact_entry.configure(state='normal' if self.length_mode.get() == 'exact' else 'disabled')

    def _set_busy(self, busy: bool, message: str):
        self.busy = busy
        self.status.set(message)
        if busy:
            self.progress['value'] = 0
        for btn in (self.send_btn, self.get_btn, self.boot_btn, self.refresh_btn,
                    self.rename_btn, self.delete_btn, self.port_refresh_btn):
            btn.configure(state='disabled' if busy else 'normal')
        self.drive_select.configure(state='disabled' if busy else 'readonly')
        self.ports.configure(state='disabled' if busy else 'normal')

    def _run_async(self, title: str, task, kind: str, *, silent: bool = False):
        if self.busy:
            return
        self._set_busy(True, title + '…')
        def worker():
            try:
                result = task()
                self.events.put(('done', kind, title, result))
            except (kx.TransferError, OSError, ValueError) as exc:
                self.events.put(('error', title, str(exc), silent))
            except Exception as exc:
                self.events.put(('error', title, f'{type(exc).__name__}: {exc}', silent))
        threading.Thread(target=worker, daemon=True).start()

    def refresh_remote(self, *, silent: bool = False):
        if self.busy:
            return
        drive = self.drive.get()
        port_name = self.port.get().strip()
        self._clear_remote()
        def task():
            with kx._open_serial(port_name) as port:
                raw = kx2.Manager(port).list_raw(drive)
            return drive, raw
        self._run_async('Чтение каталога ' + drive + ':', task, 'directory', silent=silent)

    def _display_directory(self, drive: str, raw: str):
        if drive != self.drive.get():
            return
        rows = kx2.parse_directory(raw, drive)
        try:
            known = {item['name']: item['size'] for item in backend.known_files(self.statefile)}
        except (OSError, ValueError, kx.TransferError):
            known = {}
        self._clear_remote()
        for name in rows:
            size = size_label(known[name]) if name in known else '—'
            row = self.remote_tree.insert('', 'end', values=(name, size))
            self.remote_items[row] = name
            self.remote_names.add(name)
        self.list_ok = True
        self.remote_hint.set(f'Диск {drive}:  {len(rows)} файлов  ·  каталог с FPGA')
        self._log(f'Каталог {drive}: {len(rows)} файлов')
        if raw.strip() and not rows:
            self.remote_hint.set('Каталог получен, но формат списка не распознан — см. журнал')
            self._log('Не удалось распознать строки DIR: ' + raw[:700].replace('\n', ' | '))

    def _send(self):
        if self.busy:
            return
        row = self.local_tree.selection()
        src = self.local_items.get(row[0]) if row else None
        if not src or not src.is_file():
            messagebox.showinfo('Загрузка', 'Выберите файл слева (Windows).')
            return
        try:
            remote = kx2.safe_file(f'{self.drive.get()}:{self.send_name.get()}')
            command = backend.build_send_command(self.port.get(), src, remote, self.statefile)
        except (kx.TransferError, OSError) as exc:
            messagebox.showerror('Загрузка', str(exc))
            return
        self._start_transfer('Загрузка на FPGA', command)

    def _get(self):
        if self.busy:
            return
        try:
            remote = kx.normalized_name(self.get_name.get())
        except kx.TransferError as exc:
            messagebox.showerror('Скачивание', str(exc))
            return
        mode = self.length_mode.get()
        exact = None
        if mode == 'exact':
            try:
                exact = int(self.exact_length.get())
            except ValueError:
                messagebox.showerror('Скачивание', 'Введите точную длину в байтах.')
                return
        if mode == 'auto':
            try:
                history = {item['name'] for item in backend.known_files(self.statefile)}
            except (OSError, ValueError, kx.TransferError):
                history = set()
            if remote not in history:
                if not messagebox.askokcancel('Длина неизвестна',
                      'Для этого файла нет точной длины из истории Windows.\n'
                      'Будет скачан полный размер CP/M (с возможными добавочными байтами).\n\n'
                      'Для точного размера можно выбрать режим «Указать длину».\n\nПродолжить?'):
                    return
        dest = filedialog.asksaveasfilename(title='Сохранить файл с FPGA',
                                             initialdir=str(self.folder), initialfile=remote[2:])
        if not dest:
            return
        try:
            command = backend.build_get_command(self.port.get(), remote, Path(dest), mode=mode,
                                                exact_length=exact, manifest=self.statefile)
        except (kx.TransferError, OSError) as exc:
            messagebox.showerror('Скачивание', str(exc))
            return
        self._start_transfer('Скачивание с FPGA', command)

    def _start_transfer(self, title: str, command: list[str]):
        def task():
            kwargs = {'stdout': subprocess.PIPE, 'stderr': subprocess.STDOUT,
                      'stdin': subprocess.DEVNULL, 'text': True, 'bufsize': 1,
                      'encoding': 'utf-8', 'errors': 'replace'}
            if os.name == 'nt':
                kwargs['creationflags'] = subprocess.CREATE_NO_WINDOW
            with subprocess.Popen(command, **kwargs) as process:
                assert process.stdout is not None
                for line in process.stdout:
                    message = line.rstrip('\r\n')
                    if message:
                        self.events.put(('log', message))
                    match = re.search(r'(?:Send|Receive)\s+(\d+)/(\d+)\s+blocks', message)
                    if match and int(match.group(2)):
                        self.events.put(('progress', int(match.group(1)) * 100 / int(match.group(2))))
                result_code = process.wait()
            if result_code != 0:
                raise kx.TransferError(f'{title}: код завершения {result_code}. Подробности в журнале.')
            return None
        self._run_async(title, task, 'transfer')

    def _boot_receiver(self):
        port_name = self.port.get().strip()
        self._run_async('Запуск KX22', lambda: backend.boot_receiver(port_name), 'boot')

    def rename_remote(self):
        if self.busy:
            return
        old = self._selected_remote()
        if not self.list_ok or not old:
            messagebox.showinfo('Переименование', 'Сначала обновите каталог и выберите файл справа.')
            return
        try:
            kx2.safe_file(old)
        except kx.TransferError as exc:
            messagebox.showerror('Переименование', str(exc))
            return
        value = simpledialog.askstring('Переименовать файл на FPGA',
                                        f'Новое имя для {old} (формат 8.3):',
                                        initialvalue=old[2:], parent=self)
        if value is None:
            return
        try:
            new = kx2.safe_file(value if ':' in value else old[:2] + value)
            if old == new or new[:2] != old[:2]:
                raise kx.TransferError('Выберите другое имя на том же диске.')
        except kx.TransferError as exc:
            messagebox.showerror('Переименование', str(exc))
            return
        if not messagebox.askyesno('Подтвердить переименование', f'{old}  →  {new}\n\nВыполнить на microSD FPGA?', parent=self):
            return
        port_name, drive = self.port.get().strip(), self.drive.get()
        def task():
            with kx._open_serial(port_name) as port:
                manager = kx2.Manager(port)
                manager.rename(old, new, confirmed=True)
                try:
                    raw = manager.list_raw(drive)
                    error = ''
                except (kx.TransferError, OSError, ValueError) as exc:
                    raw, error = None, str(exc)
            return 'rename', old, new, drive, raw, error
        self._run_async('Переименование ' + old, task, 'mutation')

    def delete_remote(self):
        if self.busy:
            return
        old = self._selected_remote()
        if not self.list_ok or not old:
            messagebox.showinfo('Удаление', 'Сначала обновите каталог и выберите файл справа.')
            return
        try:
            kx2.safe_file(old)
        except kx.TransferError as exc:
            messagebox.showerror('Удаление', str(exc))
            return
        if not messagebox.askyesno('Подтвердить удаление',
                f'Удалить {old} с microSD FPGA?\n\nОперация необратима!', parent=self):
            return
        port_name, drive = self.port.get().strip(), self.drive.get()
        def task():
            with kx._open_serial(port_name) as port:
                manager = kx2.Manager(port)
                manager.delete(old, confirmed=True)
                try:
                    raw = manager.list_raw(drive)
                    error = ''
                except (kx.TransferError, OSError, ValueError) as exc:
                    raw, error = None, str(exc)
            return 'delete', old, None, drive, raw, error
        self._run_async('Удаление ' + old, task, 'mutation')

    def _process_events(self):
        try:
            for _ in range(100):
                event = self.events.get_nowait()
                kind = event[0]
                if kind == 'log':
                    self._log(event[1])
                elif kind == 'progress':
                    self.progress['value'] = max(0, min(100, event[1]))
                elif kind == 'error':
                    _, title, message, silent = event
                    self._log(title + ': ' + message)
                    self._set_busy(False, 'Ошибка: ' + message[:130])
                    if not silent:
                        messagebox.showerror(APP_NAME, message)
                elif kind == 'done':
                    _, action, title, value = event
                    self._set_busy(False, title + ' — готово')
                    if action == 'directory':
                        self._display_directory(*value)
                    elif action == 'transfer':
                        self.progress['value'] = 100
                        self._log(title + ' — готово')
                        self.refresh_local()
                        self.refresh_remote(silent=True)
                    elif action == 'boot':
                        self._log(str(value))
                        self.refresh_remote(silent=True)
                    elif action == 'mutation':
                        change, old, new, drive, raw, refresh_error = value
                        try:
                            if change == 'rename':
                                backend.rename_known_file(old, new, self.statefile)
                            else:
                                backend.forget_known_file(old, self.statefile)
                        except (OSError, ValueError, kx.TransferError) as exc:
                            self._log('Файл на FPGA изменён, но история Windows не обновлена: ' + str(exc))
                        if change == 'rename':
                            self._log(f'Переименовано на FPGA: {old} → {new}')
                            self.get_name.set(new)
                        else:
                            self._log(f'Удалено на FPGA: {old}')
                            self.get_name.set('')
                        if raw is not None:
                            self._display_directory(drive, raw)
                        else:
                            self._clear_remote()
                            self._log('Операция выполнена; обновить каталог не удалось: ' + refresh_error)
                else:
                    self._log('Неизвестное событие: ' + str(kind))
        except queue.Empty:
            pass
        if self.winfo_exists():
            self.after(90, self._process_events)

    def _log(self, message: str):
        stamp = dt.datetime.now().strftime('%H:%M:%S')
        self.log.configure(state='normal')
        self.log.insert('end', f'[{stamp}] {message}\n')
        end = int(self.log.index('end-1c').split('.')[0])
        if end > MAX_LOG_LINES:
            self.log.delete('1.0', f'{end-MAX_LOG_LINES}.0')
        self.log.see('end')
        self.log.configure(state='disabled')

    def _close(self):
        if self.busy:
            messagebox.showwarning('Передача выполняется', 'Дождитесь завершения операции с FPGA.')
            return
        self.destroy()


def main():
    KonSolApp().mainloop()


if __name__ == '__main__':
    main()