"""Offline safety tests for SDRAM command generation and architecture fences."""
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "image_to_memwrites.py"


class LoaderSafetyTests(unittest.TestCase):
    def run_generator(self, data):
        with tempfile.TemporaryDirectory() as d:
            image = pathlib.Path(d) / "program.bin"
            out = pathlib.Path(d) / "commands.txt"
            image.write_bytes(data)
            result = subprocess.run([sys.executable, str(TOOL), str(image), str(out)],
                                    text=True, capture_output=True)
            lines = out.read_text().splitlines() if out.exists() else []
            return result, lines

    def test_only_sdram_writes_with_correct_endianness(self):
        result, lines = self.run_generator(b"\x93\x00\x10\x00\xaa")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(lines[-2], "mem_write 0x40010000 0x00100093")
        self.assertEqual(lines[-1], "mem_write 0x40010004 0x000000AA")
        self.assertFalse(any(x.startswith("boot") or "flash" in x.lower()
                             for x in lines if not x.startswith("#")))

    def test_reject_empty_or_oversized_image(self):
        for data in (b"", b"0" * 0xC001):
            result, lines = self.run_generator(data)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(lines, [])

    def test_original_rtl_not_modified_by_port(self):
        self.assertFalse((ROOT / "rtl" / "video_wb_overlay.v").exists())
        self.assertFalse((ROOT / "project.fs").exists())
        src = (ROOT / "firmware" / "pikosol_shell.c").read_text()
        self.assertIn("PS_VIDEO_ID", src)
        self.assertIn("if (!s->video_ok)", src)
        self.assertIn("REG_COMMIT", src)
        self.assertNotIn("0x20000000", src)


if __name__ == "__main__":
    unittest.main()
