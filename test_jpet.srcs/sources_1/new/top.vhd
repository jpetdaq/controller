----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:02:55 03/31/2015 
-- Design Name: 
-- Module Name:    main - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity main is
generic (
	SIMULATE : integer range 0 to 1 := 0
);
port (
	GTREFCLK_P, GTREFCLK_N : in std_logic;
    SYSCLK_P, SYSCLK_N : in std_logic;
    SFP_TX_P, SFP_TX_N : out std_logic;
    SFP_RX_P, SFP_RX_N : in std_logic;
	CPU_RESET : in std_logic;
    LED : out std_logic_vector(7 downto 0)
);
end main;

architecture Behavioral of main is

COMPONENT gig_ethernet_pcs_pma_0
  PORT (
    gtrefclk_bufg : IN STD_LOGIC;
    gtrefclk : IN STD_LOGIC;
    txn : OUT STD_LOGIC;
    txp : OUT STD_LOGIC;
    rxn : IN STD_LOGIC;
    rxp : IN STD_LOGIC;
    independent_clock_bufg : IN STD_LOGIC;
    txoutclk : OUT STD_LOGIC;
    rxoutclk : OUT STD_LOGIC;
    resetdone : OUT STD_LOGIC;
    cplllock : OUT STD_LOGIC;
    mmcm_reset : OUT STD_LOGIC;
    userclk : IN STD_LOGIC;
    userclk2 : IN STD_LOGIC;
    pma_reset : IN STD_LOGIC;
    mmcm_locked : IN STD_LOGIC;
    rxuserclk : IN STD_LOGIC;
    rxuserclk2 : IN STD_LOGIC;
    gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_tx_en : IN STD_LOGIC;
    gmii_tx_er : IN STD_LOGIC;
    gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_rx_dv : OUT STD_LOGIC;
    gmii_rx_er : OUT STD_LOGIC;
    gmii_isolate : OUT STD_LOGIC;
    configuration_vector : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    an_interrupt : OUT STD_LOGIC;
    an_adv_config_vector : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    an_restart_config : IN STD_LOGIC;
    status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    reset : IN STD_LOGIC;
    signal_detect : IN STD_LOGIC;
    gt0_qplloutclk_in : IN STD_LOGIC;
    gt0_qplloutrefclk_in : IN STD_LOGIC
  );
END COMPONENT;

 signal gtrefclk, gtrefclk_bufg, userclk2, clk100, clk200, locked, reset, resetdone, mmcm_locked, an_restart  : std_logic;
 signal status_vector : std_logic_vector(15 downto 0);
 signal clkout0, clkout1, userclk, clkfbout, txoutclk : std_logic;
    -- PMA reset generation signals for tranceiver
  signal pma_reset_pipe        : std_logic_vector(7 downto 0); -- flip-flop pipeline for reset duration stretch
  signal pma_reset             : std_logic;    
     -- These attributes will stop timing errors being reported in back annotated
  -- SDF simulation.
  attribute ASYNC_REG                   : string;
  attribute ASYNC_REG of pma_reset_pipe : signal is "TRUE";
  signal mmcm_reset, txoutclk_bufg : std_logic;
  
  signal counter : std_logic_vector(31 downto 0);
  signal pcs_reset : std_logic;
  signal control0, control1 : std_logic_vector(35 downto 0);
  signal trig0, trig1, gbe_rx_debug, gbe_tx_debug : std_logic_vector(255 downto 0);
  signal gmii_rxd : std_logic_vector(7 downto 0);
  signal gmii_rx_dv, gmii_rx_er : std_logic;
  
  signal mac_speed : std_logic_vector(2 downto 0);
	signal mac_rx_ra, mac_rx_sop, mac_rx_eop, mac_rx_pa, mac_rx_rd, pkg_lgth_ra, pkg_lgth_ra_q, pkg_lgth_ra_qq : std_logic;
	signal mac_rx_data, mac_tx_data : std_logic_vector(31 downto 0);
	signal mac_rx_be, mac_tx_be : std_logic_vector(1 downto 0);
	signal pkg_lgth_data, pkg_lgth_data_q, pkg_lgth_data_qq : std_logic_vector(15 downto 0);
	signal tx_ctr : std_logic_vector(15 downto 0);
	signal mac_tx_sop, mac_tx_eop, mac_tx_wr, mac_tx_wa : std_logic;
	signal gmii_txd : std_logic_vector(7 downto 0);
	signal gmii_tx_en, gmii_tx_er : std_logic;
	signal tx_clk : std_logic;
	signal rx_fifo_empty, rx_fifo_full, rx_fifo_wr : std_logic;
	signal rx_fifo_dout : std_logic_vector(7 downto 0); 	
		
	signal gbe_rx_data, gbe_tx_data : std_logic_vector(7 downto 0);
	signal gbe_rx_dv, gbe_rx_gf, gbe_tx_dv, gbe_tx_fb, gbe_tx_ack, gbe_tx_stats_valid : std_logic;
	signal gbe_debug : std_logic_vector(255 downto 0);
	
	signal logic_reset : std_logic;
	
	signal config_vec : std_logic_vector(4 downto 0);
    signal link_timer : std_logic_vector(8 downto 0);
    signal adv_config_vec : std_logic_vector(15 downto 0);
    signal damn_low_bit, damn_high_bit : std_logic;

    signal usr_data : std_logic_vector(7 downto 0);
    signal usr_data_valid : std_logic;
    signal usr_sop : std_logic;
    signal usr_eop : std_logic;
    
    signal parser_debug : std_logic_vector(7 downto 0);
