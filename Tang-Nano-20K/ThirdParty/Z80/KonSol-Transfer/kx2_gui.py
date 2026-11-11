"""KonSol KX2 v0.2.1 remote manager; KX1 GUI is preserved and separate."""
from __future__ import annotations

import tkinter as tk
from tkinter import ttk, messagebox

import konsol_transfer as kx
from kx2_client import Manager, safe_file, HELLO


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('KonSol KX2 - управление файлами CP/Mish')
        self.geometry('940x650')
        self.minsize(800, 570)
        self.port = tk.StringVar(value='COM25')
        self.drive = tk.StringVar(value='B')
        self.source = tk.StringVar()
        self.dest = tk.StringVar()
        self.armed = tk.BooleanVar(value=False)
        self.status = tk.StringVar(value='KX2 не проверен. Сначала нажмите «Проверить KX2».')
        self.list_ok = False

        top = ttk.Frame(self, padding=12)
        top.pack(fill='x')
        ttk.Label(top, text='Порт:').pack(side='left')
        ttk.Entry(top, textvariable=self.port, width=12).pack(side='left', padx=5)
        ttk.Label(top, text='Диск:').pack(side='left', padx=(15, 3))
        ttk.Combobox(top, textvariable=self.drive, values=['A', 'B'], width=4,
                     state='readonly').pack(side='left')
        ttk.Button(top, text='Проверить KX2', command=self.check_version).pack(side='left', padx=10)
        ttk.Button(top, text='Обновить DIR (KX2)', command=self.list_disk).pack(side='left')

        ttk.Label(self, textvariable=self.status, padding=(12, 4),
                  foreground='#245b83').pack(anchor='w')
        ttk.Label(self, text='Ниже — сырой вывод CP/Mish. Не путать с историей файлов Windows.',
                  padding=(12, 2)).pack(anchor='w')
        body = ttk.Frame(self, padding=(12, 2, 12, 4))
        body.pack(fill='both', expand=True)
        self.out = tk.Text(body, height=20, wrap='none', font=('Consolas', 11))
        self.out.pack(side='left', fill='both', expand=True)
        scroll = ttk.Scrollbar(body, orient='vertical', command=self.out.yview)
        scroll.pack(side='right', fill='y')
        self.out.configure(yscrollcommand=scroll.set)
        self.out.insert('1.0', 'Проверка связи: V → KX2:HELLO:0.2.1:LDR\n'
                               'Чтение каталога: L → диск A/B → DIR\n\n'
                               'Приёмник на FPGA: B:KX22.BBC (DIR *.*)\n'
                               'Старый B:KXFER.BBC не изменяется.\n')

        form = ttk.Frame(self, padding=(12, 8))
        form.pack(fill='x')
        ttk.Label(form, text='Источник A:/B:NAME.EXT').grid(row=0, column=0, sticky='w')
        ttk.Entry(form, textvariable=self.source, width=24).grid(row=1, column=0,
                                                                  sticky='we', padx=(0, 10))
        ttk.Label(form, text='Новое имя A:/B:NAME.EXT').grid(row=0, column=1, sticky='w')
        ttk.Entry(form, textvariable=self.dest, width=24).grid(row=1, column=1, sticky='we')
        self.rename_btn = ttk.Button(form, text='Переименовать', command=self.rename, state='disabled')
        self.rename_btn.grid(row=1, column=2, padx=10)
        self.delete_btn = ttk.Button(form, text='Удалить', command=self.delete, state='disabled')
        self.delete_btn.grid(row=1, column=3)
        form.columnconfigure(0, weight=1)
        form.columnconfigure(1, weight=1)

        self.arm_box = ttk.Checkbutton(
            self,
            text='Разрешить переименование/удаление файлов на диске (с подтверждением)',
            variable=self.armed, command=self._update_mutations,
            state='disabled',
        )
        self.arm_box.pack(anchor='w', padx=12, pady=4)
        ttk.Label(self, text='Без успешного DIR и ручного разрешения удаление/переименование недоступны. '
                             'Никакой записи FPGA Flash.', padding=(12, 3)).pack(anchor='w')
        self.port.trace_add('write', self._invalidate)
        self.drive.trace_add('write', self._invalidate)

    def _invalidate(self, *args):
        self.list_ok = False
        self.armed.set(False)
        self.arm_box.configure(state='disabled')
        self._update_mutations()

    def _update_mutations(self):
        state = 'normal' if self.list_ok and self.armed.get() else 'disabled'
        self.rename_btn.configure(state=state)
        self.delete_btn.configure(state=state)

    def call(self, action):
        self.status.set('Связь с FPGA: проверяю версию приёмника…')
        self.update_idletasks()
        try:
            with kx._open_serial(self.port.get().strip()) as port:
                manager = Manager(port)
                manager.probe()
                return action(manager)
        except (kx.TransferError, ValueError, OSError) as exc:
            self._invalidate()
            self.status.set('Ошибка соединения или протокола KX2.')
            messagebox.showerror('KX2 - операция не выполнена', str(exc))
            return None

    def check_version(self):
        info = self.call(lambda manager: manager.probe())
        if info is not None:
            self.status.set('Версия подтверждена: ' + info + ' (каталог ещё не проверен)')
            messagebox.showinfo('KX2', 'Приёмник v0.2.1 отвечает на V.\n'
                                         'Следующий шаг: Обновить DIR (KX2).')

    def list_disk(self):
        self._invalidate()
        drive = self.drive.get()
        raw = self.call(lambda manager: manager.list_raw(drive))
        if raw is None:
            return
        self.out.delete('1.0', 'end')
        self.out.insert('end', raw if raw else '(пустой вывод OSCLI DIR)')
        if raw.strip():
            self.list_ok = True
            self.arm_box.configure(state='normal')
            self.status.set(f'Каталог диска {drive}: обновлён.')
        else:
            self.status.set('Ответ завершён, но DIR пуст. Изменение файлов заблокировано.')
        self._update_mutations()

    def delete(self):
        if not self.list_ok or not self.armed.get():
            messagebox.showerror('KX2', 'Сначала успешно прочитайте DIR и разрешите тестовые изменения.')
            return
        try:
            name = safe_file(self.source.get())
        except kx.TransferError as exc:
            messagebox.showerror('Имя', str(exc))
            return
        if not messagebox.askyesno('ПОДТВЕРЖДЕНИЕ УДАЛЕНИЯ',
                                   f'Удалить на реальном диске FPGA файл {name}?\n'
                                   'Операция необратима. Файл должен быть резервным!'):
            return
        result = self.call(lambda manager: (manager.delete(name, confirmed=True), True)[1])
        if result:
            messagebox.showinfo('KX2', 'Приёмник подтвердил удаление ' + name)
            self.list_disk()

    def rename(self):
        if not self.list_ok or not self.armed.get():
            messagebox.showerror('KX2', 'Сначала успешно прочитайте DIR и разрешите тестовые изменения.')
            return
        try:
            old = safe_file(self.source.get())
            new = safe_file(self.dest.get())
            if old == new or old[:2] != new[:2]:
                raise kx.TransferError('Новое имя должно отличаться, диск не меняется.')
        except kx.TransferError as exc:
            messagebox.showerror('Имя', str(exc))
            return
        if not messagebox.askyesno('ПОДТВЕРЖДЕНИЕ ПЕРЕИМЕНОВАНИЯ',
                                   f'Переименовать на FPGA?\n{old}  →  {new}\n'
                                   'Убедитесь, что это ненужный файл.'):
            return
        result = self.call(lambda manager: (manager.rename(old, new, confirmed=True), True)[1])
        if result:
            messagebox.showinfo('KX2', f'Приёмник подтвердил переименование: {old} → {new}')
            self.list_disk()


if __name__ == '__main__':
    App().mainloop()
