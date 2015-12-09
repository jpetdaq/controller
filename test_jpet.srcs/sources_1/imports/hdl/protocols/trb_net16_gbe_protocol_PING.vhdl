LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;

use work.trb_net_gbe_components.all;
use work.trb_net_gbe_protocols.all;

--********
-- Response Constructor which responds to Ping messages
--

entity trb_net16_gbe_protocol_Ping is
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

		-- debug
		DEBUG_OUT              : out std_logic_vector(63 downto 0)
	);
end trb_net16_gbe_protocol_Ping;

architecture trb_net16_gbe_protocol_Ping of trb_net16_gbe_protocol_Ping is
	type dissect_states is (IDLE, READ_FRAME, WAIT_FOR_LOAD, LOAD_FRAME, CLEANUP);
	signal dissect_current_state, dissect_next_state : dissect_states;

	signal sent_frames : std_logic_vector(15 downto 0);

	signal saved_data    : std_logic_vector(447 downto 0);
	signal saved_headers : std_logic_vector(63 downto 0);

	signal data_ctr    : integer range 1 to 1500;
	signal data_length : integer range 1 to 1500;
	signal tc_data     : std_logic_vector(8 downto 0);

	signal checksum : std_logic_vector(15 downto 0);

	signal checksum_l, checksum_r     : std_logic_vector(19 downto 0);
	signal checksum_ll, checksum_rr   : std_logic_vector(15 downto 0);
	signal checksum_lll, checksum_rrr : std_logic_vector(15 downto 0);

