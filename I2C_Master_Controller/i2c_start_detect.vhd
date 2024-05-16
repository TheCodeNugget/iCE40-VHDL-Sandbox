library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_start_detect is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_bus_scl : in std_logic;
        i_bus_sda : in std_logic;
        o_start : out std_logic
    );
end entity;

architecture rtl of i2c_start_detect is

    constant c_state_idle : std_logic := '0';
    constant c_state_detect : std_logic := '1';

    signal r_startDetect_currState : std_logic := '0';
    signal r_startDetect_nextState : std_logic := '0';

begin

    -----------------------------------------------------------
    -- Detect FSM
    -----------------------------------------------------------

    rst: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_startDetect_currState <= c_state_idle;
        elsif (rising_edge(i_clk)) then
            r_startDetect_currState <= r_startDetect_nextState;
        end if;
    end process;

    detector_fsm: process (all) is
    begin
        if (rising_edge(i_clk)) then
            case (r_startDetect_currState) is
                when c_state_idle => r_startDetect_nextState <= c_state_detect when (i_bus_sda and i_bus_scl) else r_startDetect_currState;
                when c_state_detect => r_startDetect_nextState <= c_state_idle when (not (i_bus_sda and i_bus_scl)) else r_startDetect_currState;
                when others => r_startDetect_nextState <= c_state_idle;
            end case;
        end if;
    end process;

    start_detect: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_start <= '0';
        elsif rising_edge(i_clk) and (r_startDetect_currState = c_state_detect) then
            o_start <= '1' when ((not i_bus_sda) and i_bus_scl) else '0';
        end if;
    end process;

end architecture;
