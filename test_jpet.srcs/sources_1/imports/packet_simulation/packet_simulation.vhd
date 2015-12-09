-- This source file was created for J-PET project in WFAIS (Jagiellonian University in Cracow)
-- License for distribution outside WFAIS UJ and J-PET project is GPL v 3
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;

entity packet_simulation is
    Port ( 
	        clock : in  STD_LOGIC;
			  
           data_valid : out  STD_LOGIC;
           data_out : out  STD_LOGIC_VECTOR(7 downto 0);
           start_packet : out  STD_LOGIC;
           end_packet : out  STD_LOGIC
			 );
end packet_simulation;

architecture Behavioral of packet_simulation is
begin
reading: process(clock)
file source : text is in "test_data";
variable L : line;
variable K : STD_LOGIC_VECTOR (7 downto 0);
variable N : STD_LOGIC_VECTOR (7 downto 0);
variable goodnumber: boolean;
variable started: boolean:=false;
variable inside:boolean:=false;
variable maybenext:boolean:=false;
variable wait_cnt:integer:=0;
variable data_v: std_logic := '0';
variable start_p: std_logic := '0';
variable end_p: std_logic := '0';
begin
if falling_edge(clock)then
	if(wait_cnt>0)then
		wait_cnt:=wait_cnt-1;
		end_p:='0';
		if(wait_cnt=0)then
			start_p:='1';
		end if;
	else
		hread(L,N,goodnumber);
		if not goodnumber then
			if not endfile(source)then
				readline(source,L);
				hread(L,N,goodnumber);
				case N is
					when "00000000" => maybenext:=true;
					when others => maybenext:=false;
				end case;
				hread(L,N,goodnumber);
				case N is
					when "00000000" => inside:=not maybenext;
					when others => inside:=true;
				end case;
				if not inside then
					wait_cnt:=3;
					inside:=false;
					if started then
						end_p:='1';
						start_p:='0';
					else
						started:=true;
						end_p:='0';
					end if;
				else
					end_p:='0';
					start_p:='0';
				end if;
			else
				if inside then
					inside:=false;
					start_p:='0';
					end_p:='1';
				else
					start_p:='0';
					end_p:='0';
				end if;
			end if;
			data_v:='0';
		else
			if not inside then
				inside:=true;
				start_p:='0';
				end_p:='0';
			else
				end_p:='0';
				start_p:='0';
			end if;
			data_v:='1';
			data_out<=N;
		end if;
	end if;
end if;
start_packet<=start_p;
end_packet<=end_p;
data_valid<=data_v;
end process reading;
end Behavioral;
