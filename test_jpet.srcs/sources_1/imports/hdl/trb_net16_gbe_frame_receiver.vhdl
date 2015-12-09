LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

--********
-- here all frame checking has to be done, if the frame fits into protocol standards
-- if so FR_FRAME_VALID_OUT is asserted after having received all bytes of a frame
-- otherwise, after receiving all bytes, FR_FRAME_VALID_OUT keeps low and the fifo is cleared
-- also a part of addresses assignemt has to be done here

--TODO: register the output ports signals

entity trb_net16_gbe_frame_receiver is
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
		LINK_OK_IN              : in  std_logic;
		ALLOW_RX_IN             : in  std_logic;
		RX_MAC_CLK              : in  std_logic; -- receiver serdes clock
		MY_MAC_IN               : in  std_logic_vector(47 downto 0);

		-- input signals from TS_MAC
		MAC_RX_EOF_IN           : in  std_logic;
		MAC_RX_ER_IN            : in  std_logic;
		MAC_RXD_IN              : in  std_logic_vector(7 downto 0);
		MAC_RX_EN_IN            : in  std_logic;
		MAC_RX_FIFO_ERR_IN      : in  std_logic;
		MAC_RX_FIFO_FULL_OUT    : out std_logic;
		MAC_RX_STAT_EN_IN       : in  std_logic;
		MAC_RX_STAT_VEC_IN      : in  std_logic_vector(31 downto 0);

		-- output signal to control logic
		FR_Q_OUT                : out std_logic_vector(8 downto 0);
		FR_RD_EN_IN             : in  std_logic;
		FR_FRAME_VALID_OUT      : out std_logic;
		FR_GET_FRAME_IN         : in  std_logic;
		FR_FRAME_SIZE_OUT       : out std_logic_vector(15 downto 0);
		FR_FRAME_PROTO_OUT      : out std_logic_vector(15 downto 0);
		FR_IP_PROTOCOL_OUT      : out std_logic_vector(7 downto 0);
		FR_ALLOWED_TYPES_IN     : in  std_logic_vector(31 downto 0);
		FR_ALLOWED_IP_IN        : in  std_logic_vector(31 downto 0);
		FR_ALLOWED_UDP_IN       : in  std_logic_vector(31 downto 0);
		FR_VLAN_ID_IN           : in  std_logic_vector(31 downto 0);
		FR_IDENT_OUT            : out std_logic_vector(15 downto 0);
		FR_FLAGS_OFFSET_OUT     : out std_logic_vector(15 downto 0);

		FR_SRC_MAC_ADDRESS_OUT  : out std_logic_vector(47 downto 0);
		FR_DEST_MAC_ADDRESS_OUT : out std_logic_vector(47 downto 0);
		FR_SRC_IP_ADDRESS_OUT   : out std_logic_vector(31 downto 0);
		FR_DEST_IP_ADDRESS_OUT  : out std_logic_vector(31 downto 0);
		FR_SRC_UDP_PORT_OUT     : out std_logic_vector(15 downto 0);
		FR_DEST_UDP_PORT_OUT    : out std_logic_vector(15 downto 0);
		FR_UDP_CHECKSUM_OUT     : out std_logic_vector(15 downto 0);

		DEBUG_OUT               : out std_logic_vector(255 downto 0)
	);
end trb_net16_gbe_frame_receiver;

