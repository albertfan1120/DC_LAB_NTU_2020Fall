`timescale 1ns/10ps
`define CYCLE      30
`define ENDCYCLE    3000000
//`define DATA  "./data/test_no0x.txt" 
`define DATA  "./data/red.txt" 
`define ANS_LEN  "./data/sram.txt"

module test();

localparam SRAM_SIZE = 1024*1024;
localparam PIXEL = 460800; //480*320*3

logic  avm_rst, avm_clk, avm_read, avm_write, avm_waitrequest, finish, VGA_clk;
logic  o_SRAM_WE_N, o_SRAM_CE_N, o_SRAM_OE_N, o_SRAM_LB_N, o_SRAM_UB_N,sram_write;
logic  VGA_BLANK_N, VGA_HS, VGA_VS, vga_clk ;
logic [ 4:0] avm_address;
logic [31:0] avm_readdata, avm_writedata;

logic [19:0] o_SRAM_ADDR, sram_addr;
logic [15:0] io_SRAM_DQ, sram_data,sram_data_nxt;

logic [ 7:0] VGA_R,VGA_G,VGA_B;
logic [19:0] debug_wire;
logic [15:0] sram_storage[SRAM_SIZE];
logic [ 7:0] input_data[PIXEL];
logic [15:0] golden[PIXEL/2];

wire [15:0] sram_data_w;
assign sram_data_w = (sram_write) ? sram_data :'z;

logic [19:0] cnt, cnt_nxt;
integer error_num, i;
Top m0(  
    .avm_rst(avm_rst),
    .avm_clk(avm_clk), 
    .avm_address(avm_address),
    .avm_read(avm_read),
    .avm_readdata(avm_readdata),
    .avm_write(avm_write),
    .avm_writedata(avm_writedata),
    .avm_waitrequest(avm_waitrequest),
    // SRAM interface
    .o_SRAM_ADDR(sram_addr),
	.io_SRAM_DQ(sram_data_w),
	.o_SRAM_WE_N(sram_write),
    .o_SRAM_CE_N(o_SRAM_CE_N),
	.o_SRAM_OE_N(o_SRAM_OE_N),
	.o_SRAM_LB_N(o_SRAM_LB_N),
	.o_SRAM_UB_N(o_SRAM_UB_N),
    // VGA interface
   // .VGA_clk(VGA_clk),
    .VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_BLANK_N(VGA_BLANK_N),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	//
	.debug_wire(debug_wire),
    .vga_clk(vga_clk),
    .CLK50(avm_clk),
    .pll_clk(avm_clk)
    //.finish(finish)
);

initial begin
	$fsdbDumpfile("final.fsdb");
	$fsdbDumpvars;
	$fsdbDumpMDA;
end

initial	$readmemh (`DATA, input_data);
//initial	$readmemh (`ANS_LEN, golden);
always #(`CYCLE/2) avm_clk  = ~avm_clk;
always #(`CYCLE*1.5)  VGA_clk  = ~ VGA_clk;

//-------------------  start here !!! ----------------------
initial begin
        avm_clk = 1;
        avm_rst = 0;
        VGA_clk = 1;
      //  cnt= 0;
        @(negedge avm_clk)  avm_rst = 1;
        #(`CYCLE*2)     avm_rst = 0;      
        #(`CYCLE*2) avm_waitrequest = 0;
        
end

always_comb begin
	if ( sram_write ) begin
        //@(posedge avm_clk)
		sram_data_nxt = sram_storage[sram_addr];
	end else begin
		sram_storage[sram_addr] = sram_data_w;
	end
end

always_comb begin
    cnt_nxt = cnt;
    if(avm_address==8)begin
        avm_readdata  = 32'd128;
    end
    else if(avm_address==0 &&　 avm_read)begin
        avm_readdata  = input_data[cnt];
        cnt_nxt = cnt +1;
    end
end

// check time-out
initial begin
    #(`CYCLE*`ENDCYCLE);
    $display("Time-out Error! Maybe there is something wrong with the 'finish' signal \n");
     $display("=========== sram begin ===========");
		for( int j=0; j < (PIXEL/2); j++ ) begin
			$display( "sram[%2d] %4h", j,  sram_storage[j]);
		end
	$display("=========== sram end ===========");
    $finish;
end
/*
always_comb begin
    if(finish)begin
        error_num = 0;
        for(i=0;i<PIXEL/2;i=i+1)begin
            if( sram_storage[i] != golden[i])
                error_num = error_num + 1;
        end
        if(error_num==0) begin
            $display("--------------------------------------\n");
            $display("Congratulations!  The result is PASS!!\n");
            $display("--------------------------------------\n");
        end
        else
            $display("Error!!There is some wrong in your code!!\n");
       // $finish;
    end
end
*/
always_comb begin
    if(finish)begin
        $display("=========== sram begin ===========");
		for( int j=0; j < (PIXEL/2); j++ ) begin
			$display( "sram[%2d] %4h", j,  sram_storage[j]);
		end
		$display("=========== sram end ===========");
        $finish;
    end
end


always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        cnt <= 0;
        sram_data <= 0;
    end else begin
        cnt <= cnt_nxt;
        sram_data <= sram_data_nxt;
    end
end

endmodule