begin
	DISSECT_MACHINE_PROC : process(RESET, CLK)
	begin
		if RESET = '1' then
			dissect_current_state <= IDLE;
		elsif rising_edge(CLK) then
			dissect_current_state <= dissect_next_state;
		end if;
	end process DISSECT_MACHINE_PROC;

	DISSECT_MACHINE : process(dissect_current_state, PS_WR_EN_IN, PS_SELECTED_IN, PS_ACTIVATE_IN, PS_DATA_IN, data_ctr, data_length)
	begin
		case dissect_current_state is
			when IDLE =>
				if (PS_WR_EN_IN = '1' and PS_ACTIVATE_IN = '1') then
					dissect_next_state <= READ_FRAME;
				else
					dissect_next_state <= IDLE;
				end if;

			when READ_FRAME =>
				if (PS_DATA_IN(8) = '1') then
					dissect_next_state <= WAIT_FOR_LOAD;
				else
					dissect_next_state <= READ_FRAME;
				end if;

			when WAIT_FOR_LOAD =>
				if (PS_SELECTED_IN = '1') then
					dissect_next_state <= LOAD_FRAME;
				else
					dissect_next_state <= WAIT_FOR_LOAD;
				end if;

			when LOAD_FRAME =>
				if (data_ctr = data_length + 1) then
					dissect_next_state <= CLEANUP;
				else
					dissect_next_state <= LOAD_FRAME;
				end if;

			when CLEANUP =>
				dissect_next_state <= IDLE;

		end case;
	end process DISSECT_MACHINE;

	DATA_CTR_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (RESET = '1') or (dissect_current_state = IDLE) or (dissect_current_state = WAIT_FOR_LOAD) then
				data_ctr <= 2;
			elsif (dissect_current_state = READ_FRAME and PS_WR_EN_IN = '1' and PS_ACTIVATE_IN = '1') then -- in case of saving data from incoming frame
				data_ctr <= data_ctr + 1;
			elsif (dissect_current_state = LOAD_FRAME and PS_SELECTED_IN = '1' and TC_RD_EN_IN = '1') then -- in case of constructing response
				data_ctr <= data_ctr + 1;
			end if;
		end if;
	end process DATA_CTR_PROC;

	DATA_LENGTH_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (RESET = '1') then
				data_length <= 1;
			elsif (dissect_current_state = READ_FRAME and PS_DATA_IN(8) = '1') then
				data_length <= data_ctr;
			end if;
		end if;
	end process DATA_LENGTH_PROC;

	SAVE_VALUES_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (RESET = '1') or (dissect_current_state = IDLE) then
				saved_headers <= (others => '0');
				saved_data    <= (others => '0');
			elsif (dissect_current_state = IDLE and PS_WR_EN_IN = '1' and PS_ACTIVATE_IN = '1') then
				saved_headers(7 downto 0) <= PS_DATA_IN(7 downto 0);
			elsif (dissect_current_state = READ_FRAME) then
				if (data_ctr < 9) then  -- headers
					saved_headers(data_ctr * 8 - 1 downto (data_ctr - 1) * 8) <= PS_DATA_IN(7 downto 0);
				elsif (data_ctr > 8) then -- data
					saved_data((data_ctr - 8) * 8 - 1 downto (data_ctr - 8 - 1) * 8) <= PS_DATA_IN(7 downto 0);
				end if;
			elsif (dissect_current_state = LOAD_FRAME) then
				saved_headers(7 downto 0)   <= x"00";
				saved_headers(23 downto 16) <= checksum(7 downto 0);
				saved_headers(31 downto 24) <= checksum(15 downto 8);
			end if;
		end if;
	end process SAVE_VALUES_PROC;

	CS_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (RESET = '1') or (dissect_current_state = IDLE) then
				checksum_l(19 downto 0)   <= (others => '0');
				checksum_r(19 downto 0)   <= (others => '0');
				checksum_ll(15 downto 0)  <= (others => '0');
				checksum_rr(15 downto 0)  <= (others => '0');
				checksum_lll(15 downto 0) <= (others => '0');
				checksum_rrr(15 downto 0) <= (others => '0');
			elsif (dissect_current_state = READ_FRAME and data_ctr > 4) then
				if (std_logic_vector(to_unsigned(data_ctr, 1)) = "0") then
					checksum_l <= checksum_l + PS_DATA_IN(7 downto 0);
				else
					checksum_r <= checksum_r + PS_DATA_IN(7 downto 0);
				end if;
				checksum_ll  <= checksum_ll;
				checksum_lll <= checksum_lll;
				checksum_rr  <= checksum_rr;
				checksum_rrr <= checksum_rrr;
			elsif (dissect_current_state = WAIT_FOR_LOAD) then
				checksum_ll  <= x"0000" + checksum_l(7 downto 0) + checksum_r(19 downto 8);
				checksum_rr  <= x"0000" + checksum_r(7 downto 0) + checksum_l(19 downto 8);
				checksum_l   <= checksum_l;
				checksum_lll <= checksum_lll;
				checksum_r   <= checksum_r;
				checksum_rrr <= checksum_rrr;
			elsif (dissect_current_state = LOAD_FRAME and data_ctr = 2) then
				checksum_lll <= x"0000" + checksum_ll(7 downto 0) + checksum_rr(15 downto 8);
				checksum_rrr <= x"0000" + checksum_rr(7 downto 0) + checksum_ll(15 downto 8);
				checksum_l   <= checksum_l;
				checksum_ll  <= checksum_ll;
				checksum_r   <= checksum_r;
				checksum_rr  <= checksum_rr;
			else
				checksum_l   <= checksum_l;
				checksum_ll  <= checksum_ll;
				checksum_lll <= checksum_lll;
				checksum_r   <= checksum_r;
				checksum_rr  <= checksum_rr;
				checksum_rrr <= checksum_rrr;
			end if;
		end if;
	end process CS_PROC;
	checksum(7 downto 0)  <= not (checksum_rrr(7 downto 0) + checksum_lll(15 downto 8));
	checksum(15 downto 8) <= not (checksum_lll(7 downto 0) + checksum_rrr(15 downto 8));

	TC_DATA_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			tc_data(8) <= '0';

			if (dissect_current_state = LOAD_FRAME) then
				if (data_ctr < 10) then -- headers
					for i in 0 to 7 loop
						tc_data(i) <= saved_headers((data_ctr - 2) * 8 + i);
					end loop;
				else                    -- data
					for i in 0 to 7 loop
						tc_data(i) <= saved_data((data_ctr - 8 - 2) * 8 + i);
					end loop;

					-- mark the last byte
					if (data_ctr = data_length + 1) then
						tc_data(8) <= '1';
					end if;
				end if;
			else
				tc_data(7 downto 0) <= (others => '0');
			end if;

			TC_DATA_OUT <= tc_data;

		end if;
	end process TC_DATA_PROC;

	PS_RESPONSE_SYNC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (dissect_current_state = WAIT_FOR_LOAD or dissect_current_state = LOAD_FRAME or dissect_current_state = CLEANUP) then
				PS_RESPONSE_READY_OUT <= '1';
			else
				PS_RESPONSE_READY_OUT <= '0';
			end if;

			if (dissect_current_state = IDLE) then
				PS_BUSY_OUT <= '0';
			else
				PS_BUSY_OUT <= '1';
			end if;
		end if;
	end process PS_RESPONSE_SYNC;

	TC_FRAME_SIZE_OUT  <= std_logic_vector(to_unsigned(data_length, 16));
	TC_FRAME_TYPE_OUT  <= x"0008";
	TC_DEST_UDP_OUT    <= x"0000";      -- not used
	TC_SRC_MAC_OUT     <= MY_MAC_IN;
	TC_SRC_IP_OUT      <= MY_IP_IN;
	TC_SRC_UDP_OUT     <= x"0000";      -- not used
	TC_IP_PROTOCOL_OUT <= X"01";        -- ICMP
	TC_IDENT_OUT       <= x"2" & sent_frames(11 downto 0);

	ADDR_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (dissect_current_state = READ_FRAME) then
				TC_DEST_MAC_OUT <= PS_SRC_MAC_ADDRESS_IN;
				TC_DEST_IP_OUT  <= PS_SRC_IP_ADDRESS_IN;
			end if;
		end if;
	end process ADDR_PROC;

	-- needed for identification
	SENT_FRAMES_PROC : process(CLK)
	begin
		if rising_edge(CLK) then
			if (RESET = '1') then
				sent_frames <= (others => '0');
			elsif (dissect_current_state = CLEANUP) then
				sent_frames <= sent_frames + x"1";
			end if;
		end if;
	end process SENT_FRAMES_PROC;

end trb_net16_gbe_protocol_Ping;


