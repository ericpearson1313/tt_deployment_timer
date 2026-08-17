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
	output logic ready,
	input logic sample,
	// serial data interface and valid
	output logic sdata,
	output logic x_valid,
	output logic y_valid,
	output logic z_valid
	);

	// Tie off outputs
	assign sda_oe  = 0;
	assign sda_out = 0;
	assign scl_oe  = 0;
	assign scl_out = 0;
	assign ready   = 0;
	assign sdata   = 0;
	assign x_valid = 0;
	assign y_valid = 0;
	assign z_valid = 0;

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


