--synchronizes a signal do a different clock domain

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity signal_sync is
  generic(
    WIDTH : integer := 1;     --
    DEPTH : integer := 3
    );
  port(
    RESET    : in  std_logic; --Reset is neceessary to avoid optimization to shift register
    CLK0     : in  std_logic;                          --clock for first FF
    CLK1     : in  std_logic;                          --Clock for other FF
    D_IN     : in  std_logic_vector(WIDTH-1 downto 0); --Data input
    D_OUT    : out std_logic_vector(WIDTH-1 downto 0)  --Data output
    );
end entity;

architecture behavioral of signal_sync is

  signal sync_q       : std_logic_vector((DEPTH+1)*WIDTH-1 downto 0);

  attribute syn_preserve : boolean;
  attribute syn_keep : boolean;
  attribute syn_keep of sync_q : signal is true;
  attribute syn_preserve of sync_q : signal is true;


begin
  sync_q(WIDTH-1 downto 0) <= D_IN;
  D_OUT <= sync_q((DEPTH+1)*WIDTH-1 downto DEPTH*WIDTH);

  process(CLK0)
    begin
      if rising_edge(CLK0) then
        if RESET = '1' then
          sync_q(2*WIDTH-1 downto WIDTH) <= (others => '0');
        else
          sync_q(2*WIDTH-1 downto WIDTH) <= sync_q(WIDTH-1 downto 0);
        end if;
      end if;
    end process;

  gen_others : if DEPTH > 1 generate
    gen_flipflops : for i in 2 to DEPTH generate
      process(CLK1)
        begin
          if rising_edge(CLK1) then
            if RESET = '1' then
              sync_q((i+1)*WIDTH-1 downto i*WIDTH) <= (others => '0');
            else
              sync_q((i+1)*WIDTH-1 downto i*WIDTH) <= sync_q(i*WIDTH-1 downto (i-1)*WIDTH);
            end if;
          end if;
        end process;
    end generate;
  end generate;

end architecture;