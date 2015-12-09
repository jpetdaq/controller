library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use IEEE.NUMERIC_STD.ALL;

--use work.trb_net_gbe_components.all;
--use work.trb_net_gbe_protocols.all;

entity gbe_gmii_wrapper is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0;

		INCLUDE_OPENCORES_MAC : integer range 0 to 1 := 0
	);
	port(
	    LED : out std_logic_vector(7 downto 0);
		SYS_CLK        : in  std_logic;
		RESET_IN       : in  std_logic;
		GBE_CLK_DV     : in  std_logic;
		GBE_RX_CLK     : in  std_logic;
		GBE_TX_CLK     : out std_logic;

		RX_DATA_IN     : in  std_logic_vector(7 downto 0);
		RX_DATA_DV_IN  : in  std_logic;
		RX_DATA_ER_IN  : in  std_logic;

		TX_DATA_OUT    : out std_logic_vector(7 downto 0);
		TX_DATA_DV_OUT : out std_logic;
		TX_DATA_ER_OUT : out std_logic;

		DEBUG_OUT      : out std_logic_vector(255 downto 0)
	);
end gbe_gmii_wrapper;

architecture Behavioral of gbe_gmii_wrapper is

component MAC_top
port (
           Reset                   : in std_logic;
 Clk_125M                : in std_logic;
 Clk_user : in std_logic;
 Clk_reg : in std_logic;
 Speed : out std_logic_vector(2 downto 0);
 Rx_mac_ra : out std_logic;
 Rx_mac_rd : in std_logic;
 Rx_mac_data : out std_logic_vector(31 downto 0);
 Rx_mac_BE : out std_logic_vector(1 downto 0);
 Rx_mac_pa : out std_logic;
 Rx_mac_sop : out std_logic;
 Rx_mac_eop : out std_logic;
 Tx_mac_wa : out std_logic;
  Tx_mac_wr: in std_logic;
 Tx_mac_data : in std_logic_vector(31 downto 0);
 Tx_mac_BE : in std_logic_vector(1 downto 0);
 Tx_mac_sop : in std_logic;
 Tx_mac_eop : in std_logic;
Pkg_lgth_fifo_rd : in std_logic;
Pkg_lgth_fifo_ra : out std_logic;
 Pkg_lgth_fifo_data : out std_logic_vector(15 downto 0);      
Gtx_clk : out std_logic;
Rx_clk : in std_logic;
Tx_clk : in std_logic;
Tx_er  : out std_logic;
Tx_en : out std_logic;
 Txd : out std_logic_vector(7 downto 0);
 Rx_er : in std_logic;
 Rx_dv : in std_logic;
 Rxd : in std_logic_vector(7 downto 0);
 Crs : in std_logic;
 Col : in std_logic;
 CSB : in std_logic;
 WRB : in std_logic;
 CD_in : in std_logic_vector(15 downto 0);
 CD_out : out std_logic_vector(15 downto 0);
 CA : in std_logic_vector(7 downto 0);     
 Mdo : out std_logic;
 MdoEn : out std_logic;
 Mdi : in std_logic;
 Mdc : out std_logic      

); 
end component;

	signal rx_data, tx_data                                        : std_logic_vector(7 downto 0);
	signal rx_dv, rx_gf, rx_bf, tx_dv, tx_fb, tx_ack, tx_done      : std_logic;
	signal mac_rx_ra, mac_rx_sop, mac_rx_eop, mac_rx_pa, mac_rx_rd : std_logic;
	signal mac_rx_data, mac_tx_data                                : std_logic_vector(31 downto 0);
	signal mac_rx_be, mac_tx_be                                    : std_logic_vector(1 downto 0);
	signal mac_tx_sop, mac_tx_eop, mac_tx_wr, mac_tx_wa            : std_logic;
	signal tx_clk                                                  : std_logic;
	
	signal damn_low_bit, damn_high_bit : std_logic;
    signal damn_low_vec_16 : std_logic_vector(15 downto 0);
    signal damn_low_vec_8 : std_logic_vector(7 downto 0);
    
