-- SPDX-License-Identifier: GPL-3.0-only
-- PR25-08, 2026-11-14: Tang Primer 25K audio/video golden-IP experiment.
-- GPL-3.0 wrapper around A2600Nano v2.5 HDMI and PLL implementation.
library IEEE;
use IEEE.std_logic_1164.all;

entity pr25_hdmi_audio_top is
    port (
        clk_50mhz  : in std_logic;
        key_reset  : in std_logic;
        tmds_clk_p : out std_logic;
        tmds_clk_n : out std_logic;
        tmds_d_p   : out std_logic_vector(2 downto 0);
        tmds_d_n   : out std_logic_vector(2 downto 0)
    );
end pr25_hdmi_audio_top;

architecture rtl of pr25_hdmi_audio_top is
    signal pll_locked   : std_logic;
    signal clk_pixel_x5 : std_logic;
    signal clk          : std_logic;

    component CLKDIV
        generic ( DIV_MODE : STRING := "2" );
        port (
            CLKOUT : out std_logic;
            HCLKIN : in std_logic;
            RESETN : in std_logic;
            CALIB  : in std_logic
        );
    end component;

    component hdmi_audio_bars
        port (
            clk_pixel    : in std_logic;
            clk_pixel_x5 : in std_logic;
            pll_locked   : in std_logic;
            ext_reset    : in std_logic;
            tmds_clk_p   : out std_logic;
            tmds_clk_n   : out std_logic;
            tmds_d_p     : out std_logic_vector(2 downto 0);
            tmds_d_n     : out std_logic_vector(2 downto 0)
        );
    end component;
begin
    -- The exact working upstream v2.5 VHDL PLL and PLL_INIT.
    u_pll: entity work.Gowin_PLL_ntsc
        port map (
            clkin   => clk_50mhz,
            mdclk   => clk_50mhz,
            clkout0 => clk_pixel_x5,
            lock    => pll_locked
        );

    -- The same divide-by-five Gowin clocking as the working Atari image.
    u_div5: CLKDIV
        generic map ( DIV_MODE => "5" )
        port map (
            CLKOUT => clk,
            HCLKIN => clk_pixel_x5,
            RESETN => pll_locked,
            CALIB  => '0'
        );

    u_bars: hdmi_audio_bars
        port map (
            clk_pixel    => clk,
            clk_pixel_x5 => clk_pixel_x5,
            pll_locked   => pll_locked,
            ext_reset    => key_reset,
            tmds_clk_p   => tmds_clk_p,
            tmds_clk_n   => tmds_clk_n,
            tmds_d_p     => tmds_d_p,
            tmds_d_n     => tmds_d_n
        );
end rtl;
