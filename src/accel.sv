// vim: ts=4:
// I2C master for acellerometer
// Initializes the device on power up
// Then starts to poll at a fixed rate
// Data is output serially with strobes to classsify and separate
module accel_master (
	// System
	input logic clk,
	input logic reset,
	// I2C bus
   input  logic sda_in     ,
   output logic sda_oe     ,
   output logic sda_out    ,
   input  logic scl_in     ,
   output logic scl_oe     ,
   output logic scl_out	,
	// Control interface
	output logic sample,	// completed all data
	// serial data interface and valid
	output logic sdata,
	output logic x_valid,
	output logic y_valid,
	output logic z_valid
	);

	//400 Khz cycle generator
	logic [6:0] cyc_cnt;
	always @(posedge clk) 
		cyc_cnt <= ( reset ) ? 0 : ( cyc_cnt == 119 ) ? 0 : cyc_cnt+1;
	logic ph1, ph2;
	assign ph1 = ( cyc_cnt <= 71 ) ? 1'b1 : 1'b0;
	assign ph2 = ( cyc_cnt > 71 ) ? 1'b1 : 1'b0;
	
	//10 cycle bit counter
	logic [3:0] bit_cnt;
	always @(posedge clk) 
		bit_cnt <= ( reset ) ? 0 : ( cyc_cnt == 119 ) ? (( bit_cnt == 9 ) ? 0 : bit_cnt + 1 ) : bit_cnt;
		
	//400 byte counter (100 Hz)
	logic [8:0] byte_cnt;
	always @(posedge clk) 
		byte_cnt <= ( reset ) ? 0 : ( cyc_cnt == 119 && bit_cnt == 9 ) ? (( byte_cnt == 399 ) ? 0 : byte_cnt + 1 ) : byte_cnt;
		

	// Generate sampel flag at 100Hz after the last sampel bit read.
	always @(posedge clk) 
		sample <= ( cyc_cnt == 119 && bit_cnt == 9 && byte_cnt == 11 ) ? 1'b1 : 1'b0;
	
	// Generate the SCL;
	// during teh first 11 bytes dureing bits 1 thru 8 following ph1 for pulling the clk low
	assign scl_out = 0; // openj collector, drive oe to get a low
	always_ff @(posedge clk) 
		scl_oe <= ( byte_cnt < 11 && bit_cnt >= 1 && bit_cnt <= 8 && ph1 ) ? 1 : 0;
		
	// Generatge the sampel pulses
	// duroign bytes 5-10, bits 1 - 8, then 1 - 4, at rising edge of clk cyc_cnt 71 )
	always @(posedge clk) begin
		x_valid <= 	( byte_cnt == 4 && bit_cnt >= 1 && bit_cnt <= 8 && cyc_cnt == 71 ) ? 1 : 
						( byte_cnt == 5 && bit_cnt >= 1 && bit_cnt <= 4 && cyc_cnt == 71 ) ? 1 : 0;					
		y_valid <= 	( byte_cnt == 6 && bit_cnt >= 1 && bit_cnt <= 8 && cyc_cnt == 71 ) ? 1 : 
						( byte_cnt == 7 && bit_cnt >= 1 && bit_cnt <= 4 && cyc_cnt == 71 ) ? 1 : 0;
		z_valid <= 	( byte_cnt == 8 && bit_cnt >= 1 && bit_cnt <= 8 && cyc_cnt == 71 ) ? 1 : 
						( byte_cnt == 9 && bit_cnt >= 1 && bit_cnt <= 4 && cyc_cnt == 71 ) ? 1 : 0;
	end
	
	// Sda. Open collector
	// Has to generate the write data, read data tristates, start and stops.
	// 11 bytes
	// 0:  { 7'h10, 1'b0 }, 1: { 8'h0d }, 2: { 1'h0, fsr[1:0], 5'h0 } 
	// 3:  { 7'h10, 1'b1 }, 4: { 8'h03 },  // setup to read the data regs
	// 5:  { 8'bzzzzzzzz }, 6: { 8'bzzzzxxxx}  // read x direcxiton msb fist [11:4], [3:0]
	// 7:  { 8'bzzzzzzzz }, 8: { 8'bzzzzxxxx}  // read y direcxiton
	// 9:  { 8'bzzzzzzzz }, 10:{ 8'bzzzzxxxx}  // read z direcxiton, finish with stop
	
	// Upon reasd, and ack, the sda shoudl be driven 0 during ph1 of bit 9
	logic read_ack;
	always_ff @(posedge clk)
		read_ack <= ( byte_cnt >= 5 && byte_cnt <= 10 && bit_cnt == 9 && ph1 ) ? 1'b1 : 1'b0;
			
	// for a stop, the the sda should be driven during ph2 of bit 9 during byte 10
	logic stop_cmd;
	always_ff @(posedge clk)
		stop_cmd <= ( byte_cnt == 10 && bit_cnt == 9 && ph2 ) ? 1'b1 : 1'b0;
	
	// for a start, the sda should be driven to 0 during ph2 of bit 0
	logic start_cmd;
	always_ff @(posedge clk)
		start_cmd <= ( byte_cnt < 11 && bit_cnt == 0 && ph2 ) ? 1'b1 : 1'b0;
	
	// Otherwise data bits shall be driven durign bytes 0 to 4, msb fist during bits 1 to 8
	logic [7:0] cmd_write = { 7'h10, 1'b0 };
	logic [7:0] init_addr = { 8'h0d };
	logic [7:0] init_data = { 1'b0, /*fsr =*/2'b01, 5'h00 };
	logic [7:0] cmd_read  = { 7'h10, 1'b1 };
	logic [7:0] read_addr = { 8'h03,  };
	// index into bytges based on bit_cnt
	logic [2:0] idx;
	assign idx = 8 - bit_cnt;
	// skip inactive bytes, then per byte mux.
	logic data;
	always_ff @(posedge clk)
		data <= ( byte_cnt > 4 || bit_cnt == 0 || bit_cnt == 9 ) ? 1'b0 : // dont drive data otherwise
				  ( byte_cnt == 0 ) ? !cmd_write[idx] :
				  ( byte_cnt == 1 ) ? !init_addr[idx] :
				  ( byte_cnt == 2 ) ? !init_data[idx] :
				  ( byte_cnt == 3 ) ? !cmd_read[idx] :
				  ( byte_cnt == 4 ) ? !read_addr[idx] : 1'b0;
				  	
	assign sda_out = 0;
	logic [1:0] fsr;
	assign fsr = 2'b00; // Set fsr full scale range 0-2g, 1-4g, 2-8g
	always_ff @(posedge clk)
		sda_oe<= read_ack | stop_cmd | start_cmd | data;
	
	// Hook up Sdata, register and passthru
	always @(posedge clk) 
		sdata <= sda_in;
	
endmodule
	

// Accel slave, responds to I2C commands and provides 
// accell data through back door. Behavioioral, ideally synthesizable
module accel_slave (
	// System
	input  logic clk,
	input  logic reset,
	// I2C bus
    output logic sda_in     ,
    input  logic sda_oe     ,
    input  logic sda_out    ,
    output logic scl_in     ,
    input  logic scl_oe     ,
    input  logic scl_out	,
	// inner interface (from tb/model)
	// values returend when reading x,y,z.
	input  logic [11:0] x	,
	input  logic [11:0] y	,
	input  logic [11:0] z
);

endmodule

// Accel monitor: monitor the I2c bus traffic and report x,y,z as they pass by
module accel_monitor (
	// System
	input  logic clk,
	input  logic reset,
	// I2C bus
    input  logic sda,
    input  logic scl,
	// inner interface (from tb/model)
	// values returend when reading x,y,z.
	output logic strove, // valid after all 3 are stable
	output logic [11:0] x,
	output logic [11:0] y,
	output logic [11:0] z
);

endmodule


