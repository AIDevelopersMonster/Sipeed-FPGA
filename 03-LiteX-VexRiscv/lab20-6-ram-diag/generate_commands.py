#!/usr/bin/env python3
"""Offline generator: BIOS mem_write script and integrity manifest, no COM access."""
from pathlib import Path
import json, hashlib, struct
BASE = 0x40010000
SNAP = 0x40011000
HERE = Path(__file__).resolve().parent
buf = (HERE/'snapshot.bin').read_bytes()
assert len(buf)%4 == 0 and len(buf) < 0x1000
commands = [f'mem_write 0x{BASE+i:08X} 0x{int.from_bytes(buf[i:i+4],"little"):08X}' for i in range(0,len(buf),4)]
(HERE/'load_mem_write_only.txt').write_text('\n'.join(commands)+'\n',encoding='ascii')
manifest = dict(project='PiKoSoL LAB-20.6',version='v0.1.0',board='Sipeed Tang Nano 20K',
  cpu='VexRiscv_Min RV32I+Zicsr',firmware='Factory LiteX BIOS (2023-03-13)',
  program_load_address='0x40010000',entry_address='0x40010000',
  snapshot_address='0x40011000',snapshot_words=15,recorded_registers=11,post_print_registers=1,
  image_bytes=len(buf),image_words=len(buf)//4,
  bin_sha256=hashlib.sha256(buf).hexdigest(),
  bios_commands_file='load_mem_write_only.txt',
  flash_writes=False,hardware_pass=False,
  boot_command='boot 0x40010000',
  boot_notice='No return to BIOS; use physical reset. Host script never boots unless -Boot explicitly supplied.',
  source_tag='LiteX b05c3069',assumed_sdram_size_bytes=8*1024*1024)
(HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Generated {len(commands)} read/write instructions for {len(buf)}B firmware; SHA256 {manifest["bin_sha256"]}')