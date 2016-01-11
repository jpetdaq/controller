LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

--********
-- multiplexes between different protocols and manages the responses
-- 
-- 


entity trb_net16_gbe_protocol_selector is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0;

		RX_PATH_ENABLE        : integer range 0 to 1 := 1;

		INCLUDE_READOUT       : std_logic            := '0';
		INCLUDE_SLOWCTRL      : std_logic            := '0';
		INCLUDE_DHCP          : std_logic            := '0';
		INCLUDE_ARP           : std_logic            := '0';
		INCLUDE_PING          : std_logic            := '0';
		INCLUDE_FULL_RECEIVER : std_logic            := '0';

		READOUT_BUFFER_SIZE   : integer range 1 to 4;
		SLOWCTRL_BUFFER_SIZE  : integer range 1 to 4
	);
	port(
		CLK                           : in  std_logic; -- system clock
		RESET                         : in  std_logic;
		RESET_FOR_DHCP                : in  std_logic;

		-- signals to/from main controller
		PS_DATA_IN                    : in  std_logic_vector(8 downto 0);
		PS_WR_EN_IN                   : in  std_logic;
		PS_PROTO_SELECT_IN            : in  std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
		PS_BUSY_OUT                   : out std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
		PS_FRAME_SIZE_IN              : in  std_logic_vector(15 downto 0);
		PS_RESPONSE_READY_OUT         : out std_logic;

		PS_SRC_MAC_ADDRESS_IN         : in  std_logic_vector(47 downto 0);
		PS_DEST_MAC_ADDRESS_IN        : in  std_logic_vector(47 downto 0);
		PS_SRC_IP_ADDRESS_IN          : in  std_logic_vector(31 downto 0);
		PS_DEST_IP_ADDRESS_IN         : in  std_logic_vector(31 downto 0);
		PS_SRC_UDP_PORT_IN            : in  std_logic_vector(15 downto 0);
		PS_DEST_UDP_PORT_IN           : in  std_logic_vector(15 downto 0);

		PS_ID_IP_IN                   : in  std_logic_vector(15 downto 0);
		PS_FO_IP_IN                   : in  std_logic_vector(15 downto 0);
		PS_CHECKSUM_IN                : in  std_logic_vector(15 downto 0);
		
		PS_IDENT_IN                   : in  std_logic_vector(15 downto 0);
		PS_FLAGS_OFFSET_IN            : in  std_logic_vector(15 downto 0);

		-- singals to/from transmit controller with constructed response
		TC_DATA_OUT                   : out std_logic_vector(8 downto 0);
		TC_RD_EN_IN                   : in  std_logic;
		TC_FRAME_SIZE_OUT             : out std_logic_vector(15 downto 0);
		TC_FRAME_TYPE_OUT             : out std_logic_vector(15 downto 0);
		TC_IP_PROTOCOL_OUT            : out std_logic_vector(7 downto 0);
		TC_IDENT_OUT                  : out std_logic_vector(15 downto 0);
		TC_DEST_MAC_OUT               : out std_logic_vector(47 downto 0);
		TC_DEST_IP_OUT                : out std_logic_vector(31 downto 0);
		TC_DEST_UDP_OUT               : out std_logic_vector(15 downto 0);
		TC_SRC_MAC_OUT                : out std_logic_vector(47 downto 0);
		TC_SRC_IP_OUT                 : out std_logic_vector(31 downto 0);
		TC_SRC_UDP_OUT                : out std_logic_vector(15 downto 0);

		MC_BUSY_IN                    : in  std_logic;

		-- misc signals for response constructors
		MY_MAC_IN                     : in  std_logic_vector(47 downto 0);
		MY_IP_OUT                     : out std_logic_vector(31 downto 0);
		DHCP_START_IN                 : in  std_logic;
		DHCP_DONE_OUT                 : out std_logic;


		-- input for statistics from outside	
		DATA_HIST_OUT                 : out hist_array;
		SCTRL_HIST_OUT                : out hist_array;

        USR_DATA_OUT                  : out std_logic_vector(7 downto 0);
        USR_DATA_VALID_OUT            : out std_logic;
        USR_SOP_OUT                   : out std_logic;
        USR_EOP_OUT                   : out std_logic;
        
		DEBUG_OUT                     : out std_logic_vector(255 downto 0)
	);
end trb_net16_gbe_protocol_selector;

