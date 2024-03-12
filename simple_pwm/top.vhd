library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.numeric_std.all;

entity top is
    port (
      o_pwm: out std_logic
    );
end top;

architecture rtl of top is

component HSOSC is
	generic (
		CLKHF_DIV : String := "0b00"
	);
	port (
		CLKHFPU : in std_logic := '1';
		CLKHFEN : in std_logic := '1';
		CLKHF : out std_logic
	);
end component;

signal w_main_clk : std_logic;

begin
	pwm_osc: HSOSC
	port map (
	  CLKHF => w_main_clk
	);

	pwm_power: entity work.counter
	port map (
	  i_clock => w_main_clk,
	  o_count => o_pwm
	);
end rtl;