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
	assign sda_oe = 0;
	assign sda_out = 0;
	assign scl_oe = 0;
	assign scl_out = 0;

endmodule


