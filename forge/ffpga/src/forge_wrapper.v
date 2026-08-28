// vim: ts=4:
// Top level forge FPGA
// Wraps the tiny_tapeout chip

(* top *) module forge_wrapper
(
// Forge FPGA built in clk reset

(* clkbuf_inhibit *) 	input wire clk,   // from PLL
						output wire osc_en,
// Inputs
(* iopad_external_pin *)	input  wire sw1,
(* iopad_external_pin *)	input  wire sw2,
(* iopad_external_pin *)	input  wire sw3,
(* iopad_external_pin *)	input  wire sw4,
(* iopad_external_pin *)	input  wire cont_sense,

// Output
(* iopad_external_pin *)	output wire cont_enable,
(* iopad_external_pin *)	output wire speaker,
(* iopad_external_pin *)	output wire speaker_n,
(* iopad_external_pin *)	output wire charge,
(* iopad_external_pin *)	output wire dump,
(* iopad_external_pin *)	output wire deploy,
(* iopad_external_pin *)	output wire status_led,
						output wire cont_enable_oe,
						output wire speaker_oe,
						output wire speaker_n_oe,
						output wire charge_oe,
						output wire dump_oe,
						output wire deploy_oe,
						output wire status_led_oe,

// BiDir
(* iopad_external_pin *)	output wire  sda_out,
(* iopad_external_pin *)	output wire	 sda_oe, 
(* iopad_external_pin *)	input  wire  sda_in,
(* iopad_external_pin *)	output wire  scl_out,
(* iopad_external_pin *)	output wire	 scl_oe, 
(* iopad_external_pin *)	input  wire  scl_in,
						
	// Forge PLL control
						output pll_en,
						output [5:0] pll_refdiv,
						output [11:0] pll_fbdiv,
						output [2:0] pll_postdiv1,
						output [2:0] pll_postdiv2,
						output pll_bypass,
						output pll_clk_selection,
    						input pll_lock
);

    // PLL Control, 50 Mhz int Osc Ref,  48 Mhz out
    assign pll_en = 1'b1;
    assign pll_refdiv = 6'b00_0001;		// Equivalent value in decimal form 6'd1,
    assign pll_fbdiv = 12'b0000_0001_1000;	// Equivalent value in decimal form 12'd24,
    assign pll_postdiv1 = 3'b101;		// Equivalent value in decimal form 3'd5,
    assign pll_postdiv2 = 3'b101;		// Equivalent value in decimal form 3'd5,
    assign pll_bypass = 1'b0;
    assign pll_clk_selection = 1'b0;

 
    // Enable OSC
    assign osc_en = 1'b1;
    
    // Emable GPIO Output OEs
    assign cont_enable_oe	= 1'b1;
    assign speaker_oe		= 1'b1;
    assign speaker_n_oe		= 1'b1;
    assign charge_oe			= 1'b1;
    assign dump_oe			= 1'b1;
    assign deploy_oe			= 1'b1;
    assign status_led_oe		= 1'b1;

	// Create an internal reset 
	reg [7:0] rst_cnt = 0;
	reg reset = 1;
	initial reset = 1;
	initial rst_cnt = 0;
	always @(posedge clk) begin
		rst_cnt <= ( rst_cnt != 8'hff ) ? rst_cnt + 1 : rst_cnt;
		reset <= ( rst_cnt == 8'hff ) ? 1'b0 : 1'b1;
	end
			
	// Deploy Chip CORE emulation/test
	ldt_core i_core (
		.clk			( clk		    ),
		.reset		( reset 		   	),
		// Chip Inputs
		.dip_sw 		( { sw4, sw3, sw2, sw1 } ),
		.cont_sense	( cont_sense	),
		// Chip Outputs
		.cont_enable( cont_enable	),
		.speaker		( speaker	),
		.speaker_n	( speaker_n ),
		.charge		( charge			),
		.dump		( dump			),
		.deploy		( deploy			),
		.status_led ( status_led	),
		// I2C bidir ports connection to accel
		.sda_in		( sda_in			),
		.sda_oe		( sda_oe			),
		.sda_out		( sda_out		),
		.scl_in		( scl_in			),
		.scl_oe		( scl_oe			),
		.scl_out		( scl_out		),
		// Internal monitor of accel readings
		.x	 		(  	),
		.y	 		(  	),
		.z	 		(  	)		
	);


endmodule // forge_launcher_wrapper 