LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

--********
-- controls the work of the whole gbe in both directions
-- multiplexes the output between data stream and output slow control packets based on priority
-- reacts to incoming gbe slow control commands
-- 


entity trb_net16_gbe_main_control is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0;

		RX_PATH_ENABLE        : integer range 0 to 1 := 0;

		-- generics specific for protocols implementations
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
		CLK_125                       : in  std_logic;
		RESET                         : in  std_logic;

		MC_LINK_OK_OUT                : out std_logic;
		MC_RESET_LINK_IN              : in  std_logic;
		MC_IDLE_TOO_LONG_OUT          : out std_logic;
		MC_DHCP_DONE_OUT              : out std_logic;
		MC_MY_MAC_OUT                 : out std_logic_vector(47 downto 0);
		MC_MY_MAC_IN                  : in  std_logic_vector(47 downto 0);

		-- signals to/from receive controller
		RC_FRAME_WAITING_IN           : in  std_logic;
		RC_LOADING_DONE_OUT           : out std_logic;
		RC_DATA_IN                    : in  std_logic_vector(8 downto 0);
		RC_RD_EN_OUT                  : out std_logic;
		RC_FRAME_SIZE_IN              : in  std_logic_vector(15 downto 0);
		RC_FRAME_PROTO_IN             : in  std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);

		RC_SRC_MAC_ADDRESS_IN         : in  std_logic_vector(47 downto 0);
		RC_DEST_MAC_ADDRESS_IN        : in  std_logic_vector(47 downto 0);
		RC_SRC_IP_ADDRESS_IN          : in  std_logic_vector(31 downto 0);
		RC_DEST_IP_ADDRESS_IN         : in  std_logic_vector(31 downto 0);
		RC_SRC_UDP_PORT_IN            : in  std_logic_vector(15 downto 0);
		RC_DEST_UDP_PORT_IN           : in  std_logic_vector(15 downto 0);

		RC_ID_IP_IN                   : in  std_logic_vector(15 downto 0);
		RC_FO_IP_IN                   : in  std_logic_vector(15 downto 0);
		RC_CHECKSUM_IN                : in  std_logic_vector(15 downto 0);
		
		RC_IDENT_IN                   : in  std_logic_vector(15 downto 0);
		RC_FLAGS_OFFSET_IN            : in  std_logic_vector(15 downto 0);

		-- signals to/from transmit controller
		TC_TRANSMIT_CTRL_OUT          : out std_logic;
		TC_DATA_OUT                   : out std_logic_vector(8 downto 0);
		TC_RD_EN_IN                   : in  std_logic;
		TC_FRAME_SIZE_OUT             : out std_logic_vector(15 downto 0);
		TC_FRAME_TYPE_OUT             : out std_logic_vector(15 downto 0);
		TC_DEST_MAC_OUT               : out std_logic_vector(47 downto 0);
		TC_DEST_IP_OUT                : out std_logic_vector(31 downto 0);
		TC_DEST_UDP_OUT               : out std_logic_vector(15 downto 0);
		TC_SRC_MAC_OUT                : out std_logic_vector(47 downto 0);
		TC_SRC_IP_OUT                 : out std_logic_vector(31 downto 0);
		TC_SRC_UDP_OUT                : out std_logic_vector(15 downto 0);
		TC_FLAGS_OFFSET_OUT           : out std_logic_vector(15 downto 0);
		TC_IP_PROTOCOL_OUT            : out std_logic_vector(7 downto 0);
		TC_IDENT_OUT                  : out std_logic_vector(15 downto 0);
		TC_CHECKSUM_OUT               : out std_logic_vector(15 downto 0);
		TC_TRANSMIT_DONE_IN           : in  std_logic;

		-- signals to/from sgmii/gbe pcs_an_complete
		PCS_AN_COMPLETE_IN            : in  std_logic;
		MC_REDIRECT_TRAFFIC_OUT       : out std_logic;
		MC_UNIQUE_ID_IN               : in  std_logic_vector(63 downto 0);

		-- ports for specific protocols

		MAC_READY_CONF_IN             : in  std_logic;
		MAC_RECONF_OUT                : out std_logic;

		DATA_HIST_OUT                 : out hist_array;
		SCTRL_HIST_OUT                : out hist_array;
        
        USR_DATA_OUT                  : out std_logic_vector(7 downto 0);
        USR_DATA_VALID_OUT            : out std_logic;
        USR_SOP_OUT                   : out std_logic;
        USR_EOP_OUT                   : out std_logic;
        
		DEBUG_OUT                     : out std_logic_vector(255 downto 0)
	);
