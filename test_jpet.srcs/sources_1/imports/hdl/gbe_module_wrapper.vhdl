library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

entity gbe_module_wrapper is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0
	);
	port(
		SYS_CLK         : in  std_logic;
		RESET_IN        : in  std_logic;
		GBE_RX_CLK      : in  std_logic;
		GBE_TX_CLK      : in  std_logic;

		RX_DATA_IN      : in  std_logic_vector(7 downto 0);
		RX_DATA_DV_IN   : in  std_logic;
		RX_DATA_GF_IN   : in  std_logic;
		RX_DATA_BF_IN   : in  std_logic;

		TX_DATA_OUT     : out std_logic_vector(7 downto 0);
		TX_DATA_DV_OUT  : out std_logic;
		TX_DATA_FB_OUT  : out std_logic;
		TX_DATA_ACK_IN  : in  std_logic;
		TX_DATA_DONE_IN : in  std_logic;

        USR_DATA_OUT                  : out std_logic_vector(7 downto 0);
        USR_DATA_VALID_OUT            : out std_logic;
        USR_SOP_OUT                   : out std_logic;
        USR_EOP_OUT                   : out std_logic;
                
		DEBUG_OUT       : out std_logic_vector(255 downto 0)
	);
end gbe_module_wrapper;

architecture Behavioral of gbe_module_wrapper is
	signal rc_src_mac                 : std_logic_vector(47 downto 0);
	signal rc_dest_mac                : std_logic_vector(47 downto 0);
	signal rc_src_ip                  : std_logic_vector(31 downto 0);
	signal rc_dest_ip                 : std_logic_vector(31 downto 0);
	signal rc_src_udp                 : std_logic_vector(15 downto 0);
	signal rc_dest_udp                : std_logic_vector(15 downto 0);
	signal rc_id_ip                   : std_logic_vector(15 downto 0);
	signal rc_fo_ip                   : std_logic_vector(15 downto 0);
	signal rc_rd_en                   : std_logic;
	signal rc_q                       : std_logic_vector(8 downto 0);
	signal rc_loading_done            : std_logic;
	signal rc_frame_proto             : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal rc_frame_ready             : std_logic;
	signal rc_frame_size, rc_checksum : std_logic_vector(15 downto 0);
	signal my_mac                     : std_logic_vector(47 downto 0);
	signal tc_transmit_ctrl           : std_logic;
	signal tc_data                    : std_logic_vector(8 downto 0);
	signal tc_ip_proto                : std_logic_vector(7 downto 0);
	signal tc_rd_en                   : std_logic;
	signal tc_src_ip                  : std_logic_vector(31 downto 0);
	signal tc_frame_size              : std_logic_vector(15 downto 0);
	signal tc_frame_type              : std_logic_vector(15 downto 0);
	signal tc_dest_mac                : std_logic_vector(47 downto 0);
	signal tc_dest_ip                 : std_logic_vector(31 downto 0);
	signal tc_dest_udp                : std_logic_vector(15 downto 0);
	signal tc_src_mac                 : std_logic_vector(47 downto 0);
	signal tc_src_udp                 : std_logic_vector(15 downto 0);
	signal tc_ident                   : std_logic_vector(15 downto 0);
	signal tc_checksum                : std_logic_vector(15 downto 0);
	signal tc_transmit_done           : std_logic;
	signal rc_ident                   : std_logic_vector(15 downto 0);
	signal rc_flags_offset            : std_logic_vector(15 downto 0);

