-- Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2015.3 (lin64) Build 1368829 Mon Sep 28 20:06:39 MDT 2015
-- Date        : Mon Oct 26 13:48:54 2015
-- Host        : cerber2 running 64-bit Ubuntu 15.04
-- Command     : write_vhdl -force -mode synth_stub
--               /home/michal/jpet/new_jpet/test_jpet/test_jpet.srcs/sources_1/ip/xilinx_series7_vivado_fifo_512x9x36/xilinx_series7_vivado_fifo_512x9x36_stub.vhdl
-- Design      : xilinx_series7_vivado_fifo_512x9x36
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7k325tffg900-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity xilinx_series7_vivado_fifo_512x9x36 is
  Port ( 
    rst : in STD_LOGIC;
    wr_clk : in STD_LOGIC;
    rd_clk : in STD_LOGIC;
    din : in STD_LOGIC_VECTOR ( 8 downto 0 );
    wr_en : in STD_LOGIC;
    rd_en : in STD_LOGIC;
    dout : out STD_LOGIC_VECTOR ( 35 downto 0 );
    full : out STD_LOGIC;
    empty : out STD_LOGIC
  );

end xilinx_series7_vivado_fifo_512x9x36;

architecture stub of xilinx_series7_vivado_fifo_512x9x36 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "rst,wr_clk,rd_clk,din[8:0],wr_en,rd_en,dout[35:0],full,empty";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "fifo_generator_v13_0_0,Vivado 2015.3";
begin
end;