end trb_net16_gbe_main_control;

architecture trb_net16_gbe_main_control of trb_net16_gbe_main_control is
	signal tsm_reconf : std_logic;

	type link_states is (INACTIVE, ACTIVE, ENABLE_MAC, TIMEOUT, FINALIZE, WAIT_FOR_BOOT, GET_ADDRESS);
	signal link_current_state, link_next_state : link_states;

	signal link_ok             : std_logic;
	signal link_ok_timeout_ctr : std_logic_vector(15 downto 0);

	type flow_states is (IDLE, TRANSMIT_CTRL, WAIT_FOR_FC, CLEANUP);
	signal flow_current_state, flow_next_state : flow_states;

	signal link_state     : std_logic_vector(3 downto 0);
	signal redirect_state : std_logic_vector(3 downto 0);

	signal ps_wr_en          : std_logic;
	signal ps_response_ready : std_logic;
	signal ps_busy           : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal rc_rd_en          : std_logic;
	signal first_byte        : std_logic;
	signal first_byte_q      : std_logic;
	signal first_byte_qq     : std_logic;
	signal proto_select      : std_logic_vector(c_MAX_PROTOCOLS - 1 downto 0);
	signal loaded_bytes_ctr  : std_Logic_vector(15 downto 0);

	signal dhcp_start : std_logic;
	signal dhcp_done  : std_logic;
	signal wait_ctr   : std_logic_vector(31 downto 0) := x"0000_0000";

	signal rc_data_local : std_logic_vector(8 downto 0);

	type redirect_states is (IDLE, CHECK_TYPE, DROP, CHECK_BUSY, LOAD, BUSY, WAIT_ONE, FINISH, CLEANUP);
	signal redirect_current_state, redirect_next_state : redirect_states;

	signal disable_redirect, ps_wr_en_q, ps_wr_en_qq : std_logic;

	signal unique_id : std_logic_vector(63 downto 0);

	signal tc_data   : std_logic_vector(8 downto 0);
	signal mc_busy   : std_logic;
	signal incl_dhcp : std_logic;

