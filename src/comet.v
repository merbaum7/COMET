module comet #(
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

	parameter	ADATA_WIDTH		=	32,
	parameter	AADDR_WIDTH		=	32
) (
	// mii interface
	input						mii_clk,
	input						mii_rst,

	input	[MII_WIDTH-1:0]		mii_rx_d,
	input	[MII_CTLW-1:0]		mii_rx_c,
	output	[MII_WIDTH-1:0]		mii_tx_d,
	output	[MII_CTLW-1:0]		mii_tx_c,

	input	[47:0]				own_mac,

	// to sender module (parameters)
	input						i_inst_en,
	output						o_inst_fdone,

	input	[3:0]				i_ops,
	input	[47:0]				i_dst_mac,
	input	[7:0]				i_dsize,
	input	[31:0]				i_axi_srcaddr,
	input	[31:0]				i_axi_dstaddr,

	// AXI interface
	input						M_ACLK,
	input						M_ARESETN,
	// Write
	// - Address
	output	[0:0]				M_AWID,
	output	[AADDR_WIDTH-1:0]	M_AWADDR,
	output	[7:0]				M_AWLEN,
	output	[2:0]				M_AWSIZE,
	output	[1:0]				M_AWBURST,
	output						M_AWLOCK,
	output	[3:0]				M_AWCACHE,
	output	[2:0]				M_AWQOS,
	output	[0:0]				M_AWUSER,
	output	[2:0]				M_AWPROT,
	output						M_AWVALID,
	input						M_AWREADY,
	// - Data
	output	[ADATA_WIDTH-1:0]	M_WDATA,
	output	[ADATA_WIDTH/8-1:0]	M_WSTRB,
	output						M_WLAST,
	output	[0:0]				M_WUSER,
	output						M_WVALID,
	input						M_WREADY,
	// - Response
	input	[0:0]				M_BID,
	input	[1:0]				M_BRESP,
	input	[0:0]				M_BUSER,
	input						M_BVALID,
	output						M_BREADY,

	// Read
	// - Address
	output	[0:0]				M_ARID,
	output	[AADDR_WIDTH-1:0]	M_ARADDR,
	output	[7:0]				M_ARLEN,
	output	[2:0]				M_ARSIZE,
	output	[1:0]				M_ARBURST,
	output						M_ARLOCK,
	output	[3:0]				M_ARCACHE,
	output	[2:0]				M_ARPROT,
	output	[3:0]				M_ARQOS,
	output	[0:0]				M_ARUSER,
	output						M_ARVALID,
	input						M_ARREADY,

	// - Data
	input	[0:0]				M_RID,
	input	[ADATA_WIDTH-1:0]	M_RDATA,
	input	[1:0]				M_RRESP,
	input						M_RLAST,
	input	[0:0]				M_RUSER,
	input						M_RVALID,
	output						M_RREADY
);

	wire	w_hw_wait;

	// from recv to inst_ctrl
	wire	w_recv_inst_en;

	wire [3:0]		w_recv_inst_ops;
	wire [47:0]		w_recv_inst_mac;
	wire [3:0]		w_recv_inst_port;
	wire [7:0]		w_recv_inst_size;
	wire [31:0]		w_recv_inst_daddr;
	wire [31:0]		w_recv_inst_opts;

	// from inst_ctrl to sender
	wire	w_send_inst_store;

	wire [3:0]		w_send_inst_ops;
	wire [47:0]		w_send_inst_mac;
	wire [3:0]		w_send_inst_port;
	wire [7:0]		w_send_inst_size;
	wire [31:0]		w_send_inst_daddr;
	wire [31:0]		w_send_inst_opts;

	wire	w_send_inst_full;

	// module instances
	receive2AXI #(
		.MII_TYPE		(MII_TYPE),
		.AXIDATA_WIDTH	(ADATA_WIDTH),
		.AXIADDR_WIDTH	(AADDR_WIDTH)
	) receiver (
		.rst			(mii_rst),
		.mii_clk		(mii_clk),
		.mii_rx_d		(mii_rx_d),
		.mii_rx_c		(mii_rx_c),

		.hw_wait		(w_hw_wait),
		.own_mac		(own_mac),

		.intr_send		(w_recv_inst_en),

		.inst_ops		(w_recv_inst_ops),
		.inst_mac		(w_recv_inst_mac),
		.inst_port		(w_recv_inst_port),
		.inst_size		(w_recv_inst_size),
		.inst_daddr		(w_recv_inst_daddr),
		.inst_opts		(w_recv_inst_opts),

		.M_ACLK			(M_ACLK),
		.M_ARESETN		(M_ARESETN),
		
		.M_AXI_AWID		(M_AWID),
		.M_AXI_AWADDR	(M_AWADDR),
		.M_AXI_AWLEN	(M_AWLEN),
		.M_AXI_AWSIZE	(M_AWSIZE),
		.M_AXI_AWBURST	(M_AWBURST),
		.M_AXI_AWLOCK	(M_AWLOCK),
		.M_AXI_AWCACHE	(M_AWCACHE),
		.M_AXI_AWQOS	(M_AWQOS),
		.M_AXI_AWUSER	(M_AWUSER),
		.M_AXI_AWPROT	(M_AWPROT),
		.M_AXI_AWVALID	(M_AWVALID),
		.M_AXI_AWREADY	(M_AWREADY),

		.M_AXI_WDATA	(M_WDATA),
		.M_AXI_WSTRB	(M_WSTRB),
		.M_AXI_WLAST	(M_WLAST),
		.M_AXI_WUSER	(M_WUSER),
		.M_AXI_WVALID	(M_WVALID),
		.M_AXI_WREADY	(M_WREADY),

		.M_AXI_BID		(M_BID),
		.M_AXI_BRESP	(M_BRESP),
		.M_AXI_BUSER	(M_BUSER),
		.M_AXI_BVALID	(M_BVALID),
		.M_AXI_BREADY	(M_BREADY)
	);

	instruction_controller inst_ctrl (
		.clk			(M_ACLK),
		.rst			(!M_ARESETN),

		// received frame instruction
		.inst_en		(w_recv_inst_en),

		.recv_ops		(w_recv_inst_ops),
		.recv_mac		(w_recv_inst_mac),
		.recv_port		(w_recv_inst_port),
		.recv_size		(w_recv_inst_size),
		.recv_daddr		(w_recv_inst_daddr),
		.recv_opts		(w_recv_inst_opts),

		// sender operations
		.inst_store		(w_send_inst_store), // fifo read enable for instruction

		.send_ops		(w_send_inst_ops),
		.send_mac		(w_send_inst_mac),
		.send_port		(w_send_inst_port),
		.send_size		(w_send_inst_size),
		.send_daddr		(w_send_inst_daddr),
		.send_opts		(w_send_inst_opts),

		.send_full		(w_send_inst_full), // fifo full for instruction

		.i_inst_en		(i_inst_en),
		.o_inst_fdone	(o_inst_fdone),

		.i_ops			(i_ops),
		.i_dst_mac		(i_dst_mac),
		.i_dsize		(i_dsize),
		.i_axi_srcaddr	(i_axi_srcaddr),
		.i_axi_dstaddr	(i_axi_dstaddr)
	);

	AXI2send #(
		.MII_TYPE		(MII_TYPE),
		.AXIDATA_WIDTH	(ADATA_WIDTH),
		.AXIADDR_WIDTH	(AADDR_WIDTH)
	) sender (
		.rst			(mii_rst),
		.mii_clk		(mii_clk),
		.mii_tx_d		(mii_tx_d),
		.mii_tx_c		(mii_tx_c),

		.hw_wait		(w_hw_wait),

		.own_mac		(own_mac),

		.inst_store		(w_send_inst_store), // fifo write enable for instruction

		.inst_ops		(w_send_inst_ops),
		.inst_mac		(w_send_inst_mac),
		.inst_port		(w_send_inst_port),
		.inst_size		(w_send_inst_size),
		.inst_daddr		(w_send_inst_daddr),
		.inst_opts		(w_send_inst_opts),

		.inst_full		(w_send_inst_full), // fifo full for instruction

		.M_ACLK			(M_ACLK),
		.M_ARESETN		(M_ARESETN),

		.M_AXI_ARID		(M_ARID),
		.M_AXI_ARADDR	(M_ARADDR),
		.M_AXI_ARLEN	(M_ARLEN),
		.M_AXI_ARSIZE	(M_ARSIZE),
		.M_AXI_ARBURST	(M_ARBURST),
		.M_AXI_ARLOCK	(M_ARLOCK),
		.M_AXI_ARCACHE	(M_ARCACHE),
		.M_AXI_ARPROT	(M_ARPROT),
		.M_AXI_ARQOS	(M_ARQOS),
		.M_AXI_ARUSER	(M_ARUSER),
		.M_AXI_ARVALID	(M_ARVALID),
		.M_AXI_ARREADY	(M_ARREADY),

		.M_AXI_RID		(M_RID),
		.M_AXI_RDATA	(M_RDATA),
		.M_AXI_RRESP	(M_RRESP),
		.M_AXI_RLAST	(M_RLAST),
		.M_AXI_RUSER	(M_RUSER),
		.M_AXI_RVALID	(M_RVALID),
		.M_AXI_RREADY	(M_RREADY)
	);
	
endmodule