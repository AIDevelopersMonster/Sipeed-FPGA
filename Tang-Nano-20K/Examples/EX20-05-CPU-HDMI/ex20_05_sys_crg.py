"""EX20-05.15C: local lock-qualified system CRG for Sipeed Tang Nano 20K.

The installed litex_boards package is not modified on disk. The target's
_CRG factory is replaced only inside this Python build process.
"""
import inspect

from migen import ClockDomain, If, Instance, Signal
from migen.genlib.resetsync import AsyncResetSynchronizer
from litex.gen import LiteXModule
from litex.soc.cores.clock.gowin_gw2a import GW2APLL
from litex_boards.targets import sipeed_tang_nano_20k as board


class LockQualifiedCRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq):
        self.rst = Signal()
        self.cd_sys = ClockDomain()
        self.cd_por = ClockDomain()

        clk27 = platform.request("clk27")
        por_count = Signal(16, reset=(2**16 - 1))
        por_done = Signal()
        self.comb += self.cd_por.clk.eq(clk27)
        self.comb += por_done.eq(por_count == 0)
        self.sync.por += If(~por_done, por_count.eq(por_count - 1))

        self.pll = pll = GW2APLL(
            devicename=platform.devicename,
            device=platform.device,
        )
        self.comb += pll.reset.eq(~por_done)
        pll.register_clkin(clk27, 27e6)

        # Prevent the stock PLL core from installing its POR-only reset sync.
        pll.create_clkout(self.cd_sys, sys_clk_freq, with_reset=False)

        release = Signal(name="ex20_05_sys_release")
        self.specials += Instance(
            "ex20_05_sys_pll_guard",
            p_STABLE_CYCLES=4096,
            i_clk27=clk27,
            i_por_done=por_done,
            i_pll_locked=pll.locked,
            o_sys_release=release,
        )
        # Asynchronous assertion; synchronous release to the 48 MHz domain.
        self.specials += AsyncResetSynchronizer(self.cd_sys, ~release)


def install_lock_guard_crg():
    if board._CRG is LockQualifiedCRG:
        return
    source = inspect.getsource(board._CRG)
    expected = (
        "self.cd_por = ClockDomain()",
        "pll.reset.eq(~por_done)",
        "pll.create_clkout(self.cd_sys, sys_clk_freq)",
    )
    if not all("".join(s.split()) in "".join(source.split()) for s in expected):
        raise RuntimeError(
            "Installed LiteX _CRG differs from audited EX20-05.15B. "
            "Refusing to replace it."
        )
    if "_CRG(" not in inspect.getsource(board.BaseSoC.__init__):
        raise RuntimeError("BaseSoC does not use the expected _CRG factory")
    board._CRG = LockQualifiedCRG
