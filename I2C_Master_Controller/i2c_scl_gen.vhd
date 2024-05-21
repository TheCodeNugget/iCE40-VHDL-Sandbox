library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_scl_gen is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_scl_en : in std_logic;
        i_bus_scl : in std_logic;
        i_stop_detect : in std_logic;
        i_clk_div : std_logic_vector(10 downto 0);
        o_scl_timeout : out std_logic;
        o_i2c_scl : out std_logic
    );
end entity;

architecture rtl of i2c_scl_gen is

    -- I2C SLC Generator States
    constant c_scl_idle : std_logic_vector(2 downto 0) := 2b"00";
    constant c_scl_low  : std_logic_vector(2 downto 0) := 2b"01";
    constant c_scl_wait : std_logic_vector(2 downto 0) := 2b"10";
    constant c_scl_high : std_logic_vector(2 downto 0) := 2b"11";

    -- State registers
    signal r_sclGen_currState : std_logic_vector(1 downto 0);
    signal r_sclGen_nextState : std_logic_vector(1 downto 0);

    -- Counter registers
    signal r_count_reset : std_logic;
    signal r_count_en : std_logic;
    signal r_count_modby2 : std_logic;
    signal r_modulus : std_logic_vector(9 downto 0);
    signal r_count : std_logic_vector(8 downto 0);

begin

    rst: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_sclGen_currState <= c_scl_idle;
        elsif (rising_edge(i_clk)) then
            r_sclGen_currState <= r_sclGen_nextState;
        end if;
    end process;

    fsm: process (i_clk, i_rst) is
    begin
        case (r_sclGen_currState) is
            when c_scl_idle => r_sclGen_nextState <= c_scl_low when (i_scl_en) else r_sclGen_currState;
            when c_scl_low => r_sclGen_nextState <= c_scl_wait when (r_count_modby2) else r_sclGen_currState;
            when c_scl_wait => r_sclGen_nextState <= c_scl_high when (i_bus_scl) else r_sclGen_currState;
            when c_scl_high => r_sclGen_nextState <= c_scl_idle when ((not i_bus_scl) or (r_count_modby2)) else r_sclGen_currState;
        end case;
    end process;

    scl_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_i2c_scl <= '1';
        elsif (rising_edge(i_clk)) then
            case (r_sclGen_currState) is
                when c_scl_idle => o_i2c_scl <= (not i_scl_en);
                when c_scl_low => o_i2c_scl <= r_count_modby2;
                when others => o_i2c_scl <= '1';
            end case;
        end if;
    end process;

    cnt_rst: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_count_reset <= '0';
        elsif (rising_edge(i_clk)) then
            case (r_sclGen_currState) is
                when c_scl_idle => r_count_reset <= i_scl_en;
                when c_scl_wait => r_count_reset <= not i_bus_scl;
                when c_scl_high => r_count_reset <= not i_bus_scl;
                when others => r_count_reset <= '0';
            end case;

        end if;
    end process;

    cnt_en: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_count_en <= '0';
        elsif (rising_edge(i_clk)) then
            if (i_scl_en) then
                r_count_en <= '1';
            elsif (i_stop_detect = '1') or (r_sclGen_currState = c_scl_idle) then
                r_count_en <= '0';
            end if;
        end if;
    end process;

    cnt: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_count <= 9b"0";
        elsif (rising_edge(i_clk)) then
            if (r_count_reset) or (r_count_modby2) then
                r_count <= 9b"0";
            elsif (r_count_en) then
                r_count <= r_count + 9b"1";
            end if;
        end if;
    end process;

    clk_div: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_modulus <= 10b"0";
        elsif (rising_edge(i_clk)) then
            r_modulus <= i_clk_div(10 downto 1) - 10b"11";
        end if;
    end process;

    modby2: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_count_modby2 <= '1';
        else
            r_count_modby2 <= (r_count = r_modulus(8 downto 0));
        end if;
    end process;

    o_scl_timeout <= '0';
end architecture;
