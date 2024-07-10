library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_bus_fsm is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_bus_scl : in std_logic;
        i_bus_sda : in std_logic;
        i_scl_en : in std_logic;
        i_tx_en : in std_logic;
        i_start_en : in std_logic;
        i_stop_en : in std_logic;
        i_bps_mode : in std_logic_vector(1 downto 0);
        i_clk_div : in unsigned(10 downto 0);
        o_i2c_scl : out std_logic;
        o_arbtr_lost : out std_logic;
        o_falling_scl : out std_logic;
        o_scl_timeout : out std_logic;
        o_start_detect : out std_logic;
        o_start_ack : out std_logic;
        o_stop_detect : out std_logic;
        o_stop_ack : out std_logic;
        o_i2c_bus_cntrl : out std_logic
    );
end entity;

architecture rtl of i2c_bus_fsm is

    signal w_i2c_sda_start: std_logic;
    signal w_i2c_sda_stop: std_logic;
    signal w_stop_detect: std_logic;

begin

    i2c_scl_edge_detect: entity work.i2c_scl_fallingEdge_detect
    port map (
        i_clk          => i_clk,
        i_rst          => i_rst,
        i_bus_scl      => i_bus_scl,
        o_falling_scl  => o_falling_scl
    );

    i2c_scl_gen: entity work.i2c_scl_gen
    port map (
        i_clk           => i_clk,
        i_rst           => i_rst,
        i_scl_en        => i_scl_en,
        i_bus_scl       => i_bus_scl,
        i_stop_detect   => w_stop_detect,
        i_clk_div       => i_clk_div,
        o_scl_timeout   => o_scl_timeout,
        o_i2c_scl       => o_i2c_scl
    );

    i2c_start_detect: entity work.i2c_start_detect
    port map (
        i_clk          => i_clk,
        i_rst          => i_rst,
        i_bus_scl      => i_bus_scl,
        i_bus_sda      => i_bus_sda,
        o_start_detect => o_start_detect
    );

    i2c_start_gen: entity work.i2c_start_gen
    port map (
        i_clk       => i_clk,
        i_rst       => i_rst,
        i_start_en  => i_start_en,
        i_tx_en     => i_tx_en,
        i_bus_scl   => i_bus_scl,
        i_bus_sda   => i_bus_sda,
        i_bps_mode  => i_bps_mode,
        o_start_ack => o_start_ack,
        o_start_sda => w_i2c_sda_start
    );

    i2c_stop_detect: entity work.i2c_stop_detect
    port map (
        i_clk         => i_clk,
        i_rst         => i_rst,
        i_bus_scl     => i_bus_scl,
        i_bus_sda     => i_bus_sda,
        o_stop_detect => w_stop_detect
    );

    o_stop_detect <= w_stop_detect;

    i2c_stop_gen_inst: entity work.i2c_stop_gen
    port map (
        i_clk      => i_clk,
        i_rst      => i_rst,
        i_stop_en  => i_stop_en,
        i_bus_scl  => i_bus_scl,
        i_bps_mode => i_bps_mode,
        o_stop_ack => o_stop_ack,
        o_stop_sda => w_i2c_sda_stop
    );

    o_i2c_bus_cntrl <= w_i2c_sda_start and w_i2c_sda_stop;
    o_arbtr_lost <= '0';

end architecture;
