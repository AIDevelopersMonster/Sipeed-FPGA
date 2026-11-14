-- PR25-14 Tang Primer 25K: independent HDMI pixel scene and chiptune audio.
-- Original 25K Gowin_PLL_ntsc and serial TMDS stack come from PR25-13.
library ieee;
use ieee.std_logic_1164.all;

entity chipmusic_top is
  port (
    clk_50mhz : in std_logic;
    jtagseln : out std_logic;
    leds_n : out std_logic_vector(1 downto 0);
    tmds_clk_n : out std_logic;
    tmds_clk_p : out std_logic;
    tmds_d_n : out std_logic_vector(2 downto 0);
    tmds_d_p : out std_logic_vector(2 downto 0)
  );
end entity;

architecture rtl of chipmusic_top is
  signal clk : std_logic;
  signal clk_pixel_x5 : std_logic;
  signal pll_locked : std_logic;
  component CLKDIV
    generic (DIV_MODE : string := "2");
    port (
      CLKOUT: out std_logic;
      HCLKIN: in std_logic;
      RESETN: in std_logic;
      CALIB: in std_logic
    );
  end component;
begin
  -- Do not take over the cable's JTAG resource for GPIO purposes.
  jtagseln <= '0';
  leds_n(0) <= not pll_locked;
  leds_n(1) <= '0';

  mainclock: entity work.Gowin_PLL_ntsc
    port map (
      clkin => clk_50mhz,
      mdclk => clk_50mhz,
      clkout0 => clk_pixel_x5,
      lock => pll_locked
    );
  div1_inst: CLKDIV
    generic map (DIV_MODE => "5")
    port map (CLKOUT => clk, HCLKIN => clk_pixel_x5,
              RESETN => pll_locked, CALIB => '0');
  video_inst: entity work.chipmusic_video
    port map (
      clk => clk,
      clk_pixel_x5 => clk_pixel_x5,
      pll_lock => pll_locked,
      tmds_clk_n => tmds_clk_n,
      tmds_clk_p => tmds_clk_p,
      tmds_d_n => tmds_d_n,
      tmds_d_p => tmds_d_p
    );
end architecture;
