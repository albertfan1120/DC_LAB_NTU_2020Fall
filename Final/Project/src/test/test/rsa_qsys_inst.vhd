	component rsa_qsys is
		port (
			clk_clk                        : in  std_logic := 'X'; -- clk
			reset_reset_n                  : in  std_logic := 'X'; -- reset_n
			uart_0_external_connection_rxd : in  std_logic := 'X'; -- rxd
			uart_0_external_connection_txd : out std_logic;        -- txd
			altpll_0_c2_clk                : out std_logic;        -- clk
			altpll_0_c1_clk                : out std_logic         -- clk
		);
	end component rsa_qsys;

	u0 : component rsa_qsys
		port map (
			clk_clk                        => CONNECTED_TO_clk_clk,                        --                        clk.clk
			reset_reset_n                  => CONNECTED_TO_reset_reset_n,                  --                      reset.reset_n
			uart_0_external_connection_rxd => CONNECTED_TO_uart_0_external_connection_rxd, -- uart_0_external_connection.rxd
			uart_0_external_connection_txd => CONNECTED_TO_uart_0_external_connection_txd, --                           .txd
			altpll_0_c2_clk                => CONNECTED_TO_altpll_0_c2_clk,                --                altpll_0_c2.clk
			altpll_0_c1_clk                => CONNECTED_TO_altpll_0_c1_clk                 --                altpll_0_c1.clk
		);