begin


    config_vec <= b"1_0000";
    link_timer <= "000110010";
    adv_config_vec <= b"0000_0001_1010_0000";
    damn_low_bit <= '0';
    damn_high_bit <= '1';

   ibufds_gtrefclk : IBUFDS_GTE2
   port map (
      I     => GTREFCLK_P,
      IB    => GTREFCLK_N,
      CEB   => '0',
      O     => gtrefclk,
      ODIV2 => open
   );
   bufg_gtrefclk : BUFG
      port map (
         I         => gtrefclk,
         O         => gtrefclk_bufg
      );
	
	 mmcm_adv_inst : MMCME2_ADV
  generic map
   (BANDWIDTH            => "OPTIMIZED",
    CLKOUT4_CASCADE      => FALSE,
    COMPENSATION         => "ZHOLD",
    STARTUP_WAIT         => FALSE,
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT_F      => 16.000,
    CLKFBOUT_PHASE       => 0.000,
    CLKFBOUT_USE_FINE_PS => FALSE,
    CLKOUT0_DIVIDE_F     => 8.000,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.5,
    CLKOUT0_USE_FINE_PS  => FALSE,
    CLKOUT1_DIVIDE       => 16,
    CLKOUT1_PHASE        => 0.000,
    CLKOUT1_DUTY_CYCLE   => 0.5,
    CLKOUT1_USE_FINE_PS  => FALSE,
    CLKIN1_PERIOD        => 16.0,
    REF_JITTER1          => 0.010)
  port map
    -- Output clocks
   (CLKFBOUT             => clkfbout,
    CLKFBOUTB            => open,
    CLKOUT0              => clkout0,
    CLKOUT0B             => open,
    CLKOUT1              => clkout1,
    CLKOUT1B             => open,
    CLKOUT2              => open,
    CLKOUT2B             => open,
    CLKOUT3              => open,
    CLKOUT3B             => open,
    CLKOUT4              => open,
    CLKOUT5              => open,
    CLKOUT6              => open,
    -- Input clock control
    CLKFBIN              => clkfbout,
    CLKIN1               => txoutclk_bufg,
    CLKIN2               => '0',
    -- Tied to always select the primary input clock
    CLKINSEL             => '1',
    -- Ports for dynamic reconfiguration
    DADDR                => (others => '0'),
    DCLK                 => '0',
    DEN                  => '0',
    DI                   => (others => '0'),
    DO                   => open,
    DRDY                 => open,
    DWE                  => '0',
    -- Ports for dynamic phase shift
    PSCLK                => '0',
    PSEN                 => '0',
    PSINCDEC             => '0',
    PSDONE               => open,
    -- Other control and status signals
    LOCKED               => mmcm_locked,
    CLKINSTOPPED         => open,
    CLKFBSTOPPED         => open,
    PWRDWN               => '0',
    RST                  => mmcm_reset);
	 
 --mmcm_reset <= reset or (not resetdone);  --WOLOLOLOLOLO

   -- Route txoutclk input through a BUFG
   bufg_txoutclk : BUFG
   port map (
      I         => txoutclk,
      O         => txoutclk_bufg
   );

   -- This 62.5MHz clock is placed onto global clock routing and is then used
   -- for tranceiver TXUSRCLK/RXUSRCLK.
   bufg_userclk: BUFG
   port map (
      I     => clkout1,
      O     => userclk
   );    


   -- This 125MHz clock is placed onto global clock routing and is then used
   -- to clock all Ethernet core logic.
   bufg_userclk2: BUFG
   port map (
      I     => clkout0,
      O     => userclk2
   ); 
	
	   -----------------------------------------------------------------------------
   -- Transceiver PMA reset circuitry
   -----------------------------------------------------------------------------

   -- Create a reset pulse of a decent length
   process(reset, clk200)
   begin
     if (reset = '1') then
       pma_reset_pipe <= "11111111";
     elsif clk200'event and clk200 = '1' then
       pma_reset_pipe <= pma_reset_pipe(6 downto 0) & reset;
     end if;
   end process;

   pma_reset <= pma_reset_pipe(3);

