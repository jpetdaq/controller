library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gbe_to_mac_bridge is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0
	);
	port(
		MAC_CLK_IN               : in  std_logic;
		GBE_CLK_IN               : in  std_logic;
		RESET_IN                 : in  std_logic;

		MAC_TX_WA_IN             : in  std_logic;
		MAC_TX_WR_OUT            : out std_logic;
		MAC_TX_DATA_OUT          : out std_logic_vector(31 downto 0);
		MAC_TX_BE_OUT            : out std_logic_vector(1 downto 0);
		MAC_TX_SOP_OUT           : out std_logic;
		MAC_TX_EOP_OUT           : out std_logic;

		GBE_TX_DATA_IN           : in  std_logic_vector(7 downto 0);
		GBE_TX_DV_IN             : in  std_logic;
		GBE_TX_FB_IN             : in  std_logic;
		GBE_TX_ACK_OUT           : out std_logic;
		GBE_DATA_STATS_VALID_OUT : out std_logic;

		DEBUG_OUT                : out std_logic_vector(255 downto 0)
	);
end gbe_to_mac_bridge;

architecture Behavioral of gbe_to_mac_bridge is
	signal gbe_tx_data, gbe_tx_data_q                       : std_logic_vector(7 downto 0);
	signal gbe_tx_dv, gbe_tx_dv_q, gbe_tx_dv_qq, gbe_tx_fb  : std_logic;
	signal fifo_din                                         : std_logic_vector(8 downto 0);
	signal fifo_dout, fifo_dout_q                           : std_logic_vector(35 downto 0);
	signal fifo_wr_en, fifo_rd_en, fifo_empty, fifo_rd_en_q : std_logic;
	signal data_flag, flag_switch                           : std_logic                    := '0';
	signal mac_tx_wa, mac_tx_sop, mac_tx_eop, mac_tx_wr     : std_logic;
	signal word_sft_reg                                     : std_logic_vector(3 downto 0) := x"1";
	signal padding_bytes                                    : std_logic;
	signal trans_idle : std_logic;

begin

	-- register inputs from gbe
	process(GBE_CLK_IN)
	begin
		if rising_edge(GBE_CLK_IN) then
			gbe_tx_data              <= GBE_TX_DATA_IN;
			gbe_tx_data_q            <= gbe_tx_data;
			gbe_tx_dv                <= GBE_TX_DV_IN;
			gbe_tx_dv_q              <= gbe_tx_dv;
			gbe_tx_dv_qq             <= gbe_tx_dv_q;
			gbe_tx_fb                <= GBE_TX_FB_IN;
			GBE_DATA_STATS_VALID_OUT <= (not gbe_tx_dv and gbe_tx_dv_q);
			GBE_TX_ACK_OUT           <= '1';
		end if;
	end process;

	-- fifo for width and clock domain change
	fifo_bridge : entity work.fifo_512x9x36_generic_wrapper
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			RESET_IN  => RESET_IN,
			WR_CLK_IN => GBE_CLK_IN,
			RD_CLK_IN => MAC_CLK_IN,
			DATA_IN   => fifo_din,
			WR_EN_IN  => fifo_wr_en,
			RD_EN_IN  => fifo_rd_en,
			DATA_OUT  => fifo_dout,
			FULL_OUT  => open,
			EMPTY_OUT => fifo_empty,
			DEBUG_OUT => open
		);
	--TODO: control the fifo full condition

	-- marks the begining and the end of a frame
	data_flag <= '1' when (gbe_tx_dv = '0' and gbe_tx_dv_q = '1') or (gbe_tx_dv_q = '1' and gbe_tx_dv_qq = '0') else '0';

	fifo_wr_en <= gbe_tx_dv_qq or padding_bytes;

	process(GBE_CLK_IN)
	begin
		if rising_edge(GBE_CLK_IN) then
			if (gbe_tx_dv = '1' or padding_bytes = '1') then
				word_sft_reg(3 downto 0) <= word_sft_reg(2 downto 0) & word_sft_reg(3);
			else
				word_sft_reg <= word_sft_reg;
			end if;
		end if;
	end process;

	process(GBE_CLK_IN)
	begin
		if rising_edge(GBE_CLK_IN) then
			if (fifo_din(8) = '1' and word_sft_reg /= x"1") then
				padding_bytes <= '1';
			elsif (padding_bytes = '1' and word_sft_reg /= x"8") then
				padding_bytes <= '1';
			else
				padding_bytes <= '0';
			end if;
		end if;
	end process;

	process(GBE_CLK_IN)
	begin
		if rising_edge(GBE_CLK_IN) then
			fifo_din <= data_flag & gbe_tx_data_q;
		end if;
	end process;

	fifo_rd_en <= mac_tx_wa and not fifo_empty;

	process(MAC_CLK_IN)
	begin
		if rising_edge(MAC_CLK_IN) then
			if (RESET_IN = '1') then
				flag_switch <= '0';
			elsif (fifo_dout(8) = '1' or fifo_dout(17) = '1' or fifo_dout(26) = '1' or fifo_dout(35) = '1') and fifo_rd_en_q = '1' then
				flag_switch <= not flag_switch;
			else
				flag_switch <= flag_switch;
			end if;
		end if;
	end process;

	process(MAC_CLK_IN)
	begin
		if rising_edge(MAC_CLK_IN) then
			fifo_dout_q  <= fifo_dout;
			fifo_rd_en_q <= fifo_rd_en;
		end if;
	end process;

	process(MAC_CLK_IN)
	begin
		if rising_edge(MAC_CLK_IN) then
			MAC_TX_SOP_OUT <= mac_tx_sop;
			mac_tx_sop     <= (fifo_dout(8) or fifo_dout(17) or fifo_dout(26) or fifo_dout(35)) and not flag_switch and fifo_rd_en_q;
			MAC_TX_EOP_OUT <= mac_tx_eop;
			mac_tx_eop     <= (fifo_dout(8) or fifo_dout(17) or fifo_dout(26) or fifo_dout(35)) and flag_switch and not mac_tx_sop and fifo_rd_en_q;
			
