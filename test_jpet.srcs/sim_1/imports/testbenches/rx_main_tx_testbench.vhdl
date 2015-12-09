library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

entity rx_main_tx_testbench is
end rx_main_tx_testbench;

architecture Behavioral of rx_main_tx_testbench is
	signal rx_clk                            : std_logic;
	signal reset                             : std_logic;
	signal client_rxd1                       : std_logic_vector(7 downto 0);
	signal client_rx_dv1, client_good_frame1 : std_logic;

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
	signal sys_clk                    : std_logic;
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
	signal tx_done                    : std_logic;
	signal rc_ident                   : std_logic_vector(15 downto 0);
	signal rc_flags_offset            : std_logic_vector(15 downto 0);

begin
	frame_rx_i : entity work.frame_rx
		generic map(
			SIMULATE              => 1,
			INCLUDE_DEBUG         => 1,
			LATTICE_ECP3          => 0,
			XILINX_SERIES7_ISE    => 1,
			XILINX_SERIES7_VIVADO => 0
		)
		port map(
			RESET                   => RESET,
			SYS_CLK                 => sys_clk,
			MY_MAC_IN               => my_mac,
			MAC_RX_CLK_IN           => rx_clk,
			MAC_RXD_IN              => client_rxd1,
			MAC_RX_DV_IN            => client_rx_dv1,
			MAC_RX_EOF_IN           => client_good_frame1,
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

	UUT : entity work.trb_net16_gbe_main_control
		generic map(
			SIMULATE              => 1,
			INCLUDE_DEBUG         => 1,
			LATTICE_ECP3          => 0,
			XILINX_SERIES7_ISE    => 1,
			XILINX_SERIES7_VIVADO => 0,
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
			CLK                    => sys_clk,
			CLK_125                => rx_clk,
			RESET                  => RESET,
			MC_RESET_LINK_IN       => RESET,
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
			DEBUG_OUT              => open
		);

	frame_tx_i : entity work.frame_tx
		generic map(
			SIMULATE              => 1,
			INCLUDE_DEBUG         => 1,
			LATTICE_ECP3          => 0,
			XILINX_SERIES7_ISE    => 1,
			XILINX_SERIES7_VIVADO => 0
		)
		port map(
			MAIN_CTRL_CLK          => sys_clk,
			RESET                  => RESET,
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
			CLIENTEMAC0TXD         => open,
			CLIENTEMAC0TXDVLD      => open,
			CLIENTEMAC0TXFIRSTBYTE => open,
			CLIENTEMAC0TXUNDERRUN  => open,
			TX_CLIENT_CLK_0        => rx_clk,
			EMAC0CLIENTTXACK       => '0',
			EMAC0CLIENTTXSTATSVLD  => tx_done,
			DEBUG_OUT              => open
		);

	process
	begin
		rx_clk <= '1';
		wait for 4 ns;
		rx_clk <= '0';
		wait for 4 ns;
	end process;

	process
	begin
		sys_clk <= '1';
		wait for 5 ns;
		sys_clk <= '0';
		wait for 5 ns;
	end process;

	testbench_process : process
	begin
		reset              <= '1';
		client_rx_dv1      <= '0';
		client_rxd1        <= x"00";
		client_good_frame1 <= '0';
		tx_done            <= '0';
		wait for 100 ns;
		reset <= '0';
		wait for 100 ns;

		wait for 1 us;

--		wait until rising_edge(rx_clk);
--		client_rx_dv1 <= '1';
--		-- dest mac
--		client_rxd1   <= x"ff";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"ff";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"ff";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"ff";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"ff";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"ff";
--		wait until rising_edge(rx_clk);
--		-- src mac
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"aa";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"bb";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"cc";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"dd";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"ee";
--		wait until rising_edge(rx_clk);
--		-- frame type
--		client_rxd1 <= x"08";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		-- ip headers
--		client_rxd1 <= x"45";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"10";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"01";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"5a";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"49";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"ff";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"01";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"cc";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"cc";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"c0";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"a8";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"01";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"c0";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"a8";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"02";
--		-- ping headers
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"08";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"47";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"d3";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"0d";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"3c";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"01";
--		wait until rising_edge(rx_clk);
--		-- ping data
--		client_rxd1 <= x"8c";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"da";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"e7";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"4d";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"36";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"c4";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"0d";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"00";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"08";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"09";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"0a";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"0b";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"0c";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"0d";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"0e";
--		wait until rising_edge(rx_clk);
--		client_rxd1 <= x"0f";
--		wait until rising_edge(rx_clk);
--		client_good_frame1 <= '1';
--		client_rxd1        <= x"aa";
--
--		wait until rising_edge(rx_clk);
--		client_rx_dv1      <= '0';
--		client_good_frame1 <= '0';
--
--		wait until rising_edge(rx_clk);
--		wait until rising_edge(rx_clk);
--		wait until rising_edge(rx_clk);
--		wait until rising_edge(rx_clk);
--		wait until rising_edge(rx_clk);
--		tx_done <= '1';
--		wait until rising_edge(rx_clk);
--		tx_done <= '0';

				wait until rising_edge(rx_clk);
				client_rx_dv1 <= '1';
				-- dest mac
				client_rxd1   <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				-- src mac
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"aa";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"bb";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cc";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"dd";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ee";
				wait until rising_edge(rx_clk);
				-- frame type
				client_rxd1 <= x"08";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				-- ip headers
				client_rxd1 <= x"45";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"10";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"01";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"5a";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"01";           -- id
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"03";           -- id
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"20";           -- f/o (more fragments)
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";           -- f/o
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";           -- ttl
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"11";           -- udp
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cc";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cc";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"c0";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"a8";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"01";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"c0";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"a8";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"02";
				-- udp headers
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"61";           -- src port H
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"a8";           -- src port L
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"27";           -- dest port H
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"10";           -- dest port L
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"02";           -- length
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"2c";           -- length
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"aa";           -- checksum
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"bb";           -- checksum
				-- payload
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ab";
		
				for i in 1 to 100 loop
					wait until rising_edge(rx_clk);
					client_rxd1 <= std_logic_vector(to_unsigned(i, 8));
				end loop;
		
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cd";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ef";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"aa";
				wait until rising_edge(rx_clk);
				client_good_frame1 <= '1';
		
				wait until rising_edge(rx_clk);
				client_rx_dv1      <= '0';
				client_good_frame1 <= '0';
				
				wait for 1 us;
				
								wait until rising_edge(rx_clk);
				client_rx_dv1 <= '1';
				-- dest mac
				client_rxd1   <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				-- src mac
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"aa";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"bb";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cc";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"dd";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ee";
				wait until rising_edge(rx_clk);
				-- frame type
				client_rxd1 <= x"08";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				-- ip headers
				client_rxd1 <= x"45";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"10";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"01";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"5a";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"01";           -- id
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"03";           -- id
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";           -- f/o (no more fragments)
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"0d";           -- f/o (offset 0xd = 13 * 8 = 104bytes)
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";           -- ttl
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"11";           -- udp
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cc";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cc";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"c0";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"a8";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"01";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"c0";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"a8";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"02";
-- second udp frame is without headers 
--				-- udp headers
--				wait until rising_edge(rx_clk);
--				client_rxd1 <= x"61";           -- src port H
--				wait until rising_edge(rx_clk);
--				client_rxd1 <= x"a8";           -- src port L
--				wait until rising_edge(rx_clk);
--				client_rxd1 <= x"61";           -- dest port H
--				wait until rising_edge(rx_clk);
--				client_rxd1 <= x"a8";           -- dest port L
--				wait until rising_edge(rx_clk);
--				client_rxd1 <= x"02";           -- length
--				wait until rising_edge(rx_clk);
--				client_rxd1 <= x"2c";           -- length
--				wait until rising_edge(rx_clk);
--				client_rxd1 <= x"aa";           -- checksum
--				wait until rising_edge(rx_clk);
--				client_rxd1 <= x"bb";           -- checksum
				-- payload
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ab";
		
				for i in 1 to 100 loop
					wait until rising_edge(rx_clk);
					client_rxd1 <= std_logic_vector(to_unsigned(i, 8));
				end loop;
		
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cd";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ef";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"aa";
				wait until rising_edge(rx_clk);
				client_good_frame1 <= '1';
		
				wait until rising_edge(rx_clk);
				client_rx_dv1      <= '0';
				client_good_frame1 <= '0';
				
				
				wait for 1 us;
				
								wait until rising_edge(rx_clk);
				client_rx_dv1 <= '1';
				-- dest mac
				client_rxd1   <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";
				wait until rising_edge(rx_clk);
				-- src mac
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"aa";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"bb";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cc";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"dd";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ee";
				wait until rising_edge(rx_clk);
				-- frame type
				client_rxd1 <= x"08";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				-- ip headers
				client_rxd1 <= x"45";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"10";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"01";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"5a";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"01";           -- id
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"04";           -- id
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";           -- f/o (more fragments)
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";           -- f/o
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ff";           -- ttl
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"11";           -- udp
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cc";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cc";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"c0";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"a8";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"01";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"c0";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"a8";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"00";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"02";
				-- udp headers
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"61";           -- src port H
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"a8";           -- src port L
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"27";           -- dest port H
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"10";           -- dest port L
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"02";           -- length
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"2c";           -- length
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"aa";           -- checksum
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"bb";           -- checksum
				-- payload
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ab";
		
				for i in 1 to 100 loop
					wait until rising_edge(rx_clk);
					client_rxd1 <= std_logic_vector(to_unsigned(i, 8));
				end loop;
		
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"cd";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"ef";
				wait until rising_edge(rx_clk);
				client_rxd1 <= x"aa";
				wait until rising_edge(rx_clk);
				client_good_frame1 <= '1';
		
				wait until rising_edge(rx_clk);
				client_rx_dv1      <= '0';
				client_good_frame1 <= '0';

		wait;

	end process testbench_process;

end Behavioral;


