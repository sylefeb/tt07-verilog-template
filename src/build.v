`define PMOD_QQSPI 1
`define SPISCREEN_EXTRA 1
`define SIM_SB_IO 1
/*

Copyright 2019, (C) Sylvain Lefebvre and contributors
List contributors with: git shortlog -n -s -- <filename>

MIT license

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(header_2_M)

*/
`define ICESTICK 1
`define ICE40 1
`default_nettype none
// declare package pins (has to match the hardware pin definition)
// pin.NAME = <WIDTH>
// pin groups and renaming
//

module top(
  output D1,
output D2,
output D3,
output D4,
output D5,
output PMOD1,
output PMOD10,
inout  PMOD2,
inout  PMOD3,
output PMOD4,
inout  PMOD7,
inout  PMOD8,
output PMOD9,
output TR3,
output TR4,
output TR5,
output TR6,
output TR7,

  input  CLK
  );

// the init sequence pauses for some cycles
// waiting for BRAM init to stabalize
// this is a known issue with ice40 FPGAs
// https://github.com/YosysHQ/icestorm/issues/76

reg ready = 0;
reg [23:0] RST_d;
reg [23:0] RST_q;

always @* begin
  RST_d = RST_q[23] ? RST_q : RST_q + 1;
end

always @(posedge CLK) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 0;
  end
end

wire run_main;
assign run_main = 1'b1;



M_main __main(
  .clock(CLK),
  .reset(~RST_q[23]),
  .out_leds({D5,D4,D3,D2,D1}),
.out_ram_bank({PMOD10,PMOD9}),
.out_ram_clk({PMOD4}),
.out_ram_csn({PMOD1}),
.inout_ram_io0({PMOD2}),
.inout_ram_io1({PMOD3}),
.inout_ram_io2({PMOD7}),
.inout_ram_io3({PMOD8}),
.out_spiscreen_clk({TR4}),
.out_spiscreen_csn({TR5}),
.out_spiscreen_dc({TR6}),
.out_spiscreen_mosi({TR3}),
.out_spiscreen_resn({TR7}),

  .in_run(run_main)
);

endmodule
// NOTE: this is a modified exerpt from Yosys ice40 cell_sim.v
// WARNING: heavily hacked and does not support some cases (unregistered output, inverted output)

`timescale 1ps / 1ps
// `define SB_DFF_INIT initial Q = 0;
// `define SB_DFF_INIT

// SiliconBlue IO Cells