begin
	unique_id <= MC_UNIQUE_ID_IN;

	protocol_selector : entity work.trb_net16_gbe_protocol_selector
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO,
			RX_PATH_ENABLE        => RX_PATH_ENABLE,
			INCLUDE_READOUT       => INCLUDE_READOUT,
			INCLUDE_SLOWCTRL      => INCLUDE_SLOWCTRL,
			INCLUDE_DHCP          => INCLUDE_DHCP,
			INCLUDE_ARP           => INCLUDE_ARP,
			INCLUDE_PING          => INCLUDE_PING,
			INCLUDE_FULL_RECEIVER => INCLUDE_FULL_RECEIVER,
			READOUT_BUFFER_SIZE   => READOUT_BUFFER_SIZE,
			SLOWCTRL_BUFFER_SIZE  => SLOWCTRL_BUFFER_SIZE
		)
		port map(
			CLK                    => CLK,
			RESET                  => RESET,
			RESET_FOR_DHCP         => MC_RESET_LINK_IN,
			PS_DATA_IN             => rc_data_local,
			PS_WR_EN_IN            => ps_wr_en_qq,
			PS_PROTO_SELECT_IN     => proto_select,
			PS_BUSY_OUT            => ps_busy,
			PS_FRAME_SIZE_IN       => RC_FRAME_SIZE_IN,
			PS_RESPONSE_READY_OUT  => ps_response_ready,
			PS_SRC_MAC_ADDRESS_IN  => RC_SRC_MAC_ADDRESS_IN,
			PS_DEST_MAC_ADDRESS_IN => RC_DEST_MAC_ADDRESS_IN,
			PS_SRC_IP_ADDRESS_IN   => RC_SRC_IP_ADDRESS_IN,
			PS_DEST_IP_ADDRESS_IN  => RC_DEST_IP_ADDRESS_IN,
			PS_SRC_UDP_PORT_IN     => RC_SRC_UDP_PORT_IN,
			PS_DEST_UDP_PORT_IN    => RC_DEST_UDP_PORT_IN,
			PS_ID_IP_IN            => RC_ID_IP_IN,
			PS_FO_IP_IN            => RC_FO_IP_IN,
			PS_CHECKSUM_IN         => RC_CHECKSUM_IN,
			PS_IDENT_IN            => RC_IDENT_IN,
			PS_FLAGS_OFFSET_IN     => RC_FLAGS_OFFSET_IN,
			TC_DATA_OUT            => tc_data,
			TC_RD_EN_IN            => TC_RD_EN_IN,
			TC_FRAME_SIZE_OUT      => TC_FRAME_SIZE_OUT,
			TC_FRAME_TYPE_OUT      => TC_FRAME_TYPE_OUT,
			TC_IP_PROTOCOL_OUT     => TC_IP_PROTOCOL_OUT,
			TC_IDENT_OUT           => TC_IDENT_OUT,
			TC_DEST_MAC_OUT        => TC_DEST_MAC_OUT,
			TC_DEST_IP_OUT         => TC_DEST_IP_OUT,
			TC_DEST_UDP_OUT        => TC_DEST_UDP_OUT,
			TC_SRC_MAC_OUT         => TC_SRC_MAC_OUT,
			TC_SRC_IP_OUT          => TC_SRC_IP_OUT,
			TC_SRC_UDP_OUT         => TC_SRC_UDP_OUT,
			MC_BUSY_IN             => mc_busy,
			MY_MAC_IN              => MC_MY_MAC_IN,
			MY_IP_OUT              => open,
			DHCP_START_IN          => dhcp_start,
			DHCP_DONE_OUT          => dhcp_done,
			-- PROTOCOLS SPECIFIC PORTS

			DATA_HIST_OUT          => DATA_HIST_OUT,
			SCTRL_HIST_OUT         => SCTRL_HIST_OUT,
			
			USR_DATA_OUT           => USR_DATA_OUT,
            USR_DATA_VALID_OUT     => USR_DATA_VALID_OUT,
            USR_SOP_OUT            => USR_SOP_OUT,
            USR_EOP_OUT            => USR_EOP_OUT,
			
			DEBUG_OUT              => open
		);

	TC_DATA_OUT <= tc_data;

	-- do not select any response constructors when dropping a frame
	proto_select <= RC_FRAME_PROTO_IN when disable_redirect = '0' else (others => '0');

	DISABLE_REDIRECT_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (RESET = '1') then
				disable_redirect <= '0';
			elsif (redirect_current_state = CHECK_TYPE) then
				if (link_current_state /= ACTIVE and link_current_state /= GET_ADDRESS) then
					disable_redirect <= '1';
				elsif (link_current_state = GET_ADDRESS and RC_FRAME_PROTO_IN /= "10") then
					disable_redirect <= '1';
				else
					disable_redirect <= '0';
				end if;
			else
				disable_redirect <= disable_redirect;
			end if;
		end if;
	end process DISABLE_REDIRECT_PROC;

	-- warning
	SYNC_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			rc_data_local <= RC_DATA_IN;
		end if;
	end process SYNC_PROC;

	REDIRECT_MACHINE_PROC : process(RESET, CLK)
	begin
		if (RESET = '1') then
			redirect_current_state <= IDLE;
		elsif rising_edge(CLK) then
			if RX_PATH_ENABLE = 1 then
				redirect_current_state <= redirect_next_state;
			else
				redirect_current_state <= IDLE;
			end if;
		end if;
	end process REDIRECT_MACHINE_PROC;

	REDIRECT_MACHINE : process(redirect_current_state, link_current_state, RC_FRAME_WAITING_IN, ps_busy, RC_FRAME_PROTO_IN, loaded_bytes_ctr, RC_FRAME_SIZE_IN)
	begin
		case redirect_current_state is
			when IDLE =>
				redirect_state <= x"1";
				if (RC_FRAME_WAITING_IN = '1') then
					redirect_next_state <= CHECK_TYPE;
				else
					redirect_next_state <= IDLE;
				end if;

			when CHECK_TYPE =>
				if (link_current_state = ACTIVE) then
					redirect_next_state <= CHECK_BUSY;
				elsif (link_current_state = GET_ADDRESS and RC_FRAME_PROTO_IN = "10") then
					redirect_next_state <= CHECK_BUSY;
				else
					redirect_next_state <= DROP;
				end if;

			when DROP =>
				redirect_state <= x"7";
				if (loaded_bytes_ctr = RC_FRAME_SIZE_IN - x"1") then
					redirect_next_state <= WAIT_ONE;
				else
					redirect_next_state <= DROP;
				end if;

			when CHECK_BUSY =>
				redirect_state <= x"6";
				if (or_all(ps_busy and RC_FRAME_PROTO_IN) = '0') then
					redirect_next_state <= LOAD;
				else
					redirect_next_state <= BUSY;
				end if;

			when LOAD =>
				redirect_state <= x"2";
				if (loaded_bytes_ctr = RC_FRAME_SIZE_IN - x"1") then
					redirect_next_state <= WAIT_ONE;
				else
					redirect_next_state <= LOAD;
				end if;

			when BUSY =>
				redirect_state <= x"3";
				if (or_all(ps_busy and RC_FRAME_PROTO_IN) = '0') then
					redirect_next_state <= LOAD;
				else
					redirect_next_state <= BUSY;
				end if;

			when WAIT_ONE =>
				redirect_state      <= x"f";
				redirect_next_state <= FINISH;

			when FINISH =>
				redirect_state      <= x"4";
				redirect_next_state <= CLEANUP;

			when CLEANUP =>
				redirect_state      <= x"5";
				redirect_next_state <= IDLE;

		end case;
	end process REDIRECT_MACHINE;

	rc_rd_en     <= '1' when redirect_current_state = LOAD or redirect_current_state = DROP else '0';
	RC_RD_EN_OUT <= rc_rd_en;

	LOADING_DONE_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (RC_DATA_IN(8) = '1' and ps_wr_en_q = '1') then
				RC_LOADING_DONE_OUT <= '1';
			else
				RC_LOADING_DONE_OUT <= '0';
			end if;
		end if;
	end process LOADING_DONE_PROC;

	PS_WR_EN_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			ps_wr_en    <= rc_rd_en;
			ps_wr_en_q  <= ps_wr_en;
			ps_wr_en_qq <= ps_wr_en_q;
		end if;
	end process PS_WR_EN_PROC;

	LOADED_BYTES_CTR_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (redirect_current_state = IDLE) then
				loaded_bytes_ctr <= (others => '0');
			elsif (redirect_current_state = LOAD or redirect_current_state = DROP) and (rc_rd_en = '1') then
				loaded_bytes_ctr <= loaded_bytes_ctr + x"1";
			else
				loaded_bytes_ctr <= loaded_bytes_ctr;
			end if;
		end if;
	end process LOADED_BYTES_CTR_PROC;

	FIRST_BYTE_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			first_byte_q  <= first_byte;
			first_byte_qq <= first_byte_q;

			if (redirect_current_state = IDLE) then
				first_byte <= '1';
			else
				first_byte <= '0';
			end if;
		end if;
	end process FIRST_BYTE_PROC;

	--*********************
	--	DATA FLOW CONTROL

	FLOW_MACHINE_PROC : process(RESET, CLK)
	begin
		if (RESET = '1') then
			flow_current_state <= IDLE;
		elsif rising_edge(CLK) then
			flow_current_state <= flow_next_state;
		end if;
	end process FLOW_MACHINE_PROC;

	FLOW_MACHINE : process(flow_current_state, TC_TRANSMIT_DONE_IN, ps_response_ready, tc_data)
	begin
		case flow_current_state is
			when IDLE =>
				if (ps_response_ready = '1') then
					flow_next_state <= TRANSMIT_CTRL;
				else
					flow_next_state <= IDLE;
				end if;

			when TRANSMIT_CTRL =>
				if (tc_data(8) = '1') then
					flow_next_state <= WAIT_FOR_FC;
				else
					flow_next_state <= TRANSMIT_CTRL;
				end if;

			when WAIT_FOR_FC =>
				if (TC_TRANSMIT_DONE_IN = '1') then
					flow_next_state <= CLEANUP;
				else
					flow_next_state <= WAIT_FOR_FC;
				end if;

			when CLEANUP =>
				flow_next_state <= IDLE;

		end case;
	end process FLOW_MACHINE;

	process(CLK)
	begin
		if rising_edge(CLK) then
			if (flow_current_state = IDLE and ps_response_ready = '1') then
				TC_TRANSMIT_CTRL_OUT <= '1';
			else
				TC_TRANSMIT_CTRL_OUT <= '0';
			end if;

			if (flow_current_state = TRANSMIT_CTRL or flow_current_state = WAIT_FOR_FC) then
				mc_busy <= '1';
			else
				mc_busy <= '0';
			end if;
		end if;
	end process;

	--***********************
	--	LINK STATE CONTROL

	lsm_impl_gen : if SIMULATE = 0 generate
		LINK_STATE_MACHINE_PROC : process(MC_RESET_LINK_IN, CLK)
		begin
			if MC_RESET_LINK_IN = '1' then
				link_current_state <= INACTIVE;
			elsif rising_edge(CLK) then
				if RX_PATH_ENABLE = 1 then
					link_current_state <= link_next_state;
				else
					link_current_state <= INACTIVE;
				end if;
			end if;
		end process;
	end generate lsm_impl_gen;

	lsm_sim_gen : if SIMULATE = 1 generate
		LINK_STATE_MACHINE_PROC : process(MC_RESET_LINK_IN, CLK)
		begin
			if MC_RESET_LINK_IN = '1' then
				link_current_state <= WAIT_FOR_BOOT;
			elsif rising_edge(CLK) then
				if RX_PATH_ENABLE = 1 then
					link_current_state <= link_next_state;
				else
					link_current_state <= ACTIVE;
				end if;
			end if;
		end process;
	end generate lsm_sim_gen;

	incl_dhcp_gen : if (INCLUDE_DHCP = '1') generate
		incl_dhcp <= '1';
	end generate incl_dhcp_gen;
	noincl_dhcp_gen : if (INCLUDE_DHCP = '0') generate
		incl_dhcp <= '0';
	end generate noincl_dhcp_gen;

	LINK_STATE_MACHINE : process(link_current_state, dhcp_done, wait_ctr, PCS_AN_COMPLETE_IN, incl_dhcp, MAC_READY_CONF_IN, link_ok_timeout_ctr)
	begin
		case link_current_state is
			when INACTIVE =>
				link_state <= x"2";
				if (PCS_AN_COMPLETE_IN = '1') then
					link_next_state <= TIMEOUT;
				else
					link_next_state <= INACTIVE;
				end if;

			when TIMEOUT =>
				link_state <= x"3";
				if (PCS_AN_COMPLETE_IN = '0') then
					link_next_state <= INACTIVE;
				else
					if (link_ok_timeout_ctr = x"ffff") then
						link_next_state <= ENABLE_MAC; --FINALIZE;
					else
						link_next_state <= TIMEOUT;
					end if;
				end if;

			when ENABLE_MAC =>
				link_state <= x"4";
				if (PCS_AN_COMPLETE_IN = '0') then
					link_next_state <= INACTIVE;
				--elsif (tsm_ready = '1') then
				elsif (MAC_READY_CONF_IN = '1') then
					link_next_state <= FINALIZE; --INACTIVE;
				else
					link_next_state <= ENABLE_MAC;
				end if;

			when FINALIZE =>
				link_state <= x"5";
				if (PCS_AN_COMPLETE_IN = '0') then
					link_next_state <= INACTIVE;
				else
					link_next_state <= WAIT_FOR_BOOT; --ACTIVE;
				end if;

			when WAIT_FOR_BOOT =>
				link_state <= x"6";
				if (PCS_AN_COMPLETE_IN = '0') then
					link_next_state <= INACTIVE;
				else
					if (wait_ctr = x"0000_1000") then
						if (incl_dhcp = '1') then
							link_next_state <= GET_ADDRESS;
						else
							link_next_state <= ACTIVE;
						end if;
					else
						link_next_state <= WAIT_FOR_BOOT;
					end if;
				end if;

			when GET_ADDRESS =>
				link_state <= x"7";
				if (PCS_AN_COMPLETE_IN = '0') then
					link_next_state <= INACTIVE;
				else
					if (dhcp_done = '1') then
						link_next_state <= ACTIVE;
					else
						link_next_state <= GET_ADDRESS;
					end if;
				end if;

			when ACTIVE =>
				link_state <= x"1";
				if (PCS_AN_COMPLETE_IN = '0') then
					link_next_state <= INACTIVE;
				else
					link_next_state <= ACTIVE;
				end if;

		end case;
	end process LINK_STATE_MACHINE;

	MC_DHCP_DONE_OUT <= '1' when link_current_state = ACTIVE else '0';

	LINK_OK_CTR_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (link_current_state /= TIMEOUT) then
				link_ok_timeout_ctr <= (others => '0');
			elsif (link_current_state = TIMEOUT) then
				link_ok_timeout_ctr <= link_ok_timeout_ctr + x"1";
			end if;

			--		if (link_current_state = ACTIVE or link_current_state = GET_ADDRESS) then
			--			link_ok <= '1';
			--		else
			--			link_ok <= '0';
			--		end if;

			if (link_current_state = GET_ADDRESS) then
				dhcp_start <= '1';
			else
				dhcp_start <= '0';
			end if;
		end if;
	end process LINK_OK_CTR_PROC;

	link_ok <= '1';

	WAIT_CTR_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (link_current_state = WAIT_FOR_BOOT) then
				wait_ctr <= wait_ctr + x"1";
			else
				wait_ctr <= (others => '0');
			end if;
		end if;
	end process WAIT_CTR_PROC;

	MC_LINK_OK_OUT <= link_ok;

	-- END OF LINK STATE CONTROL
	--*************

	--*************
	-- GENERATE MAC_ADDRESS
	MC_MY_MAC_OUT <= MC_MY_MAC_IN; --unique_id(31 downto 8) & x"be0002";

	--*************

	process(CLK)
	begin
		if rising_edge(CLK) then
			if link_current_state = INACTIVE and PCS_AN_COMPLETE_IN = '1' then
				tsm_reconf <= '1';
			else
				tsm_reconf <= '0';
			end if;
		end if;
	end process;
	MAC_RECONF_OUT <= tsm_reconf;

-- END OF TRI SPEED MAC CONTROLLER
--***************

end trb_net16_gbe_main_control;