pcs_core_impl_gen : if SIMULATE = 0 generate
	core_wrapper : gig_ethernet_pcs_pma_0
		 port map (
			gtrefclk             => gtrefclk,
			gtrefclk_bufg        => gtrefclk_bufg,
			txp                  => SFP_TX_P,
			txn                  => SFP_TX_N,
			rxp                  => SFP_RX_P,
			rxn                  => SFP_RX_N,
			txoutclk             => txoutclk,
			rxoutclk             => open,
			rxuserclk            => userclk,
			rxuserclk2           => userclk2,
			resetdone            => resetdone,
			mmcm_locked          => mmcm_locked,
			mmcm_reset           => mmcm_reset,
			cplllock             => open,
 			userclk              => userclk,
			userclk2             => userclk2,
			independent_clock_bufg => clk200,
			pma_reset              => pma_reset,
			gmii_txd             => gmii_txd,
			gmii_tx_en           => gmii_tx_en,
			gmii_tx_er           => gmii_tx_er,
			gmii_rxd             => gmii_rxd,
			gmii_rx_dv           => gmii_rx_dv,
			gmii_rx_er           => gmii_rx_er,
			gmii_isolate         => open,
			configuration_vector => config_vec, --b"1_0000",
			an_interrupt         => open,
			an_adv_config_vector => adv_config_vec,
			an_restart_config    => damn_low_bit, --'0',
			--link_timer_value     => link_timer, --"000110010",
			status_vector        => status_vector,
			reset                => reset,
			signal_detect        => damn_high_bit, --'1',
            gt0_qplloutclk_in    => damn_low_bit, --'0',
            gt0_qplloutrefclk_in => damn_low_bit --'0'
			);
end generate pcs_core_impl_gen;


