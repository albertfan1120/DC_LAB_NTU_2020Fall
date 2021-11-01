
module rsa_qsys (
	clk_clk,
	reset_reset_n,
	altpll_0_c1_clk,
	altpll_0_c2_clk,
	uart_0_external_connection_rxd,
	uart_0_external_connection_txd);	

	input		clk_clk;
	input		reset_reset_n;
	output		altpll_0_c1_clk;
	output		altpll_0_c2_clk;
	input		uart_0_external_connection_rxd;
	output		uart_0_external_connection_txd;
endmodule
