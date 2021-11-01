
module rsa_qsys (
	clk_clk,
	reset_reset_n,
	uart_0_external_connection_rxd,
	uart_0_external_connection_txd,
	altpll_0_c2_clk,
	altpll_0_c1_clk);	

	input		clk_clk;
	input		reset_reset_n;
	input		uart_0_external_connection_rxd;
	output		uart_0_external_connection_txd;
	output		altpll_0_c2_clk;
	output		altpll_0_c1_clk;
endmodule
