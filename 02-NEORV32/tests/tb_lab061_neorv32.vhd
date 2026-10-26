-- LAB-06.1B: REAL NEORV32 execution from generated IMEM image.
-- Decodes physical UART serial bits; checks LED GPIO output and hard timeout.
-- No fake UART text output and no simulated CPU instructions.
-- SPDX-License-Identifier: MIT
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;

entity tb_lab061_neorv32 is
end entity;

architecture sim of tb_lab061_neorv32 is
  constant CLK_HALF : time := 18518 ps; -- 27MHz nominal, 37.036ns period
  constant UART_BIT : time := 8681 ns;  -- 115200 8N1, tolerance < 0.2%
  constant EXPECTED : string := "NEORV32 READY" & character'val(13) & character'val(10);

  signal clk : std_ulogic := '0';
  signal rstn : std_ulogic := '0';
  signal uart_tx : std_ulogic;
  signal uart_rx : std_ulogic := '1';
  signal led_n : std_ulogic_vector(5 downto 0);
begin
  clk <= not clk after CLK_HALF;

  u_dut: entity neorv32.lab061_neorv32_top
    port map (
      clk_i => clk, rstn_i => rstn,
      uart0_rxd_i => uart_rx, uart0_txd_o => uart_tx, led_n_o => led_n
    );

  stimulus: process
    variable rxbyte : natural;
  begin
    rstn <= '0';
    wait for 1 us;
    rstn <= '1';

    -- The first CPU GPIO write is 0x15, inverted on physical LED pins.
    if led_n /= "101010" then
      wait until led_n = "101010" for 1 ms;
    end if;
    assert led_n = "101010"
      report "LAB061_GPIO_FIRST_PATTERN_FAIL" severity failure;

    for i in EXPECTED'range loop
      -- Full physical UART start/data/stop decoding; every byte is checked.
      wait until uart_tx = '0' for 1 ms;
      assert uart_tx = '0'
        report "LAB061_UART_START_TIMEOUT byte=" & integer'image(i) severity failure;
      wait for UART_BIT / 2;
      assert uart_tx = '0'
        report "LAB061_UART_START_INVALID" severity failure;
      rxbyte := 0;
      for b in 0 to 7 loop
        wait for UART_BIT;
        assert uart_tx = '0' or uart_tx = '1'
          report "LAB061_UART_UNRESOLVED_BIT" severity failure;
        if uart_tx = '1' then rxbyte := rxbyte + 2**b; end if;
      end loop;
      wait for UART_BIT;
      assert uart_tx = '1'
        report "LAB061_UART_STOP_BIT_FAIL" severity failure;
      assert rxbyte = character'pos(EXPECTED(i))
        report "LAB061_UART_BYTE_MISMATCH at index " & integer'image(i) &
               ": got " & integer'image(rxbyte) &
               ", expected " & integer'image(character'pos(EXPECTED(i)))
        severity failure;
    end loop;

    -- Firmware waits for UART to completely empty, then switches to 0x2A.
    if led_n /= "010101" then
      wait until led_n = "010101" for 1 ms;
    end if;
    assert led_n = "010101"
      report "LAB061_GPIO_SECOND_PATTERN_FAIL" severity failure;

    report "LAB061_NEORV32_UART_GPIO_TB_PASS: 15 UART bytes, two GPIO patterns" severity note;
    std.env.finish;
    wait;
  end process;

  timeout: process
  begin
    wait for 5 ms;
    assert false report "LAB061_SIM_TIMEOUT: 5ms" severity failure;
    wait;
  end process;
end architecture;
