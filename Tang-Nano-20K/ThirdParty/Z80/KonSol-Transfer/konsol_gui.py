#!/usr/bin/env python3
"""KonSol Transfer GUI 0.1.1 for the hardware-proven KX1 transfer core.

No FPGA firmware changes. No SD imaging. No remote rename/delete claims.
Requires Python 3.10+, Tkinter and pyserial for COM operations.
"""
from __future__ import annotations

import datetime as dt
import os
import queue
import re
import subprocess
import sys
import threading
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from tkinter.scrolledtext import ScrolledText

import konsol_transfer as kx
import kx_gui_backend as backend

APP_NAME = 'KonSol Transfer GUI 0.1.1'
BG = '#0d1628'
SURFACE = '#17253b'
SURFACE_ALT = '#1b2c46'
TEXT = '#e9f1fb'
MUTED = '#a8bbd1'
ACCENT = '#47d5bf'
BLUE = '#438aff'
WARNING = '#ffcf7a'
MAX_LOG_LINES = 600


def size_label(n: int) -> str:
    if n >= 1024 * 1024:
        return f'{n / 1048576:.1f} МиБ'
    if n >= 1024:
        return f'{n / 1024:.1f} КиБ'
    return f'{n} Б'


def avail_ports() -> list[str]:
    found = []
    try:
        from serial.tools import list_ports
        found = sorted({p.device for p in list_ports.comports()})
    except ImportError:
        pass
    return found or ['COM25']


class KonSolApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('KonSol Transfer — Windows ↔ Tang Nano 20K')
        self.geometry('1160x805')
        self.minsize(915, 680)
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
        self.status = tk.StringVar(value='KX1 должен быть запущен на FPGA; COM-порт свободен')
        self.folder = backend.KX1_SIBLING if backend.KX1_SIBLING.is_dir() else Path.cwd()
        self.local_items: dict[str, Path] = {}
        self.remote_items: dict[str, dict] = {}
        self.statefile = backend.state_path()
        self._style()
        self._build()
        self.refresh_local()
        self.refresh_remote()
        self.after(90, self._process_events)
        self._log('Программа готова. COM25 / 115200 / KX1.')
        self._log('Справа показана ИСТОРИЯ отправок, а не живой каталог диска Z80.')

    def _style(self):
        style = ttk.Style(self)
        if 'clam' in style.theme_names():
            style.theme_use('clam')
        style.configure('K.TFrame', background=BG)
        style.configure('Panel.TFrame', background=SURFACE)
        style.configure('K.TLabel', background=BG, foreground=TEXT, font=('Segoe UI', 10))
        style.configure('Panel.TLabel', background=SURFACE, foreground=TEXT, font=('Segoe UI', 10))
        style.configure('Muted.TLabel', background=SURFACE, foreground=MUTED, font=('Segoe UI', 9))
        style.configure('K.TButton', padding=(10, 8), background='#273a57', foreground=TEXT, font=('Segoe UI', 10))
        style.map('K.TButton', background=[('active', '#365376'), ('disabled', '#1a2740')], foreground=[('disabled', '#74849a')])
        style.configure('Accent.TButton', padding=(14, 9), background=BLUE, foreground='white', font=('Segoe UI Semibold', 10))
        style.map('Accent.TButton', background=[('active', '#286de0'), ('disabled', '#263a60')])
        style.configure('K.TEntry', padding=6, fieldbackground='#eff6ff', foreground='#16233b')
        style.configure('K.TCombobox', padding=5, fieldbackground='#eff6ff', foreground='#16233b')
        style.configure('K.Treeview', background='#101d32', fieldbackground='#101d32', foreground='#e9f0fb',
                        rowheight=28, font=('Consolas', 10), bordercolor='#263a59', borderwidth=1)
        style.configure('K.Treeview.Heading', background='#223654', foreground='#dae9f9', relief='flat', font=('Segoe UI Semibold', 9), padding=7)
        style.map('K.Treeview', background=[('selected', '#266e86')], foreground=[('selected', 'white')])
        style.configure('K.Horizontal.TProgressbar', troughcolor='#1f324b', background=ACCENT, borderwidth=0)
        style.configure('K.TRadiobutton', background=SURFACE, foreground=TEXT, font=('Segoe UI', 9))
        style.map('K.TRadiobutton', background=[('active', SURFACE)], foreground=[('active', TEXT)])

    def _build(self):
        head = tk.Frame(self, bg=BG)
        head.pack(fill='x', padx=22, pady=(17, 9))
        tk.Label(head, text='KonSol Transfer', bg=BG, fg=TEXT, font=('Segoe UI Semibold', 22)).pack(side='left')
        tk.Label(head, text=' GUI 0.1.1  ·  Windows  ↔  Z80 / CP/Mish', bg=BG, fg=ACCENT,
                 font=('Segoe UI', 11)).pack(side='left', padx=16, pady=(10, 0))

        bar = tk.Frame(self, bg=SURFACE, padx=16, pady=10)
        bar.pack(fill='x', padx=20, pady=(0, 10))
        tk.Label(bar, text='Порт', bg=SURFACE, fg=TEXT, font=('Segoe UI Semibold', 10)).pack(side='left')
        self.ports = ttk.Combobox(bar, textvariable=self.port, values=avail_ports(), width=12, style='K.TCombobox')
        self.ports.pack(side='left', padx=(9, 6))
        self._btn(bar, '↻', self._refresh_ports, width=3).pack(side='left', padx=(0, 17))
        tk.Label(bar, text='115200 · 8N1', bg=SURFACE, fg=MUTED, font=('Segoe UI', 9)).pack(side='left')
        self.boot_btn = self._btn(bar, 'Запустить KXFER на FPGA', self._boot_receiver)
        self.boot_btn.pack(side='right')

        main = tk.PanedWindow(self, orient='horizontal', sashwidth=8, bg=BG, bd=0, relief='flat')
        main.pack(fill='both', expand=True, padx=20, pady=(0, 9))
        left = tk.Frame(main, bg=SURFACE, padx=13, pady=13)
        right = tk.Frame(main, bg=SURFACE, padx=13, pady=13)
        main.add(left, stretch='always', minsize=410)
        main.add(right, stretch='always', minsize=410)
        self._build_local(left)
        self._build_remote(right)

        bottom = tk.Frame(self, bg=BG)
        bottom.pack(fill='both', padx=20, pady=(0, 15))
        status_row = tk.Frame(bottom, bg=BG)
        status_row.pack(fill='x', pady=(0, 6))
        tk.Label(status_row, textvariable=self.status, bg=BG, fg=MUTED, anchor='w', font=('Segoe UI', 9)).pack(side='left', fill='x', expand=True)
        self.progress = ttk.Progressbar(status_row, style='K.Horizontal.TProgressbar', length=215, maximum=100, mode='determinate')
        self.progress.pack(side='right')
        self.log = ScrolledText(bottom, bg='#081221', fg='#cfe1f5', insertbackground='white',
                                font=('Consolas', 9), height=7, relief='flat', bd=1, wrap='word')
        self.log.pack(fill='both')
        self.log.configure(state='disabled')
        self.command_buttons: list[ttk.Button] = [self.boot_btn]

    def _btn(self, parent, title, callback, *, accent=False, width=None):
        return ttk.Button(parent, text=title, command=callback, style='Accent.TButton' if accent else 'K.TButton', width=width)

    def _build_local(self, p):
        tk.Label(p, text='WINDOWS · локальные файлы', bg=SURFACE, fg=TEXT, font=('Segoe UI Semibold', 13)).pack(anchor='w')
        tk.Label(p, text='Выберите файл для отправки на Z80', bg=SURFACE, fg=MUTED, font=('Segoe UI', 9)).pack(anchor='w', pady=(2, 10))
        folder_row = tk.Frame(p, bg=SURFACE)
        folder_row.pack(fill='x', pady=(0, 8))
        self.folder_label = tk.Label(folder_row, text='', bg=SURFACE, fg='#d1e4fb', anchor='w', font=('Consolas', 9))
        self.folder_label.pack(side='left', expand=True, fill='x')
        self._btn(folder_row, 'Папка…', self.choose_folder).pack(side='right', padx=(5, 0))
        self._btn(folder_row, '↻', self.refresh_local, width=3).pack(side='right')

        treebox = tk.Frame(p, bg=SURFACE)
        treebox.pack(fill='both', expand=True)
        self.local_tree = ttk.Treeview(treebox, columns=('name', 'size', 'date'), show='headings', selectmode='browse', height=3, style='K.Treeview')
        for col, title, width, anchor in [('name','Имя',210,'w'),('size','Размер',80,'e'),('date','Дата',125,'w')]:
            self.local_tree.heading(col, text=title)
            self.local_tree.column(col, minwidth=65, width=width, anchor=anchor, stretch=col == 'name')
        scroll = ttk.Scrollbar(treebox, orient='vertical', command=self.local_tree.yview)
        self.local_tree.configure(yscrollcommand=scroll.set)
        scroll.pack(side='right', fill='y')
        self.local_tree.pack(fill='both', expand=True)
        self.local_tree.bind('<<TreeviewSelect>>', self._select_local)
        self.local_tree.bind('<Double-1>', self._open_local_item)

        line = tk.Frame(p, bg=SURFACE)
        line.pack(fill='x', pady=(12, 5))
        tk.Label(line, text='Диск Z80:', bg=SURFACE, fg=TEXT).pack(side='left')
        self.target_drive = ttk.Combobox(line, values=['A', 'B'], textvariable=self.drive, width=4,
                                         state='readonly', style='K.TCombobox')
        self.target_drive.pack(side='left', padx=(8, 8))
        tk.Label(line, text='Имя CP/M (8.3):', bg=SURFACE, fg=TEXT).pack(side='left')
        self.send_entry = ttk.Entry(line, textvariable=self.send_name, width=16, style='K.TEntry')
        self.send_entry.pack(side='left', padx=(8, 0), fill='x', expand=True)
        self.send_btn = self._btn(p, '↑  Загрузить на FPGA', self._send, accent=True)
        self.send_btn.pack(fill='x', pady=(6, 0))
        tk.Label(p, text='Новый файл · существующие файлы Z80 не перезаписываются.', bg=SURFACE, fg=MUTED,
                 font=('Segoe UI', 9)).pack(anchor='w', pady=(8, 0))

    def _build_remote(self, p):
        tk.Label(p, text='Z80 · диски A: / B:', bg=SURFACE, fg=TEXT, font=('Segoe UI Semibold', 13)).pack(anchor='w')
        tk.Label(p, text='История успешных отправок, НЕ полный каталог платы', bg=SURFACE,
                 fg=WARNING, font=('Segoe UI', 9)).pack(anchor='w', pady=(2, 9))
        line = tk.Frame(p, bg=SURFACE)
        line.pack(fill='x', pady=(0, 8))
        tk.Label(line, text='Показать диск:', bg=SURFACE, fg=TEXT).pack(side='left')
        self.list_drive = tk.StringVar(value='B')
        select_drive = ttk.Combobox(line, textvariable=self.list_drive, values=['A', 'B'],
                                    width=4, state='readonly', style='K.TCombobox')
        select_drive.pack(side='left', padx=(8, 8))
        select_drive.bind('<<ComboboxSelected>>', lambda _: self.refresh_remote())
        self._btn(line, '↻ История', self.refresh_remote).pack(side='right')
        self.forget_btn = self._btn(line, 'Убрать из истории', self._forget_history)
        self.forget_btn.pack(side='right', padx=(0, 5))

        treebox = tk.Frame(p, bg=SURFACE)
        treebox.pack(fill='both', expand=True)
        self.remote_tree = ttk.Treeview(treebox, columns=('name', 'size'), show='headings', selectmode='browse', height=3, style='K.Treeview')
        self.remote_tree.heading('name', text='Известный файл на Z80')
        self.remote_tree.heading('size', text='Длина с ПК')
        self.remote_tree.column('name', width=260, minwidth=150, anchor='w')
        self.remote_tree.column('size', width=115, minwidth=75, anchor='e', stretch=False)
        scrollbar = ttk.Scrollbar(treebox, orient='vertical', command=self.remote_tree.yview)
        self.remote_tree.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side='right', fill='y')
        self.remote_tree.pack(fill='both', expand=True)
        self.remote_tree.bind('<<TreeviewSelect>>', self._select_remote)

        tk.Label(p, text='Файл Z80 (можно ввести вручную):', bg=SURFACE, fg=TEXT,
                 font=('Segoe UI', 9)).pack(anchor='w', pady=(12, 3))
        self.get_entry = ttk.Entry(p, textvariable=self.get_name, style='K.TEntry')
        self.get_entry.pack(fill='x')

        radio = tk.Frame(p, bg=SURFACE)
        radio.pack(fill='x', pady=(9, 5))
        ttk.Radiobutton(radio, text='Авто (по истории)', variable=self.length_mode,
                        value='auto', style='K.TRadiobutton', command=self._length_toggle).pack(anchor='w')
        ttk.Radiobutton(radio, text='Полный размер CP/M (возможны добавочные байты)', variable=self.length_mode,
                        value='full', style='K.TRadiobutton', command=self._length_toggle).pack(anchor='w')
        exact_row = tk.Frame(radio, bg=SURFACE)
        exact_row.pack(fill='x')
        ttk.Radiobutton(exact_row, text='Указать точную длину:', variable=self.length_mode,
                        value='exact', style='K.TRadiobutton', command=self._length_toggle).pack(side='left')
        self.exact_entry = ttk.Entry(exact_row, textvariable=self.exact_length, width=13, style='K.TEntry', state='disabled')
        self.exact_entry.pack(side='left', padx=7)
        tk.Label(exact_row, text='байт', bg=SURFACE, fg=MUTED).pack(side='left')
        self.get_btn = self._btn(p, '↓  Скачать с FPGA', self._get, accent=True)
        self.get_btn.pack(fill='x', pady=(8, 0))
        tk.Label(p, text='История Windows не равна каталогу Z80. Удаление записи не трогает FPGA.', bg=SURFACE, fg=MUTED,
                 font=('Segoe UI', 9)).pack(anchor='w', pady=(8, 0))
        tk.Label(p, text='Переименовать/удалить на FPGA можно в KC5.', bg=SURFACE, fg=MUTED,
                 font=('Segoe UI', 9)).pack(anchor='w', pady=(8, 0))

    def _refresh_ports(self):
        values = avail_ports()
        if self.port.get().strip() and self.port.get().strip() not in values:
            values.append(self.port.get().strip())
        self.ports['values'] = values
        self._log('Доступные порты: ' + ', '.join(values))

    def choose_folder(self):
        path = filedialog.askdirectory(initialdir=str(self.folder), title='Папка Windows для обмена')
        if path:
            self.folder = Path(path)
            self.refresh_local()

    def refresh_local(self):
        try:
            items = list(self.folder.iterdir())
        except OSError as e:
            messagebox.showerror('Папка Windows', str(e))
            return
        self.folder_label.config(text=str(self.folder))
        self.local_tree.delete(*self.local_tree.get_children())
        self.local_items.clear()
        if self.folder.parent != self.folder:
            id_ = self.local_tree.insert('', 'end', values=('..  [выше]', '', ''))
            self.local_items[id_] = self.folder.parent
        visible = sorted((x for x in items if x.is_dir() or x.is_file()), key=lambda p: (not p.is_dir(), p.name.casefold()))
        for item in visible:
            try:
                stat = item.stat()
                when = dt.datetime.fromtimestamp(stat.st_mtime).strftime('%d.%m %H:%M')
                size = '<DIR>' if item.is_dir() else size_label(stat.st_size)
                icon = '▸ ' if item.is_dir() else '  '
                node = self.local_tree.insert('', 'end', values=(icon + item.name, size, when))
                self.local_items[node] = item
            except OSError:
                continue

    def refresh_remote(self):
        try:
            rows = backend.known_files(self.statefile)
        except (ValueError, OSError, kx.TransferError) as e:
            self._log(f'Ошибка чтения истории: {e}')
            rows = []
        self.remote_tree.delete(*self.remote_tree.get_children())
        self.remote_items.clear()
        drive = self.list_drive.get()
        for item in rows:
            if item['name'].startswith(drive + ':'):
                node = self.remote_tree.insert('', 'end', values=(item['name'], size_label(item['size'])))
                self.remote_items[node] = item

    def _select_local(self, _event=None):
        selected = self.local_tree.selection()
        if not selected:
            return
        p = self.local_items.get(selected[0])
        if p and p.is_file():
            name = backend.filename_83(p.name)
            self.send_name.set(name or '')
            if name is None:
                self.status.set('Введите имя формата 8.3 латиницей в поле назначения')

    def _open_local_item(self, _event=None):
        selected = self.local_tree.selection()
        if not selected:
            return
        p = self.local_items.get(selected[0])
        if p and p.is_dir():
            self.folder = p
            self.refresh_local()

    def _select_remote(self, _event=None):
        selected = self.remote_tree.selection()
        if selected and selected[0] in self.remote_items:
            self.get_name.set(self.remote_items[selected[0]]['name'])
            self.length_mode.set('auto')
            self._length_toggle()

    def _forget_history(self):
        # Only edits Windows KXFER_STATE.json; it does not touch the Z80 disk.
        if self.busy:
            return
        selected = self.remote_tree.selection()
        item = self.remote_items.get(selected[0]) if selected else None
        if not item:
            messagebox.showinfo('История', 'Выберите запись в правой панели.')
            return
        remote = item['name']
        if not messagebox.askyesno('Удалить запись истории',
                f'Убрать {remote} из журнала Windows?\n\n'
                'Файл на диске Z80 НЕ будет удалён.\n'
                'Будут забыты сохранённые точная длина и SHA-256.'):
            return
        try:
            removed = backend.forget_known_file(remote, self.statefile)
        except (ValueError, OSError, kx.TransferError) as exc:
            messagebox.showerror('История', str(exc))
            return
        if removed:
            self._log(f'Убрана только локальная запись {remote}; диск Z80 не изменён.')
        self.refresh_remote()
        if self.get_name.get().strip().upper() == remote:
            self.get_name.set('')

    def _length_toggle(self):
        self.exact_entry.configure(state='normal' if self.length_mode.get() == 'exact' else 'disabled')

    def _remote_for_send(self) -> str:
        return kx.normalized_name(f'{self.drive.get()}:{self.send_name.get()}')

    def _send(self):
        selected = self.local_tree.selection()
        p = self.local_items.get(selected[0]) if selected else None
        if not p or not p.is_file():
            messagebox.showwarning('Загрузка', 'Выберите файл Windows в левой панели.')
            return
        try:
            remote = self._remote_for_send()
            cmd = backend.build_send_command(self.port.get(), p, remote, self.statefile)
        except (kx.TransferError, OSError) as e:
            messagebox.showerror('Загрузка', str(e))
            return
        # Windows manifest is only a history, NOT the Z80 file directory.
        # KX1's BASIC receiver checks actual existence via OPENIN and refuses
        # to overwrite a real file; permit retries after KC5 deleted a file.
        try:
            in_history = remote in {x['name'] for x in backend.known_files(self.statefile)}
        except (ValueError, OSError, kx.TransferError):
            in_history = False
        if in_history:
            self._log(f'{remote} есть в истории Windows; пробуем безопасную загрузку. '
                      'Проверку существования файла выполнит Z80.')
        self._start_subprocess('Загрузка на FPGA', cmd)

    def _get(self):
        try:
            remote = kx.normalized_name(self.get_name.get())
        except kx.TransferError as e:
            messagebox.showerror('Скачивание', str(e))
            return
        mode = self.length_mode.get()
        exact = None
        if mode == 'exact':
            try:
                exact = int(self.exact_length.get())
            except (TypeError, ValueError):
                messagebox.showerror('Скачивание', 'Введите число байт.')
                return
        elif mode == 'auto' and remote not in {x['name'] for x in backend.known_files(self.statefile)}:
            ok = messagebox.askokcancel('Длина файла неизвестна',
                 'Этот файл отсутствует в истории отправок KX1.\n'
                 'Будет скачан полный размер CP/M (с округлением до 128 байт).\n\n'
                 'Если точная длина известна, нажмите «Отмена» и выберите режим «Указать точную длину».\n\n'
                 'Продолжить?')
            if not ok:
                return
        dst = filedialog.asksaveasfilename(title='Куда сохранить файл с FPGA?',
                 initialdir=str(self.folder), initialfile=remote[2:])
        if not dst:
            return
        try:
            cmd = backend.build_get_command(self.port.get(), remote, Path(dst), mode=mode,
                                            exact_length=exact, manifest=self.statefile)
        except (kx.TransferError, OSError) as e:
            messagebox.showerror('Скачивание', str(e))
            return
        self._start_subprocess('Скачивание с FPGA', cmd)

    def _boot_receiver(self):
        if self.busy:
            return
        self._mark_busy(True, 'Запуск уже установленного B:KXFER.BBC…')
        def worker():
            try:
                result = backend.boot_receiver(self.port.get().strip())
                self.events.put(('log', result))
                self.events.put(('done', 'KX1 готов'))
            except BaseException as e:
                self.events.put(('error', str(e)))
        threading.Thread(target=worker, daemon=True).start()

    def _start_subprocess(self, title: str, cmd: list[str]):
        if self.busy:
            return
        self._mark_busy(True, title + '…')
        self._log(f'{title}: ' + ' '.join(cmd[-3:]))
        def worker():
            try:
                kwargs = {'stdout': subprocess.PIPE, 'stderr': subprocess.STDOUT,
                          'stdin': subprocess.DEVNULL, 'text': True, 'bufsize': 1,
                          'encoding': 'utf-8', 'errors': 'replace'}
                if os.name == 'nt':
                    kwargs['creationflags'] = subprocess.CREATE_NO_WINDOW
                with subprocess.Popen(cmd, **kwargs) as proc:
                    assert proc.stdout is not None
                    for line in proc.stdout:
                        msg = line.rstrip('\r\n')
                        if msg:
                            self.events.put(('log', msg))
                        match = re.search(r'(?:Send|Receive)\s+(\d+)/(\d+)\s+blocks', msg)
                        if match and int(match.group(2)):
                            self.events.put(('progress', int(match.group(1))*100/int(match.group(2))))
                    return_code = proc.wait()
                if return_code == 0:
                    self.events.put(('progress', 100))
                    self.events.put(('done', title + ' — PASS'))
                else:
                    self.events.put(('error', f'{title} завершилось с кодом {return_code}.\nСмотрите журнал ниже.'))
            except BaseException as e:
                self.events.put(('error', str(e)))
        threading.Thread(target=worker, daemon=True).start()

    def _mark_busy(self, flag: bool, label: str):
        self.busy = flag
        self.status.set(label)
        if flag:
            self.progress['value'] = 0
        for btn in (self.send_btn, self.get_btn, self.boot_btn, self.forget_btn):
            btn.configure(state='disabled' if flag else 'normal')

    def _process_events(self):
        try:
            for _ in range(100):
                event = self.events.get_nowait()
                typ = event[0]
                if typ == 'log':
                    self._log(event[1])
                elif typ == 'progress':
                    self.progress['value'] = max(0, min(100, event[1]))
                elif typ == 'done':
                    self._log(event[1])
                    self._mark_busy(False, event[1])
                    self.refresh_local()
                    self.refresh_remote()
                elif typ == 'error':
                    self._log('ОШИБКА: ' + event[1])
                    self._mark_busy(False, 'Ошибка передачи/подключения — подробности в журнале')
                    messagebox.showerror('KonSol Transfer', event[1])
        except queue.Empty:
            pass
        if self.winfo_exists():
            self.after(90, self._process_events)

    def _log(self, text: str):
        stamp = dt.datetime.now().strftime('%H:%M:%S')
        self.log.configure(state='normal')
        self.log.insert('end', f'[{stamp}] {text}\n')
        end = int(self.log.index('end-1c').split('.')[0])
        if end > MAX_LOG_LINES:
            self.log.delete('1.0', f'{end-MAX_LOG_LINES}.0')
        self.log.see('end')
        self.log.configure(state='disabled')

    def _close(self):
        if self.busy:
            messagebox.showwarning('Передача ещё идёт', 'Дождитесь завершения передачи, чтобы не оставить частичный KXFER.TMP на диске Z80.')
            return
        self.destroy()


def main():
    app = KonSolApp()
    app.mainloop()


if __name__ == '__main__':
    main()
