#!/usr/bin/env python3
"""PiKoSoL TP20: slow, visibly latched PMOD-LEDx8 MMIO diagnostic.
Only for the proven GPIO-ID GP14 bitstream. Does NOT program FPGA Flash.
MMIO output is active-low for the Sipeed PMOD-LEDx8 module.
Produces two independent PKD1 .bin applications: PMOD2+3, PMOD1.
"""
import sys, struct, hashlib
from pathlib import Path
# Reuse the previously offline-tested minimal RV32I encoder.
sys.path.insert(0, str(Path(__file__).resolve().parent / 'lib'))
from build_pmod_led16 import Code, MAGIC, ENTRY, VRAM, WIDTH, HEIGHT, GPIO_ID, GPIO_ID_ADDR, UART_DATA
from build_pmod_led16 import lw, sw, addi, andi, sub, rdcycle, ret

HOLD_CYCLES=60_000_000 # ~1 second at the nominal 60 MHz CPU clock; GUI RUN timeout is 8s
P1=0x80000020
P2=0x80000030
P3=0x80000040


def compile_app(ports):
    """ports = (1,) or (2,3); no other PMOD touched."""
    assert ports in ((1,),(2,3))
    pbase={1:P1,2:P2,3:P3}
    a,b=ports[0],ports[-1]
    c=Code()
    c.li(10,pbase[a]); c.li(29,UART_DATA)
    if len(ports)==2: c.li(11,pbase[b])
    c.li(6,GPIO_ID_ADDR); c.emit(lw(31,6,0)); c.li(28,GPIO_ID)
    c.br('beq',31,28,'id_ok')
    c.text(2,4,'PMOD TEST STOP: GPIO_ID MISMATCH, NO WRITES',9)
    c.uart('\r\n[PMOD STOP: WRONG GPIO_ID; NOTHING WRITTEN]\r\n')
    c.emit(ret())
    c.label('id_ok')
    c.emit(lw(15,10,0)) # prior OUT: toggles final latched pattern each rerun
    # Avoid output glitch: switch pins to HI-Z, program high=OFF, then enable outputs
    for reg in (10,11) if len(ports)==2 else (10,):
        c.emit(sw(0,reg,8), addi(7,0,255), sw(7,reg,0), sw(7,reg,8))
    # Clear top 18 lines of HDMI; don't overwrite monitor state.
    c.li(6,VRAM);c.li(28,VRAM+18*WIDTH*4)
    c.li(30,15<<24|4<<16|32)
    c.label('clear'); c.emit(sw(30,6,0),addi(6,6,4));c.br('bne',6,28,'clear')
    name='PMOD2 + PMOD3' if len(ports)==2 else 'PMOD1'
    c.text(1,4,'PiKoSoL '+name+' SLOW TEST',11)
    c.text(3,4,f'PMOD{a} OUT: 11111111   IN: 11111111')
    if len(ports)==2:c.text(5,4,f'PMOD{b} OUT: 11111111   IN: 11111111')
    c.text(7,4,'STEP 0/4   1s hold',11)
    c.text(9,4,'LED: 0=ON, 1=OFF')
    c.text(11,4,'Watch REAL PMOD LEDs')
    c.text(13,4,'FINAL LATCHED; NEXT RUN FLIPS')
    c.text(15,4,'RAM ONLY; USE RELEASE BIN TO HI-Z')
    c.uart(f'\r\n[PiKoSoL {name} SLOW / GPIO_ID GP14 / 1s per pattern]\r\n')
    c.emit(addi(14,0,0)) # mismatch counter
    for step,(pattern,label) in enumerate(((255,'ALL OFF'),(0,'ALL ON'),(170,'ALTERNATE A'),(85,'ALTERNATE B')),1):
        c.emit(addi(7,0,pattern),sw(7,10,0))
        if len(ports)==2:c.emit(sw(7,11,0))
        # UART transmission after driving permits GPIO synchronizers to settle.
        c.uart(f'STEP {step} {label} 0x{pattern:02X}\r\n')
        c.emit(lw(12,10,4),andi(12,12,255))
        c.hdmi_bits(3,4+len(f'PMOD{a} OUT: '),7)
        c.hdmi_bits(3,4+len(f'PMOD{a} OUT: 11111111   IN: '),12)
        c.br('beq',12,7,f'p{step}a_ok')
        c.emit(addi(14,14,1))
        c.label(f'p{step}a_ok')
        if len(ports)==2:
            c.emit(lw(13,11,4),andi(13,13,255))
            c.hdmi_bits(5,4+len(f'PMOD{b} OUT: '),7)
            c.hdmi_bits(5,4+len(f'PMOD{b} OUT: 11111111   IN: '),13)
            c.br('beq',13,7,f'p{step}b_ok')
            c.emit(addi(14,14,1))
            c.label(f'p{step}b_ok')
        c.text(7,4,('STEP %d/4: %-15s' % (step,label)),11)
        c.emit(rdcycle(16));c.li(17,HOLD_CYCLES)
        c.label(f'wait_{step}')
        c.emit(rdcycle(30),sub(30,30,16));c.br('bltu',30,17,f'wait_{step}')
    # Final pattern differs each RUN; never auto-restores, so a final photo tests pins.
    c.emit(addi(5,0,170))
    c.br('bne',15,5,'final_A')
    c.emit(addi(7,0,85));c.j('final_write')
    c.label('final_A');c.emit(addi(7,0,170))
    c.label('final_write')
    c.emit(sw(7,10,0))
    c.hdmi_bits(3,4+len(f'PMOD{a} OUT: '),7)
    c.emit(lw(12,10,4),andi(12,12,255))
    c.hdmi_bits(3,4+len(f'PMOD{a} OUT: 11111111   IN: '),12)
    if len(ports)==2:
        c.emit(addi(31,0,255),sub(31,31,7),sw(31,11,0))
        c.hdmi_bits(5,4+len(f'PMOD{b} OUT: '),31)
        c.emit(lw(13,11,4),andi(13,13,255))
        c.hdmi_bits(5,4+len(f'PMOD{b} OUT: 11111111   IN: '),13)
    c.text(7,4,'FINAL LATCH: ALT LEDs           ',10)
    c.text(16,4,'DONE: VISUAL CHECK REQUIRED',10)
    c.uart('[LATCHED: RUN AGAIN TO FLIP]\r\n')
    c.br('beq',14,0,'mmio_ok')
    c.uart('[MMIO MISMATCH]\r\n')
    c.j('done')
    c.label('mmio_ok')
    c.uart('[MMIO OK: CHECK REAL LEDS]\r\n')
    c.label('done');c.emit(ret())
    body=c.finish()
    return struct.pack('<IIII',MAGIC,16+len(body),ENTRY,0)+body


