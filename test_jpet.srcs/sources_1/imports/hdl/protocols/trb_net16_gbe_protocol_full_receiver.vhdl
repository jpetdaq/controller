LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

--********
-- receives and reassembles the full udp packets

entity trb_net16_gbe_protocol_full_receiver is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0
	);
	port(
		CLK                    : in  std_logic; -- system clock
		RESET                  : in  std_logic;

		-- INTERFACE	
		MY_MAC_IN              : in  std_logic_vector(47 downto 0);
		MY_IP_IN               : in  std_logic_vector(31 downto 0);
		PS_DATA_IN             : in  std_logic_vector(8 downto 0);
		PS_WR_EN_IN            : in  std_logic;
		PS_ACTIVATE_IN         : in  std_logic;
		PS_RESPONSE_READY_OUT  : out std_logic;
		PS_BUSY_OUT            : out std_logic;
		PS_SELECTED_IN         : in  std_logic;
		PS_SRC_MAC_ADDRESS_IN  : in  std_logic_vector(47 downto 0);
		PS_DEST_MAC_ADDRESS_IN : in  std_logic_vector(47 downto 0);
		PS_SRC_IP_ADDRESS_IN   : in  std_logic_vector(31 downto 0);
		PS_DEST_IP_ADDRESS_IN  : in  std_logic_vector(31 downto 0);
		PS_SRC_UDP_PORT_IN     : in  std_logic_vector(15 downto 0);
		PS_DEST_UDP_PORT_IN    : in  std_logic_vector(15 downto 0);

		TC_RD_EN_IN            : in  std_logic;
		TC_DATA_OUT            : out std_logic_vector(8 downto 0);
		TC_FRAME_SIZE_OUT      : out std_logic_vector(15 downto 0);
		TC_FRAME_TYPE_OUT      : out std_logic_vector(15 downto 0);
		TC_IP_PROTOCOL_OUT     : out std_logic_vector(7 downto 0);
		TC_IDENT_OUT           : out std_logic_vector(15 downto 0);
		TC_DEST_MAC_OUT        : out std_logic_vector(47 downto 0);
		TC_DEST_IP_OUT         : out std_logic_vector(31 downto 0);
		TC_DEST_UDP_OUT        : out std_logic_vector(15 downto 0);
		TC_SRC_MAC_OUT         : out std_logic_vector(47 downto 0);
		TC_SRC_IP_OUT          : out std_logic_vector(31 downto 0);
		TC_SRC_UDP_OUT         : out std_logic_vector(15 downto 0);

		RECEIVED_FRAMES_OUT    : out std_logic_vector(15 downto 0);
		SENT_FRAMES_OUT        : out std_logic_vector(15 downto 0);
		-- END OF INTERFACE

		PS_IDENT_IN            : in  std_logic_vector(15 downto 0);
		PS_FLAGS_OFFSET_IN     : in  std_logic_vector(15 downto 0);

		-- user data interface
		USR_DATA_OUT           : out std_logic_vector(7 downto 0);
		USR_DATA_VALID_OUT     : out std_logic;
		USR_SOP_OUT            : out std_logic;
		USR_EOP_OUT            : out std_logic;

		-- debug
		DEBUG_OUT              : out std_logic_vector(63 downto 0)
	);
end trb_net16_gbe_protocol_full_receiver;

architecture trb_net16_gbe_protocol_full_receiver of trb_net16_gbe_protocol_full_receiver is
	type dissect_states is (IDLE, READ_FRAME, COLLECT_NEXT_FRAME, CLEANUP);
	signal dissect_current_state, dissect_next_state : dissect_states;

	signal state              : std_logic_vector(3 downto 0);
	signal saved_ident        : std_logic_vector(15 downto 0);
	signal saved_flags_offset : std_logic_vector(15 downto 0);

