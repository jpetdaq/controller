library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use IEEE.NUMERIC_STD.ALL;

entity edge_to_pulse is
	generic(
		SIMULATE      : integer range 0 to 1 := 0;
		INCLUDE_DEBUG : integer range 0 to 1 := 0
	);
	port(
		CLK       : in  std_logic;
		SIGNAL_IN : in  std_logic;
		PULSE_OUT : out std_logic;

		DEBUG_OUT : out std_logic_vector(255 downto 0)
	);
end edge_to_pulse;

architecture Behavioral of edge_to_pulse is
	signal lock : std_logic := '0';

begin
	process(CLK)
	begin
		if rising_edge(CLK) then
			if (SIGNAL_IN = '1' and lock = '0') then
				PULSE_OUT <= '1';
			else
				PULSE_OUT <= '0';
			end if;
		end if;
	end process;

	process(CLK)
	begin
		if rising_edge(CLK) then
			if (SIGNAL_IN = '1') then
				lock <= '1';
			elsif (SIGNAL_IN = '0') then
				lock <= '0';
			else
				lock <= lock;
			end if;				
		end if;
	end process;

end Behavioral;