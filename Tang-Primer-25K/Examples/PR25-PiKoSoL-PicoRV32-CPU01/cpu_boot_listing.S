// PiKoSoL RV32I executable program, exact binary listing (32-bit words).
// Word address 0 is reset vector. Each line equals cpu_boot.mem.
// Rebuild: assembler can emit these .word values in the same order.
// MMIO: 0x10000000 word text buffer; 0x10001000 raw HID snapshot.
.section .text
.globl _start
_start:
    .word 0x100000b7  # PC 0x0000: x1 = VRAM MMIO base 0x10000000
    .word 0x100012b7  # PC 0x0004: x5 = HID snapshot MMIO 0x10001000
    .word 0x02000113  # PC 0x0008: space
    .word 0x00000193  # PC 0x000c: clear index=0
    .word 0x18000213  # PC 0x0010: clear 384 characters
    .word 0x0020a023  # PC 0x0014: write space
    .word 0x00408093  # PC 0x0018: increment VRAM word address
    .word 0x00118193  # PC 0x001c: index++
    .word 0xfe41cae3  # PC 0x0020: branch clear
    .word 0x100000b7  # PC 0x0024: VRAM base again
    .word 0x05000113  # PC 0x0028: ASCII 'P'
    .word 0x0020a023  # PC 0x002c: screen[0]
    .word 0x04900113  # PC 0x0030: ASCII 'I'
    .word 0x0020a223  # PC 0x0034: screen[1]
    .word 0x04b00113  # PC 0x0038: ASCII 'K'
    .word 0x0020a423  # PC 0x003c: screen[2]
    .word 0x04f00113  # PC 0x0040: ASCII 'O'
    .word 0x0020a623  # PC 0x0044: screen[3]
    .word 0x05300113  # PC 0x0048: ASCII 'S'
    .word 0x0020a823  # PC 0x004c: screen[4]
    .word 0x04f00113  # PC 0x0050: ASCII 'O'
    .word 0x0020aa23  # PC 0x0054: screen[5]
    .word 0x04c00113  # PC 0x0058: ASCII 'L'
    .word 0x0020ac23  # PC 0x005c: screen[6]
    .word 0x03200113  # PC 0x0060: ASCII '2'
    .word 0x0220a023  # PC 0x0064: screen[8]
    .word 0x03500113  # PC 0x0068: ASCII '5'
    .word 0x0220a223  # PC 0x006c: screen[9]
    .word 0x04b00113  # PC 0x0070: ASCII 'K'
    .word 0x0220a423  # PC 0x0074: screen[10]
    .word 0x02f00113  # PC 0x0078: ASCII '/'
    .word 0x0220a823  # PC 0x007c: screen[12]
    .word 0x05000113  # PC 0x0080: ASCII 'P'
    .word 0x0220ac23  # PC 0x0084: screen[14]
    .word 0x04900113  # PC 0x0088: ASCII 'I'
    .word 0x0220ae23  # PC 0x008c: screen[15]
    .word 0x04300113  # PC 0x0090: ASCII 'C'
    .word 0x0420a023  # PC 0x0094: screen[16]
    .word 0x04f00113  # PC 0x0098: ASCII 'O'
    .word 0x0420a223  # PC 0x009c: screen[17]
    .word 0x05200113  # PC 0x00a0: ASCII 'R'
    .word 0x0420a623  # PC 0x00a4: screen[19]
    .word 0x05600113  # PC 0x00a8: ASCII 'V'
    .word 0x0420a823  # PC 0x00ac: screen[20]
    .word 0x03300113  # PC 0x00b0: ASCII '3'
    .word 0x0420aa23  # PC 0x00b4: screen[21]
    .word 0x03200113  # PC 0x00b8: ASCII '2'
    .word 0x0420ac23  # PC 0x00bc: screen[22]
    .word 0x04900113  # PC 0x00c0: ASCII 'I'
    .word 0x0420ae23  # PC 0x00c4: screen[23]
    .word 0x04300113  # PC 0x00c8: ASCII 'C'
    .word 0x0620a223  # PC 0x00cc: screen[25]
    .word 0x05000113  # PC 0x00d0: ASCII 'P'
    .word 0x0620a423  # PC 0x00d4: screen[26]
    .word 0x05500113  # PC 0x00d8: ASCII 'U'
    .word 0x0620a623  # PC 0x00dc: screen[27]
    .word 0x00000393  # PC 0x00e0: previous HID usage
    .word 0x00000513  # PC 0x00e4: echo col 0
    .word 0x0002a303  # PC 0x00e8: lw x6,0(x5) : raw HID key code
    .word 0x0ff37313  # PC 0x00ec: andi x6,x6,255
    .word 0xfe730ce3  # PC 0x00f0: branch loop
    .word 0x00030393  # PC 0x00f4: last=x6
    .word 0xfe0308e3  # PC 0x00f8: branch loop
    .word 0xffc30413  # PC 0x00fc: usage-4
    .word 0x01a43493  # PC 0x0100: sltiu x9,x8,26
    .word 0x00048663  # PC 0x0104: branch digits
    .word 0x03d30313  # PC 0x0108: ASCII uppercase letter from HID
    .word 0x0240006f  # PC 0x010c: jump print
    .word 0xfe230413  # PC 0x0110: usage-30
    .word 0x00943493  # PC 0x0114: digit check
    .word 0x00048663  # PC 0x0118: branch zero
    .word 0x01330313  # PC 0x011c: digit 1..9
    .word 0x0100006f  # PC 0x0120: jump print
    .word 0x02700413  # PC 0x0124: usage code for 0
    .word 0xfc8310e3  # PC 0x0128: branch loop
    .word 0x03000313  # PC 0x012c: ASCII 0
    .word 0x00251413  # PC 0x0130: slli x8,x10,2
    .word 0x40040413  # PC 0x0134: row4 offset
    .word 0x00808433  # PC 0x0138: add x8,x1,x8
    .word 0x00642023  # PC 0x013c: screen[4*64+col]=key
    .word 0x00150513  # PC 0x0140: echo cursor++
    .word 0x03f57513  # PC 0x0144: col %= 64
    .word 0xfa1ff06f  # PC 0x0148: jump loop
