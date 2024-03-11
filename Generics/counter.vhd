library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    generic (
        width : integer := 8
    );
    port (
        clock : in std_logic;
        reset : in std_logic := '0';
        count : out std_logic_vector (width - 1 downto 0)
    );
end entity counter;

architecture rtl of counter is

signal r_count: unsigned (width - 1 downto 0) := (others => '0');

begin
    process (clock, reset) begin
        if (reset = '1') then
            r_count <= (others => '0');
        elsif (rising_edge (clock)) then
            r_count <= r_count + 1;
        end if;
    end process;
    count <= std_logic_vector(r_count);
end rtl;