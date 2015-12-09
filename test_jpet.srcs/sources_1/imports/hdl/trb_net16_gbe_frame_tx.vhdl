library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.trb_net_gbe_components.all;

entity frame_tx is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0
	);
	port(
		MAIN_CTRL_CLK          : in  std_logic; -- gk 15/10/2012
		RESET                  : in  std_logic;

		TC_MAX_FRAME_IN        : in  std_logic_vector(15 downto 0);

		-- part to connect to frame rec main controller module
		MC_TRANSMIT_CTRL_IN    : in  std_logic; -- slow control frame is waiting to be built and sent
		MC_DATA_IN             : in  std_logic_vector(8 downto 0);
		MC_RD_EN_OUT           : out std_logic;
		MC_FRAME_SIZE_IN       : in  std_logic_vector(15 downto 0);
		MC_FRAME_TYPE_IN       : in  std_logic_vector(15 downto 0);
		MC_DEST_MAC_IN         : in  std_logic_vector(47 downto 0);
		MC_DEST_IP_IN          : in  std_logic_vector(31 downto 0);
		MC_DEST_UDP_IN         : in  std_logic_vector(15 downto 0);
		MC_SRC_MAC_IN          : in  std_logic_vector(47 downto 0);
		MC_SRC_IP_IN           : in  std_logic_vector(31 downto 0);
		MC_SRC_UDP_IN          : in  std_logic_vector(15 downto 0);
		MC_IP_PROTOCOL_IN      : in  std_logic_vector(7 downto 0);
		MC_IDENT_IN            : in  std_logic_vector(15 downto 0);
		MC_CHECKSUM_IN         : in  std_logic_vector(15 downto 0);
		MC_TRANSMIT_DONE_OUT   : out std_logic;

		-- emac interface
		CLIENTEMAC0TXD         : out std_logic_vector(7 downto 0);
		CLIENTEMAC0TXDVLD      : out std_logic;
		CLIENTEMAC0TXFIRSTBYTE : out std_logic;
		CLIENTEMAC0TXUNDERRUN  : out std_logic;
		TX_CLIENT_CLK_0        : in  std_logic;
		EMAC0CLIENTTXACK       : in  std_logic;
		EMAC0CLIENTTXSTATSVLD  : in  std_logic;

		DEBUG_OUT              : out std_logic_vector(127 downto 0)
	);
end frame_tx;

architecture Behavioral of frame_tx is
	signal fc_sop, fc_eop : std_logic;

	type constructStates is (IDLE, WAIT_FOR_ACK, TRANSMIT, CLEANUP);
	signal constr_current_state, constr_next_state : constructStates;
	signal state                                   : std_logic_vector(3 downto 0);

	signal tc_wr_en                                                : std_logic;
	signal tc_data                                                 : std_logic_vector(7 downto 0);
	signal tc_ip_size                                              : std_logic_vector(15 downto 0);
	signal tc_udp_size                                             : std_logic_vector(15 downto 0);
	signal tc_flags_offset                                         : std_logic_vector(15 downto 0);
	signal tc_sod                                                  : std_logic;
	signal tc_eod                                                  : std_logic;
	signal tc_h_ready                                              : std_logic;
	signal tc_ready                                                : std_logic;
	signal tc_frame_type                                           : std_logic_vector(15 downto 0);
	signal fifo_rd_en, fc_eop_q, first_byte, tx_done, tx_done_flag : std_logic;

	signal dest_mac                : std_logic_vector(47 downto 0);
	signal dest_ip                 : std_logic_vector(31 downto 0);
	signal dest_udp                : std_logic_vector(15 downto 0);
	signal src_mac                 : std_logic_vector(47 downto 0);
	signal src_ip                  : std_logic_vector(31 downto 0);
	signal src_udp                 : std_logic_vector(15 downto 0);
	signal tc_proto                : std_logic_vector(7 downto 0);
	signal tc_ident_c, tc_checksum : std_logic_vector(15 downto 0);

