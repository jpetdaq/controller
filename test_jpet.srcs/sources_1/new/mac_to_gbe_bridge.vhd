library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mac_to_gbe_bridge is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0
	);
	port(
		MAC_CLK_IN      : in  std_logic;
		GBE_CLK_IN      : in  std_logic;
		RESET_IN        : in  std_logic;

		MAC_RX_RA_IN    : in  std_logic;
		MAC_RX_RD_OUT   : out std_logic;
		MAC_RX_DATA_IN  : in  std_logic_vector(31 downto 0);
		MAC_RX_BE_IN    : in  std_logic_vector(1 downto 0);
		MAC_RX_PA_IN    : in  std_logic;
		MAC_RX_SOP_IN   : in  std_logic;
		MAC_RX_EOP_IN   : in  std_logic;

		GBE_RX_DATA_OUT : out std_logic_vector(7 downto 0);
		GBE_RX_DV_OUT   : out std_logic;
		GBE_RX_GF_OUT   : out std_logic;
		GBE_RX_BF_OUT   : out std_logic;

		DEBUG_OUT       : out std_logic_vector(255 downto 0)
	);
end mac_to_gbe_bridge;

architecture Behavioral of mac_to_gbe_bridge is
	signal mac_rx_ra, mac_rx_rd, mac_rx_pa, mac_rx_sop, mac_rx_eop, mac_rx_eop_q : std_logic;
	signal mac_rx_data, mac_rx_data_q                                            : std_logic_vector(31 downto 0);
	signal mac_rx_be, mac_rx_be_q                                                : std_logic_vector(1 downto 0);
	signal fifo_wr_en, fifo_rd_en, fifo_rd_en_q, fifo_full, fifo_empty           : std_logic;
	signal fifo_din                                                              : std_logic_vector(35 downto 0);
	signal fifo_dout                                                             : std_logic_vector(8 downto 0);
	signal gf_flag, gbe_gf, gbe_gf_q, gbe_gf_qq                                  : std_logic;
	signal block_write : std_logic;

begin

	-- register inputs from mac
	process(MAC_CLK_IN)
	begin
		if rising_edge(MAC_CLK_IN) then
			mac_rx_ra     <= MAC_RX_RA_IN;
			MAC_RX_RD_OUT <= mac_rx_rd;
			mac_rx_data   <= MAC_RX_DATA_IN;
			mac_rx_data_q <= mac_rx_data;
			mac_rx_be     <= MAC_RX_BE_IN;
			mac_rx_be_q   <= mac_rx_be;
			mac_rx_pa     <= MAC_RX_PA_IN;
			mac_rx_sop    <= MAC_RX_SOP_IN;
			mac_rx_eop    <= MAC_RX_EOP_IN;
			mac_rx_eop_q  <= mac_rx_eop;
		end if;
	end process;

	--TODO: add the BE correct byte marking
	--fifo_din <= '0' & mac_rx_data_q(31 downto 24) & '0' & mac_rx_data_q(23 downto 16) & '0' & mac_rx_data_q(15 downto 8) & mac_rx_eop_q & mac_rx_data_q(7 downto 0);
	fifo_din <= (mac_rx_be_q(0) and not mac_rx_be_q(1)) & mac_rx_data_q(31 downto 24) & 
				(not mac_rx_be_q(0) and mac_rx_be_q(1)) & mac_rx_data_q(23 downto 16) & 
				(mac_rx_be_q(0) and mac_rx_be_q(1)) & mac_rx_data_q(15 downto 8) & 
				(not mac_rx_be_q(0) and not mac_rx_be_q(1) and mac_rx_eop_q) & mac_rx_data_q(7 downto 0);

	-- fifo for width and clock domain change
	fifo_bridge : entity work.fifo_512x36x9_generic_wrapper
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
			RESET_IN  => RESET_IN,
			WR_CLK_IN => MAC_CLK_IN,
			RD_CLK_IN => GBE_CLK_IN,
			DATA_IN   => fifo_din,
			WR_EN_IN  => fifo_wr_en,
			RD_EN_IN  => fifo_rd_en,
			DATA_OUT  => fifo_dout,
			FULL_OUT  => open,
			EMPTY_OUT => fifo_empty,
			DEBUG_OUT => open
		);
	--TODO: control the fifo full condition

	process(MAC_CLK_IN)
	begin
		if rising_edge(MAC_CLK_IN) then
			if (mac_rx_pa = '1') then
				fifo_wr_en <= '1';
			else
				fifo_wr_en <= '0';
			end if;
		end if;
	end process;

	process(MAC_CLK_IN)
	begin
		if rising_edge(MAC_CLK_IN) then
			mac_rx_rd <= mac_rx_ra;
		end if;
	end process;

	process(GBE_CLK_IN)
	begin
		if rising_edge(GBE_CLK_IN) then
			if (fifo_empty = '0') then
				fifo_rd_en <= '1';
			else
				fifo_rd_en <= '0';
			end if;
		end if;
	end process;

	-- register the outputs
	process(GBE_CLK_IN)
	begin
		if rising_edge(GBE_CLK_IN) then
			gbe_gf          <= fifo_dout(8) and not gf_flag;
			gbe_gf_q        <= gbe_gf;
			gbe_gf_qq		 <= gbe_gf_q;
			GBE_RX_GF_OUT   <= fifo_dout(8) and not gf_flag; --gbe_gf;
			GBE_RX_DATA_OUT <= fifo_dout(7 downto 0);
			GBE_RX_BF_OUT   <= '0';
			fifo_rd_en_q    <= fifo_rd_en;
			
			if (gbe_gf = '0' and gbe_gf_q = '0' and gbe_gf_qq = '0') then
				GBE_RX_DV_OUT   <= fifo_rd_en_q;
			else
				GBE_RX_DV_OUT <= '0';
			end if;
			
		end if;
	end process;

	process(GBE_CLK_IN)
	begin
		if rising_edge(GBE_CLK_IN) then
			if (fifo_dout(8) = '1') then
				gf_flag <= '1';
			else
				gf_flag <= '0';
			end if;
		end if;
	end process;

	debug_gen : if (INCLUDE_DEBUG = 1) generate
		DEBUG_OUT(7 downto 0)    <= fifo_dout(7 downto 0);
		DEBUG_OUT(8)             <= fifo_dout(8);
		DEBUG_OUT(9)             <= fifo_rd_en;
		DEBUG_OUT(10)            <= fifo_empty;
		DEBUG_OUT(11)            <= fifo_wr_en;
		DEBUG_OUT(47 downto 12)  <= fifo_din;
		DEBUG_OUT(255 downto 48) <= (others => '0');
	end generate debug_gen;

	nodebug_gen : if (INCLUDE_DEBUG = 0) generate
		DEBUG_OUT <= (others => '0');
	end generate nodebug_gen;

end Behavioral;
