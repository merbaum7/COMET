module receive_decoder (
	input				clk,

	input	[47:0]		src_mac,
	input	[15:0]		ptype,
	input	[7:0]		fport,
	input	[7:0]		dsize,
	input	[31:0]		daddr,
	input	[31:0]		opts,

	output				soft_reset,
	output				inst_pop,

	// axi write control
	output				write_start,
	output	[31:0]		write_address,
	output	[31:0]		write_size,

	// to sender module (parameters)
	output	[3:0]		inst_ops,
	output	[47:0]		inst_mac,
	output	[3:0]		inst_port,
	output	[7:0]		inst_size,
	output	[31:0]		inst_daddr,
	output	[31:0]		inst_opts
);
	parameter	REGREQ		=	16'h0101,
				DATAFRAME	=	16'h0110,
				DATAREQ		=	16'h0111,

				INIT_RESET	=	16'h01FF,
				
				FLOWCTRL	=	16'h8808;

	assign write_start		= (ptype == DATAFRAME);
	assign write_address	= daddr;
	assign write_size		= (ptype == DATAFRAME) ? 
								((dsize == 0) ? 32'd4 : ({24'h0, dsize} + 1) << 5)
        						: 32'd0;

	// Soft reset/buf pop signal
	reg		soft_reset_r;
	assign	soft_reset	= soft_reset_r;
	assign	inst_pop	= (ptype == DATAREQ) || (ptype == REGREQ);
	always @(posedge clk) begin
		soft_reset_r	<=	ptype == INIT_RESET;
	end

	// to sender module (parameters)
	assign inst_ops		= 	ptype == DATAREQ	? 4'h2	:	// REGREQ 
							ptype == REGREQ		? 4'h3	:	// DATAREQ
							4'h0;
	assign inst_mac		= src_mac;
	assign inst_port	= fport[3:0];
	assign inst_size	= dsize;
	assign inst_daddr	= daddr;
	assign inst_opts	= opts;
endmodule

