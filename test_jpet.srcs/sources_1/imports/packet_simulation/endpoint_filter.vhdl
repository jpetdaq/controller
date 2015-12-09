-- This source file was created for J-PET project in WFAIS (Jagiellonian University in Cracow)
-- License for distribution outside WFAIS UJ and J-PET project is GPL v 3
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE IEEE.std_logic_UNSIGNED.ALL;

use work.VECTOR_FUNC.all;

entity endpoint_filter is
	generic(
		SIMULATE              : integer range 0 to 1   := 0;
		INCLUDE_DEBUG         : integer range 0 to 1   := 0;

		LATTICE_ECP3          : integer range 0 to 1   := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1   := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1   := 0;

		MEM_SIZE              : integer range 0 to 255 := 0 -- the number of possible endpoints
	);
	port(
		CLK                    : in  std_logic;
		RESET                  : in  std_logic;

		-- config interface
		CONFIG_ENDP_ADDR_IN    : in  std_logic_vector(15 downto 0);
		CONFIG_ENDP_OFFSET_IN  : in  std_logic_vector(15 downto 0);
		CONFIG_WE_IN           : in  std_logic;

		-- user interface
		FILTER_ENDP_ADDR_IN    : in  std_logic_vector(15 downto 0);
		FILTER_ENDP_OFFSET_OUT : out std_logic_vector(15 downto 0);
		FILTER_ENDP_VALID_OUT  : out std_logic;

		DEBUG_OUT              : out std_logic_vector(255 downto 0)
	);
end entity endpoint_filter;

architecture RTL of endpoint_filter is
	type endp_array is array (0 to 255 - 1) of std_logic_vector(32 downto 0);
	signal endpoints : endp_array;
	signal endp_ptr  : natural range 0 to 255 - 1;

	signal endp_addr_local, endp_offset_local : std_logic_vector(15 downto 0);
	signal endp_we_local                      : std_logic;
	signal active_output                      : std_logic_vector(255 - 1 downto 0);
	signal filter_endp_addr                   : std_logic_vector(15 downto 0);

begin
	process(CLK)
	begin
		if rising_edge(CLK) then
			endp_addr_local   <= CONFIG_ENDP_ADDR_IN;
			endp_offset_local <= CONFIG_ENDP_OFFSET_IN;
			endp_we_local     <= CONFIG_WE_IN;

			filter_endp_addr <= FILTER_ENDP_ADDR_IN;
		end if;
	end process;

	process(CLK)
	begin
		if rising_edge(CLK) then
			if (RESET = '1') then
				endp_ptr <= 1;
			elsif (endp_we_local = '1' and endp_ptr < 255 - 1) then
				endp_ptr <= endp_ptr + 1;
			else
				endp_ptr <= endp_ptr;
			end if;
		end if;
	end process;

	regs_gen : for i in 0 to 255 - 1 generate
		process(CLK)
		begin
			if rising_edge(CLK) then
			    if (RESET = '1') then
			        endpoints(i) <= (others => '0');
				elsif (endp_we_local = '1' and i = endp_ptr) then
					endpoints(i) <= '1' & endp_offset_local & endp_addr_local;
				else
					endpoints(i) <= endpoints(i);
				end if;
			end if;
		end process;
	end generate regs_gen;

	output_gen : for i in 0 to 255 - 1 generate
		process(CLK)
		begin
			if rising_edge(CLK) then
			    if (RESET = '1') then
			        active_output(i) <= '0';
				elsif (filter_endp_addr = endpoints(i)(15 downto 0) and endpoints(i)(32) = '1') then
					active_output(i) <= '1';
				else
					active_output(i) <= '0';
				end if;
			end if;
		end process;
	end generate output_gen;

	process(CLK)
	begin
		if rising_edge(CLK) then
			FILTER_ENDP_OFFSET_OUT <= endpoints(bit_position(active_output))(31 downto 16);
			FILTER_ENDP_VALID_OUT  <= endpoints(bit_position(active_output))(32);
		end if;
	end process;

end architecture RTL;
