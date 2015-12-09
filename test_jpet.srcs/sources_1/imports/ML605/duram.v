module duram(
Reset,
data_a,
data_b,
wren_a,
wren_b,
address_a,
address_b,
clock_a,
clock_b,
q_a,
q_b);

parameter DATA_WIDTH    = 36; 
parameter ADDR_WIDTH    = 10;
parameter ADDR_SIZE			=	"36Kb";  
parameter BLK_RAM_TYPE  = "AUTO";
parameter ADDR_BUS_WIDTH = 10;
parameter WRITE_ENB_SIZE = 4;
parameter ADDR_DEPTH    = 2**ADDR_WIDTH;

input Reset;
input   [DATA_WIDTH -1:0]   data_a;
input                       wren_a;
input   [ADDR_WIDTH -1:0]   address_a;
input                       clock_a;
output  [DATA_WIDTH -1:0]   q_a;
input   [DATA_WIDTH -1:0]   data_b;
input                       wren_b;
input   [ADDR_WIDTH -1:0]   address_b;
input                       clock_b;
output  [DATA_WIDTH -1:0]   q_b;


wire Reset;
wire 		[ADDR_BUS_WIDTH -1:0]		address_a_full;
wire 		[ADDR_BUS_WIDTH -1:0]		address_b_full;
 				
wire    [DATA_WIDTH -1:0]  do_b;
wire    [DATA_WIDTH -1:0]  din_a;
wire    [DATA_WIDTH -1:0]  din_b;
wire 		[WRITE_ENB_SIZE-1:0] wren_a_big;
wire 		[WRITE_ENB_SIZE-1:0] wren_b_big;

assign address_a_full = {{ADDR_BUS_WIDTH-ADDR_WIDTH{1'b0}},address_a};
assign address_b_full = {{ADDR_BUS_WIDTH-ADDR_WIDTH{1'b0}},address_b};

assign wren_a_big 		= {WRITE_ENB_SIZE{wren_a}};
assign wren_b_big			= {WRITE_ENB_SIZE{wren_b}};

assign  din_a   =data_a;
assign  do_b		= q_b 	;
assign  din_b   = data_b;


BRAM_TDP_MACRO #(
.BRAM_SIZE("36Kb"), // Target BRAM: "18Kb" or "36Kb"
.DEVICE("7SERIES"), // Target device: "VIRTEX5", "VIRTEX6", "SPARTAN6"
.DOA_REG(0),  // Optional port A output register (0 or 1)
.DOB_REG(0),  // Optional port B output register (0 or 1)
.INIT_A(36'h0000000), // Initial values on port A output port
.INIT_B(36'h00000000), // Initial values on port B output port
.INIT_FILE ("NONE"),
.READ_WIDTH_A (DATA_WIDTH),  // Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
.READ_WIDTH_B (DATA_WIDTH),  // Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
.SIM_COLLISION_CHECK ("ALL"), // Collision check enable "ALL", "WARNING_ONLY",
.SRVAL_A(36'h00000000), // Set/Reset value for port A output
.SRVAL_B(36'h00000000), // Set/Reset value for port B output
.WRITE_MODE_A("WRITE_FIRST"), // "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE"
.WRITE_MODE_B("WRITE_FIRST"), // "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE"
.WRITE_WIDTH_A(DATA_WIDTH), // Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
.WRITE_WIDTH_B(DATA_WIDTH) // Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
)

BRAM_TDP_MACRO_inst (
.DOA(q_a),       // Output port-A data, width defined by READ_WIDTH_A parameter
.DOB(q_b),       // Output port-B data, width defined by READ_WIDTH_B parameter
.ADDRA(address_a_full),   // Input port-A address, width defined by Port A depth
.ADDRB(address_b_full),   // Input port-B address, width defined by Port B depth
.CLKA(clock_a),     // 1-bit input port-A clock
.CLKB(clock_b),     // 1-bit input port-B clock
.DIA(din_a),       // Input port-A data, width defined by WRITE_WIDTH_A parameter
.DIB(din_b),       // Input port-B data, width defined by WRITE_WIDTH_B parameter
.ENA(1'b1),       // 1-bit input port-A enable
.ENB(1'b1),       // 1-bit input port-B enable
.REGCEA(1'b0),  // 1-bit input port-A output register enable
.REGCEB(1'b1),	//
.RSTA(Reset),			//
.RSTB(Reset),			//
.WEA(wren_a_big),				//
.WEB(wren_b_big)				//
);



endmodule 