begin
	DISSECT_MACHINE_PROC : process(RESET, CLK)
	begin
		if (RESET = '1') then
			dissect_current_state <= IDLE;
		elsif rising_edge(CLK) then
			dissect_current_state <= dissect_next_state;
		end if;
	end process DISSECT_MACHINE_PROC;

	DISSECT_MACHINE : process(dissect_current_state, PS_WR_EN_IN, PS_ACTIVATE_IN, PS_DATA_IN, saved_flags_offset)
	begin
		case dissect_current_state is
			when IDLE =>
				state <= x"1";
				if (PS_WR_EN_IN = '1' and PS_ACTIVATE_IN = '1') then
					dissect_next_state <= READ_FRAME;
				else
					dissect_next_state <= IDLE;
				end if;

			when READ_FRAME =>
				state <= x"2";
				if (PS_DATA_IN(8) = '1') then
					if (saved_flags_offset(13) = '1') then
						dissect_next_state <= COLLECT_NEXT_FRAME;
					else
						dissect_next_state <= CLEANUP;
					end if;
				else
					dissect_next_state <= READ_FRAME;
				end if;

			when COLLECT_NEXT_FRAME =>
				if (PS_WR_EN_IN = '1' and PS_ACTIVATE_IN = '1') then
					dissect_next_state <= READ_FRAME;
				else
					dissect_next_state <= COLLECT_NEXT_FRAME;
				end if;

			when CLEANUP =>
				state              <= x"e";
				dissect_next_state <= IDLE;

		end case;
	end process DISSECT_MACHINE;

	SAVE_VALUES_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (dissect_current_state = IDLE and PS_ACTIVATE_IN = '0') then
				saved_ident        <= x"0000";
				saved_flags_offset <= x"0000";
			elsif (dissect_current_state = IDLE and PS_WR_EN_IN = '1' and PS_ACTIVATE_IN = '1') then
				saved_ident        <= PS_IDENT_IN;
				saved_flags_offset <= PS_FLAGS_OFFSET_IN;
			elsif (dissect_current_state = COLLECT_NEXT_FRAME and PS_WR_EN_IN = '1' and PS_ACTIVATE_IN = '1') then
				saved_ident        <= PS_IDENT_IN;
				saved_flags_offset <= PS_FLAGS_OFFSET_IN;
			else
				saved_ident        <= saved_ident;
				saved_flags_offset <= saved_flags_offset;
			end if;
		end if;
	end process SAVE_VALUES_PROC;

	PS_BUSY_SYNC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (dissect_current_state = IDLE) then
				PS_BUSY_OUT <= '0';
			elsif (dissect_current_state = COLLECT_NEXT_FRAME) then
				PS_BUSY_OUT <= '0';
			else
				PS_BUSY_OUT <= '1';
			end if;
		end if;
	end process PS_BUSY_SYNC;

	USR_OUT_SYNC : process(CLK)
	begin
		if rising_edge(CLK) then
			USR_DATA_OUT       <= PS_DATA_IN(7 downto 0);
			USR_DATA_VALID_OUT <= PS_WR_EN_IN;

			if (dissect_current_state = IDLE and PS_WR_EN_IN = '1' and PS_ACTIVATE_IN = '1') then
				USR_SOP_OUT <= '1';
			else
				USR_SOP_OUT <= '0';
			end if;

			if (dissect_current_state = READ_FRAME and PS_WR_EN_IN = '1' and PS_ACTIVATE_IN = '1' and PS_DATA_IN(8) = '1' and saved_flags_offset(13) = '0') then
				USR_EOP_OUT <= '1';
			else
				USR_EOP_OUT <= '0';
			end if;
		end if;
	end process USR_OUT_SYNC;

	-- protocol doesnt send anything
	PS_RESPONSE_READY_OUT <= '0';
	TC_FRAME_SIZE_OUT     <= x"0000";   -- fixed frame size
	TC_FRAME_TYPE_OUT     <= x"0000";
	TC_DEST_MAC_OUT       <= PS_SRC_MAC_ADDRESS_IN;
	TC_DEST_IP_OUT        <= x"00000000"; -- doesnt matter
	TC_DEST_UDP_OUT       <= x"0000";   -- doesnt matter
	TC_SRC_MAC_OUT        <= MY_MAC_IN;
	TC_SRC_IP_OUT         <= x"00000000"; -- doesnt matter
	TC_SRC_UDP_OUT        <= x"0000";   -- doesnt matter
	TC_IP_PROTOCOL_OUT    <= x"00";     -- doesnt matter
	TC_IDENT_OUT          <= (others => '0'); -- doesn't matter

end trb_net16_gbe_protocol_full_receiver;


