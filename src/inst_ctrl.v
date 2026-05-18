module instruction_controller (
	input				clk,
	input				rst,

	// received frame instruction
	input				inst_en,

	input	[3:0]		recv_ops,
	input	[47:0]		recv_mac,
	input	[3:0]		recv_port,
	input	[7:0]		recv_size,
	input	[31:0]		recv_daddr,
	input	[31:0]		recv_opts,

	// sender operations
	output				inst_store,

	output	[3:0]		send_ops,
	output	[47:0]		send_mac,
	output	[3:0]		send_port,
	output	[7:0]		send_size,
	output	[31:0]		send_daddr,
	output	[31:0]		send_opts,
	
	input				send_full,	// fifo full for instruction

	// hardware interface
	input				i_inst_en,
	output				o_inst_fdone,

	input	[3:0]		i_ops,
	input	[47:0]		i_dst_mac,
	input	[7:0]		i_dsize,
	input	[31:0]		i_axi_srcaddr,
	input	[31:0]		i_axi_dstaddr
);
	/* instruction decoding
		ops:
			0x1: DATAFRAME
			0x2: DATAREQ
			0x3: REGREQ
	
		REGREQ	->	DATAFRAME (size == 0)
		DATAREQ	->	DATAFRAME (size >= 0)
		Read Address: opts
	*/

	wire	[3:0]		w_ops;
	wire	[47:0]		w_mac;
	wire	[3:0]		w_port;
	wire	[7:0]		w_size;
	wire	[31:0]		w_daddr;
	wire	[31:0]		w_opts;

	wire				empty_ops;

	// instruction fifo
	fifo #(
		.BWIDTH		(128),	// {inst_ops, inst_mac, inst_port, inst_size, inst_daddr, inst_opts}
		.DEPTH		(4)
	) inst_fifo (
		.wclk		(clk),
		.rclk		(clk),
		.rst		(rst),

		.din_en		(inst_en),
		.din		({recv_ops, recv_mac, recv_port, recv_size, recv_daddr, recv_opts}),
		.full		(),

		.dout_en	(inst_store),
		.dout		({w_ops, w_mac, w_port, w_size, w_daddr, w_opts}),
		.emp		(empty_ops)
	);

	// First step:
	// - Receive mod to send mod only ✓
	// Second step:
	// - state mahine controller implement only receive mod inst
	assign send_ops		=	(w_ops == 4'h2) ? 4'h1 :	// DATAREQ -> DATAFRAME
							(w_ops == 4'h3) ? 4'h1 :	// REGREQ -> DATAFRAME
							4'h0;
	assign send_mac		=	w_mac;
	assign send_port	=	w_port;
	assign send_size	=	(send_ops == 4'h1) ? w_size : 8'h0;
	assign send_daddr	=	w_opts;
	assign send_opts	=	w_daddr;

	assign inst_store	=	!send_full && !empty_ops;
endmodule