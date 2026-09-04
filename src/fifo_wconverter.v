module fifo_Width_Converter #(
	parameter	IWIDTH	=	32,
	parameter	OWIDTH	=	8,
	parameter	DL		=	0
) (
	input					clk,
	input					rst,

	input					reject,
	input					stop,

	// out
	output					o_wen,
	output	[OWIDTH-1:0]	o_wdata,

	// in
	input					i_wen,
	input	[IWIDTH-1:0]	i_wdata,

	output					o_busy		// only used in OWIDTH less than IWIDTH
);
	generate
		if (OWIDTH > IWIDTH) begin : ogi
			localparam integer IRATIO = OWIDTH / IWIDTH;
			localparam integer ICWIDTH = (IRATIO <= 1) ? 1 : $clog2(IRATIO);

			reg [ICWIDTH-1:0] r_icount;
			reg [OWIDTH-1:0]  r_accum;
			reg [OWIDTH-1:0]  r_wdata;
			reg               r_wvalid;

			always @(posedge clk) begin
				if (rst) begin
					r_icount	<= 0;
					r_accum		<= 0;
					r_wdata		<= 0;
					r_wvalid	<= 1'b0;
				end else begin
					r_wvalid	<= 1'b0;

					// rejectは未完成wordを破棄する
					if (reject) begin
						r_icount	<= 0;
						r_accum		<= 0;
						r_wvalid	<= 1'b0;
					end else if (i_wen) begin
						if (r_icount == IRATIO-1) begin
							// 8->32の場合:
							// {byte3, byte2, byte1, byte0}
							r_wdata	<= {
								i_wdata,
								r_accum[OWIDTH-IWIDTH-1:0]
							};
							r_wvalid	<= 1'b1;
							r_icount	<= 0;
						end else begin
							r_accum[r_icount*IWIDTH +: IWIDTH] <= i_wdata;
							r_icount	<= r_icount + 1'b1;
						end
					end
				end
			end

			assign o_wdata = r_wdata;
			assign o_wen   = r_wvalid;
			assign o_busy  = 1'b0;

		end else if (OWIDTH < IWIDTH)begin : oli
			localparam integer ORATIO = IWIDTH/OWIDTH;
			localparam integer OCWIDTH = (ORATIO <= 1) ? 1 : $clog2(ORATIO);

			reg	[OCWIDTH-1:0]	r_ocount;
			reg	[OWIDTH-1:0]	r_wdata;
			reg	[IWIDTH-1:0]	r_tmpwdata;
			reg					r_wen;
			wire				w_last = (r_ocount == ORATIO-1);
			
			always @(posedge clk or posedge rst) begin
				if (rst) begin
					r_ocount		<=	0;
					r_wdata			<=	0;
					r_tmpwdata		<=	0;
					r_wen			<=	0;
				end	else begin
					if (r_wen) begin
						if (stop) begin
							r_wen			<=	r_wen;
							r_ocount		<=	r_ocount;
							r_wdata			<=	r_wdata;
						end else if (w_last) begin
							if (i_wen) begin
								// Seamlessly continue with the next input word.
								r_ocount	<=	0;
								r_tmpwdata	<=	i_wdata;
								r_wdata		<=	i_wdata[0+:OWIDTH];
								r_wen		<=	1;
							end else begin
								r_wen		<=	0;
								r_ocount	<=	0;
								r_wdata		<=	0;
							end
						end else begin
							r_ocount		<=	r_ocount + 1;
							r_wdata			<=	r_tmpwdata[(r_ocount+1)*OWIDTH+:OWIDTH];
						end
					end else if(i_wen) begin
						r_ocount		<=	0;
						r_tmpwdata		<=	i_wdata;
						r_wdata			<=	i_wdata[0+:OWIDTH];
						r_wen			<=	1;
					end
				end
			end

			assign	o_wdata	=	(stop) ? 0 : r_wdata;
			assign	o_wen	=	(stop) ? 1'b0 : r_wen;
			assign	o_busy	=	r_wen && (stop || !w_last);

		end else if (OWIDTH == IWIDTH) begin : oei
			assign	o_wdata	=	i_wdata;
			assign	o_wen	=	i_wen && !stop && !reject;
			assign	o_busy	=	stop;
		end

	endgenerate
endmodule