def release_app():
    c=Code(); c.li(29,UART_DATA)
    c.li(6,GPIO_ID_ADDR); c.emit(lw(31,6,0));c.li(28,GPIO_ID)
    c.br('beq',31,28,'valid')
    c.uart('[PMOD RELEASE STOP: GPIO ID MISMATCH]\r\n');c.emit(ret())
    c.label('valid')
    for p in (P1,P2,P3):
        c.li(10,p);c.emit(sw(0,10,8),addi(7,0,255),sw(7,10,0))
    c.uart('[PMOD1/2/3 RELEASE: DIR=0 (HI-Z), OUT=0xFF; RETURN]\r\n')
    c.emit(ret());body=c.finish()
    return struct.pack('<IIII',MAGIC,16+len(body),ENTRY,0)+body


def generate(folder):
    folder.mkdir(parents=True,exist_ok=True)
    names={
        'TP20_PMOD23_SLOW_VISUAL_LATCH.bin':compile_app((2,3)),
        'TP20_PMOD1_SLOW_VISUAL_LATCH.bin':compile_app((1,)),
        'TP20_PMOD123_RELEASE.bin':release_app(),
    }
    for name,data in names.items():
        padded=(len(data)+127)//128*128
        assert padded<=0x3000,(name,len(data),padded)
        assert struct.unpack_from('<IIII',data)==(MAGIC,len(data),ENTRY,0)
        (folder/name).write_bytes(data)
        print(name,'SIZE',len(data),'BLOCKS',padded//128,'SHA256',hashlib.sha256(data).hexdigest())
    return names

if __name__=='__main__':generate(Path(__file__).resolve().parent)
