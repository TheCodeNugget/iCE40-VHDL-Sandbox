library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity filter is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_in  : in std_logic;
        o_out : out std_logic
    );
end entity;

architecture rtl of filter is

    signal r_in_d1 : std_logic := '0';
    signal r_in_d2 : std_logic := '0';
    signal r_in_d3 : std_logic := '0';
    signal r_out_n : std_logic := '0';

begin
    process (i_clk, i_rst)
    begin
        if (i_rst = '0') then
            r_in_d1 <= '0';
            r_in_d2 <= '0';
            r_in_d3 <= '0';
        elsif (rising_edge(i_clk)) then
            r_in_d1 <= not i_in;
            r_in_d2 <= r_in_d1;
            r_in_d3 <= r_in_d2;
        end if;
    end process;

    process (i_clk, i_rst)
    begin
        if (i_rst = '0') then
            r_out_n <= '0';
        elsif (rising_edge(i_clk)) then
            r_out_n <= r_in_d3;
        end if;
    end process;
    o_out <= not r_out_n;
end architecture;