architecture trb_net16_gbe_protocol_selector of trb_net16_gbe_protocol_selector is
	signal rd_en       : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal resp_ready  : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal tc_wr       : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal tc_data     : std_logic_vector(c_MAX_PROTOCOLS * 9 - 1 downto 0);
	signal tc_size     : std_logic_vector(c_MAX_PROTOCOLS * 16 - 1 downto 0);
	signal tc_type     : std_logic_vector(c_MAX_PROTOCOLS * 16 - 1 downto 0);
	signal busy        : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal selected    : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal tc_mac      : std_logic_vector(c_MAX_PROTOCOLS * 48 - 1 downto 0);
	signal tc_ip       : std_logic_vector(c_MAX_PROTOCOLS * 32 - 1 downto 0);
	signal tc_udp      : std_logic_vector(c_MAX_PROTOCOLS * 16 - 1 downto 0);
	signal tc_src_mac  : std_logic_vector(c_MAX_PROTOCOLS * 48 - 1 downto 0);
	signal tc_src_ip   : std_logic_vector(c_MAX_PROTOCOLS * 32 - 1 downto 0);
	signal tc_src_udp  : std_logic_vector(c_MAX_PROTOCOLS * 16 - 1 downto 0);
	signal tc_ip_proto : std_logic_vector(c_MAX_PROTOCOLS * 8 - 1 downto 0);

	-- plus 1 is for the outside
	signal stat_data     : std_logic_vector(c_MAX_PROTOCOLS * 32 - 1 downto 0);
	signal stat_addr     : std_logic_vector(c_MAX_PROTOCOLS * 8 - 1 downto 0);
	signal stat_rdy      : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal stat_ack      : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal tc_ip_size    : std_logic_vector(c_MAX_PROTOCOLS * 16 - 1 downto 0);
	signal tc_udp_size   : std_logic_vector(c_MAX_PROTOCOLS * 16 - 1 downto 0);
	signal tc_size_left  : std_logic_vector(c_MAX_PROTOCOLS * 16 - 1 downto 0);
	signal tc_flags_size : std_logic_vector(c_MAX_PROTOCOLS * 16 - 1 downto 0);

	signal tc_data_not_valid : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);

	type select_states is (IDLE, LOOP_OVER, SELECT_ONE, PROCESS_REQUEST, CLEANUP);
	signal select_current_state, select_next_state : select_states;

	signal state : std_logic_vector(3 downto 0);
	signal index : integer range 0 to c_MAX_PROTOCOLS - 1;

	signal mult : std_logic;

	signal tc_ident : std_logic_vector(c_MAX_PROTOCOLS * 16 - 1 downto 0);
	signal zeros    : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);

	signal my_ip : std_logic_vector(31 downto 0);
    
    signal full_reciever_data_out : std_logic_vector(7 downto 0);
    signal full_reciever_data_valid_out : std_logic;
    signal full_reciever_data_sop : std_logic;
    signal full_reciever_data_eop : std_logic;
