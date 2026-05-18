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
			//parameter	CWWIDTH	=	$clog2(OWIDTH/IWIDTH);

			reg	[$clog2(OWIDTH/IWIDTH):0]		r_icount;
			reg	[OWIDTH-1:0]	r_wdata;
			reg					r_wen;

			always @(posedge clk) begin
				if (rst) begin
					r_icount		<=	0;
					r_wdata			<=	0;
					r_wen			<=	0;
				end	else begin
					if(i_wen) begin
						r_icount					<=	(r_icount == (OWIDTH/IWIDTH-1+DL)) ? 0 : r_icount + 1;
						r_wdata						<=	{((r_icount == 0) ? {(OWIDTH-IWIDTH){1'b0}} : r_wdata), i_wdata};
						r_wen						<=	r_icount == (OWIDTH/IWIDTH-1+DL);
					end else begin
						r_icount					<=	(r_icount == (OWIDTH/IWIDTH-1+DL)) ? 0 : r_icount;
						if (reject) begin
							r_wen						<=	1'b1;
							r_icount					<=	0;
						end else begin
							r_wen						<=	r_icount == (OWIDTH/IWIDTH-1+DL);
						end
					end	
				end
			end

			assign	o_wdata	=	r_wdata;
			assign	o_wen	=	r_wen;
			assign	o_busy	=	0;

		end else begin : oli
			//parameter	CWWIDTH	=	$clog2(IWIDTH/OWIDTH);

			reg	[$clog2(IWIDTH/OWIDTH):0]		r_ocount;
			reg	[OWIDTH-1:0]	r_wdata;
			reg	[IWIDTH-1:0]	r_tmpwdata;
			reg					r_wen;
			always @(posedge clk) begin
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
						end else if (r_ocount == IWIDTH/OWIDTH) begin
							r_wen			<=	0;
							r_ocount		<=	0;
							r_wdata			<=	0;
						end else begin
							r_ocount		<=	r_ocount + 1;
							r_wdata			<=	r_tmpwdata[r_ocount*OWIDTH+:OWIDTH];
						end
					end else if(i_wen) begin
						r_ocount		<=	1;
						r_tmpwdata		<=	i_wdata;
						r_wdata			<=	i_wdata[0+:OWIDTH];
						r_wen			<=	1;
					end				
				end
			end

			assign	o_wdata	=	(stop) ? 0 : r_wdata;
			assign	o_wen	=	(stop) ? 1'b0 : r_wen;
			assign	o_busy	=	r_wen;
		end

	endgenerate
endmodule