begin
	frame_rx_i : entity work.frame_rx
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			RESET                   => RESET_IN,
			SYS_CLK                 => SYS_CLK,
			MY_MAC_IN               => my_mac,
			MAC_RX_CLK_IN           => GBE_RX_CLK,
			MAC_RXD_IN              => RX_DATA_IN,
			MAC_RX_DV_IN            => RX_DATA_DV_IN,
			MAC_RX_EOF_IN           => RX_DATA_GF_IN,
			RC_RD_EN_IN             => rc_rd_en,
			RC_Q_OUT                => rc_q,
			RC_FRAME_WAITING_OUT    => rc_frame_ready,
			RC_LOADING_DONE_IN      => rc_loading_done,
			RC_FRAME_SIZE_OUT       => rc_frame_size,
			RC_FRAME_PROTO_OUT      => rc_frame_proto,
			RC_SRC_MAC_ADDRESS_OUT  => rc_src_mac,
			RC_DEST_MAC_ADDRESS_OUT => rc_dest_mac,
			RC_SRC_IP_ADDRESS_OUT   => rc_src_ip,
			RC_DEST_IP_ADDRESS_OUT  => rc_dest_ip,
			RC_SRC_UDP_PORT_OUT     => rc_src_udp,
			RC_DEST_UDP_PORT_OUT    => rc_dest_udp,
			RC_ID_IP_OUT            => rc_id_ip,
			RC_FO_IP_OUT            => rc_fo_ip,
			RC_REDIRECT_TRAFFIC_IN  => '0',
			RC_CHECKSUM_OUT         => rc_checksum,
			RC_IDENT_OUT            => rc_ident,
			RC_FLAGS_OFFSET_OUT     => rc_flags_offset,
			
			DEBUG_OUT               => open
		);

	main_control : entity work.trb_net16_gbe_main_control
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO,
			RX_PATH_ENABLE        => 1,
			INCLUDE_READOUT       => '0',
			INCLUDE_SLOWCTRL      => '0',
			INCLUDE_DHCP          => '1',
			INCLUDE_ARP           => '1',
			INCLUDE_PING          => '1',
			INCLUDE_FULL_RECEIVER => '1',
			READOUT_BUFFER_SIZE   => 1,
			SLOWCTRL_BUFFER_SIZE  => 1
		)
		port map(
			CLK                    => SYS_CLK,
			CLK_125                => GBE_RX_CLK,
			RESET                  => RESET_IN,
			MC_RESET_LINK_IN       => RESET_IN,
			RC_FRAME_WAITING_IN    => rc_frame_ready,
			RC_LOADING_DONE_OUT    => rc_loading_done,
			RC_DATA_IN             => rc_q,
			RC_RD_EN_OUT           => rc_rd_en,
			RC_FRAME_SIZE_IN       => rc_frame_size,
			RC_FRAME_PROTO_IN      => rc_frame_proto,
			RC_SRC_MAC_ADDRESS_IN  => rc_src_mac,
			RC_DEST_MAC_ADDRESS_IN => rc_dest_mac,
			RC_SRC_IP_ADDRESS_IN   => rc_src_ip,
			RC_DEST_IP_ADDRESS_IN  => rc_dest_ip,
			RC_SRC_UDP_PORT_IN     => rc_src_udp,
			RC_DEST_UDP_PORT_IN    => rc_dest_udp,
			RC_ID_IP_IN            => rc_id_ip,
			RC_FO_IP_IN            => rc_fo_ip,
			RC_CHECKSUM_IN         => rc_checksum,
			RC_IDENT_IN            => rc_ident,
			RC_FLAGS_OFFSET_IN     => rc_flags_offset,
			TC_TRANSMIT_CTRL_OUT   => tc_transmit_ctrl,
			TC_DATA_OUT            => tc_data,
			TC_RD_EN_IN            => tc_rd_en,
			TC_FRAME_SIZE_OUT      => tc_frame_size,
			TC_FRAME_TYPE_OUT      => tc_frame_type,
			TC_DEST_MAC_OUT        => tc_dest_mac,
			TC_DEST_IP_OUT         => tc_dest_ip,
			TC_DEST_UDP_OUT        => tc_dest_udp,
			TC_SRC_MAC_OUT         => tc_src_mac,
			TC_SRC_IP_OUT          => tc_src_ip,
			TC_SRC_UDP_OUT         => tc_src_udp,
			TC_IP_PROTOCOL_OUT     => tc_ip_proto,
			TC_IDENT_OUT           => tc_ident,
			TC_CHECKSUM_OUT        => tc_checksum,
			TC_TRANSMIT_DONE_IN    => tc_transmit_done,
			PCS_AN_COMPLETE_IN     => '1',
			MC_MY_MAC_IN           => x"1111efbe0000",
			MC_MY_MAC_OUT          => my_mac,
			MAC_READY_CONF_IN      => '1',
			MC_UNIQUE_ID_IN        => (others => '1'),
			
            USR_DATA_OUT           => USR_DATA_OUT,
            USR_DATA_VALID_OUT     => USR_DATA_VALID_OUT,
            USR_SOP_OUT            => USR_SOP_OUT,
            USR_EOP_OUT            => USR_EOP_OUT,
			
			DEBUG_OUT              => open
		);

	frame_tx_i : entity work.frame_tx
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			MAIN_CTRL_CLK          => SYS_CLK,
			RESET                  => RESET_IN,
			TC_MAX_FRAME_IN        => x"0578",
			MC_TRANSMIT_CTRL_IN    => tc_transmit_ctrl,
			MC_DATA_IN             => tc_data,
			MC_RD_EN_OUT           => tc_rd_en,
			MC_FRAME_SIZE_IN       => tc_frame_size,
			MC_FRAME_TYPE_IN       => tc_frame_type,
			MC_DEST_MAC_IN         => tc_dest_mac,
			MC_DEST_IP_IN          => tc_dest_ip,
			MC_DEST_UDP_IN         => tc_dest_udp,
			MC_SRC_MAC_IN          => tc_src_mac,
			MC_SRC_IP_IN           => tc_src_ip,
			MC_SRC_UDP_IN          => tc_src_udp,
			MC_IP_PROTOCOL_IN      => tc_ip_proto,
			MC_IDENT_IN            => tc_ident,
			MC_CHECKSUM_IN         => tc_checksum,
			MC_TRANSMIT_DONE_OUT   => tc_transmit_done,
			CLIENTEMAC0TXD         => TX_DATA_OUT,
			CLIENTEMAC0TXDVLD      => TX_DATA_DV_OUT,
			CLIENTEMAC0TXFIRSTBYTE => TX_DATA_FB_OUT,
			CLIENTEMAC0TXUNDERRUN  => open,
			TX_CLIENT_CLK_0        => GBE_TX_CLK,
			EMAC0CLIENTTXACK       => TX_DATA_ACK_IN,
			EMAC0CLIENTTXSTATSVLD  => TX_DATA_DONE_IN,
			DEBUG_OUT              => open
		);

end Behavioral;