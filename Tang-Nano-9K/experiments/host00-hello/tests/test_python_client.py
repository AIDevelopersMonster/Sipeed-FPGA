import io
import unittest
import importlib.util
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path

path=Path(__file__).resolve().parents[1]/"tools"/"host00_hello.py"
spec=importlib.util.spec_from_file_location("host00_hello",path)
mod=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestHello(unittest.TestCase):
    def run_cli(self,fn):
        with redirect_stdout(io.StringIO()),redirect_stderr(io.StringIO()):
            return mod.main(["--port","COM10"],fn)

    def test_exact(self):
        self.assertEqual(0,self.run_cli(lambda port,baud,timeout:b"HELLO\n"))
    def test_short(self):
        self.assertEqual(1,self.run_cli(lambda port,baud,timeout:b"HEL"))
    def test_wrong(self):
        self.assertEqual(1,self.run_cli(lambda port,baud,timeout:b"HELL0\n"))
    def test_exception(self):
        def broken(port,baud,timeout):
            raise OSError("Port busy")
        self.assertEqual(2,self.run_cli(broken))


if __name__=="__main__":
    unittest.main()
