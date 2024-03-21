library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider is
    generic (
        g_clkin_f: integer;
        g_clkout_f: integer
    );
    port (
        i_clk : in std_logic;
        o_clk : out std_logic := '0'
    );
end entity;


architecture rtl of clock_divider is

    function c_bit_width(n: natural) return natural is
    begin
        if n > 0 then
            return 1 + c_bit_width(n / 2);
        else
            return 1;
        end if;
    end c_bit_width;

    constant c_counter_max: natural := g_clkin_f / g_clkout_f / 2;
    constant c_counter_width: natural := c_bit_width(c_counter_max);
  
    signal counter: unsigned(c_counter_width - 1 downto 0) := (others => '0');
    signal clock_signal: std_logic := '0';
  
begin
    update_counter: process(i_clk)
    begin
        if (rising_edge(i_clk)) then
            if counter = c_counter_max then
                counter <= to_unsigned(0, c_counter_width);
                clock_signal <= not clock_signal;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;
    
    o_clk <= clock_signal;
  end architecture rtl;