pcs_core_sim_gen : if SIMULATE = 1 generate
	resetdone <= '1';
	
	process
	begin
		txoutclk <= '1';
		wait for 8 ns;
		txoutclk <= '0';
		wait for 8 ns;
	end process;
	
	process
	begin
	
		gmii_rx_dv <= '0';
		gmii_rx_er <= '0';
		gmii_rxd   <= x"00";
	
		wait for 25 us;
		
		
		-- FIRST FRAME UDP - DHCP Offer
		wait until rising_edge(gtrefclk);
		gmii_rx_dv <= '1';
		-- preamble
		gmii_rxd		<= x"55";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"55";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"55";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"55";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"55";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"55";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"55";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"d5";
		wait until rising_edge(gtrefclk);
		-- dest mac
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"be";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"ef";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"11";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"11";
		wait until rising_edge(gtrefclk);
		-- src mac
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"aa";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"bb";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"cc";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"dd";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"ee";
		wait until rising_edge(gtrefclk);
		-- frame type
		gmii_rxd		<= x"08";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		-- ip headers
		gmii_rxd		<= x"45";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"10";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"01";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"5a";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"49";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"ff";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"11";  -- udp
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"cc";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"cc";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"c0";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"a8";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"01";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"c0";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"a8";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"02";
		-- udp headers
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"43";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"44";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"02";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"2c";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"aa";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"bb";
		-- dhcp data
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"02";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"01";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"06";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"be";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"11";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"fa";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"ce";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"c0";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"a8";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"10";

		for i in 0 to 219 loop
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		end loop;

		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"35";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"01";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"05";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"00";
		wait until rising_edge(gtrefclk);
		
		-- terminal checksum
		gmii_rxd		<= x"01";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"02";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"03";
		wait until rising_edge(gtrefclk);
		gmii_rxd		<= x"04";
		wait until rising_edge(gtrefclk);
		gmii_rx_dv <= '0';	
	
	    --wait for DHCP REQUEST
		wait for 5 us;	
	
	   -- FIRST FRAME UDP - DHCP ACK
        wait until rising_edge(gtrefclk);
        gmii_rx_dv <= '1';
        -- preamble
        gmii_rxd        <= x"55";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"55";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"55";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"55";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"55";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"55";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"55";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"d5";
        wait until rising_edge(gtrefclk);
        -- dest mac
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"be";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"ef";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"11";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"11";
        wait until rising_edge(gtrefclk);
        -- src mac
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"aa";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"bb";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"cc";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"dd";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"ee";
        wait until rising_edge(gtrefclk);
        -- frame type
        gmii_rxd        <= x"08";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        -- ip headers
        gmii_rxd        <= x"45";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"10";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"01";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"5a";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"49";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"ff";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"11";  -- udp
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"cc";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"cc";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"c0";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"a8";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"01";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"c0";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"a8";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"02";
        -- udp headers
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"43";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"44";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"02";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"2c";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"aa";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"bb";
        -- dhcp data
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"02";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"01";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"06";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"be";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"11";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"fa";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"ce";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"c0";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"a8";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"10";

        for i in 0 to 219 loop
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        end loop;

        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"35";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"01";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"05";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"00";
        wait until rising_edge(gtrefclk);
        
        -- terminal checksum
        gmii_rxd        <= x"01";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"02";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"03";
        wait until rising_edge(gtrefclk);
        gmii_rxd        <= x"04";
        wait until rising_edge(gtrefclk);
        gmii_rx_dv <= '0';    
    
        for i in 0 to 10 loop
            --wait and send udp
            wait for 20 us;    
            
            -- SEND TEST UDP
            wait until rising_edge(gtrefclk);
            gmii_rx_dv <= '1';
            -- preamble
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"d5";
            wait until rising_edge(gtrefclk);
            -- dest mac
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"be";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ef";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"11";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"11";
            wait until rising_edge(gtrefclk);
            -- src mac
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"aa";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"bb";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"cc";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"dd";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ee";
            wait until rising_edge(gtrefclk);
            -- frame type
            gmii_rxd        <= x"08";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            -- ip headers
            gmii_rxd        <= x"45";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"10";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"05";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"dc";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"49";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"20";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ff";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"11";  -- udp
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"cc";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"cc";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"c0";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"a8";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"01";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"c0";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"a8";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"02";
            -- udp headers
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ac";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"fc";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"27";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"10";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"07";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"d8";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"54";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ac";
            -- test udp data
            for i in 0 to 1471 loop
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= std_logic_vector(to_unsigned(i,gmii_rxd'length));
            end loop;
            -- terminal checksum
            gmii_rxd        <= x"01";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"02";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"03";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"04";
            wait until rising_edge(gtrefclk);
            gmii_rx_dv <= '0';  
            
            wait for 5 us;    
                        
            -- SEND TEST UDP
            wait until rising_edge(gtrefclk);
            gmii_rx_dv <= '1';
            -- preamble
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"55";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"d5";
            wait until rising_edge(gtrefclk);
            -- dest mac
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"be";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ef";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"11";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"11";
            wait until rising_edge(gtrefclk);
            -- src mac
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"aa";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"bb";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"cc";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"dd";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ee";
            wait until rising_edge(gtrefclk);
            -- frame type
            gmii_rxd        <= x"08";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            -- ip headers
            gmii_rxd        <= x"45";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"10";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"02";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"24";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"49";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"b9";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ff";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"11";  -- udp
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"cc";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"cc";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"c0";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"a8";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"01";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"c0";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"a8";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"00";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"02";
            -- udp headers
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ac";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"fc";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"27";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"10";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"07";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"d8";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"54";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"ac";
            -- test udp data
            for i in 0 to 527 loop
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= std_logic_vector(to_unsigned(i,gmii_rxd'length));
            end loop;
            -- terminal checksum
            gmii_rxd        <= x"01";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"02";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"03";
            wait until rising_edge(gtrefclk);
            gmii_rxd        <= x"04";
            wait until rising_edge(gtrefclk);
            gmii_rx_dv <= '0';  
	      end loop;
	   wait;
	end process;
	
	
end generate pcs_core_sim_gen; 

gbe_i : entity work.gbe_gmii_wrapper
	generic map(
		SIMULATE              => SIMULATE,
		INCLUDE_DEBUG         => 0,

		LATTICE_ECP3          => 0,
		XILINX_SERIES7_ISE    => 0,
		XILINX_SERIES7_VIVADO => 1,

		INCLUDE_OPENCORES_MAC => 1
	)
	port map(
		SYS_CLK        => clk200,
		RESET_IN       => logic_reset, --reset,
		GBE_CLK_DV     => userclk,
		GBE_RX_CLK     => userclk2, --gtrefclk,
		GBE_TX_CLK     => open,

		RX_DATA_IN     => gmii_rxd,
		RX_DATA_DV_IN  => gmii_rx_dv,
		RX_DATA_ER_IN  => gmii_rx_er,

		TX_DATA_OUT    => gmii_txd,
		TX_DATA_DV_OUT => gmii_tx_en,
		TX_DATA_ER_OUT => gmii_tx_er,

        USR_DATA_OUT => usr_data,
        USR_DATA_VALID_OUT => usr_data_valid,
        USR_SOP_OUT => usr_sop,
        USR_EOP_OUT => usr_eop,

		DEBUG_OUT      => gbe_debug
	);
	
	logic_reset <= not locked or not mmcm_locked;
	

		clock_i : entity work.clock
  port map
   (-- Clock in ports
    CLK_IN1_P => SYSCLK_P,
    CLK_IN1_N => SYSCLK_N,
    -- Clock out ports
    CLK_OUT1 => clk100,
    CLK_OUT2 => clk200,
    -- Status and control signals
    RESET  => '0',
    LOCKED => locked);
	 
--    LED(0) <= locked;
--    LED(1) <= status_vector(0);
--    LED(2) <= status_vector(1);
--    LED(3) <= status_vector(2);
--    LED(4) <= resetdone;
--    LED(5) <= mmcm_locked;
--    LED(6) <= '1';
--    LED(7) <= '0';
	 
parser_wrapper : entity work.parser_wrapper
    port map(
        CLK => clk200,
        RESET => logic_reset,
        USR_DATA => usr_data,
        USR_DATA_VALID => usr_data_valid,
        USR_SOP => usr_sop,
        USR_EOP => usr_eop,
        DEBUG_OUT => parser_debug
    );
	 
	 LED <= parser_debug when rising_edge(clk200);
	 
	 process(locked, clk200)
	 begin
		if (locked = '0') then
			counter <= (others => '0');
		elsif rising_edge(clk200) then
			if (counter < x"2000_0000") then
				counter <= counter + x"1";
			else
				counter <= counter;
			end if;
		end if;
	end process;
	
	reset <= '1' when locked = '0' or CPU_RESET = '1' else '0';
	
end Behavioral;