architecture trb_net16_gbe_frame_receiver of trb_net16_gbe_frame_receiver is
	type filter_states is (IDLE, REMOVE_DEST, REMOVE_SRC, REMOVE_TYPE, SAVE_FRAME, DROP_FRAME, REMOVE_VID, REMOVE_VTYPE, REMOVE_IP, REMOVE_UDP, DECIDE, CLEANUP);
	signal filter_current_state, filter_next_state : filter_states;

	signal fifo_wr_en            : std_logic;
	signal rx_bytes_ctr          : std_logic_vector(15 downto 0);
	signal frame_valid_q         : std_logic;
	signal delayed_frame_valid   : std_logic;
	signal delayed_frame_valid_q : std_logic;

	signal rec_fifo_empty   : std_logic;
	signal rec_fifo_full    : std_logic;
	signal sizes_fifo_full  : std_logic;
	signal sizes_fifo_empty : std_logic;

	signal remove_ctr       : std_logic_vector(7 downto 0);
	signal new_frame        : std_logic;
	signal new_frame_lock   : std_logic                     := '0';
	signal saved_frame_type : std_logic_vector(15 downto 0);
	signal saved_vid        : std_logic_vector(15 downto 0) := (others => '0');
	signal saved_src_mac    : std_logic_vector(47 downto 0);
	signal saved_dest_mac   : std_logic_vector(47 downto 0);
	signal frame_type_valid : std_logic;
	signal saved_proto      : std_logic_vector(7 downto 0);
	signal saved_src_ip     : std_logic_vector(31 downto 0);
	signal saved_dest_ip    : std_logic_vector(31 downto 0);
	signal saved_src_udp    : std_logic_vector(15 downto 0);
	signal saved_dest_udp   : std_logic_vector(15 downto 0);
	signal saved_checksum   : std_logic_vector(15 downto 0);
	signal saved_ident      : std_logic_vector(15 downto 0);
	signal previous_ident   : std_logic_vector(15 downto 0) := x"0000";
	signal saved_flags_offset   : std_logic_vector(15 downto 0);
	signal previous_src_udp  : std_logic_vector(15 downto 0) := x"0000";
	signal previous_dest_udp : std_logic_vector(15 downto 0) := x"0000";

	signal error_frames_ctr : std_logic_vector(15 downto 0);

	-- debug signals
	signal state : std_logic_vector(3 downto 0);

	signal ip_d, macs_d, macd_d, ip_o, macs_o, macd_o : std_logic_vector(71 downto 0);
	signal sizes_d, sizes_o, fragm_d, fragm_o         : std_logic_vector(31 downto 0);
	signal rec_d, rec_o                               : std_logic_vector(8 downto 0);
	signal fifo_rd_en                                 : std_logic;

