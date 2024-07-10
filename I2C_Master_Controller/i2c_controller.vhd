library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_controller is
    port (
        i_clk       : in std_logic;
        i_rst       : in std_logic;

        i_scl_in    : in std_logic;
        i_sda_in    : in std_logic;
        o_scl_oe    : out std_logic;
        o_sda_oe    : out std_logic;
        o_int_n     : out std_logic;
        
        i_slv_addr_reg  : in std_logic_vector(9 downto 0);
        i_byte_cnt_reg  : in unsigned(7 downto 0);
        i_clk_div_lsb   : in unsigned(7 downto 0);
        i_config_reg    : in std_logic_vector(7 downto 0);
        i_mode_reg      : in std_logic_vector(7 downto 0);
        o_cmd_stat_reg  : out std_logic_vector(7 downto 0);
        o_start_ack     : out std_logic;

        i_tx_data       : in std_logic_vector(7 downto 0);
        o_tx_data_req   : out std_logic;
        o_rx_data_valid : out std_logic;
        o_rx_data       : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of i2c_controller is

    signal w_scl_oe: std_logic;
    signal w_sda_oe: std_logic;

    signal w_bus_cntrl_sda: std_logic;
    signal w_txdata_sda: std_logic;
    signal w_arbtr_lost: std_logic;
    signal w_scl_timeout: std_logic;
    signal w_int_out: std_logic;
    signal w_bps_mode: std_logic_vector(1 downto 0);
    signal w_scl_divcount: unsigned(10 downto 0);
    signal w_tx_en: std_logic;

    signal w_scl_en: std_logic;
    signal w_start_gen_en: std_logic;
    signal w_stop_gen_en: std_logic;
    signal w_sda_en: std_logic;
    signal w_i2c_falling_scl_detect: std_logic;
    signal w_i2c_start_detect: std_logic;
    signal w_i2c_start_ack: std_logic;
    signal w_i2c_stop_detect: std_logic;
    signal w_i2c_stop_ack: std_logic;

    signal r_soft_reset_d1: std_logic;
    signal r_soft_reset_d2: std_logic;
    signal r_soft_reset_d3: std_logic;

    -- Filter Wires
    signal w_scl_filtered: std_logic;
    signal w_sda_filtered: std_logic;

    signal w_rst: std_logic;
    signal w_rst_out: std_logic;
    signal w_reset: std_logic;

begin

    -- Output Enable Assignments
    o_scl_oe <= not w_scl_oe;
    w_sda_oe <= (w_bus_cntrl_sda and w_txdata_sda) and (not w_arbtr_lost);
    o_sda_oe <= not w_sda_oe;

    -- Polar Reset Assignments
    w_rst <= not i_rst;
    w_reset <= w_rst or w_rst_out;

    -- Interrupt I/O
    o_int_n <= not w_int_out;

    -----------------------------------------------------------
    -- I2C Bus Sampling Filters
    -----------------------------------------------------------

    bus_scl_filter: entity work.filter
    port map (
        i_clk => i_clk,
        i_rst => w_reset,
        i_in  => i_scl_in,
        o_out => w_scl_filtered
    );

    bus_sda_filter: entity work.filter
    port map (
        i_clk => i_clk,
        i_rst => w_reset,
        i_in  => i_sda_in,
        o_out => w_sda_filtered
    );

    -----------------------------------------------------------
    -- I2C Bus FSM Instance
    -----------------------------------------------------------

    i2c_bus_fsm_inst: entity work.i2c_bus_fsm
    port map (
        i_clk           => i_clk,
        i_rst           => w_reset,
        i_bus_scl       => w_scl_filtered,
        i_bus_sda       => w_sda_filtered,
        i_scl_en        => w_scl_en,
        i_tx_en         => w_tx_en,
        i_start_en      => w_start_gen_en,
        i_stop_en       => w_stop_gen_en,
        i_bps_mode      => w_bps_mode,
        i_clk_div       => w_scl_divcount,
        o_i2c_scl       => w_scl_oe,
        o_arbtr_lost    => w_arbtr_lost,
        o_falling_scl   => w_i2c_falling_scl_detect,
        o_scl_timeout   => w_scl_timeout,
        o_start_detect  => w_i2c_start_detect,
        o_start_ack     => w_i2c_start_ack,
        o_stop_detect   => w_i2c_stop_detect,
        o_stop_ack      => w_i2c_stop_ack,
        o_i2c_bus_cntrl => w_bus_cntrl_sda
    );

    -----------------------------------------------------------
    -- I2C Control FSM
    -----------------------------------------------------------

    i2c_fsm_top_inst: entity work.i2c_fsm_top
    port map (
        i_clk              => i_clk,
        i_rst              => w_rst,
        i_bus_sda          => w_sda_filtered,
        i_bus_scl          => w_scl_filtered,

        -- Config Ports
        i_scl_timeout      => w_scl_timeout,
        i_slv_addr_reg     => i_slv_addr_reg,
        i_byte_cnt_reg     => i_byte_cnt_reg,
        i_clk_div          => i_clk_div_lsb,
        i_config_reg       => i_config_reg,
        i_mode_reg         => i_mode_reg,
        o_start_ack        => o_start_ack,
        o_tx_en            => w_tx_en,
        o_i2c_sda_en       => w_sda_en,
        o_i2c_txdata_sda   => w_txdata_sda,
        o_scl_divcnt       => w_scl_divcount,
        o_bps_reg          => w_bps_mode,

        -- I2C Detector FSM Ports
        i_arbtr_lost       => w_arbtr_lost,
        i_scl_falling_edge => w_i2c_falling_scl_detect,
        o_scl_en           => w_scl_en,
        o_start_en         => w_start_gen_en,
        i_start_ack        => w_i2c_start_ack,
        i_start_detect     => w_i2c_start_detect,
        o_stop_en          => w_stop_gen_en,
        i_stop_ack         => w_i2c_stop_ack,
        i_stop_detect      => w_i2c_stop_detect,
        o_int_out          => w_int_out,
        o_cmd_stat_reg     => o_cmd_stat_reg,

        -- RX FIFO Ports
        o_rxfifo_wr_en     => o_rx_data_valid,
        o_rxfifo_wr_data   => o_rx_data,

        -- TX FIFO Ports
        i_txfifo_rd_data   => i_tx_data,
        o_txfifo_rd_en     => o_tx_data_req
    );

    -----------------------------------------------------------
    -- Soft Reset Synchronizer
    -----------------------------------------------------------

    w_rst_out <= r_soft_reset_d2 and (not r_soft_reset_d3);
    soft_reset_snyc: process (i_clk, w_rst) is
    begin
        if (w_rst) then
            r_soft_reset_d1 <= '0';
            r_soft_reset_d2 <= '0';
            r_soft_reset_d3 <= '0';
        elsif (rising_edge(i_clk)) then
            r_soft_reset_d1 <= i_config_reg(5);
            r_soft_reset_d2 <= r_soft_reset_d1;
            r_soft_reset_d3 <= r_soft_reset_d2;
        end if;
    end process;
end architecture;
