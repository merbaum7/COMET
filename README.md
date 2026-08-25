<!-- ![COMET](logo/COMET_logo1.png) -->
<div align="center">
    <img src="logo/COMET_logo1.png" width="80%" alt="COMET">
</div>

# COMET: Configurable Over Multi-rate Ethernet based Transceiver

COMET is an open-source implementation of MII(Media Independent Interface) Transceiver.  
It works on any FPGA boards which has Ethernet phy(phy chip or FPGA Implemented IP).


## Documentation quick links

* [Overview](#overview)
* [Publications](#publications)
* [License](#license)
* [FAQ](#faq)
* [Revision History](#revison-history)

Overview
==============================

COMET is a via Ethernet transaction transceiver for PC/FPGA mixed Cluster/Distributed System.  
This circuit prioritizes lightness and ease of implementation by intentionally eliminating heavy components and limiting its functionality.

## Based Protocol

COMET is implemented using communication based on the Ethernet data link layer. Transferred data is implemented using COMET Frames, an extension of Ethernet II Frames, achieving simple yet low-latency data transfer.

Similar to UDP, it utilizes transactions that do not guarantee data arrival. However, congestion control using PAUSE frames is used to reduce the amount of data that does not arrive due to buffer overflow. Hardware-level congestion transfer control minimizes data non-arrival to an almost negligible degree.

## Scalability

By supporting multiple MII (Media Independent Interface) standards, it became possible to adapt to interfaces with varying speeds. As a result, expansion becomes possible with FPGA boards that can be connected to commercially available L2 switches, effectively enabling scaling within the range of supported MAC addresses.

## Productivity

COMET requires only two or three parameters for setup, enabling rapid system development and improving productivity.

### Setting examples

<table>
<tr>
<th> XGMII </th>
<th> GMII </th>
<th> MII </th>
</tr>

<!-- XGMII Interface Setting -->
<td>

```verilog

wire [63:0] xgmii_rxd;
wire [7:0]  xgmii_rxc;
wire [63:0] xgmii_txd;
wire [7:0]  xgmii_txc;

comet #(
    .MII_TYPE      ("XGMII"),
    .ADATA_WIDTH   (128),
    .AADDR_WIDTH   (32)
) comet_xgmii (
    .mii_clk           (mii_clk),
    .mii_rst           (mii_rst),

    .mii_rx_d          (xgmii_rxd),
    .mii_rx_c          (xgmii_rxc),
    .mii_tx_d          (xgmii_txd),
    .mii_tx_c          (xgmii_txc),

    .own_mac           (OWN_MAC),

    .i_inst_en         (i_inst_en),
    .o_inst_fdone      (o_inst_fdone),

    .i_ops             (i_ops),
    .i_dst_mac         (i_dst_mac),
    .i_dsize           (i_dsize),
    .i_axi_srcaddr     (i_axi_srcaddr),
    .i_axi_dstaddr     (i_axi_dstaddr),

    .M_ACLK            (M_ACLK),
    .M_ARESETN         (M_ARESETN),

    .M_AWID            (M_AWID),
    .M_AWADDR          (M_AWADDR),
    .M_AWLEN           (M_AWLEN),
    .M_AWSIZE          (M_AWSIZE),
    .M_AWBURST         (M_AWBURST),
    .M_AWLOCK          (M_AWLOCK),
    .M_AWCACHE         (M_AWCACHE),
    .M_AWQOS           (M_AWQOS),
    .M_AWUSER          (M_AWUSER),
    .M_AWPROT          (M_AWPROT),
    .M_AWVALID         (M_AWVALID),
    .M_AWREADY         (M_AWREADY),

    .M_WDATA           (M_WDATA),
    .M_WSTRB           (M_WSTRB),
    .M_WLAST           (M_WLAST),
    .M_WUSER           (M_WUSER),
    .M_WVALID          (M_WVALID),
    .M_WREADY          (M_WREADY),

    .M_BID             (M_BID),
    .M_BRESP           (M_BRESP),
    .M_BUSER           (M_BUSER),
    .M_BVALID          (M_BVALID),
    .M_BREADY          (M_BREADY),

    .M_ARID            (M_ARID),
    .M_ARADDR          (M_ARADDR),
    .M_ARLEN           (M_ARLEN),
    .M_ARSIZE          (M_ARSIZE),
    .M_ARBURST         (M_ARBURST),
    .M_ARLOCK          (M_ARLOCK),
    .M_ARCACHE         (M_ARCACHE),
    .M_ARPROT          (M_ARPROT),
    .M_ARQOS           (M_ARQOS),
    .M_ARUSER          (M_ARUSER),
    .M_ARVALID         (M_ARVALID),
    .M_ARREADY         (M_ARREADY),

    .M_RID             (M_RID),
    .M_RDATA           (M_RDATA),
    .M_RRESP           (M_RRESP),
    .M_RLAST           (M_RLAST),
    .M_RUSER           (M_RUSER),
    .M_RVALID          (M_RVALID),
    .M_RREADY          (M_RREADY)
);
```

</td>

<!-- GMII Interface Setting -->
<td>

```verilog

wire [7:0] gmii_rxd;
wire       gmii_rx_dv;
wire       gmii_rx_er;
wire [7:0] gmii_txd;
wire       gmii_tx_en;

comet #(
    .MII_TYPE      ("GMII"),
    .ADATA_WIDTH   (32),
    .AADDR_WIDTH   (32)
) comet_xgmii (
    .mii_clk           (mii_clk),
    .mii_rst           (mii_rst),

    .mii_rx_d          (gmii_rxd),
    .mii_rx_c          (gmii_rx_dv),
    .mii_tx_d          (gmii_txd),
    .mii_tx_c          (gmii_tx_en),

    .own_mac           (OWN_MAC),

    .i_inst_en         (i_inst_en),
    .o_inst_fdone      (o_inst_fdone),

    .i_ops             (i_ops),
    .i_dst_mac         (i_dst_mac),
    .i_dsize           (i_dsize),
    .i_axi_srcaddr     (i_axi_srcaddr),
    .i_axi_dstaddr     (i_axi_dstaddr),

    .M_ACLK            (M_ACLK),
    .M_ARESETN         (M_ARESETN),

    .M_AWID            (M_AWID),
    .M_AWADDR          (M_AWADDR),
    .M_AWLEN           (M_AWLEN),
    .M_AWSIZE          (M_AWSIZE),
    .M_AWBURST         (M_AWBURST),
    .M_AWLOCK          (M_AWLOCK),
    .M_AWCACHE         (M_AWCACHE),
    .M_AWQOS           (M_AWQOS),
    .M_AWUSER          (M_AWUSER),
    .M_AWPROT          (M_AWPROT),
    .M_AWVALID         (M_AWVALID),
    .M_AWREADY         (M_AWREADY),

    .M_WDATA           (M_WDATA),
    .M_WSTRB           (M_WSTRB),
    .M_WLAST           (M_WLAST),
    .M_WUSER           (M_WUSER),
    .M_WVALID          (M_WVALID),
    .M_WREADY          (M_WREADY),

    .M_BID             (M_BID),
    .M_BRESP           (M_BRESP),
    .M_BUSER           (M_BUSER),
    .M_BVALID          (M_BVALID),
    .M_BREADY          (M_BREADY),

    .M_ARID            (M_ARID),
    .M_ARADDR          (M_ARADDR),
    .M_ARLEN           (M_ARLEN),
    .M_ARSIZE          (M_ARSIZE),
    .M_ARBURST         (M_ARBURST),
    .M_ARLOCK          (M_ARLOCK),
    .M_ARCACHE         (M_ARCACHE),
    .M_ARPROT          (M_ARPROT),
    .M_ARQOS           (M_ARQOS),
    .M_ARUSER          (M_ARUSER),
    .M_ARVALID         (M_ARVALID),
    .M_ARREADY         (M_ARREADY),

    .M_RID             (M_RID),
    .M_RDATA           (M_RDATA),
    .M_RRESP           (M_RRESP),
    .M_RLAST           (M_RLAST),
    .M_RUSER           (M_RUSER),
    .M_RVALID          (M_RVALID),
    .M_RREADY          (M_RREADY)
);
```

</td>

<!-- MII Interface Setting -->
<td>

```verilog

wire [3:0] mii_rxd;
wire       mii_rx_dv;
wire       mii_rx_er;
wire [3:0] mii_txd;
wire       mii_tx_en;

comet #(
    .MII_TYPE      ("MII"),
    .ADATA_WIDTH   (32),
    .AADDR_WIDTH   (32)
) comet_xgmii (
    .mii_clk           (mii_clk),
    .mii_rst           (mii_rst),

    .mii_rx_d          (mii_rxd),
    .mii_rx_c          (mii_rx_dv),
    .mii_tx_d          (mii_txd),
    .mii_tx_c          (mii_tx_en),

    .own_mac           (OWN_MAC),

    .i_inst_en         (i_inst_en),
    .o_inst_fdone      (o_inst_fdone),

    .i_ops             (i_ops),
    .i_dst_mac         (i_dst_mac),
    .i_dsize           (i_dsize),
    .i_axi_srcaddr     (i_axi_srcaddr),
    .i_axi_dstaddr     (i_axi_dstaddr),

    .M_ACLK            (M_ACLK),
    .M_ARESETN         (M_ARESETN),

    .M_AWID            (M_AWID),
    .M_AWADDR          (M_AWADDR),
    .M_AWLEN           (M_AWLEN),
    .M_AWSIZE          (M_AWSIZE),
    .M_AWBURST         (M_AWBURST),
    .M_AWLOCK          (M_AWLOCK),
    .M_AWCACHE         (M_AWCACHE),
    .M_AWQOS           (M_AWQOS),
    .M_AWUSER          (M_AWUSER),
    .M_AWPROT          (M_AWPROT),
    .M_AWVALID         (M_AWVALID),
    .M_AWREADY         (M_AWREADY),

    .M_WDATA           (M_WDATA),
    .M_WSTRB           (M_WSTRB),
    .M_WLAST           (M_WLAST),
    .M_WUSER           (M_WUSER),
    .M_WVALID          (M_WVALID),
    .M_WREADY          (M_WREADY),

    .M_BID             (M_BID),
    .M_BRESP           (M_BRESP),
    .M_BUSER           (M_BUSER),
    .M_BVALID          (M_BVALID),
    .M_BREADY          (M_BREADY),

    .M_ARID            (M_ARID),
    .M_ARADDR          (M_ARADDR),
    .M_ARLEN           (M_ARLEN),
    .M_ARSIZE          (M_ARSIZE),
    .M_ARBURST         (M_ARBURST),
    .M_ARLOCK          (M_ARLOCK),
    .M_ARCACHE         (M_ARCACHE),
    .M_ARPROT          (M_ARPROT),
    .M_ARQOS           (M_ARQOS),
    .M_ARUSER          (M_ARUSER),
    .M_ARVALID         (M_ARVALID),
    .M_ARREADY         (M_ARREADY),

    .M_RID             (M_RID),
    .M_RDATA           (M_RDATA),
    .M_RRESP           (M_RRESP),
    .M_RLAST           (M_RLAST),
    .M_RUSER           (M_RUSER),
    .M_RVALID          (M_RVALID),
    .M_RREADY          (M_RREADY)
);
```

</td>

</tr>
</table>

## Supported Interfaces

- MII(4bit)　　: 100BASE
- GMII(8bit) 　: 1000BASE
- XGMII(64bit) : 10GBASE
- 25GMII(64bit): 25GBASE

Publications
==============================

* Keisuke Takano,
  "RDMA and PR mechanism for Middle Scale FPGA clusters",
  Janualy 2026. IEICE Conferences Archives, In: Technical Committee on Reconfigurable Systems (RECONF) in 2026/1.
* Keisuke Takano,
  "Concept of Heterogeneous PC-FPGA hybrid system",
  August 2025. IEICE Conferences Archives, In: Summer United Workshops on Parallel, Distributed and Cooperative Processing 2025.
  


License
==============================

Solderpad Hardware License v2.1 (https://solderpad.org/licenses/SHL-2.1)


FAQ
==============================

Comming soon.


Revison History
==============================

You can find the releases in https://github.com/merbaum7/COMET 
- 0.99.0 (May.15, 2026): The initial release.  
- 0.99.1 (May.18, 2026): The initial implement of Internal port disable version.  
- 0.99.2 (May.20, 2026): Valid Input instruction port (From FPGA Logic).  
  [Address Width is FIXED 32bit]  
- 0.99.3 (Jun.19, 2026): Fixed Send/Recv data size definition.  
- 0.99.4 (Jul.18, 2026): Fixed Existing Partially Synchronous Reset to Asynchronous Reset.  
- 0.99.5 (Aug.25, 2026): Fixed option parameter multiplexer in Sender Module.  
- 0.99.6 (Aug.25, 2026): Fixed AXI read/write size (in header decoding).  

