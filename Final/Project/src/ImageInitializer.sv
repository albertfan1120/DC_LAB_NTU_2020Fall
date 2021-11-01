module ImageInitializer(
    input         i_clk,
    input         i_rst_n,
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest,
    output        o_finished,
    // SRAM Interface
    output [15:0] o_data,
    output [19:0] o_address,
	 output [1:0] o_state
);

// =========== Parameter ============= // 
localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;
localparam PIXEL       = 460800 - 1; // total 480*320*3 = 460800
// ======= State declaration ========= //
logic [1:0] state, state_nxt;
localparam IDLE     = 0;
localparam GET_DATA = 1;
localparam FINISH   = 2;

// ==========  Variables ============ //
logic        avm_read_r, avm_read_w;
logic        finish;
logic [ 4:0] avm_address_r, avm_address_w;
logic [15:0] data, data_nxt;
logic [19:0] address, address_nxt;

logic [ 1:0] sram_counter, sram_counter_nxt;
logic [18:0] pixel_counter, pixel_counter_nxt;
// ====== Output assignment ======== //
assign avm_address   = avm_address_r;
assign avm_read      = avm_read_r;
assign avm_write     = 0;
assign avm_writedata = 0;
assign o_data        = data;
assign o_address     = address;
assign o_finished    = finish;
assign o_state = state;

task StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_address_w = addr;
    end
endtask

// ====== FSM  ====== //
always_comb begin
    state_nxt = state;
    case(state)
        IDLE:begin
            if( (!avm_waitrequest) && avm_readdata[RX_OK_BIT] ) begin 
                state_nxt = GET_DATA;
            end
        end
        GET_DATA:begin
            if(!avm_waitrequest)begin
                if((pixel_counter == PIXEL) /*&& (sram_counter)*/)
                    state_nxt = FINISH;
                else
                    state_nxt = IDLE;
            end 
        end
        FINISH:begin
            state_nxt = FINISH;
        end
    endcase
end
// ========== Counter ============ //
always_comb begin
   // sram_counter_nxt = sram_counter;
    pixel_counter_nxt = pixel_counter;
    finish = 0;
    case(state)
        GET_DATA:begin
            pixel_counter_nxt = pixel_counter + 1;
            /*if(sram_counter == 2)
                sram_counter_nxt = 1;
            else 
                sram_counter_nxt = sram_counter + 1;*/
        end
        FINISH:begin
            finish = 1;
        end
		  default:
		  begin
			 pixel_counter_nxt = pixel_counter;
			 finish = 0;
		  end
    endcase
end

//======= address read IO ===========//
always_comb begin
    avm_address_w = avm_address_r;
    avm_read_w = avm_read_r;
    case(state)
        IDLE:begin   
            if((!avm_waitrequest) && avm_readdata[RX_OK_BIT]) begin           
                StartRead(RX_BASE); 
            end else begin
                StartRead(STATUS_BASE);
            end
        end
        GET_DATA:begin
            if(!avm_waitrequest) begin           
               avm_read_w = 0;
            end
        end
		 default:
		 begin
			   avm_address_w = avm_address_r;
				avm_read_w = avm_read_r;
		 end 
    endcase
end
//====== data recieve and transmit =========//
always_comb begin
    //data_nxt = data;
	 data = 0;
    address_nxt = address;
    case(state)
        GET_DATA:begin
            //if(sram_counter == 2)
                address_nxt = address + 1;
            //data_nxt = { data[7:0], avm_readdata[7:0]};
				data/*_nxt*/ = { 8'd0, avm_readdata[7:0]};
        end
    endcase
end

always_ff @(posedge i_clk or posedge i_rst_n) begin
    if (i_rst_n) begin
        state <= IDLE;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        sram_counter <= 0;
        pixel_counter <= 0;
        address <= 0;
       // data <= 0;
    end else begin
        if(!avm_waitrequest)begin
            sram_counter   <= sram_counter_nxt;
            pixel_counter <= pixel_counter_nxt;
            address <= address_nxt;
          //  data <= data_nxt;
        end
        state <= state_nxt;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
    end
end

endmodule