begin

    damn_low_bit  <= '0';
    damn_high_bit  <= '1';
    damn_low_vec_16 <= x"0000";
    damn_low_vec_8 <= x"00";

	gbe_i : entity work.gbe_module_wrapper
		generic map(
			SIMULATE              => SIMULATE,
			INCLUDE_DEBUG         => INCLUDE_DEBUG,
			LATTICE_ECP3          => LATTICE_ECP3,
			XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
			XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
		)
		port map(
		      LED=> LED,
			SYS_CLK         => SYS_CLK,
			RESET_IN        => RESET_IN,
			GBE_RX_CLK      => tx_clk,
			GBE_TX_CLK      => tx_clk,
			RX_DATA_IN      => rx_data,
			RX_DATA_DV_IN   => rx_dv,
			RX_DATA_GF_IN   => rx_gf,
			RX_DATA_BF_IN   => rx_bf,
			TX_DATA_OUT     => tx_data,
			TX_DATA_DV_OUT  => tx_dv,
			TX_DATA_FB_OUT  => tx_fb,
			TX_DATA_ACK_IN  => tx_ack,
			TX_DATA_DONE_IN => tx_done,
			DEBUG_OUT       => open
		);

	OPENCORES_MAC_GEN : if INCLUDE_OPENCORES_MAC = 1 generate
		gbe_mac_bridge_i : entity work.gbe_to_mac_bridge
			generic map(
				SIMULATE              => SIMULATE,
				INCLUDE_DEBUG         => INCLUDE_DEBUG,
				LATTICE_ECP3          => LATTICE_ECP3,
				XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
				XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
			)
			port map(
				MAC_CLK_IN               => GBE_CLK_DV,
				GBE_CLK_IN               => tx_clk,
				RESET_IN                 => RESET_IN,
				MAC_TX_WA_IN             => mac_tx_wa,
				MAC_TX_WR_OUT            => mac_tx_wr,
				MAC_TX_DATA_OUT          => mac_tx_data,
				MAC_TX_BE_OUT            => mac_tx_be,
				MAC_TX_SOP_OUT           => mac_tx_sop,
				MAC_TX_EOP_OUT           => mac_tx_eop,
				GBE_TX_DATA_IN           => tx_data,
				GBE_TX_DV_IN             => tx_dv,
				GBE_TX_FB_IN             => tx_fb,
				GBE_TX_ACK_OUT           => tx_ack,
				GBE_DATA_STATS_VALID_OUT => tx_done,
				DEBUG_OUT                => open
			);

		mac_gbe_bridge_i : entity work.mac_to_gbe_bridge
			generic map(
				SIMULATE              => SIMULATE,
				INCLUDE_DEBUG         => INCLUDE_DEBUG,
				LATTICE_ECP3          => LATTICE_ECP3,
				XILINX_SERIES7_ISE    => XILINX_SERIES7_ISE,
				XILINX_SERIES7_VIVADO => XILINX_SERIES7_VIVADO
			)
			port map(
				MAC_CLK_IN      => GBE_CLK_DV,
				GBE_CLK_IN      => tx_clk,
				RESET_IN        => RESET_IN,
				MAC_RX_RA_IN    => mac_rx_ra,
				MAC_RX_RD_OUT   => mac_rx_rd,
				MAC_RX_DATA_IN  => mac_rx_data,
				MAC_RX_BE_IN    => mac_rx_be,
				MAC_RX_PA_IN    => mac_rx_pa,
				MAC_RX_SOP_IN   => mac_rx_sop,
				MAC_RX_EOP_IN   => mac_rx_eop,
				GBE_RX_DATA_OUT => rx_data,
				GBE_RX_DV_OUT   => rx_dv,
				GBE_RX_GF_OUT   => rx_gf,
				GBE_RX_BF_OUT   => open,
				DEBUG_OUT       => open
			);

		mac_i : MAC_top
			port map(
				--system signals
				Reset              => RESET_IN,
				Clk_125M           => GBE_RX_CLK,
				Clk_user           => GBE_CLK_DV,
				Clk_reg            => GBE_CLK_DV,
				Speed              => open,
				--user interface 
				Rx_mac_ra          => mac_rx_ra,
				Rx_mac_rd          => mac_rx_rd,
				Rx_mac_data        => mac_rx_data,
				Rx_mac_BE          => mac_rx_be,
				Rx_mac_pa          => mac_rx_pa,
				Rx_mac_sop         => mac_rx_sop,
				Rx_mac_eop         => mac_rx_eop,
				--user interface 
				Tx_mac_wa          => mac_tx_wa,
				Tx_mac_wr          => mac_tx_wr,
				Tx_mac_data        => mac_tx_data,
				Tx_mac_BE          => mac_tx_be,
				Tx_mac_sop         => mac_tx_sop,
				Tx_mac_eop         => mac_tx_eop,
				--pkg_lgth fifo
				Pkg_lgth_fifo_rd   => damn_high_bit, --'1',  --WOLO
				Pkg_lgth_fifo_ra   => open,
				Pkg_lgth_fifo_data => open,
				--Phy interface         
				Gtx_clk            => tx_clk,
				Rx_clk             => GBE_RX_CLK,
				Tx_clk             => damn_low_bit, --'0',  --WOLO
				Tx_er              => TX_DATA_ER_OUT,
				Tx_en              => TX_DATA_DV_OUT,
				Txd                => TX_DATA_OUT,
				Rx_er              => RX_DATA_ER_IN,
				Rx_dv              => RX_DATA_DV_IN,
				Rxd                => RX_DATA_IN,
				Crs                => damn_low_bit, --'0',
				Col                => damn_low_bit, --'0',
				--host interface
				CSB                => damn_high_bit, --'1',
				WRB                => damn_high_bit, --'1',
				CD_in              => damn_low_vec_16, --x"0000",
				CD_out             => open,
				CA                 => damn_low_vec_8, -- x"00",
				--mdx
				Mdo                => open,
				MdoEn              => open,
				Mdi                => damn_low_bit, --'0',
				Mdc                => open
			);

		GBE_TX_CLK <= tx_clk;

	end generate OPENCORES_MAC_GEN;
	
	incl_debug_gen : if INCLUDE_DEBUG = 1 generate
		DEBUG_OUT(0) <= mac_tx_wa;
		DEBUG_OUT(1) <= mac_tx_wr;
		DEBUG_OUT(2) <= mac_tx_sop;
		DEBUG_OUT(3) <= mac_tx_eop;
		DEBUG_OUT(35 downto 4) <= mac_tx_data;
		DEBUG_OUT(37 downto 36) <= mac_tx_be;	
		
		DEBUG_OUT(38) <= mac_rx_ra;
		DEBUG_OUT(39) <= mac_rx_rd;
		DEBUG_OUT(40) <= mac_rx_sop;
		DEBUG_OUT(41) <= mac_rx_eop;
		DEBUG_OUT(42) <= mac_rx_pa;
		DEBUG_OUT(44 downto 43) <= mac_rx_be;
		DEBUG_OUT(76 downto 45) <= mac_rx_data;
	end generate incl_debug_gen;

end Behavioral;