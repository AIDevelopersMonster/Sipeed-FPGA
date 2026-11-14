#!/usr/bin/env python3
"""Create isolated GW2AR PicoRV32 build tree from pinned PiKoSoL 9K sources.

No source is ever modified in the original 9K tree. This script does not
compile Gowin, operate JTAG, alter Flash, or touch any SD media.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


def replace_once(s: str, before: str, after: str) -> str:
    assert s.count(before) == 1, f"expected one occurrence, got {s.count(before)}: {before!r}"
    return s.replace(before, after)


def stage(repo: Path, out: Path) -> None:
    repo = repo.resolve()
    project = repo / 'Tang-Nano-20K/Examples/EX20-06-PiKoSoL-PicoRV32'
    ex05 = repo / 'Tang-Nano-20K/Examples/EX20-05-CPU-HDMI'
    old = repo / '01-PicoRV32/lab04'
    pico = repo / '01-PicoRV32/vendor/picorv32/picorv32.v'
    if not pico.is_file():
        raise FileNotFoundError(f'Pinned PicoRV32 missing: {pico}. Run 01-PicoRV32/tools/fetch_picorv32.ps1')
    for vendor in ('TMDS_rPLL.v', 'dvi_tx.v'):
        if not (ex05 / 'vendor' / vendor).is_file():
            raise FileNotFoundError(f'EX20-05 pinned vendor source missing: {vendor}. Run EX20-05 prepare_vendor.ps1')
    out.mkdir(parents=True, exist_ok=False)
    for part in ('rtl', 'tools', 'firmware', 'vendor', 'constraints'):
        (out / part).mkdir()
    for src in (project / 'rtl').glob('*.v'):
        shutil.copy2(src, out / 'rtl' / src.name)
    for src in (project / 'constraints').glob('*'):
        shutil.copy2(src, out / 'constraints' / src.name)
    shutil.copy2(project / 'gowin_build.tcl', out / 'gowin_build.tcl')
    for name in ('lab04_led_mask_cdc.v', 'lab04_tty_byte_cdc.v', 'lab04_uart_tty_bridge.v'):
        shutil.copy2(old / 'rtl' / name, out / 'rtl' / name)
    for name in ('uart_rx_8n1.v', 'uart_tx_8n1.v'):
        shutil.copy2(repo / '01-PicoRV32' / 'rtl' / name, out / 'rtl' / name)
    shutil.copy2(old / 'rtl' / 'lab04_font_8x12.hex', out / 'lab04_font_8x12.hex')
    shutil.copy2(pico, out / 'vendor' / 'picorv32.v')
    for name in ('TMDS_rPLL.v', 'dvi_tx.v'):
        shutil.copy2(ex05 / 'vendor' / name, out / 'vendor' / name)

    # Preserve complete legacy bus handshake and CPU/UART; enlarge memory and
    # decode 8 x 32-byte graphic descriptors (64 mailbox indices).
    soc = (old / 'rtl' / 'lab04_cpu_soc.v').read_text(encoding='utf-8')
    edits = [
        ('module lab04_cpu_soc (', 'module pikosol20k_cpu_soc ('),
        ('output wire [3:0] video_wr_index,', 'output wire [5:0] video_wr_index,'),
        ("(mem_addr[31:14] == 18'b0)", "(mem_addr[31:15] == 17'b0)"),
        ("(mem_addr[31:10] == 22'd16)", "(mem_addr[31:13] == 19'd8)"),
        ('wire [3:0] vid_idx = mem_addr[5:2];', 'wire [5:0] vid_idx = mem_addr[7:2];'),
        ("wire vid_idx_valid = (vid_idx <= 4'd5) ||\n                         (vid_idx >= 4'd8 && vid_idx <= 4'd13) ||\n                         (vid_idx == 4'd15);",
         "wire vid_idx_valid = (vid_idx[2:0] <= 3'd5) ||\n                         (vid_idx == 6'd15) || (vid_idx == 6'd63);"),
        ("vid_idx_valid && (mem_addr[7:6] == 2'b0) &&", 'vid_idx_valid &&'),
        ('reg [23:0] video_shadow [0:15];', 'reg [23:0] video_shadow [0:63];'),
        ('reg [31:0] shell_ram [0:255]', 'reg [31:0] shell_ram [0:2047]'),
        ('shell_ram[mem_addr[9:2]]', 'shell_ram[mem_addr[12:2]]'),
        ('.word_addr(mem_addr[13:2])', '.word_addr(mem_addr[14:2])'),
        ('vi<16', 'vi<64')
    ]
    for before, after in edits:
        if before == 'shell_ram[mem_addr[9:2]]':
            assert soc.count(before) == 2
            soc = soc.replace(before, after)
        else:
            soc = replace_once(soc, before, after)
    (out / 'rtl' / 'pikosol20k_cpu_soc.v').write_text(soc, encoding='utf-8')

    cdc = (old / 'rtl' / 'lab04_video_cmd_cdc.v').read_text(encoding='utf-8')
    cdc_edits = [
        ('module lab04_video_cmd_cdc (', 'module pikosol20k_video_cmd_cdc ('),
        ('input wire [3:0] wr_index,', 'input wire [5:0] wr_index,'),
        ('output reg [3:0] event_index,', 'output reg [5:0] event_index,'),
        ('reg [27:0] packet_hold_sys;', 'reg [29:0] packet_hold_sys;'),
        ("28'd0", "30'd0"),
        ('packet_hold_sys[27:24]', 'packet_hold_sys[29:24]'),
        ("event_index <= 4'd0", "event_index <= 6'd0")
    ]
    for before, after in cdc_edits:
        cdc = replace_once(cdc, before, after)
    # Preserve CDC protocol; annotate only the first and second
    # metastability synchronizer stages in this 20K staged copy.
    a0 = '(* syn_keep = 1 *) reg '
    a1 = '(* syn_keep = 1, async_reg = "true" *) reg '
    assert cdc.count(a0) == 4
    cdc = cdc.replace(a0, a1)
    (out / 'rtl' / 'pikosol20k_video_cmd_cdc.v').write_text(cdc, encoding='utf-8')
    for fname in ('lab04_led_mask_cdc.v', 'lab04_tty_byte_cdc.v'):
        f = out / 'rtl' / fname
        original = f.read_text(encoding='utf-8')
        assert original.count(a0) == 4, fname
        f.write_text(original.replace(a0, a1), encoding='utf-8')

    # The source shell itself is extended: all 8 objects become addressable
    # through OBJ A..H, and graphic movement is not confined to the 9K panel.
    firmware = (old / 'firmware' / 'lab04_boot.S').read_text(encoding='utf-8')
    fixes = [
        ('lui s8, 0x4', 'lui s8, 0x10'),
        ('s8, 256', 's8, 512'),
        ('addi t4, s7, -47', 'addi t4, s7, -95'),
        ('Tang Nano 9K / HDMI 640x480', 'Tang Nano 20K / native HDMI 1280x720'),
        ('Tang Nano 9K; 640x480 HDMI; UART 115200 8N1',
         'Tang Nano 20K; 1280x720 HDMI; UART 115200 8N1'),
        ('PiKoSoL INTERACTIVE SHELL v0.2.0', 'PiKoSoL 20K / PicoRV32 v0.3 candidate'),
        ('ROM 16KiB @00000000; RAM 1KiB @00004000',
         'ROM 32KiB @00000000; RAM 8KiB @00010000'),
        ('LINE 47 characters; history 1 command; 32x76 text VRAM.',
         'LINE 95 characters; history 1; 160x60 text VRAM.'),
        ('PiKoSoL 640x480', 'PiKoSoL 1280x720'),
        ('addi t6, t5, -112', 'addi t6, t5, 0'),
        ('addi t6, t6, -345', 'addi t6, t6, -721'),
        ('addi t6, t5, -32', 'addi t6, t5, 0'),
        ('addi t6, t6, -449', 'addi t6, t6, -1281'),
        ('addi t6, t4, -129', 'addi t6, t4, -513'),
        ('addi t6, t4, -32', 'addi t6, t4, -8')
    ]
    for before, after in fixes:
        if before == 's8, 256':
            assert firmware.count(before) == 2
            firmware = firmware.replace(before, after)
        elif before == 'addi t6, t6, -449':
            assert firmware.count(before) == 2
            firmware = firmware.replace(before, after)
        else:
            firmware = replace_once(firmware, before, after)

    # Expand object selector to C..H (A/B remain byte-exact bus compatible).
    obj_cmd = '    addi t5, zero, 66\n    beq t4, t5, select_b\n'
    assert firmware.count(obj_cmd) == 1
    firmware = firmware.replace(obj_cmd, obj_cmd + ''.join(
        f'    addi t5, zero, {65+n}\n    beq t4, t5, select_{chr(97+n)}\n'
        for n in range(2, 8)))
    live_cmd = '    addi t5, zero, 66\n    beq t3, t5, select_b\n'
    live_start = firmware.index('\nlive_input:\n')
    live_end = firmware.index('\nsingle_command:\n', live_start)
    live_block = firmware[live_start:live_end]
    assert live_block.count(live_cmd) == 1
    live_block = live_block.replace(live_cmd, live_cmd + ''.join(
        f'    addi t5, zero, {65+n}\n    beq t3, t5, select_{chr(97+n)}\n'
        for n in range(2, 8)))
    firmware = firmware[:live_start] + live_block + firmware[live_end:]
    selector = 'select_b:\n    addi s3, s2, 32\n    jal zero, video_done\n'
    assert firmware.count(selector) == 1
    firmware = firmware.replace(selector, selector + ''.join(
        f'select_{chr(97+n)}:\n    addi s3, s2, {32*n}\n    jal zero, video_done\n'
        for n in range(2, 8)))
    panel = ('    beq s3, s2, panel_a\n    addi t1, zero, 66\n'
             '    jal zero, panel_selection\npanel_a:\n'
             '    addi t1, zero, 65\npanel_selection:\n'
             '    jal ra, putc\n')
    firmware = replace_once(firmware, panel,
        '    sub t1, s3, s2\n    srli t1, t1, 5\n'
        '    addi t1, t1, 65\n    jal ra, putc\n')
    # More descriptors: initialize C..H before the first command frame COMMIT.
    objects = [
        (560,130,120,90,0x00ffff), (760,180,144,100,0xff00ff),
        (980,260,136,96,0xffff00), (120,430,128,100,0x00ff00),
        (440,470,128,80,0xff0000), (760,440,160,110,0xffffff)
    ]
    init = ''
    for i, (x,y,w,h,color) in enumerate(objects, start=2):
        off = i*32
        for regoff, val in ((0,x),(4,y),(8,w),(12,h)):
            init += f'    addi t4, zero, {val}\n    sw t4, {off+regoff}(s2)\n'
        # Color assembly uses only instructions supported by ROM assembler.
        hi = (color + 0x800) >> 12
        lo = color - (hi << 12)
        assert -2048 <= lo <= 2047
        init += f'    lui t4, {hi}\n'
        init += f'    addi t4, t4, {lo}\n'
        init += f'    sw t4, {off+16}(s2)\n'
        init += f'    addi t4, zero, 1\n    sw t4, {off+20}(s2)\n'
    firmware = replace_once(firmware, '    sw t4, 52(s2)\n    sw t4, 60(s2)\n',
        '    sw t4, 52(s2)\n' + init + '    sw t4, 60(s2)\n')
    firmware = firmware.replace('OBJ A|B', 'OBJ A-H').replace('A/B RGUW', 'A-H RGUW')
    (out / 'firmware' / 'lab04_boot.S').write_text(firmware, encoding='utf-8')

    assembler = (old / 'tools' / 'build_rom.py').read_text(encoding='utf-8')
    for before, after in (
        ('CAPACITY = 4096', 'CAPACITY = 8192'),
        ('4096 x 32', '8192 x 32'),
        ('4096x32', '8192x32'),
        ('[11:0] word_addr', '[12:0] word_addr'),
        ('[0:4095]', '[0:8191]'),
        ("schema='LAB0432_ROM_v2'", "schema='PIKOSOL20K_ROM_v1'")
    ):
        assembler = replace_once(assembler, before, after)
    (out / 'tools' / 'build_rom.py').write_text(assembler, encoding='utf-8')
    subprocess.run([sys.executable, str(out / 'tools' / 'build_rom.py')], check=True, cwd=out)
    # GowinSynthesis resolves readmemh relative to its source/current work
    # directory depending on the version. This must be staged at BOTH paths,
    # as in the hardware-confirmed 9K LAB-04 build. Without it, Gowin logs
    # EX3988 Cannot open file 'lab04_boot.hex' and ROM is not initialized.
    for memory_file in ('lab04_boot.hex', 'lab04_font_8x12.hex'):
        original = (out / 'firmware' / memory_file) if memory_file == 'lab04_boot.hex' else (out / memory_file)
        if not original.is_file():
            raise FileNotFoundError(f'ROM/font not built: {original}')
        for destination in (out / memory_file, out / 'rtl' / memory_file):
            if original != destination:
                shutil.copy2(original, destination)
    manifest = {}
    for file in sorted(out.rglob('*')):
        if file.is_file():
            manifest[str(file.relative_to(out)).replace('\\','/')] = hashlib.sha256(file.read_bytes()).hexdigest()
    (out / 'input_sha256.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('PIKOSOL20K_SOURCE_STAGE_PASS:', out)
    print('PNR / STA / BOARD: NOT RUN. FLASH: NOT TOUCHED.')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    opts = parser.parse_args()
    stage(opts.repo, opts.out)


if __name__ == '__main__':
    main()
