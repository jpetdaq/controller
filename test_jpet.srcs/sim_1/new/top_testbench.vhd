----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.10.2015 12:50:00
-- Design Name: 
-- Module Name: top_testbench - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top_testbench is
--  Port ( );
end top_testbench;

architecture Behavioral of top_testbench is

component main is
generic (
	SIMULATE : integer range 0 to 1 := 1
);
port (
	 GTREFCLK_P, GTREFCLK_N : in std_logic;
    SYSCLK_P, SYSCLK_N : in std_logic;
    SFP_TX_P, SFP_TX_N : out std_logic;
    SFP_RX_P, SFP_RX_N : in std_logic;
	 CPU_RESET : in std_logic;
    LED : out std_logic_vector(7 downto 0)
);
end component;

signal refclk_n, refclk_p : std_logic;
signal sysclk_p, sysclk_n : std_logic;

begin

uut :  main
generic map (
	SIMULATE => 1
)
port map(
	GTREFCLK_P => refclk_p,
	GTREFCLK_N => refclk_n,
    SYSCLK_P => sysclk_p,
    SYSCLK_N => sysclk_n,
    SFP_TX_P => open,
    SFP_TX_N => open,
    SFP_RX_P => '0',
    SFP_RX_N => '1',
	 CPU_RESET => '0',
    LED => open
);

process
begin
    sysclk_p <= '1'; wait for 2500 ps;
    sysclk_p <= '0'; wait for 2500 ps;
end process;
sysclk_n <= not sysclk_p;


process
begin
    refclk_p <= '1'; wait for 4 ns;
    refclk_p <= '0'; wait for 4 ns;
end process;
refclk_n <= not refclk_p;   

end Behavioral;
