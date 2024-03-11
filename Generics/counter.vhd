library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    generic (
        g_width : integer := 8
    );
    port (
        i_clock : in std_logic;
        i_reset : in std_logic := '0';
        o_count : out std_logic_vector (g_width - 1 downto 0)
    );
end entity counter;

architecture rtl of counter is

signal r_count: unsigned (g_width - 1 downto 0) := (others => '0');

begin
    process (i_clock, i_reset) begin
        if (i_reset = '1') then
            r_count <= (others => '0');
        elsif (rising_edge (i_clock)) then
            r_count <= r_count + 1;
        end if;
    end process;
    o_count <= std_logic_vector(r_count);
end rtl;