begin
	TRANSMIT_CONTROLLER : entity work.trb_net16_gbe_transmit_control2
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			CLK                      => MAIN_CTRL_CLK,
			RESET                    => RESET,

			-- signal to/from main controller
			TC_DATAREADY_IN          => MC_TRANSMIT_CTRL_IN,
			TC_RD_EN_OUT             => MC_RD_EN_OUT,
			TC_DATA_IN               => MC_DATA_IN(7 downto 0),
			TC_FRAME_SIZE_IN         => MC_FRAME_SIZE_IN,
			TC_FRAME_TYPE_IN         => MC_FRAME_TYPE_IN,
			TC_IP_PROTOCOL_IN        => MC_IP_PROTOCOL_IN,
			TC_DEST_MAC_IN           => MC_DEST_MAC_IN,
			TC_DEST_IP_IN            => MC_DEST_IP_IN,
			TC_DEST_UDP_IN           => MC_DEST_UDP_IN,
			TC_SRC_MAC_IN            => MC_SRC_MAC_IN,
			TC_SRC_IP_IN             => MC_SRC_IP_IN,
			TC_SRC_UDP_IN            => MC_SRC_UDP_IN,
			TC_TRANSMISSION_DONE_OUT => MC_TRANSMIT_DONE_OUT,
			TC_IDENT_IN              => MC_IDENT_IN,
			TC_CHECKSUM_IN           => MC_CHECKSUM_IN,
			TC_MAX_FRAME_IN          => TC_MAX_FRAME_IN,

			-- signal to/from frame constructor
			FC_DATA_OUT              => tc_data,
			FC_WR_EN_OUT             => tc_wr_en,
			FC_READY_IN              => tc_ready,
			FC_H_READY_IN            => tc_h_ready,
			FC_FRAME_TYPE_OUT        => tc_frame_type,
			FC_IP_SIZE_OUT           => tc_ip_size,
			FC_UDP_SIZE_OUT          => tc_udp_size,
			FC_IDENT_OUT             => tc_ident_c,
			FC_CHECKSUM_OUT          => tc_checksum,
			FC_FLAGS_OFFSET_OUT      => tc_flags_offset,
			FC_SOD_OUT               => tc_sod,
			FC_EOD_OUT               => tc_eod,
			FC_IP_PROTOCOL_OUT       => tc_proto,
			DEST_MAC_ADDRESS_OUT     => dest_mac,
			DEST_IP_ADDRESS_OUT      => dest_ip,
			DEST_UDP_PORT_OUT        => dest_udp,
			SRC_MAC_ADDRESS_OUT      => src_mac,
			SRC_IP_ADDRESS_OUT       => src_ip,
			SRC_UDP_PORT_OUT         => src_udp,

			-- debug
			DEBUG_OUT                => open
		);

	DEBUG_OUT(3 downto 0) <= state;

	CLIENTEMAC0TXDVLD <= '1' when (constr_current_state = WAIT_FOR_ACK) or (constr_current_state = TRANSMIT and fc_eop_q = '0')
		else '0';

	CLIENTEMAC0TXUNDERRUN <= '0';

	fifo_rd_en <= '1' when (constr_current_state = IDLE and fc_sop = '1') or (constr_current_state = WAIT_FOR_ACK and EMAC0CLIENTTXACK = '1') or (constr_current_state = TRANSMIT and fc_eop = '0')
		else '0';

	CLIENTEMAC0TXFIRSTBYTE <= first_byte;

	FIRST_BYTE_PROC : process(TX_CLIENT_CLK_0)
	begin
		if rising_edge(TX_CLIENT_CLK_0) then
			if (RESET = '1') then
				first_byte <= '0';
			elsif (constr_current_state = WAIT_FOR_ACK and EMAC0CLIENTTXACK = '1') then
				first_byte <= '1';
			else
				first_byte <= '0';
			end if;
		end if;
	end process FIRST_BYTE_PROC;

	CONSTRUCT_MACHINE_PROC : process(TX_CLIENT_CLK_0)
	begin
		if rising_edge(TX_CLIENT_CLK_0) then
			if (RESET = '1') then
				constr_current_state <= IDLE;
			else
				constr_current_state <= constr_next_state;
			end if;
		end if;
	end process CONSTRUCT_MACHINE_PROC;

	-- STATE MACHINE TO ACCESS TSMAC
	CONSTRUCT_MACHINE : process(constr_current_state, fc_sop, EMAC0CLIENTTXACK, fc_eop)
	begin
		case constr_current_state is
			when IDLE =>
				state <= x"1";
				if (fc_sop = '1') then
					constr_next_state <= WAIT_FOR_ACK;
				else
					constr_next_state <= IDLE;
				end if;

			when WAIT_FOR_ACK =>
				state <= x"3";
				if (EMAC0CLIENTTXACK = '1') then
					constr_next_state <= TRANSMIT;
				else
					constr_next_state <= WAIT_FOR_ACK;
				end if;

			when TRANSMIT =>
				state <= x"4";
				if (fc_eop = '1') then
					constr_next_state <= CLEANUP;
				else
					constr_next_state <= TRANSMIT;
				end if;

			when CLEANUP =>
				state             <= x"5";
				constr_next_state <= IDLE;

		end case;
	end process CONSTRUCT_MACHINE;

	-- ENTITY THAT TAKES PREPARED DATA AND CONSTRUCTS ETHERNET FRAMES
	FRAME_CONSTR : entity work.trb_net16_gbe_frame_constr
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			-- ports for user logic
			RESET                   => RESET,
			CLK                     => MAIN_CTRL_CLK,
			LINK_OK_IN              => '1',
			--
			WR_EN_IN                => tc_wr_en,
			DATA_IN                 => tc_data,
			START_OF_DATA_IN        => tc_sod,
			END_OF_DATA_IN          => tc_eod,
			IP_F_SIZE_IN            => tc_ip_size,
			UDP_P_SIZE_IN           => tc_udp_size,
			HEADERS_READY_OUT       => tc_h_ready,
			READY_OUT               => tc_ready,
			DEST_MAC_ADDRESS_IN     => dest_mac,
			DEST_IP_ADDRESS_IN      => dest_ip,
			DEST_UDP_PORT_IN        => dest_udp,
			SRC_MAC_ADDRESS_IN      => src_mac,
			SRC_IP_ADDRESS_IN       => src_ip,
			SRC_UDP_PORT_IN         => src_udp,
			FRAME_TYPE_IN           => tc_frame_type,
			IHL_VERSION_IN          => x"45",
			TOS_IN                  => x"10",
			IDENTIFICATION_IN       => tc_ident_c,
			CHECKSUM_IN             => tc_checksum,
			FLAGS_OFFSET_IN         => tc_flags_offset,
			TTL_IN                  => x"ff",
			PROTOCOL_IN             => tc_proto,
			FRAME_DELAY_IN          => (others => '0'),
			-- ports for packetTransmitter
			RD_CLK                  => TX_CLIENT_CLK_0,
			FT_DATA_OUT(7 downto 0) => CLIENTEMAC0TXD,
			FT_DATA_OUT(8)          => fc_eop,
			FT_TX_EMPTY_OUT         => open, --fifo_empty,
			FT_TX_RD_EN_IN          => fifo_rd_en,
			FT_START_OF_PACKET_OUT  => fc_sop,
			FT_TX_DONE_IN           => tx_done,
			FT_TX_DISCFRM_IN        => '0',
			-- debug ports
			DEBUG_OUT               => open
		);

	tx_done_sync_inst : entity work.edge_to_pulse
		generic map(SIMULATE      => SIMULATE,
			        INCLUDE_DEBUG => INCLUDE_DEBUG
		)
		port map(CLK       => TX_CLIENT_CLK_0,
			     SIGNAL_IN => EMAC0CLIENTTXSTATSVLD,
			     PULSE_OUT => tx_done,
			     DEBUG_OUT => open
		);

--	TX_DONE_PROC : process(TX_CLIENT_CLK_0)
--	begin
--		if rising_edge(TX_CLIENT_CLK_0) then
--			if (RESET = '1') then
--				tx_done      <= '0';
--				tx_done_flag <= '0';
--			elsif (EMAC0CLIENTTXSTATSVLD = '1' and tx_done_flag = '0') then
--				tx_done      <= '1';
--				tx_done_flag <= '1';
--			elsif (EMAC0CLIENTTXSTATSVLD = '0' and tx_done_flag = '1') then
--				tx_done      <= '0';
--				tx_done_flag <= '0';
--			else
--				tx_done      <= '0';
--				tx_done_flag <= tx_done_flag;
--			end if;
--		end if;
--	end process TX_DONE_PROC;

	FC_EOP_Q_PROC : process(TX_CLIENT_CLK_0)
	begin
		if rising_edge(TX_CLIENT_CLK_0) then
			fc_eop_q <= fc_eop;
		end if;
	end process FC_EOP_Q_PROC;

end Behavioral;