begin
	zeros <= (others => '0');

	arp_gen : if INCLUDE_ARP = '1' generate
		-- protocol Nr. 1 ARP
		ARP : entity work.trb_net16_gbe_protocol_ARP
			generic map(
				SIMULATE              => SIMULATE,
				INCLUDE_DEBUG         => INCLUDE_DEBUG,
				LATTICE_ECP3          => LATTICE_ECP3,
				XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
				XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
			)
			port map(
				CLK                    => CLK,
				RESET                  => RESET,

				-- INTERFACE
				MY_MAC_IN              => MY_MAC_IN,
				MY_IP_IN               => my_ip,
				PS_DATA_IN             => PS_DATA_IN,
				PS_WR_EN_IN            => PS_WR_EN_IN,
				PS_ACTIVATE_IN         => PS_PROTO_SELECT_IN(0),
				PS_RESPONSE_READY_OUT  => resp_ready(0),
				PS_BUSY_OUT            => busy(0),
				PS_SELECTED_IN         => selected(0),
				PS_SRC_MAC_ADDRESS_IN  => PS_SRC_MAC_ADDRESS_IN,
				PS_DEST_MAC_ADDRESS_IN => PS_DEST_MAC_ADDRESS_IN,
				PS_SRC_IP_ADDRESS_IN   => PS_SRC_IP_ADDRESS_IN,
				PS_DEST_IP_ADDRESS_IN  => PS_DEST_IP_ADDRESS_IN,
				PS_SRC_UDP_PORT_IN     => PS_SRC_UDP_PORT_IN,
				PS_DEST_UDP_PORT_IN    => PS_DEST_UDP_PORT_IN,
				TC_RD_EN_IN            => TC_RD_EN_IN,
				TC_DATA_OUT            => tc_data(1 * 9 - 1 downto 0 * 9),
				TC_FRAME_SIZE_OUT      => tc_size(1 * 16 - 1 downto 0 * 16),
				TC_FRAME_TYPE_OUT      => tc_type(1 * 16 - 1 downto 0 * 16),
				TC_IP_PROTOCOL_OUT     => tc_ip_proto(1 * 8 - 1 downto 0 * 8),
				TC_IDENT_OUT           => tc_ident(1 * 16 - 1 downto 0 * 16),
				TC_DEST_MAC_OUT        => tc_mac(1 * 48 - 1 downto 0 * 48),
				TC_DEST_IP_OUT         => tc_ip(1 * 32 - 1 downto 0 * 32),
				TC_DEST_UDP_OUT        => tc_udp(1 * 16 - 1 downto 0 * 16),
				TC_SRC_MAC_OUT         => tc_src_mac(1 * 48 - 1 downto 0 * 48),
				TC_SRC_IP_OUT          => tc_src_ip(1 * 32 - 1 downto 0 * 32),
				TC_SRC_UDP_OUT         => tc_src_udp(1 * 16 - 1 downto 0 * 16),
				RECEIVED_FRAMES_OUT    => open,
				SENT_FRAMES_OUT        => open,
				DEBUG_OUT              => open
			-- END OF INTERFACE 
			);
	end generate arp_gen;

	no_arp_gen : if INCLUDE_ARP = '0' generate
		resp_ready(0) <= '0';
		busy(0)       <= '0';
	end generate no_arp_gen;

	dhcp_gen : if INCLUDE_DHCP = '1' generate
		-- protocol No. 2 DHCP
		DHCP : entity work.trb_net16_gbe_protocol_DHCP
			generic map(
				SIMULATE              => SIMULATE,
				INCLUDE_DEBUG         => INCLUDE_DEBUG,
				LATTICE_ECP3          => LATTICE_ECP3,
				XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
				XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
			)
			port map(
				CLK                    => CLK,
				RESET                  => RESET_FOR_DHCP,

				-- INTERFACE	
				MY_MAC_IN              => MY_MAC_IN,
				MY_IP_IN               => my_ip,
				PS_DATA_IN             => PS_DATA_IN,
				PS_WR_EN_IN            => PS_WR_EN_IN,
				PS_ACTIVATE_IN         => PS_PROTO_SELECT_IN(1),
				PS_RESPONSE_READY_OUT  => resp_ready(1),
				PS_BUSY_OUT            => busy(1),
				PS_SELECTED_IN         => selected(1),
				PS_SRC_MAC_ADDRESS_IN  => PS_SRC_MAC_ADDRESS_IN,
				PS_DEST_MAC_ADDRESS_IN => PS_DEST_MAC_ADDRESS_IN,
				PS_SRC_IP_ADDRESS_IN   => PS_SRC_IP_ADDRESS_IN,
				PS_DEST_IP_ADDRESS_IN  => PS_DEST_IP_ADDRESS_IN,
				PS_SRC_UDP_PORT_IN     => PS_SRC_UDP_PORT_IN,
				PS_DEST_UDP_PORT_IN    => PS_DEST_UDP_PORT_IN,
				TC_RD_EN_IN            => TC_RD_EN_IN,
				TC_DATA_OUT            => tc_data(2 * 9 - 1 downto 1 * 9),
				TC_FRAME_SIZE_OUT      => tc_size(2 * 16 - 1 downto 1 * 16),
				TC_FRAME_TYPE_OUT      => tc_type(2 * 16 - 1 downto 1 * 16),
				TC_IP_PROTOCOL_OUT     => tc_ip_proto(2 * 8 - 1 downto 1 * 8),
				TC_IDENT_OUT           => tc_ident(2 * 16 - 1 downto 1 * 16),
				TC_DEST_MAC_OUT        => tc_mac(2 * 48 - 1 downto 1 * 48),
				TC_DEST_IP_OUT         => tc_ip(2 * 32 - 1 downto 1 * 32),
				TC_DEST_UDP_OUT        => tc_udp(2 * 16 - 1 downto 1 * 16),
				TC_SRC_MAC_OUT         => tc_src_mac(2 * 48 - 1 downto 1 * 48),
				TC_SRC_IP_OUT          => tc_src_ip(2 * 32 - 1 downto 1 * 32),
				TC_SRC_UDP_OUT         => tc_src_udp(2 * 16 - 1 downto 1 * 16),
				RECEIVED_FRAMES_OUT    => open,
				SENT_FRAMES_OUT        => open,
				-- END OF INTERFACE

				MY_IP_OUT              => my_ip,
				DHCP_START_IN          => DHCP_START_IN,
				DHCP_DONE_OUT          => DHCP_DONE_OUT,
				DEBUG_OUT              => open
			);
	end generate dhcp_gen;

	no_dhcp_gen : if INCLUDE_DHCP = '0' generate
		resp_ready(1) <= '0';
		busy(1)       <= '0';
	end generate no_dhcp_gen;

	ping_gen : if INCLUDE_PING = '1' generate
		--protocol No. 3 Ping
		Ping : entity work.trb_net16_gbe_protocol_Ping
			generic map(
				SIMULATE              => SIMULATE,
				INCLUDE_DEBUG         => INCLUDE_DEBUG,
				LATTICE_ECP3          => LATTICE_ECP3,
				XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
				XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
			)
			port map(
				CLK                    => CLK,
				RESET                  => RESET,

				---- INTERFACE
				MY_MAC_IN              => MY_MAC_IN,
				MY_IP_IN               => my_ip,
				PS_DATA_IN             => PS_DATA_IN,
				PS_WR_EN_IN            => PS_WR_EN_IN,
				PS_ACTIVATE_IN         => PS_PROTO_SELECT_IN(2),
				PS_RESPONSE_READY_OUT  => resp_ready(2),
				PS_BUSY_OUT            => busy(2),
				PS_SELECTED_IN         => selected(2),
				PS_SRC_MAC_ADDRESS_IN  => PS_SRC_MAC_ADDRESS_IN,
				PS_DEST_MAC_ADDRESS_IN => PS_DEST_MAC_ADDRESS_IN,
				PS_SRC_IP_ADDRESS_IN   => PS_SRC_IP_ADDRESS_IN,
				PS_DEST_IP_ADDRESS_IN  => PS_DEST_IP_ADDRESS_IN,
				PS_SRC_UDP_PORT_IN     => PS_SRC_UDP_PORT_IN,
				PS_DEST_UDP_PORT_IN    => PS_DEST_UDP_PORT_IN,
				TC_RD_EN_IN            => TC_RD_EN_IN,
				TC_DATA_OUT            => tc_data(3 * 9 - 1 downto 2 * 9),
				TC_FRAME_SIZE_OUT      => tc_size(3 * 16 - 1 downto 2 * 16),
				TC_FRAME_TYPE_OUT      => tc_type(3 * 16 - 1 downto 2 * 16),
				TC_IP_PROTOCOL_OUT     => tc_ip_proto(3 * 8 - 1 downto 2 * 8),
				TC_IDENT_OUT           => tc_ident(3 * 16 - 1 downto 2 * 16),
				TC_DEST_MAC_OUT        => tc_mac(3 * 48 - 1 downto 2 * 48),
				TC_DEST_IP_OUT         => tc_ip(3 * 32 - 1 downto 2 * 32),
				TC_DEST_UDP_OUT        => tc_udp(3 * 16 - 1 downto 2 * 16),
				TC_SRC_MAC_OUT         => tc_src_mac(3 * 48 - 1 downto 2 * 48),
				TC_SRC_IP_OUT          => tc_src_ip(3 * 32 - 1 downto 2 * 32),
				TC_SRC_UDP_OUT         => tc_src_udp(3 * 16 - 1 downto 2 * 16),
				RECEIVED_FRAMES_OUT    => open,
				SENT_FRAMES_OUT        => open,
				DEBUG_OUT              => open
			-- END OF INTERFACE
			);
	end generate ping_gen;

	no_ping_gen : if INCLUDE_PING = '0' generate
		resp_ready(2) <= '0';
		busy(2)       <= '0';
	end generate no_ping_gen;
	
	full_receiver_gen : if INCLUDE_FULL_RECEIVER = '1' generate
	 	--protocol No. 4 FullReceiver
		FullReceiver : entity work.trb_net16_gbe_protocol_full_receiver
			generic map(
				SIMULATE              => SIMULATE,
				INCLUDE_DEBUG         => INCLUDE_DEBUG,
				LATTICE_ECP3          => LATTICE_ECP3,
				XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
				XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
			)
			port map(
				CLK                    => CLK,
				RESET                  => RESET,

				---- INTERFACE
				MY_MAC_IN              => MY_MAC_IN,
				MY_IP_IN               => my_ip,
				PS_DATA_IN             => PS_DATA_IN,
				PS_WR_EN_IN            => PS_WR_EN_IN,
				PS_ACTIVATE_IN         => PS_PROTO_SELECT_IN(3),
				PS_RESPONSE_READY_OUT  => resp_ready(3),
				PS_BUSY_OUT            => busy(3),
				PS_SELECTED_IN         => selected(3),
				PS_SRC_MAC_ADDRESS_IN  => PS_SRC_MAC_ADDRESS_IN,
				PS_DEST_MAC_ADDRESS_IN => PS_DEST_MAC_ADDRESS_IN,
				PS_SRC_IP_ADDRESS_IN   => PS_SRC_IP_ADDRESS_IN,
				PS_DEST_IP_ADDRESS_IN  => PS_DEST_IP_ADDRESS_IN,
				PS_SRC_UDP_PORT_IN     => PS_SRC_UDP_PORT_IN,
				PS_DEST_UDP_PORT_IN    => PS_DEST_UDP_PORT_IN,
				TC_RD_EN_IN            => TC_RD_EN_IN,
				TC_DATA_OUT            => tc_data(4 * 9 - 1 downto 3 * 9),
				TC_FRAME_SIZE_OUT      => tc_size(4 * 16 - 1 downto 3 * 16),
				TC_FRAME_TYPE_OUT      => tc_type(4 * 16 - 1 downto 3 * 16),
				TC_IP_PROTOCOL_OUT     => tc_ip_proto(4 * 8 - 1 downto 3 * 8),
				TC_IDENT_OUT           => tc_ident(4 * 16 - 1 downto 3 * 16),
				TC_DEST_MAC_OUT        => tc_mac(4 * 48 - 1 downto 3 * 48),
				TC_DEST_IP_OUT         => tc_ip(4 * 32 - 1 downto 3 * 32),
				TC_DEST_UDP_OUT        => tc_udp(4 * 16 - 1 downto 3 * 16),
				TC_SRC_MAC_OUT         => tc_src_mac(4 * 48 - 1 downto 3 * 48),
				TC_SRC_IP_OUT          => tc_src_ip(4 * 32 - 1 downto 3 * 32),
				TC_SRC_UDP_OUT         => tc_src_udp(4 * 16 - 1 downto 3 * 16),
				RECEIVED_FRAMES_OUT    => open,
				SENT_FRAMES_OUT        => open,
			-- END OF INTERFACE
				PS_IDENT_IN            => PS_IDENT_IN,
				PS_FLAGS_OFFSET_IN     => PS_FLAGS_OFFSET_IN,
				
				-- user data interface
				USR_DATA_OUT           => full_reciever_data_out,
				USR_DATA_VALID_OUT     => full_reciever_data_valid_out,
				USR_SOP_OUT            => full_reciever_data_sop,
				USR_EOP_OUT            => full_reciever_data_eop,
			
				DEBUG_OUT              => open
			);
	end generate full_receiver_gen;
	
	USR_DATA_OUT_UPDATE : process(RESET, CLK)
	begin
	   if RESET = '1' then
           USR_DATA_OUT <= "00000000";
           USR_DATA_VALID_OUT <= '0';
           USR_SOP_OUT <= '0';
           USR_EOP_OUT <= '0';
        elsif rising_edge(CLK) then
            USR_DATA_OUT <= full_reciever_data_out;
            USR_DATA_VALID_OUT <= full_reciever_data_valid_out;
            USR_SOP_OUT <= full_reciever_data_sop;
            USR_EOP_OUT <= full_reciever_data_eop;
        end if;
    end process USR_DATA_OUT_UPDATE;
	   
	
	no_full_receiver_gen : if INCLUDE_FULL_RECEIVER = '0' generate
		resp_ready(3) <= '0';
		busy(3)       <= '0';
	end generate no_full_receiver_gen;

	--***************
	-- DO NOT TOUCH,  response selection logic

	PS_BUSY_OUT <= busy;

	SELECT_MACHINE_PROC : process(RESET, CLK)
	begin
		if RESET = '1' then
			select_current_state <= IDLE;
		elsif rising_edge(CLK) then
			select_current_state <= select_next_state;
		end if;
	end process SELECT_MACHINE_PROC;

	SELECT_MACHINE : process(select_current_state, MC_BUSY_IN, resp_ready, index, zeros, busy)
	begin
		case (select_current_state) is
			when IDLE =>
				if (MC_BUSY_IN = '0') then
					select_next_state <= LOOP_OVER;
				else
					select_next_state <= IDLE;
				end if;

			when LOOP_OVER =>
				if (resp_ready /= zeros) then
					if (resp_ready(index) = '1') then
						select_next_state <= SELECT_ONE;
					elsif (index = c_MAX_PROTOCOLS) then
						select_next_state <= CLEANUP;
					else
						select_next_state <= LOOP_OVER;
					end if;
				else
					select_next_state <= CLEANUP;
				end if;

			when SELECT_ONE =>
				if (MC_BUSY_IN = '1') then
					select_next_state <= PROCESS_REQUEST;
				else
					select_next_state <= SELECT_ONE;
				end if;

			when PROCESS_REQUEST =>
				if (busy(index) = '0') then
					select_next_state <= CLEANUP;
				else
					select_next_state <= PROCESS_REQUEST;
				end if;

			when CLEANUP =>
				select_next_state <= IDLE;

		end case;

	end process SELECT_MACHINE;

	INDEX_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (select_current_state = IDLE) then
				index <= 0;
			elsif (select_current_state = LOOP_OVER and resp_ready(index) = '0') then
				index <= index + 1;
			else
				index <= index;
			end if;
		end if;
	end process INDEX_PROC;

	SELECTOR_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (select_current_state = SELECT_ONE or select_current_state = PROCESS_REQUEST) then
				TC_DATA_OUT        <= tc_data((index + 1) * 9 - 1 downto index * 9);
				TC_FRAME_SIZE_OUT  <= tc_size((index + 1) * 16 - 1 downto index * 16);
				TC_FRAME_TYPE_OUT  <= tc_type((index + 1) * 16 - 1 downto index * 16);
				TC_DEST_MAC_OUT    <= tc_mac((index + 1) * 48 - 1 downto index * 48);
				TC_DEST_IP_OUT     <= tc_ip((index + 1) * 32 - 1 downto index * 32);
				TC_DEST_UDP_OUT    <= tc_udp((index + 1) * 16 - 1 downto index * 16);
				TC_SRC_MAC_OUT     <= tc_src_mac((index + 1) * 48 - 1 downto index * 48);
				TC_SRC_IP_OUT      <= tc_src_ip((index + 1) * 32 - 1 downto index * 32);
				TC_SRC_UDP_OUT     <= tc_src_udp((index + 1) * 16 - 1 downto index * 16);
				TC_IP_PROTOCOL_OUT <= tc_ip_proto((index + 1) * 8 - 1 downto index * 8);
				TC_IDENT_OUT       <= tc_ident((index + 1) * 16 - 1 downto index * 16);
				if (select_current_state = SELECT_ONE) then
					PS_RESPONSE_READY_OUT <= '1';
					selected(index)       <= '0';
				else
					PS_RESPONSE_READY_OUT <= '0';
					selected(index)       <= '1';
				end if;
			else
				TC_DATA_OUT           <= (others => '0');
				TC_FRAME_SIZE_OUT     <= (others => '0');
				TC_FRAME_TYPE_OUT     <= (others => '0');
				TC_DEST_MAC_OUT       <= (others => '0');
				TC_DEST_IP_OUT        <= (others => '0');
				TC_DEST_UDP_OUT       <= (others => '0');
				TC_SRC_MAC_OUT        <= (others => '0');
				TC_SRC_IP_OUT         <= (others => '0');
				TC_SRC_UDP_OUT        <= (others => '0');
				TC_IP_PROTOCOL_OUT    <= (others => '0');
				TC_IDENT_OUT          <= (others => '0');
				PS_RESPONSE_READY_OUT <= '0';
				selected              <= (others => '0');
			end if;
		end if;
	end process SELECTOR_PROC;
end trb_net16_gbe_protocol_selector;