library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_4096x9_generic_wrapper is
	generic(
		SIMULATE              : integer range 0 to 1 := 0;
		INCLUDE_DEBUG         : integer range 0 to 1 := 0;

		LATTICE_ECP3          : integer range 0 to 1 := 0;
		XILINX_SERIES7_ISE    : integer range 0 to 1 := 0;
		XILINX_SERIES7_VIVADO : integer range 0 to 1 := 0
	);
	port(
		WR_CLK_IN : in  std_logic;
		RD_CLK_IN : in  std_logic;
		RESET_IN  : in  std_logic;

		DATA_IN   : in  std_logic_vector(8 downto 0);
		WR_EN_IN  : in  std_logic;

		DATA_OUT  : out std_logic_vector(8 downto 0);
		RD_EN_IN  : in  std_logic;

		FULL_OUT  : out std_logic;
		EMPTY_OUT : out std_logic;

		DEBUG_OUT : out std_logic_vector(255 downto 0)
	);
end entity fifo_4096x9_generic_wrapper;

architecture RTL of fifo_4096x9_generic_wrapper is
	component lattice_ecp3_fifo_4096x9 is
		port(
			Data    : in  std_logic_vector(8 downto 0);
			WrClock : in  std_logic;
			RdClock : in  std_logic;
			WrEn    : in  std_logic;
			RdEn    : in  std_logic;
			Reset   : in  std_logic;
			RPReset : in  std_logic;
			Q       : out std_logic_vector(8 downto 0);
			Empty   : out std_logic;
			Full    : out std_logic
		);
	end component lattice_ecp3_fifo_4096x9;

	component xilinx_series7_ise_fifo_4096x9 is
		port(
			din    : in  std_logic_vector(8 downto 0);
			wr_clk : in  std_logic;
			rd_clk : in  std_logic;
			wr_en  : in  std_logic;
			rd_en  : in  std_logic;
			rst    : in  std_logic;
			dout   : out std_logic_vector(8 downto 0);
			empty  : out std_logic;
			full   : out std_logic
		);
	end component xilinx_series7_ise_fifo_4096x9;
	
	component xilinx_series7_vivado_fifo_4096x9 IS
      PORT (
        rst : IN STD_LOGIC;
        wr_clk : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC
      );
    END component xilinx_series7_vivado_fifo_4096x9;
    
begin
	LATTICE_ECP3_gen : if LATTICE_ECP3 = 1 generate
		receive_fifo : lattice_ecp3_fifo_4096x9
			port map(
				Data    => DATA_IN,
				WrClock => WR_CLK_IN,
				RdClock => RD_CLK_IN,
				WrEn    => WR_EN_IN,
				RdEn    => RD_EN_IN,
				Reset   => RESET_IN,
				RPReset => RESET_IN,
				Q       => DATA_OUT,
				Empty   => EMPTY_OUT,
				Full    => FULL_OUT
			);
	end generate LATTICE_ECP3_gen;

	XILINX_SERIES7_ISE_gen : if XILINX_SERIES7_ISE = 1 generate
		receive_fifo : xilinx_series7_ise_fifo_4096x9
			port map(
				din    => DATA_IN,
				wr_clk => WR_CLK_IN,
				rd_clk => RD_CLK_IN,
				wr_en  => WR_EN_IN,
				rd_en  => RD_EN_IN,
				rst    => RESET_IN,
				dout   => DATA_OUT,
				empty  => EMPTY_OUT,
				full   => FULL_OUT
			);
	end generate XILINX_SERIES7_ISE_gen;

    XILINX_SERIES7_VIVADO_gen : if XILINX_SERIES7_VIVADO = 1 generate
		receive_fifo : xilinx_series7_vivado_fifo_4096x9
			port map(
				din    => DATA_IN,
				wr_clk => WR_CLK_IN,
				rd_clk => RD_CLK_IN,
				wr_en  => WR_EN_IN,
				rd_en  => RD_EN_IN,
				rst    => RESET_IN,
				dout   => DATA_OUT,
				empty  => EMPTY_OUT,
				full   => FULL_OUT
			);
	end generate XILINX_SERIES7_VIVADO_gen;

end architecture RTL;
