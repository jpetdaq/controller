library ieee;
use ieee.std_logic_1164.all;
USE IEEE.numeric_std.ALL;

use work.trb_net_gbe_protocols.all;

package trb_net_gbe_components is
	function or_all(arg : std_logic_vector) return std_logic;
	function and_all(arg : std_logic_vector) return std_logic;

	type hist_array is array(31 downto 0) of std_logic_vector(31 downto 0);

end package;

package body trb_net_gbe_components is
	function or_all(arg : std_logic_vector) return std_logic is
		variable tmp : std_logic := '1';
	begin
		tmp := '0';
		for i in arg'range loop
			tmp := tmp or arg(i);
		end loop;                       -- i
		return tmp;
	end function or_all;

	function and_all(arg : std_logic_vector) return std_logic is
		variable tmp : std_logic := '1';
	begin
		tmp := '1';
		for i in arg'range loop
			tmp := tmp and arg(i);
		end loop;                       -- i
		return tmp;
	end function and_all;

end package body trb_net_gbe_components;