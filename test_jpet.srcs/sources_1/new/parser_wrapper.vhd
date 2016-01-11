----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/14/2015 11:51:23 AM
-- Design Name: 
-- Module Name: parser_wrapper - Behavioral
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

entity parser_wrapper is
    Port ( CLK : in STD_LOGIC;
           RESET : in STD_LOGIC;
           USR_DATA : in STD_LOGIC_VECTOR (7 downto 0);
           USR_DATA_VALID : in STD_LOGIC;
           USR_SOP : in STD_LOGIC;
           USR_EOP : in STD_LOGIC;
           DEBUG_OUT : out STD_LOGIC_VECTOR (7 downto 0)
    );
end parser_wrapper;

architecture Behavioral of parser_wrapper is
    signal parser_eventID : std_logic_vector(31 downto 0);
    signal parser_triggerID : std_logic_vector(31 downto 0);
    signal parser_deviceID : std_logic_vector(15 downto 0);
    signal parser_dataWORD : std_logic_vector(31 downto 0);
    signal parser_out_data : std_logic;
    
    signal device_filter_channel_offset : std_logic_vector(15 downto 0);
    signal device_filter_accepted : std_logic;
    signal debug_leds : std_logic_vector(7 downto 0);
begin

--parser_gen : if INCLUDE_FULL_RECEIVER = '1' generate
    Parser : entity work.parser
    port map (
        clk_read => CLK,
        reset => RESET,
        start_packet => USR_SOP,
        end_packet => USR_EOP,
        data_valid => USR_DATA_VALID,
        data_in => USR_DATA,      
        eventID => parser_eventID,
        triggerID => parser_triggerID,
        deviceID => parser_deviceID,
        dataWORD => parser_dataWORD,
        out_data => parser_out_data
    );
    DeviceFilter : entity work.devicefilter 
    port map (
        deviceID => parser_deviceID,
        in_data => parser_out_data,
        clock => CLK,
        channel_offset => device_filter_channel_offset,
        accepted => device_filter_accepted
    );
    TdcParser : entity work.tdc_parser 
    port map (
        clock => CLK,
        in_data => device_filter_accepted,
        dataWORD => parser_dataWORD,
        channel_offset => device_filter_channel_offset,
        eventID => parser_eventID,
        triggerID => parser_triggerID,
        
        out_data => DEBUG_OUT(0), -- out std_logic;
        time_isrising => DEBUG_OUT(1), --out std_logic;
        time_channel => open, -- out std_logic_vector(15 downto 0);
        time_epoch => open, -- out std_logic_vector(27 downto 0);
        time_fine => open, -- out std_logic_vector(9 downto 0);
        time_coasser => open -- out std_logic_vector(10 downto 0)
    );
--end generate parser_gen;

end Behavioral;
