-- This source file was created for J-PET project in WFAIS (Jagiellonian University in Cracow)
-- License for distribution outside WFAIS UJ and J-PET project is GPL v 3
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package VECTOR_FUNC is
	function bit_position(s : std_logic_vector) return integer;
end VECTOR_FUNC;

package body VECTOR_FUNC is
	function bit_position(s : std_logic_vector) return integer is
		variable position : natural := 0;
	begin
		for i in s'range loop
			if s(i) = '1' then
				position := i;
			end if;
		end loop;
		return position;
	end function bit_position;
end VECTOR_FUNC;