module receive2AXI #(
	parameter	MII_TYPE		=	"MII",
	parameter	MII_WIDTH		=	(MII_TYPE =="25GMII") ? 64
								:	(MII_TYPE == "XGMII") ? 64
								:	(MII_TYPE ==  "GMII") ? 8 
								:	(MII_TYPE ==   "MII") ? 4
								:	0,
	parameter	MII_CTLW		=	(MII_TYPE =="25GMII") ? 8
								:	(MII_TYPE == "XGMII") ? 8
								:	(MII_TYPE ==  "GMII") ? 1 
								:	(MII_TYPE ==   "MII") ? 1
								:	0,

	parameter	AXIDATA_WIDTH	=	128,
	parameter	AXIADDR_WIDTH	=	32
) (
	input						rst,

	// mii interface
	input						mii_clk,

	input	[MII_WIDTH-1:0]		mii_rx_d,
	input	[MII_CTLW-1:0]		mii_rx_c,

	output						hw_wait,
	input	[47:0]				own_mac,

	output						intr_send,

	output	[3:0]				inst_ops,
	output	[47:0]				inst_mac,
	output	[3:0]				inst_port,
	output	[7:0]				inst_size,
	output	[31:0]				inst_daddr,
	output	[31:0]				inst_opts,

	// Write
	input						M_ACLK,
	input						M_ARESETN,
	// - Address
	output	[0:0]				M_AXI_AWID,
	output	[AXIADDR_WIDTH-1:0]	M_AXI_AWADDR,
	output	[7:0]				M_AXI_AWLEN,
	output	[2:0]				M_AXI_AWSIZE,
	output	[1:0]				M_AXI_AWBURST,
	output						M_AXI_AWLOCK,
	output	[3:0]				M_AXI_AWCACHE,
	output	[2:0]				M_AXI_AWQOS,
	output	[0:0]				M_AXI_AWUSER,
	output	[2:0]				M_AXI_AWPROT,
	output						M_AXI_AWVALID,
	input						M_AXI_AWREADY,
	// - Data
	output	[AXIDATA_WIDTH-1:0]	M_AXI_WDATA,
	output	[AXIDATA_WIDTH/8-1:0]	M_AXI_WSTRB,
	output						M_AXI_WLAST,
	output	[0:0]				M_AXI_WUSER,
	output						M_AXI_WVALID,
	input						M_AXI_WREADY,
	// - Response
	input	[0:0]				M_AXI_BID,
	input	[1:0]				M_AXI_BRESP,
	input	[0:0]				M_AXI_BUSER,
	input						M_AXI_BVALID,
	output						M_AXI_BREADY
);
	parameter	MIIFIFO_WIDTH	=	(MII_TYPE =="25GMII") ? MII_WIDTH
								:	(MII_TYPE == "XGMII") ? MII_WIDTH
								:	8;

	wire						w_flow_recv;
	wire						w_buf_afull;
	wire						w_emp;

	// Data IF(FIFO)
	wire						w_buf_wen;
	wire	[MIIFIFO_WIDTH-1:0]	w_buf_d;

	wire						w_axififo_wen;
	wire	[AXIDATA_WIDTH-1:0]	w_axififo_d;

	wire						w_axi_ren;
	wire	[AXIDATA_WIDTH-1:0]	w_axi_d;

	// decoder IF
	wire	[47:0]				w_src_mac;
	wire	[47:0]				w_dst_mac;
	wire	[15:0]				w_ptype;	
	wire	[7:0]				w_fport;
	wire	[7:0]				w_dsize;
	wire	[31:0]				w_daddr;
	wire	[31:0]				w_opts;
	wire						w_head;

	wire						w_wstart;
	wire	[31:0]				w_addr;
	wire	[31:0]				w_size;

	wire	[47:0]				w_buf_src_mac;
	wire	[47:0]				w_buf_dst_mac;
	wire	[15:0]				w_buf_ptype;	
	wire	[7:0]				w_buf_fport;
	wire	[7:0]				w_buf_dsize;
	wire	[31:0]				w_buf_daddr;
	wire	[31:0]				w_buf_opts;
	wire						w_inst_done;
	
	recv_mii #(
		.MII_TYPE			(MII_TYPE),
		.NMATCH_DENY		(1)
	) inst_phy (
		.clk				(mii_clk),
		.rst				(rst),

		.mii_rx_d			(mii_rx_d),
		.mii_rx_c			(mii_rx_c),

		.hw_wait			(w_flow_recv),

		.own_mac			(own_mac),

		// Data IF(FIFO)
		.buf_wen			(w_buf_wen),
		.buf_d				(w_buf_d),

		// Frame SRC/DST
		.src_mac			(w_src_mac),
		.dst_mac			(w_dst_mac),
		.ptype				(w_ptype),
		.fport				(w_fport),
		.dsize				(w_dsize),
		.daddr				(w_daddr),
		.opts				(w_opts),

		.head_end			(w_head),

		.read_deny_type1	(16'h0101),	// REGREQ : 0101
		.read_deny_type2	(16'h0111),	// DATAREQ: 0111
		.read_deny_type3	(16'h0000)
	);

	// flow frame sending flag
	assign	hw_wait	=	w_buf_afull || w_flow_recv;

	fifo_Width_Converter #(
		.IWIDTH			(MIIFIFO_WIDTH),
		.OWIDTH			(AXIDATA_WIDTH),
		.DL				(MII_TYPE == "MII")
	) inst_conv (
		.clk			(mii_clk),
		.rst			(rst),

		.reject			(1'h0),
		.stop			(1'h0),

		.i_wen			(w_buf_wen),
		.i_wdata		(w_buf_d),

		.o_wen			(w_axififo_wen),
		.o_wdata		(w_axififo_d),

		.o_busy			()
	);

	fifo #(
		.BWIDTH			(AXIDATA_WIDTH),
		.DEPTH			(64)
	) inst_d_fifo (
		.wclk			(mii_clk),
		.rclk			(M_ACLK),
		.rst			(rst),

		.afull			(),
		.emp			(w_emp),

		.din_en			(w_axififo_wen),
		.din			(w_axififo_d),

		.dout_en		(w_axi_ren),
		.dout			(w_axi_d)
	);

	// srcmac[48], packettype[16], fpgaport[4], datasize[8], address[32], opts[32] = 140bit
	fifo #(
		.BWIDTH			(140),
		.DEPTH			(8)
	) inst_i_fifo (
		.wclk			(mii_clk),
		.rclk			(M_ACLK),
		.rst			(rst),

		.afull			(w_buf_afull),
		//.emp			(),

		.din_en			(w_head),
		.din			({w_src_mac, w_ptype, w_fport[3:0], w_dsize, w_daddr, w_opts}),

		.dout_en		(w_inst_done || intr_send),
		.dout			({w_buf_src_mac, w_buf_ptype, w_buf_fport[3:0], w_buf_dsize, w_buf_daddr, w_buf_opts})
	);
	assign	w_buf_fport[7:4]	= 4'h0;

	receive_decoder rdecoder (
		.clk				(M_ACLK),

		.src_mac			(w_buf_src_mac),
		.ptype				(w_buf_ptype),
		.fport				(w_buf_fport),
		.dsize				(w_buf_dsize),
		.daddr				(w_buf_daddr),
		.opts				(w_buf_opts),

		.soft_reset			(),
		.inst_pop			(intr_send),

		.write_start		(w_wstart),
		.write_address		(w_addr),
		.write_size			(w_size),

		.inst_ops			(inst_ops),
		.inst_mac			(inst_mac),
		.inst_port			(inst_port),
		.inst_size			(inst_size),
		.inst_daddr			(inst_daddr),
		.inst_opts			(inst_opts)
	);

	axi_m_write #(
		.MAX_BURST_LEN		(256),
		.ADDR_WIDTH			(AXIADDR_WIDTH),
		.DATA_WIDTH			(AXIDATA_WIDTH)
	) inst_axi (
		.i_wstart			(w_wstart),
		.i_start_address	(w_addr),
		.i_write_size		(w_size),
		.o_wdone			(w_inst_done),

		.i_fixed_burst		(1'h0),

		//.i_fifo_full		(1'b0),
		.i_fifo_empty		(w_emp),
		.i_fifo_data		(w_axi_d),
		.o_fifo_en			(w_axi_ren),

		.M_ACLK				(M_ACLK),
		.M_ARESETN			(M_ARESETN),

		.M_AWID				(M_AXI_AWID),
		.M_AWADDR			(M_AXI_AWADDR),
		.M_AWLEN			(M_AXI_AWLEN),
		.M_AWSIZE			(M_AXI_AWSIZE),
		.M_AWBURST			(M_AXI_AWBURST),
		.M_AWLOCK			(M_AXI_AWLOCK),
		.M_AWCACHE			(M_AXI_AWCACHE),
		.M_AWQOS			(M_AXI_AWQOS),
		.M_AWUSER			(M_AXI_AWUSER),
		.M_AWPROT			(M_AXI_AWPROT),
		.M_AWVALID			(M_AXI_AWVALID),
		.M_AWREADY			(M_AXI_AWREADY),

		.M_WDATA			(M_AXI_WDATA),
		.M_WSTRB			(M_AXI_WSTRB),
		.M_WLAST			(M_AXI_WLAST),
		.M_WUSER			(M_AXI_WUSER),
		.M_WVALID			(M_AXI_WVALID),
		.M_WREADY			(M_AXI_WREADY),

		.M_BID				(M_AXI_BID),
		.M_BRESP			(M_AXI_BRESP),
		.M_BUSER			(M_AXI_BUSER),
		.M_BVALID			(M_AXI_BVALID),
		.M_BREADY			(M_AXI_BREADY)
	);

endmodule