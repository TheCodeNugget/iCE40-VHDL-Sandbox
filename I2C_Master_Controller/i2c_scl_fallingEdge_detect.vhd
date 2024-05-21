library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_scl_fallingEdge_detect is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_bus_scl : in std_logic;
        o_falling_scl : out std_logic
    );
end entity;

architecture rtl of i2c_scl_fallingEdge_detect is

    -- I2C Bus States
    constant c_bus_idle: std_logic_vector(1 downto 0) := b"00";
    constant c_bus_scl0: std_logic_vector(1 downto 0) := b"01";
    constant c_bus_scll: std_logic_vector(1 downto 0) := b"10";

    signal r_scl_state: std_logic_vector(1 downto 0) := b"00";
begin

    -----------------------------------------------------------
    -- SCL FSM
    -----------------------------------------------------------

    scl_fsm: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_scl_state <= c_bus_idle;
        elsif (rising_edge(i_clk)) then
            case c_bus_idle is
                when c_bus_idle =>
                    if (not i_bus_scl) then
                        r_scl_state <= c_bus_scl0;
                    end if;
                when c_bus_scl0 =>
                    r_scl_state <= c_bus_scll;
                when c_bus_scll =>
                    if (i_bus_scl) then
                        r_scl_state <= c_bus_idle;
                    end if;
            end case;
        end if;
    end process;

    -----------------------------------------------------------
    -- Raise Falling Edge Flag
    -----------------------------------------------------------

    edge_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_falling_scl <= '0';
        elsif (rising_edge(i_clk)) then
            o_falling_scl <= '1' when (r_scl_state = c_bus_scl0) else '0';
        end if;
    end process;

end architecture;
