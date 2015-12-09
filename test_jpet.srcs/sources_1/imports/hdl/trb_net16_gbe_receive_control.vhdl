LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;
USE IEEE.numeric_std.ALL;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

--********
-- controller has to control the rest of the logic (TX part, TS_MAC, HUB) accordingly to 
-- the message received from receiver, frame checking is already done
-- 

--TODO: register the component input/output ports

entity trb_net16_gbe_receive_control is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0
	);
	port(
		CLK                     : in  std_logic; -- system clock
		RESET                   : in  std_logic;

		-- signals to/from frame_receiver
		RC_DATA_IN              : in  std_logic_vector(8 downto 0);
		FR_RD_EN_OUT            : out std_logic;
		FR_FRAME_VALID_IN       : in  std_logic;
		FR_GET_FRAME_OUT        : out std_logic;
		FR_FRAME_SIZE_IN        : in  std_logic_vector(15 downto 0);
		FR_FRAME_PROTO_IN       : in  std_logic_vector(15 downto 0);
		FR_IP_PROTOCOL_IN       : in  std_logic_vector(7 downto 0);

		FR_SRC_MAC_ADDRESS_IN   : in  std_logic_vector(47 downto 0);
		FR_DEST_MAC_ADDRESS_IN  : in  std_logic_vector(47 downto 0);
		FR_SRC_IP_ADDRESS_IN    : in  std_logic_vector(31 downto 0);
		FR_DEST_IP_ADDRESS_IN   : in  std_logic_vector(31 downto 0);
		FR_SRC_UDP_PORT_IN      : in  std_logic_vector(15 downto 0);
		FR_DEST_UDP_PORT_IN     : in  std_logic_vector(15 downto 0);

		FR_ID_IP_IN             : in  std_logic_vector(15 downto 0);
		FR_FO_IP_IN             : in  std_logic_vector(15 downto 0);
		FR_UDP_CHECKSUM_IN      : in  std_logic_vector(15 downto 0);
		
		FR_IDENT_IN             : in  std_logic_vector(15 downto 0);
		FR_FLAGS_OFFSET_IN      : in  std_logic_vector(15 downto 0);

		-- signals to/from main controller
		RC_RD_EN_IN             : in  std_logic;
		RC_Q_OUT                : out std_logic_vector(8 downto 0);
		RC_FRAME_WAITING_OUT    : out std_logic;
		RC_LOADING_DONE_IN      : in  std_logic;
		RC_FRAME_SIZE_OUT       : out std_logic_vector(15 downto 0);
		RC_FRAME_PROTO_OUT      : out std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
		RC_SRC_MAC_ADDRESS_OUT  : out std_logic_vector(47 downto 0);
		RC_DEST_MAC_ADDRESS_OUT : out std_logic_vector(47 downto 0);
		RC_SRC_IP_ADDRESS_OUT   : out std_logic_vector(31 downto 0);
		RC_DEST_IP_ADDRESS_OUT  : out std_logic_vector(31 downto 0);
		RC_SRC_UDP_PORT_OUT     : out std_logic_vector(15 downto 0);
		RC_DEST_UDP_PORT_OUT    : out std_logic_vector(15 downto 0);
		RC_ID_IP_OUT            : out std_logic_vector(15 downto 0);
		RC_FO_IP_OUT            : out std_logic_vector(15 downto 0);
		RC_CHECKSUM_OUT         : out std_logic_vector(15 downto 0);
		RC_REDIRECT_TRAFFIC_IN  : in  std_logic;
		
		RC_IDENT_OUT            : out std_logic_vector(15 downto 0);
		RC_FLAGS_OFFSET_OUT     : out std_logic_vector(15 downto 0);

		-- statistics
		FRAMES_RECEIVED_OUT     : out std_logic_vector(31 downto 0);
		BYTES_RECEIVED_OUT      : out std_logic_vector(31 downto 0);

		DEBUG_OUT               : out std_logic_vector(63 downto 0)
	);
end trb_net16_gbe_receive_control;

architecture trb_net16_gbe_receive_control of trb_net16_gbe_receive_control is
	type load_states is (IDLE, PREPARE, WAIT_ONE, READY);
	signal load_current_state, load_next_state : load_states;

	signal frames_received_ctr : std_logic_vector(31 downto 0);
	signal frames_readout_ctr  : std_logic_vector(31 downto 0);
	signal bytes_rec_ctr       : std_logic_vector(31 downto 0);

	signal state             : std_logic_vector(3 downto 0);
	signal proto_code        : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal reset_prioritizer : std_logic;
	signal zeros             : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal saved_proto       : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);

