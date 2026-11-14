# PiKoSoL PR25-07: synth -> PnR -> bitstream in Gowin gw_sh.exe.
# The ONLY output is local implementation files; FPGA/Flash are not programmed.
open_project pikosol_term_dvi.gprj
set_option -top_module pikosol_term_dvi
set_option -verilog_std sysv2017
set_option -use_cpu_as_gpio 1
# The GW5A-25 MBGA121N SSPI regular-IO setting is mandatory.
set_option -use_sspi_as_gpio 1
set_option -bit_incl_bsram_init 1
run all
