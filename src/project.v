// vim: ts=4: 
/*
 * Copyright (c) 2026 Eric Pearson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_deploy_timer(
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out[7:6]  = ( ui_in[7:5] + uio_in[7:2] ) >> 4 ;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out[7:2] = 0;
  assign uio_oe[7:2]  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, ui_in[7:5], uio_in[7:2], 1'b0};

	// Instantiate core
	ldt_core i_core (
		.clk		( clk		),
		.reset		( !rst_n 	),
		.dip_sw 	( ui_in[3:0]),
		.cont_sense	( ui_in[4]  ),
		.cont_enable( uo_out[0] ),
		.speaker	( uo_out[1] ),
		.deploy		( uo_out[2] ),
		.dump		( uo_out[3] ),
		.charge		( uo_out[4] ),
		.status_led ( uo_out[5] ),
		.sda_in		( uio_in[0] ),
		.sda_oe		( uio_oe[0] ),
		.sda_out	( uio_out[0]),
		.scl_in		( uio_in[1] ),
		.scl_oe		( uio_oe[1] ),
		.scl_out	( uio_out[1]),
		// not used
		.x(), 
		.y(),
		.z()
	);

endmodule
