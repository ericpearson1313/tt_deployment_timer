// vim: ts=4:
`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Replace tt_um_example with your module name:
  tt_um_deploy_timer user_project (
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

	// connect to observe signal names, makes viewing easier

	wire sda_accel_oe, sda_accel_out, sda_accel_in;
	assign sda_accel_oe = uio_oe[0];
	assign sda_accel_out= uio_out[0];
	assign sda_accel_in = uio_in[0];

	wire scl_accel_oe, scl_accel_out, scl_accel_in;
	assign scl_accel_oe = uio_oe[1];
	assign scl_accel_out= uio_out[1];
	assign sda_accel_in = uio_in[1];

	wire [3:0] dip_sw;
	assign dip_sw = ui_in[3:0];

	wire cont_sense, cont_enable;
	assign cont_sense  = ui_in[4]; // activehigh
	assign cont_enable = uo_out[0];; // active low

	wire speaker, deploy, dump, charge;
	assign speaker = uo_out[1];; // active low
	assign deploy  = uo_out[2];; // active low
	assign dump    = uo_out[3];; // active low
	assign charge  = uo_out[4];; // active low
	wire status_led;
	assign status_led = uo_out[5];

	wire reset;
	assign reset = !rst_n;
	
endmodule
