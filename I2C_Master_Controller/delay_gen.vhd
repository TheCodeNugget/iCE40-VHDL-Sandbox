library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity delay_gen is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_threshold : in unsigned(15 downto 0);
        o_done : out std_logic
    );
end entity;

architecture rtl of delay_gen is

    signal r_count: unsigned(15 downto 0) := 16b"0";
begin

    count: process (all) is
    begin
        if (i_rst or o_done) then
            r_count <= "0";
        else
            if (i_start) then
                r_count <= "1";
            elsif ((r_count = i_threshold) or (r_count = "0")) then
                r_count <= "0";
            else
                r_count <= r_count + "1";
            end if;
        end if;
    end process;

    done_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_done <= '0';
        else
        o_done <= '1' when (r_count = i_threshold) else '0';
        end if;
    end process;
end architecture;