--			if (trans_idle = '0') then		
--				if (fifo_dout(35) = '1') then
--					MAC_TX_BE_OUT <= "01";
--				elsif (fifo_dout(26) = '1') then
--					MAC_TX_BE_OUT <= "10";
--				elsif (fifo_dout(17) = '1') then
--					MAC_TX_BE_OUT <= "11";
--				else
--					MAC_TX_BE_OUT <= "00";
--				end if;
--			else
--				MAC_TX_BE_OUT <= "00";
--			end if;
			MAC_TX_BE_OUT <= "00";

			MAC_TX_DATA_OUT <= fifo_dout_q(34 downto 27) & fifo_dout_q(25 downto 18) & fifo_dout_q(16 downto 9) & fifo_dout_q(7 downto 0);
			MAC_TX_WR_OUT   <= mac_tx_wr;
			mac_tx_wr       <= fifo_rd_en_q;

			mac_tx_wa <= MAC_TX_WA_IN;
		end if;
	end process;
	
	process(MAC_CLK_IN)
	begin
		if rising_edge(MAC_CLK_IN) then
			if (mac_tx_eop = '1') then
				trans_idle <= '1';
			elsif (mac_tx_sop = '1') then
				trans_idle <= '0';
			else
				trans_idle <= trans_idle;
			end if;
		end if;
	end process;
			

	debug_gen : if (INCLUDE_DEBUG = 1) generate
		DEBUG_OUT(7 downto 0)    <= fifo_din(7 downto 0);
		DEBUG_OUT(8)             <= fifo_dout(8);
		DEBUG_OUT(9)             <= fifo_rd_en;
		DEBUG_OUT(10)            <= fifo_empty;
		DEBUG_OUT(11)            <= fifo_wr_en;
		DEBUG_OUT(47 downto 12)  <= fifo_dout;
		DEBUG_OUT(48)            <= mac_tx_sop;
		DEBUG_OUT(49)            <= mac_tx_eop;
		DEBUG_OUT(255 downto 50) <= (others => '0');
	end generate debug_gen;

	nodebug_gen : if (INCLUDE_DEBUG = 0) generate
		DEBUG_OUT <= (others => '0');
	end generate nodebug_gen;

end Behavioral;
