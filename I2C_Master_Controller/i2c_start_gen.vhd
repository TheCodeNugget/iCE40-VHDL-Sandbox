library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_start_gen is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start_en : in std_logic;
        i_tx_en : in std_logic;
        i_bus_scl : in std_logic;
        i_bus_sda : in std_logic;
        i_bps_mode : in std_logic_vector(1 downto 0);
        o_start_ack : out std_logic;
        o_start_sda : out std_logic
    );
end entity;

architecture rtl of i2c_start_gen is

    -- I2C Mode timing thresholds set for 19.2MHz Clock
    constant c_bps_std_mode : unsigned(15 downto 0) := 16d"140"; -- 4.7-us
    constant c_bps_fs_mode : unsigned(15 downto 0) := 16d"26"; -- 1.3-us
    constant c_bps_fsp_mode : unsigned(15 downto 0) := 16d"10"; -- 0.5-us

    -- I2C Speed modes
    constant c_i2c_std: std_logic_vector(1 downto 0) := b"00"; -- Standard Mode
    constant c_i2c_fs: std_logic_vector(1 downto 0) := b"01"; -- Full Speed Mode
    constant c_i2c_fsp: std_logic_vector(1 downto 0) := b"10"; -- Fast Mode

    -- Detector States
    constant c_idle_state : std_logic_vector(2 downto 0) := 3b"000";
    constant c_wait_scl1 : std_logic_vector(2 downto 0) := 3b"001";
    constant c_wait_start : std_logic_vector(2 downto 0) := 3b"010";
    constant c_detect : std_logic_vector(2 downto 0) := 3b"011";
    constant c_gen_sda0 : std_logic_vector(2 downto 0) := 3b"100";
    constant c_wait_scl0 : std_logic_vector(2 downto 0) := 3b"101";
    constant c_hold_scl0 : std_logic_vector(2 downto 0) := 3b"110";

    -- Intermediate Signals
    signal r_startGen_currstate : std_logic_vector(2 downto 0);
    signal r_startGen_nextstate : std_logic_vector(2 downto 0);
    signal r_start_delay : std_logic;
    signal r_delay_threshold : unsigned (15 downto 0);
    signal w_delay_done : std_logic;

begin

    -----------------------------------------------------------
    -- Delay Generation
    -----------------------------------------------------------

    delay_gen_inst_01: entity work.delay_gen
    port map (
        i_clk       => i_clk,
        i_rst       => i_rst,
        i_start     => r_start_delay,
        i_threshold => r_delay_threshold,
        o_done      => w_delay_done
    );

    rst: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_startGen_currstate <= c_idle_state;
        elsif (rising_edge(i_clk)) then
            r_startGen_currstate <= r_startGen_nextstate;
        end if;
    end process;

    fsm: process (all) is
    begin
        if (rising_edge(i_clk)) then
            case r_startGen_currstate is
                when c_idle_state => r_startGen_nextstate <= c_wait_scl1 when (i_start_en) else r_startGen_currstate;
                when c_wait_scl1 => r_startGen_nextstate <= c_wait_start when (i_bus_scl) else r_startGen_currstate;
                when c_wait_start => r_startGen_nextstate <= c_detect when (w_delay_done) else r_startGen_currstate;
                when c_detect => r_startGen_nextstate <= c_gen_sda0 when (i_bus_sda and i_bus_scl) else r_startGen_currstate;
                when c_gen_sda0 => r_startGen_nextstate <= c_wait_scl0;
                when c_wait_scl0 => r_startGen_nextstate <= c_hold_scl0 when (not i_bus_scl) else r_startGen_currstate;
                when c_hold_scl0 => r_startGen_nextstate <= c_idle_state when (i_tx_en) else r_startGen_currstate;
                when others => r_startGen_nextstate <= c_idle_state;
            end case;
        end if;
    end process;

    sda_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_start_sda <= '1';
        elsif (rising_edge(i_clk)) then
            if (r_startGen_currstate = c_gen_sda0) or (r_startGen_currstate = c_wait_scl0) or (r_startGen_currstate = c_hold_scl0) then
                o_start_sda <= '0';
            else
                o_start_sda <= '1';
            end if;
        end if;
    end process;

    delay_handler: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_start_delay <= '0';
        elsif (rising_edge(i_clk)) then
            if ((r_startGen_currstate = c_wait_scl1) = (i_bus_scl = '1')) or (r_startGen_currstate = c_gen_sda0) then
                r_start_delay <= '1';
            else
                r_start_delay <= '0';
            end if;
        end if;
    end process;

    start_ack_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_start_ack <= '0';
        elsif (rising_edge(i_clk)) then
            o_start_ack <= '1' when ((r_startGen_currstate = c_hold_scl0) = (w_delay_done = '1')) else '0';
        end if;
    end process;

    mode_select: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_delay_threshold <= c_bps_std_mode;
        elsif (rising_edge(i_clk)) then
            case (i_bps_mode) is
                when c_i2c_std => r_delay_threshold <= c_bps_std_mode;
                when c_i2c_fs => r_delay_threshold <= c_bps_fs_mode;
                when c_i2c_fsp => r_delay_threshold <= c_bps_fsp_mode;
                when others => r_delay_threshold <= c_bps_std_mode;
            end case;
        end if;
    end process;
end architecture;