module _SB_IO (
	// inout  PACKAGE_PIN,
  input  PACKAGE_PIN_I,
  output PACKAGE_PIN_O,
  output PACKAGE_PIN_OE,

	//input  LATCH_INPUT_VALUE,
	//input  CLOCK_ENABLE,
	input  INPUT_CLK,
	input  OUTPUT_CLK,
	input  OUTPUT_ENABLE,
	input  D_OUT_0,
	input  D_OUT_1,
	output D_IN_0,
	output D_IN_1
);
	parameter [5:0] PIN_TYPE = 6'b000000;
	parameter [0:0] PULLUP = 1'b0;
	parameter [0:0] NEG_TRIGGER = 1'b0;
	parameter IO_STANDARD = "SB_LVCMOS";

	reg dout, din_0, din_1;
	reg din_q_0, din_q_1;
	reg dout_q_0, dout_q_1;
	reg outena_q;

  wire CLOCK_ENABLE;
  assign CLOCK_ENABLE = 1'b1;
  wire LATCH_INPUT_VALUE;
  assign LATCH_INPUT_VALUE = 1'b0;

	// IO tile generates a constant 1'b1 internally if global_cen is not connected

	generate if (!NEG_TRIGGER) begin
		always @(posedge INPUT_CLK)  din_q_0         <= PACKAGE_PIN_I;
		always @(negedge INPUT_CLK)  din_q_1         <= PACKAGE_PIN_I;
		always @(posedge OUTPUT_CLK) dout_q_0        <= D_OUT_0;
		always @(negedge OUTPUT_CLK) dout_q_1        <= D_OUT_1;
		always @(posedge OUTPUT_CLK) outena_q        <= OUTPUT_ENABLE;
	end else begin
		always @(negedge INPUT_CLK)  din_q_0         <= PACKAGE_PIN_I;
		always @(posedge INPUT_CLK)  din_q_1         <= PACKAGE_PIN_I;
		always @(negedge OUTPUT_CLK) dout_q_0        <= D_OUT_0;
		always @(posedge OUTPUT_CLK) dout_q_1        <= D_OUT_1;
		always @(negedge OUTPUT_CLK) outena_q        <= OUTPUT_ENABLE;
	end endgenerate

	always @* begin
		//if (!PIN_TYPE[1] || !LATCH_INPUT_VALUE)
	  din_0 = PIN_TYPE[0] ? PACKAGE_PIN_I : din_q_0;
		din_1 = din_q_1;
	end

	// work around simulation glitches on dout in DDR mode
	//reg outclk_delayed_1;
	//reg outclk_delayed_2;
	//always @* outclk_delayed_1 <= OUTPUT_CLK;
	//always @* outclk_delayed_2 <= outclk_delayed_1;

	always @* begin
		//if (PIN_TYPE[3])
	  //  dout = PIN_TYPE[2] ? !dout_q_0 : D_OUT_0;
		//else
		dout = (/*outclk_delayed_2*/OUTPUT_CLK ^ NEG_TRIGGER) || PIN_TYPE[2] ? dout_q_0 : dout_q_1;
	end

	assign D_IN_0 = din_0, D_IN_1 = din_1;

	generate
    assign PACKAGE_PIN_O = dout;
		if (PIN_TYPE[5:4] == 2'b01) assign PACKAGE_PIN_OE = 1'b1;
		if (PIN_TYPE[5:4] == 2'b10) assign PACKAGE_PIN_OE = OUTPUT_ENABLE;
		if (PIN_TYPE[5:4] == 2'b11) assign PACKAGE_PIN_OE = outena_q;
	endgenerate

endmodule


`ifndef PASSTHROUGH
`define PASSTHROUGH

module passthrough(
	input  inv,
  output outv);

assign outv = inv;

endmodule

`endif


// SL 2021-12-12
// produces an inverted clock of same frequency through DDR primitives

`ifndef DDR_CLOCK
`define DDR_CLOCK

module ddr_clock(
        input  clock,
        input  enable,
        output ddr_clock
    );

`ifdef ICE40

`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(6'b1100_01)
  ) sbio_clk (
      .PACKAGE_PIN(ddr_clock),
      .D_OUT_0(1'b0),
      .D_OUT_1(1'b1),
      .OUTPUT_ENABLE(enable),
      .OUTPUT_CLK(clock)
  );

`else

`ifdef ECP5

reg rnenable;

ODDRX1F oddr
      (
        .Q(ddr_clock),
        .D0(1'b0),
        .D1(1'b1),
        .SCLK(clock),
        .RST(~enable)
      );

always @(posedge clock) begin
  rnenable <= ~enable;
end

`else

  reg renable;
  reg rddr_clock;
  always @(posedge clock) begin
    rddr_clock <= 0;
    renable    <= enable;
  end
  always @(negedge clock) begin
    rddr_clock <= renable;
  end
  assign ddr_clock = rddr_clock;

`endif
`endif

endmodule

`endif


`ifndef ICE40_SB_IO_INOUT
`define ICE40_SB_IO_INOUT

module sb_io_inout #(parameter TYPE=6'b1101_00) (
  input        clock,
	input        oe,
  input        out,
	output       in,
  inout        pin
  );

  wire unused;

`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(TYPE)
  ) sbio (
      .PACKAGE_PIN(pin),
			.OUTPUT_ENABLE(oe),
      .D_OUT_0(out),
      .D_OUT_1(out),
      .D_IN_0(unused),
			.D_IN_1(in),
      .OUTPUT_CLK(clock),
      .INPUT_CLK(clock)
  );

endmodule

`endif

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf


`ifndef ICE40_SB_IO
`define ICE40_SB_IO

module sb_io(
  input        clock,
  input        out,
  output       pin
  );
`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(6'b0101_01)
    //                ^^ ignored (input)
    //           ^^^^ registered output
  ) sbio (
      .PACKAGE_PIN(pin),
      .D_OUT_0(out),
      .OUTPUT_ENABLE(1'b1),
      .OUTPUT_CLK(clock)
  );

endmodule

`endif

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf


module M_spi_mode3_send_M_main_display (
in_enable,
in_data_or_command,
in_byte,
out_spi_clk,
out_spi_mosi,
out_spi_dc,
out_ready,
reset,
out_clock,
clock
);
input  [0:0] in_enable;
input  [0:0] in_data_or_command;
input  [7:0] in_byte;
output  [0:0] out_spi_clk;
output  [0:0] out_spi_mosi;
output  [0:0] out_spi_dc;
output  [0:0] out_ready;
input reset;
output out_clock;
input clock;
assign out_clock = clock;

reg  [1:0] _d_osc;
reg  [1:0] _q_osc;
reg  [0:0] _d_dc;
reg  [0:0] _q_dc;
reg  [8:0] _d_sending;
reg  [8:0] _q_sending;
reg  [8:0] _d_busy;
reg  [8:0] _q_busy;
reg  [0:0] _d_spi_clk;
reg  [0:0] _q_spi_clk;
reg  [0:0] _d_spi_mosi;
reg  [0:0] _q_spi_mosi;
reg  [0:0] _d_spi_dc;
reg  [0:0] _q_spi_dc;
reg  [0:0] _d_ready;
reg  [0:0] _q_ready;
assign out_spi_clk = _q_spi_clk;
assign out_spi_mosi = _q_spi_mosi;
assign out_spi_dc = _q_spi_dc;
assign out_ready = _q_ready;



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_osc = _q_osc;
_d_dc = _q_dc;
_d_sending = _q_sending;
_d_busy = _q_busy;
_d_spi_clk = _q_spi_clk;
_d_spi_mosi = _q_spi_mosi;
_d_spi_dc = _q_spi_dc;
_d_ready = _q_ready;
// _always_pre
// __block_1
_d_spi_dc = _q_dc;

_d_osc = _q_busy[0+:1] ? {_q_osc[0+:1],_q_osc[1+:1]}:2'b1;

_d_spi_clk = ~_q_busy[0+:1]||(_d_osc[1+:1]);

_d_ready = ~_q_busy[1+:1];

if (in_enable) begin
// __block_2
// __block_4
_d_dc = in_data_or_command;

_d_sending = {in_byte[0+:1],in_byte[1+:1],in_byte[2+:1],in_byte[3+:1],in_byte[4+:1],in_byte[5+:1],in_byte[6+:1],in_byte[7+:1],1'b0};

_d_busy = 9'b111111111;

_d_osc = 1;

// __block_5
end else begin
// __block_3
// __block_6
_d_spi_mosi = _q_sending[0+:1];

_d_sending = _d_osc[1+:1] ? {1'b0,_q_sending[1+:8]}:_q_sending;

_d_busy = _d_osc[1+:1] ? {1'b0,_q_busy[1+:8]}:_q_busy;

// __block_7
end
// 'after'
// __block_8
// __block_9
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_osc <= (reset) ? 1 : _d_osc;
_q_dc <= (reset) ? 0 : _d_dc;
_q_sending <= (reset) ? 0 : _d_sending;
_q_busy <= (reset) ? 0 : _d_busy;
_q_spi_clk <= _d_spi_clk;
_q_spi_mosi <= _d_spi_mosi;
_q_spi_dc <= _d_spi_dc;
_q_ready <= _d_ready;
end

endmodule


module M_qpsram_qspi_M_main_terrain_ram_spi (
in_send,
in_trigger,
in_send_else_read,
out_read,
out_clk,
out_csn,
inout_io0_i,
inout_io0_o,
inout_io0_oe,
inout_io1_i,
inout_io1_o,
inout_io1_oe,
inout_io2_i,
inout_io2_o,
inout_io2_oe,
inout_io3_i,
inout_io3_o,
inout_io3_oe,
reset,
out_clock,
clock
);
input  [7:0] in_send;
input  [0:0] in_trigger;
input  [0:0] in_send_else_read;
output  [7:0] out_read;
output  [0:0] out_clk;
output  [0:0] out_csn;
input   [0:0] inout_io0_i;
output  [0:0] inout_io0_o;
output  [0:0] inout_io0_oe;
input   [0:0] inout_io1_i;
output  [0:0] inout_io1_o;
output  [0:0] inout_io1_oe;
input   [0:0] inout_io2_i;
output  [0:0] inout_io2_o;
output  [0:0] inout_io2_oe;
input   [0:0] inout_io3_i;
output  [0:0] inout_io3_o;
output  [0:0] inout_io3_oe;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [0:0] _w_ddr_clock_unnamed_4_ddr_clock;
wire  [0:0] _w_sb_io_inout_unnamed_5_in;
wire  [0:0] _w_sb_io_inout_unnamed_6_in;
wire  [0:0] _w_sb_io_inout_unnamed_7_in;
wire  [0:0] _w_sb_io_inout_unnamed_8_in;
wire  [0:0] _w_sb_io_unnamed_9_pin;
reg  [3:0] _t_io_oe;
reg  [3:0] _t_io_o;
reg  [0:0] _t_chip_select;

reg  [7:0] _d_sending = 0;
reg  [7:0] _q_sending = 0;
reg  [0:0] _d_osc = 0;
reg  [0:0] _q_osc = 0;
reg  [0:0] _d_enable = 0;
reg  [0:0] _q_enable = 0;
reg  [7:0] _d_read;
reg  [7:0] _q_read;
assign out_read = _q_read;
assign out_clk = _w_ddr_clock_unnamed_4_ddr_clock;
assign out_csn = _w_sb_io_unnamed_9_pin;
ddr_clock ddr_clock_unnamed_4 (
.clock(clock),
.enable(_q_enable),
.ddr_clock(_w_ddr_clock_unnamed_4_ddr_clock));
sb_io_inout #(
.TYPE(6'b1101_00)
)
sb_io_inout_unnamed_5 (
.clock(clock),
.oe(_t_io_oe[0+:1]),
.out(_t_io_o[0+:1]),
.in(_w_sb_io_inout_unnamed_5_in),
.pin_i(inout_io0_i),
.pin_o(inout_io0_o),
.pin_oe(inout_io0_oe)
);
sb_io_inout #(
.TYPE(6'b1101_00)
)
sb_io_inout_unnamed_6 (
.clock(clock),
.oe(_t_io_oe[1+:1]),
.out(_t_io_o[1+:1]),
.in(_w_sb_io_inout_unnamed_6_in),
.pin_i(inout_io1_i),
.pin_o(inout_io1_o),
.pin_oe(inout_io1_oe)
);
sb_io_inout #(
.TYPE(6'b1101_00)
)
sb_io_inout_unnamed_7 (
.clock(clock),
.oe(_t_io_oe[2+:1]),
.out(_t_io_o[2+:1]),
.in(_w_sb_io_inout_unnamed_7_in),
.pin_i(inout_io2_i),
.pin_o(inout_io2_o),
.pin_oe(inout_io2_oe)
);
sb_io_inout #(
.TYPE(6'b1101_00)
)
sb_io_inout_unnamed_8 (
.clock(clock),
.oe(_t_io_oe[3+:1]),
.out(_t_io_o[3+:1]),
.in(_w_sb_io_inout_unnamed_8_in),
.pin_i(inout_io3_i),
.pin_o(inout_io3_o),
.pin_oe(inout_io3_oe)
);
sb_io sb_io_unnamed_9 (
.clock(clock),
.out(_t_chip_select),
.pin(_w_sb_io_unnamed_9_pin));



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_sending = _q_sending;
_d_osc = _q_osc;
_d_enable = _q_enable;
_d_read = _q_read;
// _always_pre
// __block_1
_t_chip_select = ~(in_trigger|_q_enable);

_t_io_oe = {4{in_send_else_read}};

_d_read = {_q_read[0+:4],{_w_sb_io_inout_unnamed_8_in[0+:1],_w_sb_io_inout_unnamed_7_in[0+:1],_w_sb_io_inout_unnamed_6_in[0+:1],_w_sb_io_inout_unnamed_5_in[0+:1]}};

_t_io_o = ~_q_osc ? _q_sending[0+:4]:_q_sending[4+:4];

_d_sending = (~_q_osc|~_q_enable) ? in_send:_q_sending;

_d_osc = ~in_trigger ? 1'b0:~_q_osc;

_d_enable = in_trigger;

// __block_2
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_sending <= _d_sending;
_q_osc <= _d_osc;
_q_enable <= _d_enable;
_q_read <= _d_read;
end

endmodule


module M_qpsram_ram_M_main_terrain_ram (
in_in_ready,
in_init,
in_addr,
in_wdata,
in_wenable,
out_rdata,
out_busy,
out_data_next,
out_ram_csn,
out_ram_clk,
inout_ram_io0_i,
inout_ram_io0_o,
inout_ram_io0_oe,
inout_ram_io1_i,
inout_ram_io1_o,
inout_ram_io1_oe,
inout_ram_io2_i,
inout_ram_io2_o,
inout_ram_io2_oe,
inout_ram_io3_i,
inout_ram_io3_o,
inout_ram_io3_oe,
reset,
out_clock,
clock
);
input  [0:0] in_in_ready;
input  [0:0] in_init;
input  [23:0] in_addr;
input  [7:0] in_wdata;
input  [0:0] in_wenable;
output  [7:0] out_rdata;
output  [0:0] out_busy;
output  [0:0] out_data_next;
output  [0:0] out_ram_csn;
output  [0:0] out_ram_clk;
input   [0:0] inout_ram_io0_i;
output  [0:0] inout_ram_io0_o;
output  [0:0] inout_ram_io0_oe;
input   [0:0] inout_ram_io1_i;
output  [0:0] inout_ram_io1_o;
output  [0:0] inout_ram_io1_oe;
input   [0:0] inout_ram_io2_i;
output  [0:0] inout_ram_io2_o;
output  [0:0] inout_ram_io2_oe;
input   [0:0] inout_ram_io3_i;
output  [0:0] inout_ram_io3_o;
output  [0:0] inout_ram_io3_oe;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [7:0] _w_spi_read;
wire  [0:0] _w_spi_clk;
wire  [0:0] _w_spi_csn;
reg  [0:0] _t_accept_in;

reg  [31:0] _d_sendvec = 0;
reg  [31:0] _q_sendvec = 0;
reg  [7:0] _d__spi_send;
reg  [7:0] _q__spi_send;
reg  [0:0] _d__spi_trigger;
reg  [0:0] _q__spi_trigger;
reg  [0:0] _d__spi_send_else_read;
reg  [0:0] _q__spi_send_else_read;
reg  [2:0] _d_stage = 1;
reg  [2:0] _q_stage = 1;
reg  [4:0] _d_wait = 0;
reg  [4:0] _q_wait = 0;
reg  [2:0] _d_after = 0;
reg  [2:0] _q_after = 0;
reg  [4:0] _d_sending = 0;
reg  [4:0] _q_sending = 0;
reg  [0:0] _d_send_else_read = 0;
reg  [0:0] _q_send_else_read = 0;
reg  [0:0] _d_continue = 0;
reg  [0:0] _q_continue = 0;
reg  [7:0] _d_rdata;
reg  [7:0] _q_rdata;
reg  [0:0] _d_busy = 0;
reg  [0:0] _q_busy = 0;
reg  [0:0] _d_data_next = 0;
reg  [0:0] _q_data_next = 0;
assign out_rdata = _q_rdata;
assign out_busy = _q_busy;
assign out_data_next = _q_data_next;
assign out_ram_csn = _w_spi_csn;
assign out_ram_clk = _w_spi_clk;
M_qpsram_qspi_M_main_terrain_ram_spi spi (
.in_send(_q__spi_send),
.in_trigger(_q__spi_trigger),
.in_send_else_read(_q__spi_send_else_read),
.out_read(_w_spi_read),
.out_clk(_w_spi_clk),
.out_csn(_w_spi_csn),
.inout_io0_i(inout_ram_io0_i),
.inout_io0_o(inout_ram_io0_o),
.inout_io0_oe(inout_ram_io0_oe),
.inout_io1_i(inout_ram_io1_i),
.inout_io1_o(inout_ram_io1_o),
.inout_io1_oe(inout_ram_io1_oe),
.inout_io2_i(inout_ram_io2_i),
.inout_io2_o(inout_ram_io2_o),
.inout_io2_oe(inout_ram_io2_oe),
.inout_io3_i(inout_ram_io3_i),
.inout_io3_o(inout_ram_io3_o),
.inout_io3_oe(inout_ram_io3_oe),
.reset(reset),
.clock(clock));



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_sendvec = _q_sendvec;
_d__spi_send = _q__spi_send;
_d__spi_trigger = _q__spi_trigger;
_d__spi_send_else_read = _q__spi_send_else_read;
_d_stage = _q_stage;
_d_wait = _q_wait;
_d_after = _q_after;
_d_sending = _q_sending;
_d_send_else_read = _q_send_else_read;
_d_continue = _q_continue;
_d_rdata = _q_rdata;
_d_busy = _q_busy;
_d_data_next = _q_data_next;
// _always_pre
// __block_1
_d__spi_send_else_read = _q_send_else_read;

_t_accept_in = 0;

_d_data_next = 0;

_d_continue = _q_continue&in_in_ready;

  case (_q_stage)
  0: begin
// __block_3_case
// __block_4
_d_stage = _q_wait[4+:1] ? _q_after:0;

_d_wait = _q_wait+1;

// __block_5
  end
  1: begin
// __block_6_case
// __block_7
_t_accept_in = 1;

// __block_8
  end
  2: begin
// __block_9_case
// __block_10
_d__spi_trigger = 1;

_d__spi_send = _q_sendvec[24+:8];

_d_sendvec = {_q_sendvec[0+:24],8'b0};

_d_stage = 0;

_d_wait = 16;

_d_after = _q_sending[0+:1] ? 3:2;

_d_sending = _q_sending>>1;

// __block_11
  end
  3: begin
// __block_12_case
// __block_13
_d_send_else_read = in_wenable;

_d__spi_trigger = ~in_init;

_d__spi_send = in_wdata;

_d_data_next = in_wenable;

_d_stage = 0;

_d_wait = in_wenable ? 16:7;

_d_after = 4;

// __block_14
  end
  4: begin
// __block_15_case
// __block_16
_d_rdata = _w_spi_read;

_d_data_next = 1;

_d__spi_trigger = _d_continue;

_d__spi_send = in_wdata;

_d_busy = _d_continue;

_d_wait = 16;

_d_stage = ~_d_continue ? 1:0;

_d_after = 4;

_t_accept_in = ~_d_continue;

// __block_17
  end
endcase
// __block_2
if ((in_in_ready|in_init)&_t_accept_in&~reset) begin
// __block_18
// __block_20
_d_sending = 5'b01000;

_d_sendvec = in_init ? {32'b00000000000100010000000100000001}:{in_wenable ? 8'h02:8'hEB,in_addr};

_d_send_else_read = 1;

_d_busy = 1;

_d_stage = 2;

_d_continue = 1;

// __block_21
end else begin
// __block_19
end
// 'after'
// __block_22
// __block_23
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_sendvec <= _d_sendvec;
_q__spi_send <= _d__spi_send;
_q__spi_trigger <= _d__spi_trigger;
_q__spi_send_else_read <= _d__spi_send_else_read;
_q_stage <= _d_stage;
_q_wait <= _d_wait;
_q_after <= _d_after;
_q_sending <= _d_sending;
_q_send_else_read <= _d_send_else_read;
_q_continue <= _d_continue;
_q_rdata <= _d_rdata;
_q_busy <= _d_busy;
_q_data_next <= _d_data_next;
end

endmodule


module M_terrain_renderer_M_main_terrain (
in_write_en,
out_ram_clk,
out_ram_csn,
out_ram_bank,
out_pixel_ready,
out_pixel_data,
out_screen_send,
out_screen_reset,
inout_ram_io0_i,
inout_ram_io0_o,
inout_ram_io0_oe,
inout_ram_io1_i,
inout_ram_io1_o,
inout_ram_io1_oe,
inout_ram_io2_i,
inout_ram_io2_o,
inout_ram_io2_oe,
inout_ram_io3_i,
inout_ram_io3_o,
inout_ram_io3_oe,
out_done,
reset,
out_clock,
clock
);
input  [0:0] in_write_en;
output  [0:0] out_ram_clk;
output  [0:0] out_ram_csn;
output  [1:0] out_ram_bank;
output  [0:0] out_pixel_ready;
output  [15:0] out_pixel_data;
output  [0:0] out_screen_send;
output  [0:0] out_screen_reset;
input   [0:0] inout_ram_io0_i;
output  [0:0] inout_ram_io0_o;
output  [0:0] inout_ram_io0_oe;
input   [0:0] inout_ram_io1_i;
output  [0:0] inout_ram_io1_o;
output  [0:0] inout_ram_io1_oe;
input   [0:0] inout_ram_io2_i;
output  [0:0] inout_ram_io2_o;
output  [0:0] inout_ram_io2_oe;
input   [0:0] inout_ram_io3_i;
output  [0:0] inout_ram_io3_o;
output  [0:0] inout_ram_io3_oe;
output out_done;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [7:0] _w_ram_rdata;
wire  [0:0] _w_ram_busy;
wire  [0:0] _w_ram_data_next;
wire  [0:0] _w_ram_ram_csn;
wire  [0:0] _w_ram_ram_clk;
wire  [7:0] _c__ram_wdata;
reg  [0:0] _t__ram_in_ready;
reg  [0:0] _t__ram_init;
reg  [0:0] _t__ram_wenable;
reg signed [21:0] _t___block_40_x_off;
reg  [7:0] _t___block_51_hmap;
reg  [8:0] _t___block_51_h_diff;
reg  [11:0] _t___block_61_y_ground;

reg  [23:0] _d__ram_addr;
reg  [23:0] _q__ram_addr;
reg signed [21:0] _d___block_5_v_x;
reg signed [21:0] _q___block_5_v_x;
reg signed [21:0] _d___block_5_v_y;
reg signed [21:0] _q___block_5_v_y;
reg  [8:0] _d___block_5_vheight;
reg  [8:0] _q___block_5_vheight;
reg  [8:0] _d___block_5_next_vheight;
reg  [8:0] _q___block_5_next_vheight;
reg  [7:0] _d___block_5_cmds;
reg  [7:0] _q___block_5_cmds;
reg  [1:0] _d___block_9_n2;
reg  [1:0] _q___block_9_n2;
reg  [9:0] _d___block_12_cnt;
reg  [9:0] _q___block_12_cnt;
reg  [9:0] _d___block_29_x;
reg  [9:0] _q___block_29_x;
reg  [7:0] _d___block_33_y_last;
reg  [7:0] _q___block_33_y_last;
reg  [8:0] _d___block_33_iz;
reg  [8:0] _q___block_33_iz;
reg signed [21:0] _d___block_33_z;
reg signed [21:0] _q___block_33_z;
reg  [4:0] _d___block_37_n5;
reg  [4:0] _q___block_37_n5;
reg  [39:0] _d___block_37_step;
reg  [39:0] _q___block_37_step;
reg  [9:0] _d___block_40_inv_z;
reg  [9:0] _q___block_40_inv_z;
reg signed [21:0] _d___block_40_p_x;
reg signed [21:0] _q___block_40_p_x;
reg signed [21:0] _d___block_40_p_y;
reg signed [21:0] _q___block_40_p_y;
reg  [23:0] _d___block_48_c_h = 0;
reg  [23:0] _q___block_48_c_h = 0;
reg  [2:0] _d___block_48_n3;
reg  [2:0] _q___block_48_n3;
reg  [17:0] _d___block_51_tmp;
reg  [17:0] _q___block_51_tmp;
reg  [17:0] _d___block_51_h_diff_H;
reg  [17:0] _q___block_51_h_diff_H;
reg  [9:0] _d___block_51_domul;
reg  [9:0] _q___block_51_domul;
reg signed [10:0] _d___block_61_y;
reg signed [10:0] _q___block_61_y;
reg signed [13:0] _d___block_61_y_screen;
reg signed [13:0] _q___block_61_y_screen;
reg  [1:0] _d_ram_bank;
reg  [1:0] _q_ram_bank;
reg  [0:0] _d_pixel_ready;
reg  [0:0] _q_pixel_ready;
reg  [15:0] _d_pixel_data;
reg  [15:0] _q_pixel_data;
reg  [0:0] _d_screen_send;
reg  [0:0] _q_screen_send;
reg  [0:0] _d_screen_reset;
reg  [0:0] _q_screen_reset;
reg  [3:0] _d__idx_fsm0,_q__idx_fsm0;
reg  _autorun = 0;
assign out_ram_clk = _w_ram_ram_clk;
assign out_ram_csn = _w_ram_ram_csn;
assign out_ram_bank = _q_ram_bank;
assign out_pixel_ready = _q_pixel_ready;
assign out_pixel_data = _q_pixel_data;
assign out_screen_send = _q_screen_send;
assign out_screen_reset = _q_screen_reset;
assign out_done = (_q__idx_fsm0 == 0) && _autorun
;
M_qpsram_ram_M_main_terrain_ram ram (
.in_in_ready(_t__ram_in_ready),
.in_init(_t__ram_init),
.in_addr(_d__ram_addr),
.in_wdata(_c__ram_wdata),
.in_wenable(_t__ram_wenable),
.out_rdata(_w_ram_rdata),
.out_busy(_w_ram_busy),
.out_data_next(_w_ram_data_next),
.out_ram_csn(_w_ram_ram_csn),
.out_ram_clk(_w_ram_ram_clk),
.inout_ram_io0_i(inout_ram_io0_i),
.inout_ram_io0_o(inout_ram_io0_o),
.inout_ram_io0_oe(inout_ram_io0_oe),
.inout_ram_io1_i(inout_ram_io1_i),
.inout_ram_io1_o(inout_ram_io1_o),
.inout_ram_io1_oe(inout_ram_io1_oe),
.inout_ram_io2_i(inout_ram_io2_i),
.inout_ram_io2_o(inout_ram_io2_o),
.inout_ram_io2_oe(inout_ram_io2_oe),
.inout_ram_io3_i(inout_ram_io3_i),
.inout_ram_io3_o(inout_ram_io3_o),
.inout_ram_io3_oe(inout_ram_io3_oe),
.reset(reset),
.clock(clock));



`ifdef FORMAL
initial begin
assume(reset);
end
assume property($initstate || (out_done));
`endif
always @* begin
_d__ram_addr = _q__ram_addr;
_d___block_5_v_x = _q___block_5_v_x;
_d___block_5_v_y = _q___block_5_v_y;
_d___block_5_vheight = _q___block_5_vheight;
_d___block_5_next_vheight = _q___block_5_next_vheight;
_d___block_5_cmds = _q___block_5_cmds;
_d___block_9_n2 = _q___block_9_n2;
_d___block_12_cnt = _q___block_12_cnt;
_d___block_29_x = _q___block_29_x;
_d___block_33_y_last = _q___block_33_y_last;
_d___block_33_iz = _q___block_33_iz;
_d___block_33_z = _q___block_33_z;
_d___block_37_n5 = _q___block_37_n5;
_d___block_37_step = _q___block_37_step;
_d___block_40_inv_z = _q___block_40_inv_z;
_d___block_40_p_x = _q___block_40_p_x;
_d___block_40_p_y = _q___block_40_p_y;
_d___block_48_c_h = _q___block_48_c_h;
_d___block_48_n3 = _q___block_48_n3;
_d___block_51_tmp = _q___block_51_tmp;
_d___block_51_h_diff_H = _q___block_51_h_diff_H;
_d___block_51_domul = _q___block_51_domul;
_d___block_61_y = _q___block_61_y;
_d___block_61_y_screen = _q___block_61_y_screen;
_d_ram_bank = _q_ram_bank;
_d_pixel_ready = _q_pixel_ready;
_d_pixel_data = _q_pixel_data;
_d_screen_send = _q_screen_send;
_d_screen_reset = _q_screen_reset;
_d__idx_fsm0 = _q__idx_fsm0;
_t___block_40_x_off = 0;
_t___block_51_hmap = 0;
_t___block_51_h_diff = 0;
_t___block_61_y_ground = 0;
// _always_pre
// __block_1
_t__ram_wenable = 0;

_t__ram_in_ready = 0;

_t__ram_init = 0;

_d_pixel_ready = 0;

_d_screen_send = 0;

// __block_2
(* full_case *)
case (_q__idx_fsm0)
1: begin
// _top
// __block_5
// var inits
_d___block_5_v_x = 2097152;
_d___block_5_v_y = 3129344;
_d___block_5_vheight = 190;
_d___block_5_next_vheight = 190;
_d___block_5_cmds = 0;
// --
_d__idx_fsm0 = 2;
end
2: begin
// __while__block_6
if (~_q___block_5_cmds[7+:1]) begin
// __block_7
// __block_9
// var inits
_d___block_9_n2 = 2'b11;
// --
_d__ram_addr = 4194304|1048576|{_q___block_5_cmds,1'b0};

_d__idx_fsm0 = 4;
end else begin
// __block_8
_d__idx_fsm0 = 3;
end
end
4: begin
// __while__block_10
if (_q___block_9_n2[0+:1]) begin
// __block_11
// __block_13
_t__ram_in_ready = 1;

if (_w_ram_data_next) begin
// __block_14
// __block_16
_d_pixel_data = {_q_pixel_data[0+:8],_w_ram_rdata};

_d___block_9_n2 = _q___block_9_n2>>1;

// __block_17
end else begin
// __block_15
end
// 'after'
// __block_18
// __block_19
_d__idx_fsm0 = 4;
end else begin
// __block_12
// var inits
_d___block_12_cnt = 1;
// --
_d_screen_reset = ~_q_pixel_data[9+:1];

_d_screen_send = ~_q_pixel_data[15+:1];

_d__idx_fsm0 = 5;
end
end
3: begin
// __while__block_26
if (1) begin
// __block_27
// __block_29
// var inits
_d___block_29_x = 0;
// --
_d__idx_fsm0 = 6;
end else begin
// __block_28
// __block_72
_d__idx_fsm0 = 0;
end
end
5: begin
// __while__block_20
if (_q___block_12_cnt!=0) begin
// __block_21
// __block_23
_d___block_12_cnt = _q___block_12_cnt+1;

// __block_24
_d__idx_fsm0 = 5;
end else begin
// __block_22
_d___block_5_cmds = _q___block_5_cmds+1;

// __block_25
_d__idx_fsm0 = 2;
end
end
6: begin
// __while__block_30
if (_q___block_29_x!=320) begin
// __block_31
// __block_33
// var inits
_d___block_33_y_last = 239;
_d___block_33_iz = 2;
_d___block_33_z = 4096;
// --
_d__idx_fsm0 = 7;
end else begin
// __block_32
_d___block_5_vheight = _q___block_5_next_vheight+128;

_d___block_5_v_y = _q___block_5_v_y+8192;

_d___block_5_v_x = _q___block_5_v_x+2048;

// __block_71
_d__idx_fsm0 = 3;
end
end
7: begin
// __while__block_34
if (_q___block_33_iz!=256) begin
// __block_35
// __block_37
// var inits
_d___block_37_n5 = 5'b11111;
// --
_d__ram_addr = 4194304|{_q___block_29_x,_q___block_33_iz[0+:8],3'b000};

_d__idx_fsm0 = 8;
end else begin
// __block_36
_d___block_29_x = _q___block_29_x+1;

// __block_70
_d__idx_fsm0 = 6;
end
end
8: begin
// __while__block_38
if (_q___block_37_n5[0+:1]) begin
// __block_39
// __block_41
_t__ram_in_ready = 1;

if (_w_ram_data_next) begin
// __block_42
// __block_44
_d___block_37_step = {_q___block_37_step[0+:32],_w_ram_rdata};

_d___block_37_n5 = _q___block_37_n5>>1;

// __block_45
end else begin
// __block_43
end
// 'after'
// __block_46
// __block_47
_d__idx_fsm0 = 8;
end else begin
// __block_40
_d___block_40_inv_z = _q___block_37_step[24+:10];

_t___block_40_x_off = $signed(_q___block_37_step[0+:22]);

_d___block_40_p_x = _q___block_5_v_x+_t___block_40_x_off;

_d___block_40_p_y = _q___block_5_v_y+(_q___block_33_z);

_d__idx_fsm0 = 9;
end
end
9: begin
// __block_48
// var inits
_d___block_48_n3 = 3'b111;
// --
_d__ram_addr = {_q___block_40_p_y[11+:10],_q___block_40_p_x[11+:10],2'b00};

_d__idx_fsm0 = 10;
end
10: begin
// __while__block_49
if (_q___block_48_n3[0+:1]) begin
// __block_50
// __block_52
_t__ram_in_ready = 1;

if (_w_ram_data_next) begin
// __block_53
// __block_55
_d___block_48_c_h = {_q___block_48_c_h[0+:16],_w_ram_rdata};

_d___block_48_n3 = _q___block_48_n3>>1;

// __block_56
end else begin
// __block_54
end
// 'after'
// __block_57
// __block_58
_d__idx_fsm0 = 10;
end else begin
// __block_51
// var inits
_d___block_51_tmp = 0;
_d___block_51_domul = 10'b1111111111;
// --
_t___block_51_hmap = _q___block_48_c_h[16+:8];

_d___block_5_next_vheight = (_q___block_33_iz==2) ? _q___block_48_c_h[16+:8]:_q___block_5_next_vheight;

_t___block_51_h_diff = (_q___block_5_vheight-_t___block_51_hmap);

_d___block_51_h_diff_H = _t___block_51_h_diff;

_d__idx_fsm0 = 11;
end
end
11: begin
// __while__block_59
if (_q___block_51_domul[0+:1]) begin
// __block_60
// __block_62
_d___block_51_tmp = _q___block_40_inv_z[0+:1] ? (_q___block_51_tmp+_q___block_51_h_diff_H):_q___block_51_tmp;

_d___block_40_inv_z = _q___block_40_inv_z>>1;

_d___block_51_h_diff_H = _q___block_51_h_diff_H<<1;

_d___block_51_domul = _q___block_51_domul>>1;

// __block_63
_d__idx_fsm0 = 11;
end else begin
// __block_61
_t___block_61_y_ground = (_q___block_51_tmp>>6)+32;

_d___block_61_y = _q___block_33_y_last;

_d___block_61_y_screen = (_q___block_33_iz==255) ? -1:_t___block_61_y_ground;

_d_pixel_data = (_q___block_33_iz==255) ? 0:_q___block_48_c_h[0+:16];

_d__idx_fsm0 = 12;
end
end
12: begin
// __while__block_64
if (_q___block_61_y>_q___block_61_y_screen) begin
// __block_65
// __block_67
_d_pixel_ready = in_write_en;

_d___block_61_y = in_write_en ? _q___block_61_y-1:_q___block_61_y;

// __block_68
_d__idx_fsm0 = 12;
end else begin
// __block_66
_d___block_33_y_last = _q___block_61_y;

_d___block_33_z = _q___block_33_z+2048;

_d___block_33_iz = _q___block_33_iz+1;

// __block_69
_d__idx_fsm0 = 7;
end
end
0: begin
end
default: begin
_d__idx_fsm0 = {4{1'bx}};
`ifdef FORMAL
assume(0);
`endif
 end
endcase
// _always_post
// __block_3
// __block_4
// pipeline stage triggers
end

always @(posedge clock) begin
_q__ram_addr <= _d__ram_addr;
_q___block_5_v_x <= (reset) ? 2097152 : _d___block_5_v_x;
_q___block_5_v_y <= (reset) ? 3129344 : _d___block_5_v_y;
_q___block_5_vheight <= (reset) ? 190 : _d___block_5_vheight;
_q___block_5_next_vheight <= (reset) ? 190 : _d___block_5_next_vheight;
_q___block_5_cmds <= (reset) ? 0 : _d___block_5_cmds;
_q___block_9_n2 <= (reset) ? 2'b11 : _d___block_9_n2;
_q___block_12_cnt <= (reset) ? 1 : _d___block_12_cnt;
_q___block_29_x <= (reset) ? 0 : _d___block_29_x;
_q___block_33_y_last <= (reset) ? 239 : _d___block_33_y_last;
_q___block_33_iz <= (reset) ? 2 : _d___block_33_iz;
_q___block_33_z <= (reset) ? 4096 : _d___block_33_z;
_q___block_37_n5 <= (reset) ? 5'b11111 : _d___block_37_n5;
_q___block_37_step <= _d___block_37_step;
_q___block_40_inv_z <= _d___block_40_inv_z;
_q___block_40_p_x <= _d___block_40_p_x;
_q___block_40_p_y <= _d___block_40_p_y;
_q___block_48_c_h <= _d___block_48_c_h;
_q___block_48_n3 <= (reset) ? 3'b111 : _d___block_48_n3;
_q___block_51_tmp <= (reset) ? 0 : _d___block_51_tmp;
_q___block_51_h_diff_H <= _d___block_51_h_diff_H;
_q___block_51_domul <= (reset) ? 10'b1111111111 : _d___block_51_domul;
_q___block_61_y <= _d___block_61_y;
_q___block_61_y_screen <= _d___block_61_y_screen;
_q_ram_bank <= _d_ram_bank;
_q_pixel_ready <= _d_pixel_ready;
_q_pixel_data <= _d_pixel_data;
_q_screen_send <= _d_screen_send;
_q_screen_reset <= _d_screen_reset;
_q__idx_fsm0 <= reset ? 0 : ( ~_autorun ? 1 : _d__idx_fsm0);
_autorun <= reset ? 0 : 1;
end

endmodule


module M_main (
out_leds,
out_ram_clk,
out_ram_csn,
out_ram_bank,
out_spiscreen_clk,
out_spiscreen_mosi,
out_spiscreen_dc,
out_spiscreen_resn,
out_spiscreen_csn,
inout_ram_io0_i,
inout_ram_io0_o,
inout_ram_io0_oe,
inout_ram_io1_i,
inout_ram_io1_o,
inout_ram_io1_oe,
inout_ram_io2_i,
inout_ram_io2_o,
inout_ram_io2_oe,
inout_ram_io3_i,
inout_ram_io3_o,
inout_ram_io3_oe,
in_run,
out_done,
reset,
out_clock,
clock
);
output  [4:0] out_leds;
output  [0:0] out_ram_clk;
output  [0:0] out_ram_csn;
output  [1:0] out_ram_bank;
output  [0:0] out_spiscreen_clk;
output  [0:0] out_spiscreen_mosi;
output  [0:0] out_spiscreen_dc;
output  [0:0] out_spiscreen_resn;
output  [0:0] out_spiscreen_csn;
input   [0:0] inout_ram_io0_i;
output  [0:0] inout_ram_io0_o;
output  [0:0] inout_ram_io0_oe;
input   [0:0] inout_ram_io1_i;
output  [0:0] inout_ram_io1_o;
output  [0:0] inout_ram_io1_oe;
input   [0:0] inout_ram_io2_i;
output  [0:0] inout_ram_io2_o;
output  [0:0] inout_ram_io2_oe;
input   [0:0] inout_ram_io3_i;
output  [0:0] inout_ram_io3_o;
output  [0:0] inout_ram_io3_oe;
input in_run;
output out_done;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [0:0] _w_display_spi_clk;
wire  [0:0] _w_display_spi_mosi;
wire  [0:0] _w_display_spi_dc;
wire  [0:0] _w_display_ready;
wire  [0:0] _w_sb_io_unnamed_0_pin;
wire  [0:0] _w_sb_io_unnamed_1_pin;
wire  [0:0] _w_sb_io_unnamed_2_pin;
wire  [0:0] _w_sb_io_unnamed_3_pin;
wire  [0:0] _w_terrain_ram_clk;
wire  [0:0] _w_terrain_ram_csn;
wire  [1:0] _w_terrain_ram_bank;
wire  [0:0] _w_terrain_pixel_ready;
wire  [15:0] _w_terrain_pixel_data;
wire  [0:0] _w_terrain_screen_send;
wire  [0:0] _w_terrain_screen_reset;
wire _w_terrain_done;
reg  [0:0] _t_screen_resn;
reg  [0:0] _t__display_enable;
reg  [0:0] _t__display_data_or_command;
reg  [7:0] _t__display_byte;
reg  [0:0] _t__terrain_write_en;

reg  [15:0] _d_pixel_to_send;
reg  [15:0] _q_pixel_to_send;
reg  [16:0] _d_pixel_do_send;
reg  [16:0] _q_pixel_do_send;
reg  [31:0] _d_busy;
reg  [31:0] _q_busy;
reg  [4:0] _d_leds;
reg  [4:0] _q_leds;
reg  [1:0] _d_ram_bank;
reg  [1:0] _q_ram_bank;
reg  [0:0] _d_spiscreen_csn = 0;
reg  [0:0] _q_spiscreen_csn = 0;
assign out_leds = _q_leds;
assign out_ram_clk = _w_terrain_ram_clk;
assign out_ram_csn = _w_terrain_ram_csn;
assign out_ram_bank = _q_ram_bank;
assign out_spiscreen_clk = _w_sb_io_unnamed_0_pin;
assign out_spiscreen_mosi = _w_sb_io_unnamed_1_pin;
assign out_spiscreen_dc = _w_sb_io_unnamed_2_pin;
assign out_spiscreen_resn = _w_sb_io_unnamed_3_pin;
assign out_spiscreen_csn = _q_spiscreen_csn;
assign out_done = 0;
M_spi_mode3_send_M_main_display display (
.in_enable(_t__display_enable),
.in_data_or_command(_t__display_data_or_command),
.in_byte(_t__display_byte),
.out_spi_clk(_w_display_spi_clk),
.out_spi_mosi(_w_display_spi_mosi),
.out_spi_dc(_w_display_spi_dc),
.out_ready(_w_display_ready),
.reset(reset),
.clock(clock));
sb_io sb_io_unnamed_0 (
.clock(clock),
.out(_w_display_spi_clk),
.pin(_w_sb_io_unnamed_0_pin));
sb_io sb_io_unnamed_1 (
.clock(clock),
.out(_w_display_spi_mosi),
.pin(_w_sb_io_unnamed_1_pin));
sb_io sb_io_unnamed_2 (
.clock(clock),
.out(_w_display_spi_dc),
.pin(_w_sb_io_unnamed_2_pin));
sb_io sb_io_unnamed_3 (
.clock(clock),
.out(_t_screen_resn),
.pin(_w_sb_io_unnamed_3_pin));
M_terrain_renderer_M_main_terrain terrain (
.in_write_en(_t__terrain_write_en),
.out_ram_clk(_w_terrain_ram_clk),
.out_ram_csn(_w_terrain_ram_csn),
.out_ram_bank(_w_terrain_ram_bank),
.out_pixel_ready(_w_terrain_pixel_ready),
.out_pixel_data(_w_terrain_pixel_data),
.out_screen_send(_w_terrain_screen_send),
.out_screen_reset(_w_terrain_screen_reset),
.inout_ram_io0_i(inout_ram_io0_i),
.inout_ram_io0_o(inout_ram_io0_o),
.inout_ram_io0_oe(inout_ram_io0_oe),
.inout_ram_io1_i(inout_ram_io1_i),
.inout_ram_io1_o(inout_ram_io1_o),
.inout_ram_io1_oe(inout_ram_io1_oe),
.inout_ram_io2_i(inout_ram_io2_i),
.inout_ram_io2_o(inout_ram_io2_o),
.inout_ram_io2_oe(inout_ram_io2_oe),
.inout_ram_io3_i(inout_ram_io3_i),
.inout_ram_io3_o(inout_ram_io3_o),
.inout_ram_io3_oe(inout_ram_io3_oe),
.out_done(_w_terrain_done),
.reset(reset),
.clock(clock));



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_pixel_to_send = _q_pixel_to_send;
_d_pixel_do_send = _q_pixel_do_send;
_d_busy = _q_busy;
_d_leds = _q_leds;
_d_ram_bank = _q_ram_bank;
_d_spiscreen_csn = _q_spiscreen_csn;
// _always_pre
// __block_1
_d_ram_bank = 2'b00;

_d_spiscreen_csn = 0;

_d_leds = _w_terrain_screen_send ? {_w_terrain_screen_send,_w_terrain_pixel_data[12+:4]}:_q_leds;

_t_screen_resn = _w_terrain_screen_reset;

_t__display_data_or_command = _w_terrain_screen_send ? ~_w_terrain_pixel_data[8+:1]:1'b1;

_t__display_byte = _w_terrain_screen_send ? _w_terrain_pixel_data[0+:8]:_q_pixel_to_send[0+:8];

_t__display_enable = _w_terrain_screen_send|_q_pixel_do_send[0+:1];

_d_pixel_do_send = _w_terrain_pixel_ready ? {_w_terrain_pixel_ready,15'b0,_w_terrain_pixel_ready}:{1'b0,_q_pixel_do_send[1+:16]};

_d_pixel_to_send = _w_terrain_pixel_ready ? _w_terrain_pixel_data:_d_pixel_do_send[0+:1] ? {8'b0,_w_terrain_pixel_data[8+:8]}:_w_terrain_pixel_data;

_d_busy = _w_terrain_pixel_ready ? 32'hffffffff:{1'b0,_q_busy[1+:31]};

_t__terrain_write_en = ~_d_busy[0+:1];

// __block_2
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_pixel_to_send <= (reset) ? 0 : _d_pixel_to_send;
_q_pixel_do_send <= (reset) ? 0 : _d_pixel_do_send;
_q_busy <= (reset) ? 0 : _d_busy;
_q_leds <= _d_leds;
_q_ram_bank <= _d_ram_bank;
_q_spiscreen_csn <= _d_spiscreen_csn;
end

endmodule
