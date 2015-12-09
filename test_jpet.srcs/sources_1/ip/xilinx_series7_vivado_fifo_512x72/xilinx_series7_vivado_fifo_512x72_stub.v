// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.3 (lin64) Build 1368829 Mon Sep 28 20:06:39 MDT 2015
// Date        : Mon Oct 26 13:46:24 2015
// Host        : cerber2 running 64-bit Ubuntu 15.04
// Command     : write_verilog -force -mode synth_stub
//               /home/michal/jpet/new_jpet/test_jpet/test_jpet.srcs/sources_1/ip/xilinx_series7_vivado_fifo_512x72/xilinx_series7_vivado_fifo_512x72_stub.v
// Design      : xilinx_series7_vivado_fifo_512x72
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k325tffg900-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_0_0,Vivado 2015.3" *)
module xilinx_series7_vivado_fifo_512x72(rst, wr_clk, rd_clk, din, wr_en, rd_en, dout, full, empty)
/* synthesis syn_black_box black_box_pad_pin="rst,wr_clk,rd_clk,din[71:0],wr_en,rd_en,dout[71:0],full,empty" */;
  input rst;
  input wr_clk;
  input rd_clk;
  input [71:0]din;
  input wr_en;
  input rd_en;
  output [71:0]dout;
  output full;
  output empty;
endmodule
