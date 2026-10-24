# CRC16/CCITT-FALSE byte-update core v1

Standalone combinational RTL module `crc16_ccitt_byte.v`, without a registered CRC state. The caller sets its starting state to `0xFFFF` and feeds one accepted byte at a time. Polynomial `0x1021`, no reflection, xorout zero; expected CRC of ASCII `123456789` is `0x29B1`.

This CRC protects **UART transport frames only**. It is not the SD-card SPI CRC16 (already checked independently by `lab05_sd_read_sector`), nor a file-system checksum. Requests and responses append CRC low byte first; this encoding is a HOST-01 protocol choice. Test with `iverilog -g2005 -s tb_crc16_ccitt -o crc.vvp rtl/crc16_ccitt_byte.v tests/tb_crc16_ccitt.v && vvp crc.vvp`.
