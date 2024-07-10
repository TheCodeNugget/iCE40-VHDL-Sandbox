library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_controller_top is
    port (
        i_clk   : in std_logic;     -- System Clock, Target at 24MHz
        i_rst_N   : in std_logic;     -- Master Reset Active-Low

        io_scl  : inout std_logic;  -- Serial Clock Line
        io_sda  : inout std_logic;  -- Serial Data Line
        o_int_n :  out std_logic;   -- Interrupt Signal (Active Low)

        i_byte_cnt_reg  : in unsigned(7 downto 0);  -- Sets number of bytes to be sent/received
        i_clk_div_lsb   : in unsigned(7 downto 0);  -- Sets lower byte of the SCL clock divider, upper 3 bits in mode register
        i_slv_addr_reg  : in std_logic_vector(9 downto 0);  -- 10-bit slave address register, will use (6 downto 0) for 7-bit addressing mode
        i_config_reg    : in std_logic_vector(5 downto 0);  -- Config register for the controller (soft_reset/abort_reg/tx_interrupt_en/tx_interrupt_en/interrupt)
        i_mode_reg      : in std_logic_vector(7 downto 0);  -- Operation mode register, controlls speed/(read/write)/scl_div_cnt/bps_mode/adr_mode/ack
        o_cmd_stat_reg  : out std_logic_vector(7 downto 0); -- Current Status of the controller
        o_start_ack     : out std_logic;    -- Acknowledge flag for the start bit given by the user

        o_tx_data_req   : out std_logic;   -- Lets the user know that transmit data is required.
        i_tx_data       : in std_logic_vector(7 downto 0); -- Transmit Data Register
        o_rx_data_valid : out std_logic;   -- A "1" corresponds to valid data availability on the o_rx_data register.
        o_rx_data       : out std_logic_vector(7 downto 0) -- Received Data Register
    );
end entity;

architecture rtl of i2c_controller_top is
    
    signal w_scl_in: std_logic;
    signal w_scl_oe: std_logic;
    signal w_sda_in: std_logic;
    signal w_sda_oe: std_logic;

begin

    io_scl <= '0' when w_scl_oe else 'Z';
    w_scl_in <= io_scl;

    io_sda <= '0' when w_sda_oe else 'Z';
    w_sda_in <= io_sda;

    i2c_controller: entity work.i2c_controller
    port map (
        i_clk           => i_clk,
        i_rst           => i_rst_N,
        i_scl_in        => w_scl_in,
        i_sda_in        => w_sda_in,
        o_scl_oe        => w_scl_oe,
        o_sda_oe        => w_sda_oe,
        o_int_n         => o_int_n,
        i_slv_addr_reg  => i_slv_addr_reg,
        i_byte_cnt_reg  => i_byte_cnt_reg,
        i_clk_div_lsb   => i_clk_div_lsb,
        i_config_reg    => i_config_reg,
        i_mode_reg      => i_mode_reg,
        o_cmd_stat_reg  => o_cmd_stat_reg,
        o_start_ack     => o_start_ack,
        i_tx_data       => i_tx_data,
        o_tx_data_req   => o_tx_data_req,
        o_rx_data_valid => o_rx_data_valid,
        o_rx_data       => o_rx_data
    );
end architecture;
