LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
ENTITY top IS
END top;
 
ARCHITECTURE behavior OF top IS
   component packet_simulation port(
		clock : IN  std_logic;
		data_valid: out std_logic;
      data_out : out std_logic_vector(7 downto 0);
      start_packet: out std_logic;
      end_packet : out std_logic
   );end component;
   component parser port ( 
	   clk_read : in  STD_LOGIC;
      reset : in  STD_LOGIC;
      start_packet : in  STD_LOGIC;
      end_packet : in  STD_LOGIC;
      data_valid : in  STD_LOGIC;
		data_in : in STD_LOGIC_VECTOR(7 downto 0);	  
		eventID: out std_logic_vector(31 downto 0);
		triggerID: out std_logic_vector(31 downto 0);
		deviceID: out std_logic_vector(15 downto 0);
		dataWORD: out std_logic_vector(31 downto 0);
		out_data: out std_logic
	);end component;
	component devicefilter port(
		deviceID: in std_logic_vector(15 downto 0);
		in_data: in std_logic;
		clock: in std_logic;
		channel_offset: out std_logic_vector(15 downto 0);
		accepted: out std_logic
	);end component;
	component tdc_parser port(
		in_data:in std_logic;
		dataWORD: in std_logic_vector(31 downto 0);
		channel_offset: in std_logic_vector(15 downto 0);
	   eventID: in std_logic_vector(31 downto 0);
		triggerID: in std_logic_vector(31 downto 0);
		out_data: out std_logic;
		time_isrising:out std_logic;
		time_channel: out std_logic_vector(15 downto 0);
		time_epoch: out std_logic_vector(27 downto 0);
		time_fine: out std_logic_vector(9 downto 0);
		time_coasser:out std_logic_vector(10 downto 0)
	);end component;
	
   signal clock : std_logic:='0';
   signal reset : std_logic:='0';
   signal data_valid : std_logic:='0';
   signal start_packet : std_logic;
   signal end_packet : std_logic;
   signal data_bus : std_logic_vector(7 downto 0);

	signal beforefilter:std_logic:='0';
	signal afterfilter:std_logic:='0';
	signal data_word: std_logic_vector(31 downto 0);
	signal deviceID: std_logic_vector(15 downto 0);
	signal eventID: std_logic_vector(31 downto 0);
	signal triggerID: std_logic_vector(31 downto 0);
	signal channel_offset: std_logic_vector(15 downto 0);
	
	signal tdc_data: std_logic;
	signal time_channel: std_logic_vector(15 downto 0);
	signal time_isrising: std_logic;
	signal time_epoch: std_logic_vector(27 downto 0);
	signal time_fine: std_logic_vector(9 downto 0);
	signal time_coasser: std_logic_vector(10 downto 0);

   constant clock_period : time := 10 ns;
BEGIN 
   uut: packet_simulation PORT MAP (
      clock => clock,
      data_valid => data_valid,
      data_out => data_bus,
      start_packet => start_packet,
      end_packet => end_packet
   );
   parse:parser port map (
      clk_read => clock,
		reset => reset,
      start_packet => start_packet,
      end_packet => end_packet,
      data_valid => data_valid,
      data_in => data_bus,
		eventID => eventID,
		triggerID => triggerID,
		deviceID => deviceID,
		dataWORD => data_word,
		out_data => beforefilter
	);
	filter:devicefilter port map (
		deviceID => deviceID,
		in_data => beforefilter,
		clock => clock,
		channel_offset => channel_offset,
		accepted => afterfilter
	);
	tdc:tdc_parser port map(
		in_data => afterfilter,
		dataWORD => data_word,
		channel_offset => channel_offset,
		eventID => eventID,
		triggerID => triggerID,
		
		out_data => tdc_data,
		time_isrising => time_isrising,
		time_channel => time_channel,
		time_epoch => time_epoch,
		time_fine => time_fine,
		time_coasser => time_coasser
	);
   clock_process :process
   begin
		clock <= '0';
		wait for clock_period/2;
		clock <= '1';
		wait for clock_period/2;
   end process;	
   stim_proc: process
   begin		
      wait;
   end process;
end;
