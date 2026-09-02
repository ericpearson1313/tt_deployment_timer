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
	output logic z_valid,
	// Flight recoder input (big endian byte order)
	input logic [62:0] record,
	input logic stop_recording
	);

	//400 Khz cycle generator
	logic [6:0] cyc_cnt;
	always @(posedge clk) 
		cyc_cnt <= ( reset ) ? 0 : ( cyc_cnt == 119 ) ? 0 : cyc_cnt+1;
	logic ph1, ph2;
	assign ph1 = ( cyc_cnt <= 71 ) ? 1'b1 : 1'b0; // 1.5usec low on scl
	assign ph2 = ( cyc_cnt > 71 ) ? 1'b1 : 1'b0;  // 1 usec high
	
	// 11 bit times per byte
	logic [3:0] bit_cnt;
	always @(posedge clk) 
		bit_cnt <= ( reset ) ? 0 : ( cyc_cnt == 119 ) ? (( bit_cnt == 10 ) ? 0 : bit_cnt + 1 ) : bit_cnt;
		
	//363 byte counter ~= 100 Hz
	logic [8:0] byte_limit = 363;
	logic [8:0] byte_cnt;
	always @(posedge clk) 
		byte_cnt <= ( reset ) ? 0 : ( cyc_cnt == 119 && bit_cnt == 10 ) ? 
			(( byte_cnt == byte_limit ) ? 0 : byte_cnt + 1 ) : byte_cnt;
		
	// Generate sampel flag at 100Hz after the last sampel bit read.
	always @(posedge clk) 
		sample <= ( cyc_cnt == 119 && bit_cnt == 10 && byte_cnt == 11 ) ? 1'b1 : 1'b0;

	// Sample counter for address
	logic [12:0] scount;
	always @(posedge clk) 
		scount<= ( reset ) ? 0 : ( cyc_cnt == 119 && bit_cnt == 10 && byte_cnt == 11 ) ? scount + 1: scount ;
	
	// Generate the SCL;
	// during teh first 12 bytes dureing bits 1 thru 9 following ph1 for pulling the clk low
	// during bit 0 scl is high for start or stop, but low in gaps
	assign scl_out = 0; // openj collector, drive oe to get a low
	always_ff @(posedge clk) 
		scl_oe <= ( byte_cnt < 23 && bit_cnt >= 1 && bit_cnt <= 9 && ph1 ||
		            byte_cnt < 23 && bit_cnt == 10 ||
                    byte_cnt >= 1 && byte_cnt < 23 && byte_cnt != 3 && byte_cnt != 5 && byte_cnt != 12 && bit_cnt == 0  ) ? 1 : 0;
		
	// Generatge the sampel pulses
	// duroign bytes 5-10, bits 1 - 8, then 1 - 4, at rising edge of clk cyc_cnt 71 )
	always @(posedge clk) begin
		x_valid <= 	( byte_cnt == 6 && bit_cnt >= 1 && bit_cnt <= 8 && cyc_cnt == 71 ) ? 1 : 
					( byte_cnt == 7 && bit_cnt >= 1 && bit_cnt <= 4 && cyc_cnt == 71 ) ? 1 : 0;					
		y_valid <= 	( byte_cnt == 8 && bit_cnt >= 1 && bit_cnt <= 8 && cyc_cnt == 71 ) ? 1 : 
					( byte_cnt == 9 && bit_cnt >= 1 && bit_cnt <= 4 && cyc_cnt == 71 ) ? 1 : 0;
		z_valid <= 	( byte_cnt == 10&& bit_cnt >= 1 && bit_cnt <= 8 && cyc_cnt == 71 ) ? 1 : 
					( byte_cnt == 11&& bit_cnt >= 1 && bit_cnt <= 4 && cyc_cnt == 71 ) ? 1 : 0;
	end
	
	// Sda. Open collector
	// Has to generate the write data, read data tristates, start and stops.
	// 11 bytes
	// 0:  { 7'h15, 1'b0 }, 1: { 8'h0d }, 2: { 1'h0, fsr[1:0], 5'h0 } // write init accel
	// 3:  { 7'h15, 1'b0 }, 4: { 8'h03 },  // write the read address
	// 5:  { 7'h15, 1'b1 }, // read the data regs
	// 6:  { 8'bzzzzzzzz }, 7: { 8'bzzzzxxxx}  // read x direcxiton msb fist [11:4], [3:0]
	// 8:  { 8'bzzzzzzzz }, 9: { 8'bzzzzxxxx}  // read y direcxiton
	// 10: { 8'bzzzzzzzz }, 11:{ 8'bzzzzxxxx}  // read z direcxiton, finish with stop
	// 12: { 7'hA0, 1'b0 }, 13: { 1'b0, scount[11:5] }, 14: { scount[4:0], 3'b000 } // Fram write address
	// 15: { scount[12], dbyte[0][6:0]] }, n=16..22 : { dbyte[n-15] } // Fram write data

	// Upon reasd, and ack, the sda shoudl be driven 0 during ph1 of bit 9
	logic read_ack;
	always_ff @(posedge clk)
		read_ack <= ( byte_cnt >= 6 && byte_cnt <= 11 && bit_cnt == 9 ) ? 1'b1 : 1'b0;
			
	// for a stop, the the sda should be driven during ph2 of bit 9 during byte 10
	logic stop_cmd;
	always_ff @(posedge clk)
		stop_cmd <= ( byte_cnt == 23 && bit_cnt == 0 && ph1 ) ? 1'b1 : 1'b0;

	logic pre_stop;
	always_ff @(posedge clk) 
		pre_stop <= ( byte_cnt == 22 && bit_cnt == 10 ) ? 1'b1 : 1'b0;
	
	// for a start, the sda should be driven to 0 during ph2 of bit 0
	logic start_cmd;
	always_ff @(posedge clk)
		start_cmd <= ( byte_cnt < 23 && bit_cnt == 0 && ph2 ) ? 1'b1 : 1'b0;
	
	// Otherwise data bits shall be driven durign bytes 0 to 4, msb fist during bits 1 to 8
	logic [0:7] cmd_write = { 7'h15, 1'b0 }; // write accel
	logic [0:7] init_addr = { 8'h0d };
	logic [0:7] init_data = { 1'b0, /*fsr =*/2'b01, 5'h00 };
	logic [0:7] read_addr = { 8'h03 };
	logic [0:7] cmd_read  = { 7'h15, 1'b1 }; // read accel
	logic [0:7] cmd_write2; //= { 7'b1010000, 1'b0 }; // write fram
	assign cmd_write2= ( stop_recording ) ? 8'hFe : 8'hA0; // write fram (or write nowhere)
	logic [0:7] cmd_haddr, cmd_laddr;
	assign cmd_haddr = { 1'b0, scount[11:5] };
	assign cmd_laddr = { scount[4:0], 3'b000  };
	logic [0:7][0:7] dbyte;
	assign dbyte = { scount[12], record[62:0] };
	// index into bytges based on bit_cnt
	logic [2:0] idx;
	assign idx = bit_cnt - 1;
	// skip inactive bytes, then per byte mux.
	logic data;
	always_ff @(posedge clk)
		data <=   ( byte_cnt >= 6 && byte_cnt <= 11 ) ? 1'b0 : // read during bytes 6 thru 11
				  ( bit_cnt == 0 || bit_cnt == 9 || bit_cnt == 10 ) ? 1'b0 : // no data other than bits 1 thru 8
				  // accel init
				  ( byte_cnt == 0 ) ? !cmd_write[idx] :
				  ( byte_cnt == 1 ) ? !init_addr[idx] :
				  ( byte_cnt == 2 ) ? !init_data[idx] :
				  // accel read
				  ( byte_cnt == 3 ) ? !cmd_write[idx] :
				  ( byte_cnt == 4 ) ? !read_addr[idx] : 
				  ( byte_cnt == 5 ) ? !cmd_read [idx] : 
				  // Fram write
				  ( byte_cnt == 12 ) ? !cmd_write2[idx] : 
				  ( byte_cnt == 13 ) ? !cmd_haddr[idx] :
				  ( byte_cnt == 14 ) ? !cmd_laddr[idx] :
				  // Fram data
				  ( byte_cnt == 15 ) ? !dbyte[0][idx] :
				  ( byte_cnt == 16 ) ? !dbyte[1][idx] :
				  ( byte_cnt == 17 ) ? !dbyte[2][idx] :
				  ( byte_cnt == 18 ) ? !dbyte[3][idx] :
				  ( byte_cnt == 19 ) ? !dbyte[4][idx] :
				  ( byte_cnt == 20 ) ? !dbyte[5][idx] :
				  ( byte_cnt == 21 ) ? !dbyte[6][idx] :
				  ( byte_cnt == 22 ) ? !dbyte[7][idx] : 1'b0;
				  	
	assign sda_out = 0;
	logic [1:0] fsr;
	assign fsr = 2'b00; // Set fsr full scale range 0-2g, 1-4g, 2-8g
	always_ff @(posedge clk)
		sda_oe<= read_ack | stop_cmd | start_cmd | data | pre_stop;
	
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
	input  logic en,
	// I2C bus
    input  logic sda     ,
    output logic sda_oe  ,
    input  logic scl     ,
	// inner interface (from tb/model)
	// values returend when reading x,y,z.
	input  logic [11:0] x	,
	input  logic [11:0] y	,
	input  logic [11:0] z
);

	// Deterine events
	logic sda_del, scl_del;
	logic start, stop, rise, fall; // edges to detect
	always_ff @(posedge clk) begin
		sda_del <= ( reset ) ? 1 : ( en ) ? sda : sda_del;
		scl_del <= ( reset ) ? 1 : ( en ) ? scl : scl_del;
		start <= en & scl & scl_del & !sda &  sda_del;
		stop  <= en & scl & scl_del &  sda & !sda_del;
		rise <=  en & scl & !scl_del;
		fall <=  en & !scl & scl_del;
	end
	
	// count starts, stops, and rising edges
	logic [2:0] start_cnt;
	logic [6:0] rise_cnt; // Max 6 * 9
	logic [6:0] fall_cnt; // Max 6 * 9
	always_ff @(posedge clk) begin
		start_cnt <= ( reset ) ? 0 : ( stop ) ? 0 : ( start ) ? start_cnt + 1 : start_cnt;
		rise_cnt  <= ( reset ) ? 0 : ( start ) ? 0 : ( rise ) ? rise_cnt  + 1 : rise_cnt ;
		fall_cnt  <= ( reset ) ? 0 : ( start ) ? 0 : ( fall ) ? fall_cnt  + 1 : fall_cnt ;
	end

	// Really just want to index into a bit array indexed by fall count
	logic [0:6*9-1] inbuf;
	assign inbuf = { x[11:4], 1'b0, x[3:0], 4'b0000, 1'b0,
	                 y[11:4], 1'b0, y[3:0], 4'b0000, 1'b0,
	                 z[11:4], 1'b0, z[3:0], 4'b0000, 1'b0 };
	logic [5:0] idx;
	assign idx = fall_cnt - 10;
	logic data;
	assign data = inbuf[idx];
	
	// Control generation of acks for all 3 bytes of first msg
	// and first 2 of 8 bytes of 2nd message
	logic ack;
	assign ack = ( start_cnt == 1 && fall_cnt == 1+0*9+8  ||
                   start_cnt == 1 && fall_cnt == 1+1*9+8  ||
                   start_cnt == 1 && fall_cnt == 1+2*9+8  ||
                   start_cnt == 2 && fall_cnt == 1+0*9+8  ||
                   start_cnt == 2 && fall_cnt == 1+1*9+8  ||
                   start_cnt == 3 && fall_cnt == 1+0*9+8  ||
				   start_cnt == 4 && fall_cnt == 1+0*9*8  ||
				   start_cnt == 4 && fall_cnt == 1+1*9*8  ||
				   start_cnt == 4 && fall_cnt == 1+2*9*8  ) ? 1'b1 : 1'b0;

	// Control when the sda_oe can be driven high with !data
	logic dval;
	assign dval = ( start_cnt == 3 && fall_cnt >= 1+1*9 && fall_cnt <= 1+6*9+7 ) ? 1'b1 : 1'b0;

	// Drive SDA Pin
	assign sda_oe = ( ack ) ? 1 : ( dval ) ? !data : 0;

endmodule

// Accel monitor: monitor the I2c bus traffic and report x,y,z as they pass by
// External metastability flops and filtering
module accel_monitor (
	// System
	input  logic clk,
	input  logic reset,
	input  logic en, // Allows LPF 
	// I2C bus
    input  logic sda,
    input  logic scl,
	// Dump observed bytes
	output logic [7:0] data,
	output logic data_strobe,
	// inner interface (from tb/model)
	// values returend when reading x,y,z.
	output logic strobe, // valid after all 3 are stable
	output logic [11:0] x,
	output logic [11:0] y,
	output logic [11:0] z
);

	// Deterine events
	logic sda_del, scl_del;
	logic start, stop, rise, fall; // edges to detect
	always_ff @(posedge clk) begin
		sda_del <= ( reset ) ? 1 : ( en ) ? sda : sda_del;
		scl_del <= ( reset ) ? 1 : ( en ) ? scl : scl_del;
		start <= en & scl & scl_del & !sda &  sda_del;
		stop  <= en & scl & scl_del &  sda & !sda_del;
		rise <=  en & scl & !scl_del;
		fall <=  en & !scl & scl_del;
	end
	
	// count starts, stops, and rising edges
	logic [2:0] start_cnt;
	logic [6:0] rise_cnt; // Max 8 * 9 = 72
	logic [3:0] bit_cnt;
	always_ff @(posedge clk) begin
		start_cnt <= ( reset ) ? 0 : ( stop ) ? 0 : ( start ) ? start_cnt + 1 : start_cnt;
		rise_cnt  <= ( reset ) ? 0 : ( start ) ? 0 : ( rise ) ? rise_cnt  + 1 : rise_cnt ;
		bit_cnt   <= ( reset ) ? 0 : ( start ) ? 0 : ( rise && bit_cnt == 8 ) ? 0 : ( rise ) ? bit_cnt + 1 : bit_cnt;
	end

	// Shift data into regisers MSB first
	// start_cnt == 3,
	// sample sda at rise, 
	// X rise_cnt = 2*9+;8, 3*9+:4
	// Y rise_cnt = 4*9+;8, 5*9+:4
	// Z rise_cnt = 6*9+;8, 7*9+:4
	logic enx, eny, enz, endat;
	assign enx = (( start_cnt == 3 && rise && rise_cnt >= 1*9 && rise_cnt < 1*9+8 ) ||
				  ( start_cnt == 3 && rise && rise_cnt >= 2*9 && rise_cnt < 2*9+4 ) ) ? 1'b1 : 1'b0;
	assign eny = (( start_cnt == 3 && rise && rise_cnt >= 3*9 && rise_cnt < 3*9+8 ) ||
				  ( start_cnt == 3 && rise && rise_cnt >= 4*9 && rise_cnt < 4*9+4 ) ) ? 1'b1 : 1'b0;
	assign enz = (( start_cnt == 3 && rise && rise_cnt >= 5*9 && rise_cnt < 5*9+8 ) ||
				  ( start_cnt == 3 && rise && rise_cnt >= 6*9 && rise_cnt < 6*9+4 ) ) ? 1'b1 : 1'b0;
	assign endat = ( bit_cnt <= 7 && rise  ) ? 1'b1 : 1'b0;

	logic [11:0] sregx, sregy, sregz;
	logic [7:0] sdata;
	always_ff @(posedge clk) begin
			sregx <= ( reset ) ? 0 : ( enx ) ? { sregx[10:0], sda } : sregx;
			sregy <= ( reset ) ? 0 : ( eny ) ? { sregy[10:0], sda } : sregy;
			sregz <= ( reset ) ? 0 : ( enz ) ? { sregz[10:0], sda } : sregz;
			sdata <= ( reset ) ? 0 : ( endat  ) ? { sdata[6:0], sda } : sdata;
			x <= ( reset ) ? 0 : ( stop ) ? sregx : x;
			y <= ( reset ) ? 0 : ( stop ) ? sregy : y;
			z <= ( reset ) ? 0 : ( stop ) ? sregz : z;
			data <= ( reset ) ? 0 : ( bit_cnt == 8 && rise ) ? sdata : data;
			data_strobe <= ( bit_cnt == 8 && rise ) ? 1'b1 : 1'b0;
			strobe <= stop;
	end
	
endmodule


