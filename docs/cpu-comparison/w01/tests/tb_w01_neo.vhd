-- W01 byte-exact UART frame / digest / cycle count using REAL NEORV32 + enabled Zicntr.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library neorv32;
entity tb_w01_neo is end;
architecture sim of tb_w01_neo is
  constant HALF : time := 18518 ps;
  constant UART_BIT : time := 8680 ns;
  constant PREFIX : string := "W01:B26F8CA7:";
  signal clk : std_ulogic := '0';
  signal rstn : std_ulogic := '0';
  signal rx : std_ulogic := '1';
  signal tx : std_ulogic;
  signal leds : std_ulogic_vector(5 downto 0);
begin
  clk <= not clk after HALF;
  dut: entity neorv32.w01_neo_top port map (
    clk_i=>clk,rstn_i=>rstn,uart0_rxd_i=>rx,
    uart0_txd_o=>tx,led_n_o=>leds
  );
  p: process
    variable bs : string(1 to 23);
    variable value : natural;
    variable cycles : natural := 0;
    variable nibble : natural;
  begin
    wait for 1 us;
    rstn <= '1';
    if leds /= "101010" then wait until leds = "101010" for 3 ms; end if;
    assert leds="101010" report "W01_NEO_GPIO_START_FAIL" severity failure;
    if leds /= "010101" then wait until leds = "010101" for 12 ms; end if;
    assert leds="010101" report "W01_NEO_DIGEST_LED_FAIL" severity failure;
    for i in bs'range loop
      wait until tx='0' for 2 ms;
      assert tx='0' report "W01_NEO_UART_START_TIMEOUT" severity failure;
      wait for UART_BIT/2;
      assert tx='0' report "W01_NEO_UART_START_INVALID" severity failure;
      value:=0;
      for bitnum in 0 to 7 loop
        wait for UART_BIT;
        assert tx='0' or tx='1' report "W01_NEO_UART_BIT_UNKNOWN" severity failure;
        if tx='1' then value:=value+2**bitnum;end if;
      end loop;
      wait for UART_BIT;
      assert tx='1' report "W01_NEO_UART_STOP_INVALID" severity failure;
      bs(i):=character'val(value);
    end loop;
    assert bs(1 to 13)=PREFIX
      report "W01_NEO_DIGEST_FAIL: " & bs severity failure;
    for i in 14 to 21 loop
      nibble:=character'pos(bs(i));
      if nibble>=48 and nibble<=57 then
        nibble:=nibble-48;
      elsif nibble>=65 and nibble<=70 then
        nibble:=nibble-65+10;
      else
        assert false report "W01_NEO_INVALID_CYCLE_HEX" severity failure;
      end if;
      cycles:=cycles*16+nibble;
    end loop;
    assert bs(22)=character'val(13) and bs(23)=character'val(10)
      report "W01_NEO_UART_CRLF_MISSING" severity failure;
    assert cycles>=100 and cycles<=1000000
      report "W01_NEO_CYCLES_OUT_OF_RANGE" severity failure;
    report "W01_NEO_SIM_PASS digest=B26F8CA7 cycles=" &
       integer'image(cycles) & " bytes=23" severity note;
    std.env.finish;
    wait;
  end process;
  p_timeout: process
  begin
    wait for 25 ms;
    assert false report "W01_NEO_SIM_TIMEOUT: 25ms" severity failure;
    wait;
  end process;
end architecture;
