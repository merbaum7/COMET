module send_decoder (
	input				clk,

	// inst
	input	[3:0]		i_ops,
	input	[47:0]		i_mac,
	input	[3:0]		i_port,
	input	[7:0]		i_size,
	input	[31:0]		i_daddr,
	input	[31:0]		i_opts,

	// future work(using burst control)
	// input				head_done,
	// output				inst_done,

	// axi read control
	output				read_start,
	output	[31:0]		read_address,
	output	[31:0]		read_size,

	// to phy module (parameters)
	output	[47:0]		dst_mac,
	output	[15:0]		ptype,
	output	[7:0]		fport,
	output	[7:0]		dsize,
	output	[31:0]		daddr,
	output	[31:0]		opts
);
	parameter	REGREQ		=	16'h0101,
				DATAFRAME	=	16'h0110,
				DATAREQ		=	16'h0111,

				INIT_RESET	=	16'h01FF;

	assign read_start		= (ptype == DATAFRAME);
	assign read_address		= i_opts;
	assign read_size		= (ptype == DATAFRAME) ? ({24'h0,dsize}+1) << 5 : 32'h0;

	assign dst_mac	=	i_mac;
	assign ptype	=	i_ops == 4'h1 ? DATAFRAME :
						i_ops == 4'h2 ? DATAREQ :
						i_ops == 4'h3 ? REGREQ :
						16'h0;
	assign fport	= 	{4'h0,i_port};
	assign dsize	= 	i_size;
	assign daddr	= 	i_daddr;
	assign opts		= 	(ptype == DATAFRAME) ? i_opts : 32'h0;
endmodule

module AXI2send #(
	parameter	MII_TYPE		=	"GMII",
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

	parameter	AXIDATA_WIDTH	=	32,
	parameter	AXIADDR_WIDTH	=	32
)(
	input						rst,

	// mii interface
	input						mii_clk,

	output	[MII_WIDTH-1:0]		mii_tx_d,
	output	[MII_CTLW-1:0]		mii_tx_c,

	input						hw_wait,
	input	[47:0]				own_mac,

	input						inst_store,	// fifo write enable for instruction

	input	[3:0]				inst_ops,
	input	[47:0]				inst_mac,
	input	[3:0]				inst_port,
	input	[7:0]				inst_size,
	input	[31:0]				inst_daddr,
	input	[31:0]				inst_opts,

	output						inst_full,	// fifo full for instruction

	// Read
	input						M_ACLK,
	input						M_ARESETN,
	// - Address
	output	[0:0]				M_AXI_ARID,
	output	[AXIADDR_WIDTH-1:0]	M_AXI_ARADDR,
	output	[7:0]				M_AXI_ARLEN,
	output	[2:0]				M_AXI_ARSIZE,
	output	[1:0]				M_AXI_ARBURST,
	output						M_AXI_ARLOCK,
	output	[3:0]				M_AXI_ARCACHE,
	output	[2:0]				M_AXI_ARPROT,
	output	[3:0]				M_AXI_ARQOS,
	output	[0:0]				M_AXI_ARUSER,
	output						M_AXI_ARVALID,
	input						M_AXI_ARREADY,
	// - Data
	input	[0:0]				M_AXI_RID,
	input	[AXIDATA_WIDTH-1:0]	M_AXI_RDATA,
	input	[1:0]				M_AXI_RRESP,
	input						M_AXI_RLAST,
	input	[0:0]				M_AXI_RUSER,
	input						M_AXI_RVALID,
	output						M_AXI_RREADY
);
	parameter	MIIFIFO_WIDTH	=	(MII_TYPE =="25GMII") ? MII_WIDTH
								:	(MII_TYPE == "XGMII") ? MII_WIDTH
								:	8;

	// Data IF(MII internal FIFO)
	wire						w_inbuf_full;
	wire						w_inbuf_wen;
	wire	[MIIFIFO_WIDTH-1:0]	w_inbuf_d;

	// DATA IF(FIFO)
	wire						w_full;
	wire						w_empty;
	wire						w_buf_ren;
	wire	[AXIDATA_WIDTH-1:0]	w_buf_rd;
	wire						w_buf_wen;
	wire	[AXIDATA_WIDTH-1:0]	w_buf_wd;

	wire						w_busy;

	// decoded IF
	wire	[47:0]				w_src_mac;
	wire	[47:0]				w_dst_mac;
	wire	[15:0]				w_ptype;	
	wire	[7:0]				w_fport;
	wire	[7:0]				w_dsize;
	wire	[31:0]				w_daddr;
	wire	[31:0]				w_opts;

	wire						w_rstart;
	wire	[31:0]				w_addr;
	wire	[31:0]				w_size;

	wire	[3:0]				w_buf_ops;
	wire	[47:0]				w_buf_mac;
	wire	[3:0]				w_buf_port;
	wire	[7:0]				w_buf_size;
	wire	[31:0]				w_buf_daddr;
	wire	[31:0]				w_buf_opts;
	wire						w_inst_done;

	send_mii #(
		.MII_TYPE		(MII_TYPE),
		.MII_BUFLEN		(16),

		.PARAM_REG		(1)
	) inst_phy (
		.clk			(mii_clk),
		.rst			(rst),

		.mii_tx_d		(mii_tx_d),
		.mii_tx_c		(mii_tx_c),

		.hw_wait		(hw_wait),
		.force_send		(w_buf_ops == 4'h2 || w_buf_ops == 4'h3),

		// Data IF(FIFO)
		.buf_clk		(M_ACLK),
		.buf_wen		(w_inbuf_wen),
		.buf_d			(w_inbuf_d),
		.buf_full		(w_inbuf_full),

		.src_mac		(w_src_mac),
		.dst_mac		(w_dst_mac),
		.ptype			(w_ptype),
		.fport			(w_fport),
		.dsize			(w_dsize),
		.daddr			(w_daddr),
		.opts			(w_opts),

		.head_end		(w_inst_done),
		.send_done		()
	);
	
	assign	w_src_mac	= own_mac;

	fifo_Width_Converter #(
		.IWIDTH			(AXIDATA_WIDTH),
		.OWIDTH			(MIIFIFO_WIDTH),
		.DL				(MII_TYPE == "MII")
	) inst_conv (
		.clk			(M_ACLK),
		.rst			(rst),

		.reject			(1'b0),
		.stop			(w_inbuf_full),

		.o_wen			(w_inbuf_wen),
		.o_wdata		(w_inbuf_d),

		.i_wen			(w_buf_ren),
		.i_wdata		(w_buf_rd),

		.o_busy			(w_busy)
	);

	assign	w_buf_ren	=	!(w_empty | w_busy);

	fifo #(
		.BWIDTH			(AXIDATA_WIDTH),
		.DEPTH			(64)
	) inst_d_fifo (
		.wclk			(M_ACLK),
		.rclk			(M_ACLK),
		.rst			(rst),

		.afull			(w_full),
		.emp			(w_empty),

		.dout_en		(w_buf_ren),
		.dout			(w_buf_rd),

		.din_en			(w_buf_wen),
		.din			(w_buf_wd)
	);

	// ops[4], dstmac[48], fpgaport[4], datasize[8], address[32], opts[32] = 128bit
	fifo #(
		.BWIDTH			(128),
		.DEPTH			(8)
	) inst_i_fifo (
		.wclk			(M_ACLK),
		.rclk			(mii_clk),
		.rst			(rst),

		.afull			(inst_full),
		//.emp			(),

		.din_en			(inst_store),
		.din			({inst_ops, inst_mac, inst_port, inst_size, inst_daddr, inst_opts}),

		.dout_en		(w_inst_done),
		.dout			({w_buf_ops, w_buf_mac, w_buf_port, w_buf_size, w_buf_daddr, w_buf_opts})
	);

	send_decoder sdecoder (
		.clk				(M_ACLK),

		.i_ops				(w_buf_ops),
		.i_mac				(w_buf_mac),
		.i_port				(w_buf_port),
		.i_size				(w_buf_size),
		.i_daddr			(w_buf_daddr),
		.i_opts				(w_buf_opts),

		.dst_mac			(w_dst_mac),
		.ptype				(w_ptype),
		.fport				(w_fport),
		.dsize				(w_dsize),
		.daddr				(w_daddr),
		.opts				(w_opts),

		.read_start			(w_rstart),
		.read_address		(w_addr),
		.read_size			(w_size)
	);

	axi_m_read #(
		.MAX_BURST_LEN		(256),

		.ADDR_WIDTH			(AXIADDR_WIDTH),
		.DATA_WIDTH			(AXIDATA_WIDTH)
	) u_axi_read_base (
		.i_rstart			(w_rstart),
		.i_start_address	(w_addr),
		.i_read_size		(w_size),
		.o_rdone			(),

		.i_fixed_burst		(1'b0),

		.i_fifo_full		(w_full),
		.o_fifo_data		(w_buf_wd),
		.o_fifo_en			(w_buf_wen),

		.M_ACLK				(M_ACLK),
		.M_ARESETN			(M_ARESETN),

		.M_ARID				(M_AXI_ARID),
		.M_ARADDR			(M_AXI_ARADDR),
		.M_ARLEN			(M_AXI_ARLEN),
		.M_ARSIZE			(M_AXI_ARSIZE),
		.M_ARBURST			(M_AXI_ARBURST),
		.M_ARLOCK			(M_AXI_ARLOCK),
		.M_ARCACHE			(M_AXI_ARCACHE),
		.M_ARPROT			(M_AXI_ARPROT),
		.M_ARQOS			(M_AXI_ARQOS),
		.M_ARUSER			(M_AXI_ARUSER),
		.M_ARVALID			(M_AXI_ARVALID),
		.M_ARREADY			(M_AXI_ARREADY),

		.M_RID				(M_AXI_RID),
		.M_RDATA			(M_AXI_RDATA),
		.M_RRESP			(M_AXI_RRESP),
		.M_RLAST			(M_AXI_RLAST),
		.M_RUSER			(M_AXI_RUSER),
		.M_RVALID			(M_AXI_RVALID),
		.M_RREADY			(M_AXI_RREADY)
	);

endmodule