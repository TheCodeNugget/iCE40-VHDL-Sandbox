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

    rst: process (rising_edge(i_clk), rising_edge(i_rst))
    begin
        if (i_rst) then
            r_startDetect_currState <= c_state_idle;
        else
            r_startDetect_currState <= r_startDetect_nextState;
        end if;
    end process;

    detector_fsm: process (all)
    begin
        r_startDetect_nextState <= r_startDetect_currState;
        case (r_startDetect_currState) is
            when c_state_idle =>
                if (i_bus_sda and i_bus_scl) then
                    r_startDetect_nextState <= c_state_detect;
                end if;
            when c_state_detect =>
                if (not (i_bus_scl and i_bus_sda)) then
                    r_startDetect_nextState <= c_state_idle;
                end if;
            when others =>
                r_startDetect_nextState <= c_state_idle;
        end case;
    end process;

    start_detect: process (rising_edge(i_clk), rising_edge(i_rst))
    begin
        if (i_rst) then
            o_start <= '0';
        elsif (r_startDetect_currState = c_state_detect) then
            o_start <= '1' when ((not i_bus_sda) and i_bus_scl) else '0';
        end if;
    end process;

end architecture;
