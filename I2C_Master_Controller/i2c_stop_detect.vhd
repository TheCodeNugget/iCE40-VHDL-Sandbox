library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_stop_detect is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_bus_scl : in std_logic;
        i_bus_sda : in std_logic;
        o_stop : out std_logic
    );
end entity;

architecture rtl of i2c_stop_detect is

    signal r_state : std_logic := '0';

begin

    detect_fsm: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_state <= '0';
        elsif (rising_edge(i_clk)) then
            if (not i_bus_sda) and (i_bus_scl) then
                r_state <= '1';
            elsif not ((not i_bus_sda) and (i_bus_scl)) then
                r_state <= '0';
            end if;
        end if;
    end process;

    stop_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_stop <= '0';
        elsif (rising_edge(i_clk)) then
            if ((r_state) and (i_bus_sda) and (i_bus_scl)) then
                o_stop <= '1';
            end if;
        end if;
    end process;
end architecture;
