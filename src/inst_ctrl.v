module instruction_controller #(
	parameter RECVCOUNT_TH = 3
)(
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
	
	input				send_full,		// fifo full for instruction

	// hardware interface
	input				i_inst_en,
	output				o_inst_fdone,	// input instruction fetch done

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
	
		DATAREQ	->	DATAFRAME (size >= 0)
		Read Address: opts
	*/

	wire	[3:0]		w_ops;
	wire	[47:0]		w_mac;
	wire	[3:0]		w_port;
	wire	[7:0]		w_size;
	wire	[31:0]		w_daddr;
	wire	[31:0]		w_opts;

	wire 				w_inst_pop;

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

		.dout_en	(w_inst_pop),
		.dout		({w_ops, w_mac, w_port, w_size, w_daddr, w_opts}),
		.emp		(empty_ops)
	);

	// First step:
	// - Receive mod to send mod only ✓
	// Second step:
	// - State mahine controller implement only receive mod inst ✓
	// Third step:
	// - Add Input signal decode state, and preference of receive mod inst ✓
	// 

	localparam 		WAIT	= 	3'h0,
					RECV	=	3'h1,
					INPUT	=	3'h2;

	reg 	[2:0]		r_state;		// instruction exec state
	reg		[1:0]		r_ri_count;		// receiver instruction exec counter
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			r_state		<=	WAIT;
			r_ri_count	<=	2'h0;
		end else begin
			case (r_state)
				// IDLE State
				WAIT: begin
					if (send_full) begin
						r_state		<=	WAIT;
					end else if (!empty_ops) begin
						r_state		<=	RECV;
						r_ri_count	<=	2'h0;
					end else if (i_inst_en) begin
						r_state		<=	INPUT;
					end
				end 
				// Receive Instruction Execution State
				RECV: begin
					if (!empty_ops && !send_full) begin
						if (i_inst_en) begin
							if (r_ri_count < RECVCOUNT_TH) begin
								r_state		<=	RECV;
							end else begin
								r_state		<=	INPUT;
							end
						end else begin
							r_state		<=	RECV;
						end

						// Receive Inst count
						if (r_ri_count < RECVCOUNT_TH) begin
							r_ri_count	<=	r_ri_count + 1;
						end else begin
							r_ri_count	<=	r_ri_count;
						end
					end else if (i_inst_en) begin
						r_state		<=	INPUT;
					end else begin
						r_state		<=	WAIT;
					end
				end
				// Input Instruction Execution State
				INPUT: begin
					if (!empty_ops) begin 
						r_state		<=	RECV;
						r_ri_count	<=	2'h0;
					end else if (i_inst_en && !send_full) begin
						r_state		<=	WAIT;
					end else begin
						r_state		<=	WAIT;
					end
				end
				default: 
					r_state	<=	WAIT;
			endcase
		end
	end
	
	// Receive Instruction Decoder
	wire	[3:0]	w_recv_i_ops;
	wire	[47:0]	w_recv_i_mac;
	wire 	[3:0]	w_recv_i_port;
	wire	[7:0]	w_recv_i_size;
	wire	[31:0]	w_recv_i_daddr;
	wire	[31:0]	w_recv_i_opts;
	
	assign	w_recv_i_ops	=	(w_ops == 4'h2) ? 4'h1 :	// DATAREQ -> DATAFRAME
	
								4'h0;
	assign	w_recv_i_mac	=	w_mac;
	assign	w_recv_i_port	=	w_port;
	assign	w_recv_i_size	=	(w_recv_i_ops == 4'h1) ? w_size : 8'h0;
	assign	w_recv_i_daddr	=	w_opts;
	assign	w_recv_i_opts	=	w_daddr;

	assign	w_inst_pop	=	(r_state == RECV)	?	!send_full && !empty_ops : 1'b0;


	assign	send_ops	=	(r_state == RECV)	?	w_recv_i_ops	: 
							(r_state == INPUT)	?	i_ops			:
							4'b0;
	assign	send_mac	=	(r_state == RECV)	?	w_recv_i_mac	: 
							(r_state == INPUT)	?	i_dst_mac		:
							48'b0;
	assign	send_port	=	(r_state == RECV)	?	w_recv_i_port	: 
							(r_state == INPUT)	?	4'h0			:
							4'b0;
	assign	send_size	=	(r_state == RECV)	?	w_recv_i_size	: 
							(r_state == INPUT)	?	i_dsize			:
							8'b0;
	assign	send_daddr	=	(r_state == RECV)	?	w_recv_i_daddr	: 
							(r_state == INPUT)	?	
								(i_ops == 4'h1)		?	i_axi_dstaddr	:
								(i_ops == 4'h2)		?	i_axi_srcaddr	:
								32'h0	:
							32'b0;
	assign	send_opts	=	(r_state == RECV)	?	w_recv_i_opts	: 
							(r_state == INPUT)	?	
								(i_ops == 4'h1)		?	i_axi_srcaddr	:
								(i_ops == 4'h2)		?	i_axi_dstaddr	:
								32'h0	:
							32'b0;

	assign	inst_store	=	send_full			?	1'b0		:
							(r_state == RECV)	?	w_inst_pop	: 
							(r_state == INPUT)	?	i_inst_en	:
							1'b0;

	assign	o_inst_fdone=	(r_state == INPUT) && inst_store;
endmodule