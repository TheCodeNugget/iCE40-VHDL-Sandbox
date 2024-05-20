library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_stop_gen is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_stop_en : in std_logic;
        i_bus_scl : in std_logic;
        i_bps_mode : in std_logic_vector(1 downto 0);
        o_stop_ack : out std_logic;
        o_stop_sda : out std_logic
    );
end entity;

architecture rtl of i2c_stop_gen is
    -- I2C Mode timing thresholds set for input clock
    constant c_bps_std_mode : unsigned(15 downto 0) := 16d"140"; -- 4.7-us
    constant c_bps_fs_mode : unsigned(15 downto 0) := 16d"26"; -- 1.3-us
    constant c_bps_fsp_mode : unsigned(15 downto 0) := 16d"10"; -- 0.5-us

    -- I2C Speed modes
    constant c_i2c_std: std_logic_vector(1 downto 0) := 2b"00"; -- Standard Mode
    constant c_i2c_fs: std_logic_vector(1 downto 0) := 2b"01"; -- Full Speed Mode
    constant c_i2c_fsp: std_logic_vector(1 downto 0) := 2b"10"; -- Fast Mode

    -- Generator States
    constant c_state_idle : std_logic_vector(1 downto 0) := 2b"00";
    constant c_state_hold_wait : std_logic_vector(1 downto 0) := 2b"01";
    constant c_state_detect_sda0 : std_logic_vector(1 downto 0) := 2b"10";
    constant c_stop_gen_sda0 : std_logic_vector(1 downto 0) := 2b"11";

    -- Intermediate Signals
    signal r_state : std_logic_vector(1 downto 0);
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

    fsm: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_state <= c_state_idle;
        elsif (rising_edge(i_clk)) then
            case r_state is
                when c_state_idle => r_state <= c_state_detect_sda0 when (i_stop_en) else c_state_idle;
                when c_state_detect_sda0 => r_state <= c_state_hold_wait when (i_bus_scl) else c_state_idle;
                when c_state_hold_wait => r_state <= c_state_idle when (w_delay_done) else c_state_idle;
                when others => r_state <= c_state_idle;
            end case;
        end if;
    end process;

    rst: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_stop_sda <= '1';
        elsif (rising_edge(i_clk)) then
            if ((r_state = c_stop_gen_sda0) or (r_state = c_state_hold_wait)) then
                o_stop_sda <= '0';
            else
                o_stop_sda <= '1';
            end if;
        end if;
    end process;

    delay_handler: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_start_delay <= '0';
        elsif (rising_edge(i_clk)) then
            if (r_state = c_state_detect_sda0) and (i_bus_scl = '1') then
                r_start_delay <= '1';
            else
                r_start_delay <= '0';
            end if;
        end if;
    end process;

    ack_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_stop_ack <= '0';
        elsif (rising_edge(i_clk)) then
            o_stop_ack <= '1' when (r_state = c_stop_gen_sda0) else '0';
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
