import unittest
from patch_monitor_u import patch_source

BASE = """        cp 'B'
        jp z, monitor_boot
        cp 'L'
monitor_sd_load:
        call sd_boot
        ret
        db "B           - boot CP/M from the SD card", 13, 10
        db "L           - load CP/M",13,10
msg_ready:
        db "Ready",13,10,0
"""

class PatchTests(unittest.TestCase):
    def test_uart_boot_inserted(self):
        s = patch_source(BASE)
        for x in ("cp 'U'", "jp z, monitor_boot_uart", "ld (BOOT_PAGE), a",
                  "cp $F6", "ld hl, $F633", "cp $81", "cp $83",
                  "ld (hl), $83", "jp $F600"):
            self.assertIn(x, s)
    def test_refuses_duplicate(self):
        with self.assertRaises(ValueError):
            patch_source(patch_source(BASE))
    def test_refuses_unknown_version(self):
        with self.assertRaises(ValueError):
            patch_source("invalid source")
if __name__ == "__main__":
    unittest.main()
