`timescale 1ns / 1ns
module RMON_dpram(
Reset   ,         
Clk     ,         
//port-a for Rmon 
Addra,            
Dina,            
Douta,           
Wea,             
//port-b for CPU  
Addrb,            
Doutb   
);

input           Reset   ;
input           Clk     ; 
                //port-a for Rmon  
input   [5:0]   Addra;
input   [31:0]  Dina;
output  [31:0]  Douta;
input           Wea;
                //port-b for CPU
input   [5:0]   Addrb;
output  [31:0]  Doutb;
//******************************************************************************
//internal signals                                                              
//******************************************************************************

wire            Clka;
wire            Clkb;
assign          Clka=Clk;
assign  #2      Clkb=Clk;
//******************************************************************************


duram #(32,6,"36Kb","M4K",10) U_duram(
.Reset					(Reset					),    
.data_a         (Dina           ),  
.data_b         (32'b0          ),  
.wren_a         (Wea            ),  
.wren_b         (1'b0           ),  
.address_a      (Addra          ),  
.address_b      (Addrb          ),  
.clock_a        (Clka           ),  
.clock_b        (Clkb           ),  
.q_a            (Douta          ),  
.q_b            (Doutb          )); 

endmodule
