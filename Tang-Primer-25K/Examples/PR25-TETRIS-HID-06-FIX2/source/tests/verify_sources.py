#!/usr/bin/env python3
"""Minimal static check for the prepared hardware experiment; not an HDL simulator."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
engine=(root/'tetris_engine.sv').read_text()
top=(root/'lab_top_tetris_hid06.sv').read_text()
build=(root/'Build_Tetris_HID06.ps1').read_text()
assert re.search(r'module\s+tetris_engine\b',engine)
assert re.search(r'module\s+lab_top\b',top)
assert 'tetris_engine #(.CLK_MHZ(clk_mhz))' in top
assert 'tetris_engine.sv' in build
assert 'reset       (~host_reset_n)' in top
assert '.usb_dp_i    (gpio[30])' in top
assert '.usb_dm_i    (gpio[31])' in top
assert '.usb_oe      (usb_oe)' in top
assert '.FULL_SPEED(1)' in top
assert "k_left" in engine and "k_right" in engine
assert all(f"8'h{v}" in engine for v in ('1E','1F','20','21','50','4F','51','52','2C'))
assert 'phase <= ST_HARD' in engine
assert 'phase <= ST_LOCK' in engine
assert 'ST_SCAN' in engine and 'score <=' in engine
assert 'game_view <= ~game_view' in top
assert 'host_mode <= ~host_mode' in top
assert '--run 2 --fsFile' in build
assert 'git push' not in build and 'write_flash' not in build
for name,src in [('tetris_engine.sv',engine),('lab_top_tetris_hid06.sv',top)]:
    text=re.sub(r'//[^\n]*','',src)
    for a,b in [('module','endmodule'),('function','endfunction'),('case','endcase')]:
        # Avoid matching endcase as case, endfunction as function.
        left=len(re.findall(r'(?<!end)\b'+a+r'\b',text))
        right=len(re.findall(r'\b'+b+r'\b',text))
        assert left==right,(name,a,left,right)
    assert text.count('(')==text.count(')'),(name,'paren')
    assert text.count('[')==text.count(']'),(name,'bracket')
print('STATIC CHECK PASS: USB mapping, 6-key input, game controls, build paths, HDL block balance')
print('This is not RTL simulation, Gowin BUILD or BOARD PASS.')
