# PiKoSoL PR25-07, GowinSynthesis in SystemVerilog 2017 mode.
# Run with gw_sh.exe from this project directory.
# Only synthesis: never touches FPGA SRAM or external Flash.
open_project pikosol_term_dvi.gprj
set_option -top_module pikosol_term_dvi
set_option -verilog_std sysv2017
run syn
