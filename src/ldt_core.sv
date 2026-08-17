// vim: ts=4: 
/*
 * Copyright (c) 2026 Eric Pearson
 * SPDX-License-Identifier: Apache-2.0
 */

// The LDT launch delay timer core
module ldt_core (
		input  logic 		clk,
		input  logic 		reset,
    	input  logic  [3:0] dip_sw,
    	input  logic 		cont_sense ,
    	output logic 		cont_enable,
    	output logic 		speaker    ,
    	output logic 		deploy     ,
    	output logic 		dump       ,
    	output logic 		charge     ,
    	output logic 		status_led ,
    	input  logic 		sda_in     ,
    	output logic 		sda_oe     ,
    	output logic 		sda_out    ,
    	input  logic 		scl_in     ,
    	output logic 		scl_oe     ,
    	output logic 		scl_out    
    );

	// Tie off outputs
	assign cont_enable = 1; // active low
	assign speaker = 0;
	assign deploy = 0;
	assign dump = 1; // defaunt on 
	assign charge = 0;
	assign status_led = 1; // power led
	//assign sda_oe = 0;
	//assign sda_out = 0;
	//assign scl_oe = 0;
	//assign scl_out = 0;

	// Connect Accel block to sda/scl interface
	accel_master i_accel (
		.clk		( clk ),
		.reset		( reset ),
		// i2c bus
		.sda_in		( sda_in  ),
		.sda_oe		( sda_oe  ),
		.sda_out	( sda_out ),
		.scl_in		( scl_in  ),
		.scl_oe 	( scl_oe  ),
		.scl_out	( scl_out ),
		// Status
		.ready 		( ),
		.sample		( ), 
		// Data
		.sdata		( ),
		.x_valid	( ),
		.y_valid	( ),
		.z_valid	( )
	);

	// Launch Detect
	
	// Continuity

	// Speaker Tone Generator

	// Timer

	// PreCharge

	// Deployment

	// Recovery Warble

endmodule