begin
	zeros                   <= (others => '0');
	FR_RD_EN_OUT            <= RC_RD_EN_IN;
	RC_Q_OUT                <= RC_DATA_IN;
	RC_FRAME_SIZE_OUT       <= FR_FRAME_SIZE_IN;
	RC_SRC_MAC_ADDRESS_OUT  <= FR_SRC_MAC_ADDRESS_IN;
	RC_DEST_MAC_ADDRESS_OUT <= FR_DEST_MAC_ADDRESS_IN;
	RC_SRC_IP_ADDRESS_OUT   <= FR_SRC_IP_ADDRESS_IN;
	RC_DEST_IP_ADDRESS_OUT  <= FR_DEST_IP_ADDRESS_IN;
	RC_SRC_UDP_PORT_OUT     <= FR_SRC_UDP_PORT_IN;
	RC_DEST_UDP_PORT_OUT    <= FR_DEST_UDP_PORT_IN;
	RC_ID_IP_OUT            <= FR_ID_IP_IN;
	RC_FO_IP_OUT            <= FR_FO_IP_IN;
	RC_CHECKSUM_OUT         <= FR_UDP_CHECKSUM_IN;
	RC_IDENT_OUT            <= FR_IDENT_IN;
	RC_FLAGS_OFFSET_OUT     <= FR_FLAGS_OFFSET_IN;

	protocol_prioritizer : entity work.trb_net16_gbe_protocol_prioritizer
		port map(
			CLK              => CLK,
			RESET            => reset_prioritizer,
			FRAME_TYPE_IN    => FR_FRAME_PROTO_IN,
			PROTOCOL_CODE_IN => FR_IP_PROTOCOL_IN,
			UDP_PROTOCOL_IN  => FR_DEST_UDP_PORT_IN,
			TCP_PROTOCOL_IN  => FR_DEST_UDP_PORT_IN,
			CODE_OUT         => proto_code
		);

	reset_prioritizer <= '1' when load_current_state = IDLE else '0';

	RC_FRAME_PROTO_OUT <= proto_code when RC_REDIRECT_TRAFFIC_IN = '0' else zeros; -- no more ones as the incorrect value, last slot for Trash

	LOAD_MACHINE_PROC : process(CLK, RESET)
	begin
		if (RESET = '1') then
			load_current_state <= IDLE;
		elsif rising_edge(CLK) then
			load_current_state <= load_next_state;
		end if;

	end process LOAD_MACHINE_PROC;

	LOAD_MACHINE : process(load_current_state, frames_readout_ctr, frames_received_ctr, RC_LOADING_DONE_IN)
	begin
		case load_current_state is
			when IDLE =>
				state <= x"1";
				if (frames_readout_ctr /= frames_received_ctr) then -- frame is still waiting in frame_receiver
					load_next_state <= PREPARE;
				else
					load_next_state <= IDLE;
				end if;

			when PREPARE =>             -- prepare frame size
				state           <= x"2";
				load_next_state <= WAIT_ONE;

			when WAIT_ONE =>
				state           <= x"4";
				load_next_state <= READY;

			when READY =>               -- wait for reading out the whole frame
				state <= x"3";
				if (RC_LOADING_DONE_IN = '1') then
					load_next_state <= IDLE;
				else
					load_next_state <= READY;
				end if;

		end case;
	end process LOAD_MACHINE;

	process(CLK)
	begin
		if rising_edge(CLK) then
			if (load_current_state = PREPARE) then
				FR_GET_FRAME_OUT <= '1';
			else
				FR_GET_FRAME_OUT <= '0';
			end if;

			if (load_current_state = READY and RC_LOADING_DONE_IN = '0') then
				RC_FRAME_WAITING_OUT <= '1';
			else
				RC_FRAME_WAITING_OUT <= '0';
			end if;
		end if;
	end process;

	FRAMES_REC_CTR_PROC : process(RESET, CLK)
	begin
		if (RESET = '1') then
			frames_received_ctr <= (others => '0');
		elsif rising_edge(CLK) then
			if (FR_FRAME_VALID_IN = '1') then
				frames_received_ctr <= frames_received_ctr + x"1";
			else
				frames_received_ctr <= frames_received_ctr;
			end if;
		end if;
	end process FRAMES_REC_CTR_PROC;

	FRAMES_READOUT_CTR_PROC : process(RESET, CLK)
	begin
		if (RESET = '1') then
			frames_readout_ctr <= (others => '0');
		elsif rising_edge(CLK) then
			if (RC_LOADING_DONE_IN = '1') then
				frames_readout_ctr <= frames_readout_ctr + x"1";
			else
				frames_readout_ctr <= frames_readout_ctr;
			end if;
		end if;
	end process FRAMES_READOUT_CTR_PROC;

	SYNC_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			FRAMES_RECEIVED_OUT                                    <= frames_received_ctr;
			--BYTES_RECEIVED_OUT               <= bytes_rec_ctr;
			BYTES_RECEIVED_OUT(15 downto 0)                        <= bytes_rec_ctr(15 downto 0);
			BYTES_RECEIVED_OUT(16 + c_MAX_PROTOCOLS - 1 downto 16) <= saved_proto;
			BYTES_RECEIVED_OUT(31 downto 16 + c_MAX_PROTOCOLS)     <= (others => '0');
		end if;
	end process SYNC_PROC;

	BYTES_REC_CTR_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (RESET = '1') then
				bytes_rec_ctr <= (others => '0');
			elsif (FR_FRAME_VALID_IN = '1') then
				bytes_rec_ctr <= bytes_rec_ctr + FR_FRAME_SIZE_IN;
			end if;
		end if;
	end process BYTES_REC_CTR_PROC;

end trb_net16_gbe_receive_control;