begin

	-- new_frame is asserted when first byte of the frame arrives
	NEW_FRAME_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (LINK_OK_IN = '0' or MAC_RX_EOF_IN = '1') then
				new_frame      <= '0';
				new_frame_lock <= '0';
			elsif (new_frame_lock = '0') and (MAC_RX_EN_IN = '1') then
				new_frame      <= '1';
				new_frame_lock <= '1';
			else
				new_frame      <= '0';
				new_frame_lock <= new_frame_lock;
			end if;
		end if;
	end process NEW_FRAME_PROC;

	FILTER_MACHINE_PROC : process(RX_MAC_CLK, RESET)
	begin
		if RESET = '1' then
			filter_current_state <= IDLE;
		elsif rising_edge(RX_MAC_CLK) then
			filter_current_state <= filter_next_state;
		end if;
	end process FILTER_MACHINE_PROC;

	FILTER_MACHINE : process(filter_current_state, saved_frame_type, saved_flags_offset, previous_ident, saved_ident, LINK_OK_IN, saved_proto, MY_MAC_IN, saved_dest_mac, remove_ctr, new_frame, MAC_RX_EOF_IN, frame_type_valid, ALLOW_RX_IN)
	begin
		case filter_current_state is
			when IDLE =>
				state <= x"1";
				if (new_frame = '1') and (ALLOW_RX_IN = '1') and (LINK_OK_IN = '1') then
					filter_next_state <= REMOVE_DEST;
				else
					filter_next_state <= IDLE;
				end if;

			-- frames arrive without preamble!
			when REMOVE_DEST =>
				state <= x"3";
				if (remove_ctr = x"03") then -- counter starts with a delay that's why only 3
					-- destination MAC address filtering here 
					if (saved_dest_mac = MY_MAC_IN) or (saved_dest_mac = x"ffffffffffff") then -- must accept broadcasts for ARP
						filter_next_state <= REMOVE_SRC;
					else
						filter_next_state <= DECIDE;
					end if;
				else
					filter_next_state <= REMOVE_DEST;
				end if;

			when REMOVE_SRC =>
				state <= x"4";
				if (remove_ctr = x"09") then
					filter_next_state <= REMOVE_TYPE;
				else
					filter_next_state <= REMOVE_SRC;
				end if;

			when REMOVE_TYPE =>
				state <= x"5";
				if (remove_ctr = x"0b") then
					if (saved_frame_type = x"8100") then -- VLAN tagged frame
						filter_next_state <= REMOVE_VID;
					else                -- no VLAN tag
						if (saved_frame_type = x"0800") then -- in case of IP continue removing headers
							filter_next_state <= REMOVE_IP;
						else
							filter_next_state <= DECIDE;
						end if;
					end if;
				else
					filter_next_state <= REMOVE_TYPE;
				end if;

			when REMOVE_VID =>
				state <= x"a";
				if (remove_ctr = x"0d") then
					filter_next_state <= REMOVE_VTYPE;
				else
					filter_next_state <= REMOVE_VID;
				end if;

			when REMOVE_VTYPE =>
				state <= x"b";
				if (remove_ctr = x"0f") then
					if (saved_frame_type = x"0800") then -- in case of IP continue removing headers
						filter_next_state <= REMOVE_IP;
					else
						filter_next_state <= DECIDE;
					end if;
				else
					filter_next_state <= REMOVE_VTYPE;
				end if;

			when REMOVE_IP =>
				state <= x"c";
				if (remove_ctr = x"11") then
					if (saved_proto = x"11" and saved_flags_offset(12 downto 0) = "0000000000000") then -- forced to recognize udp only, TODO check all protocols
						filter_next_state <= REMOVE_UDP;
					elsif (saved_proto = x"11" and saved_flags_offset(12 downto 0) /= "0000000000000") then
						filter_next_state <= DECIDE; 
					else
						filter_next_state <= DECIDE;
					end if;
				else
					filter_next_state <= REMOVE_IP;
				end if;

			when REMOVE_UDP =>
				state <= x"d";
				if (remove_ctr = x"19") then
					filter_next_state <= DECIDE;
				else
					filter_next_state <= REMOVE_UDP;
				end if;

			when DECIDE =>
				state <= x"6";
				if (frame_type_valid = '1') then
					filter_next_state <= SAVE_FRAME;
				elsif (saved_frame_type = x"0806") then
					filter_next_state <= SAVE_FRAME;
				-- case for fragmented udp packets
				elsif (saved_proto = x"11" and saved_flags_offset(12 downto 0) /= "0000000000000" and previous_ident = saved_ident) then
					filter_next_state <= SAVE_FRAME;
				else
					filter_next_state <= DROP_FRAME;
				end if;

			when SAVE_FRAME =>
				state <= x"7";
				if (MAC_RX_EOF_IN = '1') then
					filter_next_state <= CLEANUP;
				else
					filter_next_state <= SAVE_FRAME;
				end if;

			when DROP_FRAME =>
				state <= x"8";
				if (MAC_RX_EOF_IN = '1') then
					filter_next_state <= CLEANUP;
				else
					filter_next_state <= DROP_FRAME;
				end if;

			when CLEANUP =>
				state             <= x"9";
				filter_next_state <= IDLE;

		end case;
	end process;

	-- counts the bytes to be removed from the ethernet headers fields
	REMOVE_CTR_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) or (filter_current_state = REMOVE_VTYPE and remove_ctr = x"0f") or (filter_current_state = REMOVE_TYPE and remove_ctr = x"0b") then
				remove_ctr <= (others => '1');
			elsif (MAC_RX_EN_IN = '1') and (filter_current_state /= IDLE) then --and (filter_current_state /= CLEANUP) then
				remove_ctr <= remove_ctr + x"1";
			else
				remove_ctr <= remove_ctr;
			end if;
		end if;
	end process REMOVE_CTR_PROC;

	SAVED_FRAGM_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_flags_offset <= (others => '0');
				saved_ident <= (others => '0');
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"05") then
				saved_flags_offset(7 downto 0) <= MAC_RXD_IN;
				saved_ident <= saved_ident;
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"04") then
				saved_flags_offset(15 downto 8) <= MAC_RXD_IN;
				saved_ident <= saved_ident;
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"03") then
				saved_ident(7 downto 0) <= MAC_RXD_IN;
				saved_flags_offset <= saved_flags_offset;
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"02") then
				saved_ident(15 downto 8) <= MAC_RXD_IN;
				saved_flags_offset <= saved_flags_offset;	
			else
				saved_ident <= saved_ident;
				saved_flags_offset <= saved_flags_offset;
			end if;
		end if;
	end process SAVED_FRAGM_PROC;
	
	PREVIOUS_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = REMOVE_IP and remove_ctr = x"11" and saved_flags_offset(13) = '1' and saved_flags_offset(12 downto 0) = "0000000000000") then
				previous_ident <= saved_ident;
			else
				previous_ident <= previous_ident;				
			end if;
			
			if (filter_current_state = REMOVE_UDP and remove_ctr = x"19") then
				previous_src_udp <= saved_src_udp;
				previous_dest_udp <= saved_dest_udp;
			else
				previous_src_udp <= previous_src_udp;
				previous_dest_udp <= previous_dest_udp;
			end if;
		end if;
	end process PREVIOUS_PROC;

	SAVED_PROTO_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_proto <= (others => '0');
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"07") then
				saved_proto <= MAC_RXD_IN;
			else
				saved_proto <= saved_proto;
			end if;
		end if;
	end process SAVED_PROTO_PROC;

	SAVED_SRC_IP_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_src_ip <= (others => '0');
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"0a") then
				saved_src_ip(7 downto 0) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"0b") then
				saved_src_ip(15 downto 8) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"0c") then
				saved_src_ip(23 downto 16) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"0d") then
				saved_src_ip(31 downto 24) <= MAC_RXD_IN;
			else
				saved_src_ip <= saved_src_ip;
			end if;
		end if;
	end process SAVED_SRC_IP_PROC;

	SAVED_DEST_IP_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_dest_ip <= (others => '0');
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"0e") then
				saved_dest_ip(7 downto 0) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"0f") then
				saved_dest_ip(15 downto 8) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"10") then
				saved_dest_ip(23 downto 16) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_IP) and (remove_ctr = x"11") then
				saved_dest_ip(31 downto 24) <= MAC_RXD_IN;
			else
				saved_dest_ip <= saved_dest_ip;
			end if;
		end if;
	end process SAVED_DEST_IP_PROC;

	SAVED_SRC_UDP_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_src_udp <= (others => '0');
			elsif (filter_current_state = REMOVE_UDP) and (remove_ctr = x"12") then
				saved_src_udp(15 downto 8) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_UDP) and (remove_ctr = x"13") then
				saved_src_udp(7 downto 0) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_IP and remove_ctr = x"11" and saved_flags_offset(12 downto 0) /= "0000000000000" and saved_proto = x"11" and previous_ident = saved_ident) then
				saved_src_udp <= previous_src_udp;
			else
				saved_src_udp <= saved_src_udp;
			end if;
		end if;
	end process SAVED_SRC_UDP_PROC;

	SAVED_DEST_UDP_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_dest_udp <= (others => '0');
			elsif (filter_current_state = REMOVE_UDP) and (remove_ctr = x"14") then
				saved_dest_udp(15 downto 8) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_UDP) and (remove_ctr = x"15") then
				saved_dest_udp(7 downto 0) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_IP and remove_ctr = x"11" and saved_flags_offset(12 downto 0) /= "0000000000000" and saved_proto = x"11" and previous_ident = saved_ident) then
				saved_dest_udp <= previous_dest_udp;
			else
				saved_dest_udp <= saved_dest_udp;
			end if;
		end if;
	end process SAVED_DEST_UDP_PROC;

	SAVED_UDP_CHECKSUM_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_checksum <= (others => '0');
			elsif (filter_current_state = REMOVE_UDP) and (remove_ctr = x"18") then
				saved_checksum(15 downto 8) <= MAC_RXD_IN;
				saved_checksum(7 downto 0)  <= x"00";
			elsif (filter_current_state = REMOVE_UDP) and (remove_ctr = x"19") then
				saved_checksum(7 downto 0)  <= MAC_RXD_IN;
				saved_checksum(15 downto 8) <= saved_checksum(15 downto 8);
			else
				saved_checksum <= saved_checksum;
			end if;
		end if;
	end process SAVED_UDP_CHECKSUM_PROC;

	-- saves the destination mac address of the incoming frame
	SAVED_DEST_MAC_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = CLEANUP) then
				saved_dest_mac <= (others => '0');
			elsif (filter_current_state = IDLE) and (MAC_RX_EN_IN = '1') and (new_frame = '0') then
				saved_dest_mac(7 downto 0) <= MAC_RXD_IN;
			elsif (filter_current_state = IDLE) and (new_frame = '1') and (ALLOW_RX_IN = '1') then
				saved_dest_mac(15 downto 8) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_DEST) and (remove_ctr = x"FF") then
				saved_dest_mac(23 downto 16) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_DEST) and (remove_ctr = x"00") then
				saved_dest_mac(31 downto 24) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_DEST) and (remove_ctr = x"01") then
				saved_dest_mac(39 downto 32) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_DEST) and (remove_ctr = x"02") then
				saved_dest_mac(47 downto 40) <= MAC_RXD_IN;
			else
				saved_dest_mac <= saved_dest_mac;
			end if;
		end if;
	end process SAVED_DEST_MAC_PROC;

	-- saves the source mac address of the incoming frame
	SAVED_SRC_MAC_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_src_mac <= (others => '0');
			elsif (filter_current_state = REMOVE_DEST) and (remove_ctr = x"03") then
				saved_src_mac(7 downto 0) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_SRC) and (remove_ctr = x"04") then
				saved_src_mac(15 downto 8) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_SRC) and (remove_ctr = x"05") then
				saved_src_mac(23 downto 16) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_SRC) and (remove_ctr = x"06") then
				saved_src_mac(31 downto 24) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_SRC) and (remove_ctr = x"07") then
				saved_src_mac(39 downto 32) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_SRC) and (remove_ctr = x"08") then
				saved_src_mac(47 downto 40) <= MAC_RXD_IN;
			else
				saved_src_mac <= saved_src_mac;
			end if;
		end if;
	end process SAVED_SRC_MAC_PROC;

	-- saves the frame type of the incoming frame for futher check
	SAVED_FRAME_TYPE_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_frame_type <= (others => '0');
			elsif (filter_current_state = REMOVE_SRC) and (remove_ctr = x"09") then
				saved_frame_type(15 downto 8) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_TYPE) and (remove_ctr = x"0a") then
				saved_frame_type(7 downto 0) <= MAC_RXD_IN;
			-- two more cases for VLAN tagged frame
			elsif (filter_current_state = REMOVE_VID) and (remove_ctr = x"0d") then
				saved_frame_type(15 downto 8) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_VTYPE) and (remove_ctr = x"0e") then
				saved_frame_type(7 downto 0) <= MAC_RXD_IN;
			else
				saved_frame_type <= saved_frame_type;
			end if;
		end if;
	end process SAVED_FRAME_TYPE_PROC;

	-- saves VLAN id when tagged frame spotted
	SAVED_VID_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (filter_current_state = IDLE) then
				saved_vid <= (others => '0');
			elsif (filter_current_state = REMOVE_TYPE and remove_ctr = x"0b" and saved_frame_type = x"8100") then
				saved_vid(15 downto 8) <= MAC_RXD_IN;
			elsif (filter_current_state = REMOVE_VID and remove_ctr = x"0c") then
				saved_vid(7 downto 0) <= MAC_RXD_IN;
			else
				saved_vid <= saved_vid;
			end if;
		end if;
	end process SAVED_VID_PROC;

	type_validator : entity work.trb_net16_gbe_type_validator
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			CLK                      => RX_MAC_CLK,
			RESET                    => RESET,
			FRAME_TYPE_IN            => saved_frame_type,
			SAVED_VLAN_ID_IN         => saved_vid,
			ALLOWED_TYPES_IN         => FR_ALLOWED_TYPES_IN,
			VLAN_ID_IN               => FR_VLAN_ID_IN,

			-- IP level
			IP_PROTOCOLS_IN          => saved_proto,
			ALLOWED_IP_PROTOCOLS_IN  => FR_ALLOWED_IP_IN,

			-- UDP level
			UDP_PROTOCOL_IN          => saved_dest_udp,
			ALLOWED_UDP_PROTOCOLS_IN => FR_ALLOWED_UDP_IN,

			-- TCP level
			TCP_PROTOCOL_IN          => (others => '0'),
			ALLOWED_TCP_PROTOCOLS_IN => (others => '0'),
			VALID_OUT                => frame_type_valid,
			DEBUG_OUT                => open
		);

	receive_fifo : entity work.fifo_4096x9_generic_wrapper
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			WR_CLK_IN => RX_MAC_CLK,
			RD_CLK_IN => CLK,
			RESET_IN  => RESET,
			DATA_IN   => rec_d,
			WR_EN_IN  => fifo_wr_en,
			DATA_OUT  => rec_o,
			RD_EN_IN  => fifo_rd_en,
			FULL_OUT  => rec_fifo_full,
			EMPTY_OUT => rec_fifo_empty,
			DEBUG_OUT => open
		);

	RX_FIFO_SYNC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			rec_d(8)          <= MAC_RX_EOF_IN;
			rec_d(7 downto 0) <= MAC_RXD_IN;

			if (MAC_RX_EN_IN = '1') then
				if (filter_current_state = SAVE_FRAME) then
					fifo_wr_en <= '1';
				elsif (filter_current_state = REMOVE_VTYPE and remove_ctr = x"f") then
					fifo_wr_en <= '1';
				elsif (filter_current_state = DECIDE and frame_type_valid = '1') then
					fifo_wr_en <= '1';
				elsif (filter_current_state = DECIDE and saved_proto = x"11" and saved_flags_offset(12 downto 0) /= "0000000000000" and previous_ident = saved_ident) then
					fifo_wr_en <= '1';
				else
					fifo_wr_en <= '0';
				end if;
			else
				fifo_wr_en <= '0';
			end if;

			MAC_RX_FIFO_FULL_OUT <= rec_fifo_full;
		end if;
	end process RX_FIFO_SYNC;

	fifo_rd_en <= FR_RD_EN_IN;

	sizes_d(15 downto 0)  <= rx_bytes_ctr;
	sizes_d(31 downto 16) <= saved_frame_type;
	sizes_fifo : entity work.fifo_512x32_generic_wrapper
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			WR_CLK_IN => RX_MAC_CLK,
			RD_CLK_IN => CLK,
			RESET_IN  => RESET,
			DATA_IN   => sizes_d,
			WR_EN_IN  => frame_valid_q,
			DATA_OUT  => sizes_o,
			RD_EN_IN  => FR_GET_FRAME_IN,
			FULL_OUT  => sizes_fifo_full,
			EMPTY_OUT => sizes_fifo_empty,
			DEBUG_OUT => open
		);

	macs_d(47 downto 0)  <= saved_src_mac;
	macs_d(63 downto 48) <= saved_src_udp;
	macs_d(71 downto 64) <= saved_checksum(7 downto 0);
	macs_fifo : entity work.fifo_512x72_generic_wrapper
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			WR_CLK_IN => RX_MAC_CLK,
			RD_CLK_IN => CLK,
			RESET_IN  => RESET,
			DATA_IN   => macs_d,
			WR_EN_IN  => frame_valid_q,
			DATA_OUT  => macs_o,
			RD_EN_IN  => FR_GET_FRAME_IN,
			FULL_OUT  => open,
			EMPTY_OUT => open,
			DEBUG_OUT => open
		);

	macd_d(47 downto 0)  <= saved_dest_mac;
	macd_d(63 downto 48) <= saved_dest_udp;
	macd_d(71 downto 64) <= saved_checksum(15 downto 8); --(others => '0');
	macd_fifo : entity work.fifo_512x72_generic_wrapper
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			WR_CLK_IN => RX_MAC_CLK,
			RD_CLK_IN => CLK,
			RESET_IN  => RESET,
			DATA_IN   => macd_d,
			WR_EN_IN  => frame_valid_q,
			DATA_OUT  => macd_o,
			RD_EN_IN  => FR_GET_FRAME_IN,
			FULL_OUT  => open,
			EMPTY_OUT => open,
			DEBUG_OUT => open
		);

	ip_d(31 downto 0)  <= saved_src_ip;
	ip_d(63 downto 32) <= saved_dest_ip;
	ip_d(71 downto 64) <= saved_proto;
	ip_fifo : entity work.fifo_512x72_generic_wrapper
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			WR_CLK_IN => RX_MAC_CLK,
			RD_CLK_IN => CLK,
			RESET_IN  => RESET,
			DATA_IN   => ip_d,
			WR_EN_IN  => frame_valid_q,
			DATA_OUT  => ip_o,
			RD_EN_IN  => FR_GET_FRAME_IN,
			FULL_OUT  => open,
			EMPTY_OUT => open,
			DEBUG_OUT => open
		);
	
	fragm_d(15 downto 0) <= saved_flags_offset;
	fragm_d(31 downto 16) <= saved_ident;
	fragments_fifo : entity work.fifo_512x32_generic_wrapper
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			WR_CLK_IN => RX_MAC_CLK,
			RD_CLK_IN => CLK,
			RESET_IN  => RESET,
			DATA_IN   => fragm_d,
			WR_EN_IN  => frame_valid_q,
			DATA_OUT  => fragm_o,
			RD_EN_IN  => FR_GET_FRAME_IN,
			FULL_OUT  => open,
			EMPTY_OUT => open,
			DEBUG_OUT => open
		);

	process(CLK)
	begin
		if rising_edge(CLK) then
			FR_SRC_IP_ADDRESS_OUT            <= ip_o(31 downto 0);
			FR_DEST_IP_ADDRESS_OUT           <= ip_o(63 downto 32);
			FR_IP_PROTOCOL_OUT               <= ip_o(71 downto 64);
			FR_DEST_UDP_PORT_OUT             <= macd_o(63 downto 48);
			FR_DEST_MAC_ADDRESS_OUT          <= macd_o(47 downto 0);
			FR_SRC_MAC_ADDRESS_OUT           <= macs_o(47 downto 0);
			FR_SRC_UDP_PORT_OUT              <= macs_o(63 downto 48);
			FR_FRAME_PROTO_OUT               <= sizes_o(31 downto 16);
			FR_FRAME_SIZE_OUT                <= sizes_o(15 downto 0);
			FR_UDP_CHECKSUM_OUT(7 downto 0)  <= macs_o(71 downto 64);
			FR_UDP_CHECKSUM_OUT(15 downto 8) <= macd_o(71 downto 64);
			FR_IDENT_OUT                     <= fragm_o(31 downto 16);
			FR_FLAGS_OFFSET_OUT              <= fragm_o(15 downto 0);
			FR_Q_OUT                         <= rec_o;
		end if;
	end process;

	FRAME_VALID_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (MAC_RX_EOF_IN = '1' and ALLOW_RX_IN = '1' and frame_type_valid = '1') then
				frame_valid_q <= '1';
			else
				frame_valid_q <= '0';
			end if;
		end if;
	end process FRAME_VALID_PROC;

	RX_BYTES_CTR_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (RESET = '1') or (delayed_frame_valid_q = '1') then
				rx_bytes_ctr <= x"0001";
			elsif (fifo_wr_en = '1') then
				rx_bytes_ctr <= rx_bytes_ctr + x"1";
			end if;
		end if;
	end process;

	ERROR_FRAMES_CTR_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			if (RESET = '1') then
				error_frames_ctr <= (others => '0');
			elsif (MAC_RX_ER_IN = '1') then
				error_frames_ctr <= error_frames_ctr + x"1";
			end if;
		end if;
	end process ERROR_FRAMES_CTR_PROC;

	SYNC_PROC : process(RX_MAC_CLK)
	begin
		if rising_edge(RX_MAC_CLK) then
			delayed_frame_valid   <= MAC_RX_EOF_IN;
			delayed_frame_valid_q <= delayed_frame_valid;
		end if;
	end process SYNC_PROC;

	--*****************
	-- synchronization between 125MHz receive clock and 100MHz system clock
	FRAME_VALID_SYNC : entity work.pulse_sync
		port map(
			CLK_A_IN    => RX_MAC_CLK,
			RESET_A_IN  => RESET,
			PULSE_A_IN  => frame_valid_q,
			CLK_B_IN    => CLK,
			RESET_B_IN  => RESET,
			PULSE_B_OUT => FR_FRAME_VALID_OUT
		);

end trb_net16_gbe_frame_receiver;


