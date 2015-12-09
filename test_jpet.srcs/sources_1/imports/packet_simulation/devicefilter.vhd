-- This source file was created for J-PET project in WFAIS (Jagiellonian University in Cracow)
-- License for distribution outside WFAIS UJ and J-PET project is GPL v 3
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity devicefilter is
	port(
		deviceID: in std_logic_vector(15 downto 0);
		in_data: in std_logic;
		clock: in std_logic;
		
		channel_offset: out std_logic_vector(15 downto 0);
		accepted: out std_logic
	);
end devicefilter;

architecture Behavioral of devicefilter is
    signal accept : std_logic:='0';
    signal counter : integer:=0;
begin

check_device:process(in_data, clock)
begin
    if rising_edge(clock) then
        if in_data = '1' then
            counter <= 4;
        elsif accept = '1' then
            accept <= '0';
        elsif counter > 0 then
            counter <= counter-1;
            if counter = 0 then
                accept <= '1';
            end if;
        end if;
    end if;
end process check_device;

accept_device:process(accept, clock)
begin
	if rising_edge(clock)then
        accepted<=accept;
    end if;
end process accept_device;

calculate_channel_offset:process(accept, clock)
begin
	if rising_edge(clock) then
	    if accept='1' then
            channel_offset<=deviceID;
        end if;
	end if;
end process calculate_channel_offset;
end Behavioral;
