module Top (
    // RS232 interface
    input         avm_rst,
    input         avm_clk, 
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest,
    // SRAM interface
    output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
    // VGA interface
    output        vga_clk,
    output [7:0] VGA_R,
	output [7:0] VGA_G,
	output [7:0] VGA_B,
	output VGA_BLANK_N,
	output VGA_HS,
	output VGA_VS,
	//
	output [19:0]  debug_wire,
	input   CLK50,
	input pll_clk,
	input [17:0] SW,
	input CLK25_2,
	input  CLK75_6,
	input CLK1M
	
   // output         finish
);

// ====== State declaration =========//
localparam S_GET_IMAGE = 0;
localparam S_CALCULATE = 1;
localparam S_DISPLAY   = 2;
localparam S_DARK      = 3;
localparam S_BUFFER_0  = 4;
localparam S_BUFFER_1  = 5;
localparam S_TERMINATE = 6;
localparam S_DISPLAY2  = 7;
logic [2:0] state_r, state_w;
// =========== Variables ============//
logic        init_finished, cal_finished, VGA_start, dark_start, dark_finish, sram_we_n, dark_we;
logic        calculate_start,  calculate_finish, cal_we;
logic [31:0] test_data, test_data_nxt;
logic [19:0] addr_record, addr_play, sram_addr, dark_addr, cal_addr;
logic [15:0] data_record, data_play, sram_dq, dark_ans, dark_read_data, cal_ans, cal_read_data;


// ======== Output assignment =========//

// SRAM
assign o_SRAM_ADDR = sram_addr;
assign io_SRAM_DQ  = sram_dq;
assign o_SRAM_WE_N = sram_we_n;
assign data_play      = (state_r  != S_GET_IMAGE) ? io_SRAM_DQ : 16'd0; // sram_dq as input
assign dark_read_data = (state_r  == S_DARK)      ? io_SRAM_DQ : 16'd0; // sram_dq as input
assign cal_read_data  = (state_r  == S_CALCULATE) ? io_SRAM_DQ : 16'd0; // sram_dq as input

assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;
assign finish = init_finished;


assign debug_wire[3:0] = {1'b0, state_r};
assign debug_wire[ 7: 4] = data_play[ 7:4];
assign debug_wire[11: 8] = data_play[11:8];
assign debug_wire[15:12] = data_play[15:12];

ImageInitializer init0(
    .i_clk(avm_clk),
    .i_rst_n(avm_rst),
    .avm_address(avm_address),
    .avm_read(avm_read),
    .avm_readdata(avm_readdata),
    .avm_write(avm_write),
    .avm_writedata(avm_writedata),
    .avm_waitrequest(avm_waitrequest),
    .o_finished(init_finished),
    .o_data(data_record),
    .o_address(addr_record),
	 .o_state(test)
);

VGA VGA0(
	.SRAM_CLK(CLK75_6),
	.VGA_CLK(CLK25_2),
	.RST_N(avm_rst),
	.i_start(VGA_start),
	.data(data_play),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_BLANK_N(VGA_BLANK_N),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.SRAM_ADDR(addr_play)
);

dark d0(
   .clk(avm_clk),
	.rst(avm_rst),
	.start(dark_start),
	.data(dark_read_data),
	.ANS(dark_ans),
	.SRAM_ADDR(dark_addr),
	.SRAM_WRITE(dark_we),
   .o_finish(dark_finish)
);

Blur B0(
   .clk(CLK25_2),
	.rst(avm_rst),
	.start(calculate_start),
	.SRAM_DATA(cal_read_data),
	.ANS(cal_ans),
	.SRAM_ADDR(cal_addr),
	.SRAM_WRITE(cal_we),
   .o_finish(calculate_finish)
);


//============ FSM ===============//

always_comb begin
    state_w = state_r;
    VGA_start = 0;
    dark_start = 0;
    sram_addr = 0;
    sram_we_n = 1;
    sram_dq = 16'dz;
    calculate_start = 0;
    case(state_r)
        S_GET_IMAGE:begin
            sram_addr = addr_record;
            sram_we_n = 0;
            sram_dq = data_record;
            if(init_finished)begin
                state_w = S_DISPLAY;
            end  
        end
        S_DARK:begin
            dark_start = 1;
            sram_addr = dark_addr;
            sram_we_n = ~dark_we;
            if(~dark_we)begin // read
                sram_dq = 16'dz;
            end
            else begin //write
                sram_dq = dark_ans;
            end
            if(dark_finish)
                state_w = S_CALCULATE;
        end
		S_CALCULATE:begin
            calculate_start = 1;
            sram_we_n = ~cal_we;
            sram_addr = cal_addr;
            if(~cal_we)begin // read
                sram_dq = 16'dz;
            end
            else begin //write
                sram_dq = cal_ans;
            end
            if(calculate_finish)
                state_w = S_DISPLAY2;
        end
        S_DISPLAY:begin
            state_w = S_DISPLAY;
            sram_addr = addr_play;
            VGA_start = 1;
				if(SW[0])
					state_w = S_DARK;	
        end
		  S_DISPLAY2:begin
				state_w = S_DISPLAY2;
            sram_addr = addr_play;
            VGA_start = 1;
		  end
    endcase
end


always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        state_r <= S_GET_IMAGE;
    end else begin
        state_r <= state_w;
    end
end


endmodule
