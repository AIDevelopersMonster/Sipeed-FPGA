# Third-party notices — PiKoSoL PONG RGB

This project contains original game RTL, constraints, PowerShell build automation, and a browser keyboard client. Authored files are under the repository's MIT License.

## SimpleVOut (SVO)

- Upstream: https://github.com/cliffordwolf/SimpleVOut
- Copyright (C) 2014 Clifford Wolf.
- License: ISC; the original copyright and permission notices must be preserved.
- Sources include svo_enc.v, svo_tcard.v, svo_tmds.v, svo_utils.v, and svo_vdma.v.
- Their Sipeed PicoTiny copy is fetched at the pinned commit c3b795799f23de91982be52db4273a8eea100cdb of https://github.com/sipeed/TangNano-9K-example.
- The fetched vendor files remain outside version control under 01-PicoRV32/vendor/picotiny_ref; their notices remain intact.
- This project does not use or include upstream SVO's svo_pong.v; gameplay is independently implemented in games/pong-rgb/rtl/pong_rgb_core.v.
- SVO is not relicensed as MIT. The full ISC notice travels with its independently fetched source files.

## Gowin FPGA primitives and tools

Gowin EDA, Gowin clock-generator wrappers, PLL/CLKDIV/OSER10/LVDS
device primitives, and other vendor IP are subject to manufacturer
and applicable third-party license terms, not the project's MIT license.
Proprietary vendor implementation tools and HDL are not redistributed here.

Compiled .fs images are published separately for Tang Nano 9K, following
post-route timing and hardware validation, exact SHA-256 matching, and
review of the vendor license applicable to the installed EDA version.
A compiled bitstream is not a source-code license grant.
