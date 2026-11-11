-- W01 dedicated NEORV32, counters Zicntr enabled; accepted LAB-06.1 source unchanged.
-- Pure VHDL, pinned NEORV32 from _deps, no FPGA vendor IP or Flash.
-- Source license: MIT; upstream NEORV32 components retain BSD-3-Clause.
library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

entity w01_neo_top is
  port (
    clk_i       : in  std_ulogic;
    rstn_i      : in  std_ulogic;
    uart0_rxd_i : in  std_ulogic;
    uart0_txd_o : out std_ulogic;
    led_n_o     : out std_ulogic_vector(5 downto 0)
  );
end entity;

architecture rtl of w01_neo_top is
  signal gpio_o : std_ulogic_vector(31 downto 0);
begin
  -- The board's six LEDs are active-low.
  led_n_o <= not gpio_o(5 downto 0);

  u_cpu: neorv32_top
    generic map (
      CLOCK_FREQUENCY => 27000000,
      BOOT_MODE_SELECT => 2,
      RISCV_ISA_C => false,
      RISCV_ISA_M => false,
      RISCV_ISA_Zicntr => true,
      -- Gowin GW1NR-9C PA2122 workaround: ARCHSEL=0 maps to DPB with
      -- unsupported WRITE_MODE0=2'b10. ARCHSEL=2 uses resettable FFs.
      -- New hardware configuration: re-run GHDL SIM before Gowin PnR.
      CPU_RF_ARCH_SEL => 2,
      IMEM_EN => true,
      IMEM_SIZE => 16*1024,
      DMEM_EN => true,
      DMEM_SIZE => 2*1024,
      IO_UART0_EN => true,
      IO_GPIO_NUM => 6,
      IO_CLINT_EN => false,
      OCD_EN => false,
      XBUS_EN => false
    )
    port map (
      clk_i => clk_i,
      rstn_i => rstn_i,
      gpio_o => gpio_o,
      uart0_txd_o => uart0_txd_o,
      uart0_rxd_i => uart0_rxd_i
    );
end architecture;
