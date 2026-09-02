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
		output logic		speaker_n  ,
    	output logic 		deploy     ,
    	output logic 		dump       ,
    	output logic 		charge     ,
    	output logic 		status_led ,
    	input  logic 		sda_in     ,
    	output logic 		sda_oe     ,
    	output logic 		sda_out    ,
    	input  logic 		scl_in     ,
    	output logic 		scl_oe     ,
    	output logic 		scl_out    ,
		// fpga probes
		output logic [11:0]	x, y, z
    );

	// Tie off outputs
	//assign cont_enable = 1; // active low
	//assign speaker = 0;
	//assign speaker_n = 0;
	//assign deploy = 0;
	//assign dump = 1; // defaunt on 
	//assign charge = 0;
	assign status_led = 1; // power led
	//assign sda_oe = 0;
	//assign sda_out = 0;
	//assign scl_oe = 0;
	//assign scl_out = 0;

	// Connect Accel block to sda/scl interface

	logic [10:0] timer;
	logic x_valid;
	logic y_valid;
	logic z_valid;
	logic sdata;
	logic sample; // 100Hz, after xyz samples
	logic stop_rec;
	logic [11:0] xs, ys, zs;
	logic [2:0] start_cnt;
	accel_master i_accel (
		.clk			( clk ),
		.reset		( reset ),
		// i2c bus
		.sda_in		( sda_in  ),
		.sda_oe		( sda_oe  ),
		.sda_out		( sda_out ),
		.scl_in		( scl_in  ),
		.scl_oe 		( scl_oe  ),
		.scl_out		( scl_out ),
		.sample			(sample ), 
		.sdata			(sdata ),
		.x_valid		(x_valid),
		.y_valid		(y_valid),
		.z_valid		(z_valid),
		.record         ( { charge, dump, deploy, cont_enable, cont_sense, speaker, status_led, 
							xs[11:0], ys[11:0], zs[11:0], 
							dip_sw[3:0], timer[7:0],
                            timer[10:8], start_cnt[2:0], 2'b00 } ),
		.stop_recording ( stop_rec )
	);
	
	// Testbench fpga monitors of x,y,z
	
	always @(posedge clk) begin
		xs <= ( reset ) ? 0 : ( x_valid ) ? { xs[10:0], sdata } : xs;
		ys <= ( reset ) ? 0 : ( y_valid ) ? { ys[10:0], sdata } : ys;
		zs <= ( reset ) ? 0 : ( z_valid ) ? { zs[10:0], sdata } : zs;
		x <= ( reset ) ? 0 : ( sample ) ? xs : x;
		y <= ( reset ) ? 0 : ( sample ) ? ys : y;
		z <= ( reset ) ? 0 : ( sample ) ? zs : z;
	end

	// 100 Hz operating tick
	logic tick;
	always_ff @(posedge clk)
		tick <= sample;
	
	// Tone count of 1 sec for audio, free running
	logic [6:0] audio_cnt; // 1 sec count of 100 ticks
	always_ff @(posedge clk)
		audio_cnt <= ( reset ) ? 0 : ( sample ) ? ( ( audio_cnt == 99 ) ? 0 : audio_cnt + 1 ) : audio_cnt;

	// Continuity
	logic safe;
	always_ff @(posedge clk)
		cont_enable <= ( safe && audio_cnt >=9 && audio_cnt < 15 ) ? 1'b1 : 1'b0;
	
	logic cont_sense_q;
	always_ff @(posedge clk)
		cont_sense_q <= cont_sense;

	// Launch Detect
	logic launch_detect;
	always_ff @(posedge clk)
		launch_detect <= ( reset ) ? 0 : (x[11]^x[10]);

	// Launch Enable
	always_ff @(posedge clk)
		start_cnt <= ( reset ) ? 0 : 
						( start_cnt == 5 ) ? 5 : 
						( tick && launch_detect ) ? 0 : 
						( tick && !launch_detect ) ? start_cnt + 1 : start_cnt;
	logic launch_enable;
	assign launch_enable = ( start_cnt == 5 && launch_detect ) ? 1'b1 : 1'b0;
	

	// Speaker Tone Generator
	localparam NOTE_C8 = 13'h1665; // C8 � 4186 Hz 
	localparam NOTE_D8 = 13'h13F5; // D8 � 4698 Hz
	localparam NOTE_E8 = 13'h11C7; // E8 � 5274 Hz
	localparam NOTE_F8 = 13'h10C7; // F8 � 5588 Hz
	localparam NOTE_G8 = 13'h0EF3; // G8 � 6272 Hz
	
	logic [12:0] tone_cnt;
	logic cont_tone;
	logic spk_en, spk_toggle;
	logic done;

	always @(posedge clk) begin
		if( reset ) begin
			spk_toggle <= 0;
			spk_en <= 0;
			tone_cnt <= 0;
		end else if( tone_cnt == 0 ) begin
			spk_toggle <= !spk_toggle;
			{spk_en, tone_cnt}<= 
					( start_cnt != 5 ) ? ( ( audio_cnt[3] ) ? { 1'b1, NOTE_G8 } : 0 ) :
					( safe && audio_cnt >=  0 && audio_cnt <  5 ) ? { 1'b1, NOTE_C8 } :
					( safe && audio_cnt >= 10 && audio_cnt < 15 && !cont_sense_q) ? { 1'b1, NOTE_C8 } :
					( done ) ? (( audio_cnt < 50) ? { 1'b1, NOTE_D8 } : { 1'b1, NOTE_F8 }) : 0;
		end else begin
			tone_cnt <= tone_cnt - 1;
			spk_en <= spk_en;
			spk_toggle <= spk_toggle;
		end
	end
	
	assign speaker = spk_toggle & spk_en ; 
	assign speaker_n = !spk_toggle & spk_en ;

	// Timer

	logic [10:0] end_time, pre_time;
	assign end_time = ( dip_sw ^ 4'hF ) * 100 + 100;
	assign pre_time = end_time - 50;
	always @(posedge clk)
		timer <= ( reset ) ? 0 :
				 ( tick && timer <  25 &&  launch_enable ) ? timer + 1 :
				 ( tick && timer <  25 && !launch_enable ) ? 0 :
				 ( tick && timer >= 25 && timer < 11'h7FF ) ? timer + 1 : timer; // latch at max

	// Stop Recording 
	always @(posedge clk)
		stop_rec <= ( reset ) ? 0 : &timer | stop_rec; // 20.47 secs after launch stop recording (foreever)
	
	// Dump = safe
	assign safe = ( timer < 25 ) ? 1'b1 : 1'b0;
	always @(posedge clk)
		dump <= ( timer < 25 || timer >= end_time ) ? 1'b1 : 1'b0;

	// PreCharge (0.5 sec)
	always @(posedge clk)
		charge <= ( timer >= pre_time && timer < end_time ) ? 1'b1 : 1'b0 ;

	// Deployment (10ms)
	always @(posedge clk)
		deploy <= ( timer == end_time ) ? 1'b1 : 1'b0 ;

	// Done (drives warble, timer will saturate
	always @(posedge clk)
		done <= ( timer > end_time ) ? 1'b1 : 1'b0;
endmodule


