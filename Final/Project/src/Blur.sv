module Blur(
    input         clk,
	 input 		clk_div,
	input         rst,
	input         start,
	input  [15:0] SRAM_DATA,
	output [15:0] ANS,
	output [19:0] SRAM_ADDR,
	output        SRAM_WRITE, // 1 = write, 0 = read
	output        o_finish
);

localparam START_ADDR  = 500000;
localparam ROW_PIXEL   = 447; // 64 + 320 + 63
localparam BLUR_SIZE   = 128 - 1; 
localparam END_ADDR    = 10;
localparam MAX_V       = 204; // 0.8*255
localparam OFFSET      = 320;
localparam STORE_START = 0;
localparam STORE_END   = 1240800 - 1;
localparam MINUS       = 50;
localparam MINUS2      = 20;
// ====== State declaration =========//
logic [3:0] state, state_nxt;
localparam IDLE      = 0;
localparam FIRST_ROW = 1;
localparam TAKE_DATA = 2;
localparam BLUR      = 3;
localparam MAX       = 4;
localparam GET_Y     = 5;
localparam FINISH    = 6;
localparam PREPARE   = 7;
localparam COMPUTE   = 8;
localparam SEND      = 9;
localparam BUFFER    = 10;
localparam BUFFER2   = 11;
localparam LOAD_RIGHT= 12;
localparam DIV       = 13;
// =========== Variables ============//
logic        finish, sram_write, max_cycle, max_cycle_nxt, y_cycle, y_cycle_nxt, div_valid, div_ready;
logic [ 1:0] rgb_cnt, rgb_cnt_nxt;
logic [30:0] blur_ans, blur_ans_nxt;
logic [ 7:0] max_ans, max_ans_nxt, denominator, denominator_nxt;
logic [ 6:0] w_count, w_count_nxt, v_count, v_count_nxt; 
logic [19:0] sram_addr, sram_addr_nxt, origin_addr, origin_addr_nxt, store_addr, store_addr_nxt, mask_start, mask_start_nxt;
logic [19:0] lock_addr, lock_addr_nxt;
logic [30:0] add_ans, add_ans_nxt, last_add, last_add_nxt;
logic [15:0] output_ans, output_ans_nxt, temp,  numerator, numerator_nxt;
logic [ 8:0] pixel_w, pixel_w_nxt, pixel_v, pixel_v_nxt;
logic [ 7:0] sh1, sh2, sh3, sh4, sh5, sh6, sh7;
logic [30:0] row_add [0:127];
logic [30:0] row_add_nxt [0:127];
logic [31:0] in_A, in_B;
logic [63:0] div_out;
logic        OK, OK2;
logic [15:0] temp2;
logic [15:0] temp3;

logic [63:0] div_temp;
integer i;
// ======== Output assignment =========//
assign o_finish   = (state==FINISH) ? 1:0;
assign SRAM_WRITE = sram_write;
assign SRAM_ADDR  = sram_addr;
assign ANS = output_ans;

// ============= FSM ============= //
assign OK = (w_count == BLUR_SIZE) ? 1 : 0;
assign OK2 = (v_count == BLUR_SIZE) ? 1 : 0;
always_comb begin
    state_nxt = state;
    case(state)
        IDLE:begin
            if(start)
                state_nxt = PREPARE;
        end
        PREPARE:begin
            state_nxt = FIRST_ROW;
        end
        FIRST_ROW:begin
            if(w_count == BLUR_SIZE)begin
                state_nxt = TAKE_DATA;
            end
        end
        TAKE_DATA:begin
            if(OK &&OK2)begin
                state_nxt = BLUR;
            end   
        end
        BLUR:begin
            state_nxt = MAX;
        end
        MAX:begin
            if(max_cycle) begin
                state_nxt = GET_Y;
            end
        end
        GET_Y:begin
            state_nxt = COMPUTE;
        end
        COMPUTE:begin
            state_nxt = LOAD_RIGHT;
        end
        LOAD_RIGHT:begin
            if(div_ready)
                state_nxt = SEND;
        end
        SEND:begin
            if(rgb_cnt == 2)begin

                if(pixel_v == 479)begin
                    if(pixel_w == 319)begin
                        state_nxt = FINISH;
                    end
                    else begin
                        state_nxt = PREPARE;
                    end
                end 
                else
                    state_nxt = BUFFER2; // down
            end
            else 
                state_nxt = BUFFER;
        end
        BUFFER:begin
            state_nxt = GET_Y;
        end
        BUFFER2:begin
            state_nxt = TAKE_DATA;
        end
        FINISH:begin
            state_nxt = FINISH;
        end
    endcase
end



// ========= Combinential =========== //

assign in_A = { 16'd0, numerator};
assign in_B = { 24'd0, denominator};

multDiv DIV0(
    .clk(clk),
    .rst_n(!rst),
    .valid(div_valid), // input
    .ready(div_ready), //output
    .mode(1),
    .in_A(in_A),
    .in_B(in_B),
    .out(div_out)
);

always_comb begin
    
    sram_write = 0;
    max_ans_nxt = max_ans;
    max_cycle_nxt = max_cycle;
    y_cycle_nxt = y_cycle;
    sram_addr_nxt = sram_addr;
    w_count_nxt = w_count;
    v_count_nxt = v_count;
    add_ans_nxt = add_ans;
    blur_ans_nxt = blur_ans;
    origin_addr_nxt = origin_addr;
    numerator_nxt = numerator;
    denominator_nxt = denominator;
    store_addr_nxt = store_addr;
    output_ans_nxt = output_ans;
    mask_start_nxt = mask_start;
    rgb_cnt_nxt = rgb_cnt;
    lock_addr_nxt = lock_addr;
    temp = 0;
    pixel_v_nxt = pixel_v;
    pixel_w_nxt = pixel_w;
    last_add_nxt = last_add;
	 sh1 = 0;
	 sh2 = 0;
	 sh3 = 0;
	 sh4 = 0;
	 sh5 = 0;
	 sh6 = 0;
    div_valid = 0;
	 div_temp = 0;
	 temp2 = 0;
	 temp3 = 0;
    for(i=0;i<128;i=i+1)begin
        row_add_nxt[i] = row_add[i];
    end
    case(state)
        PREPARE:begin
            sram_addr_nxt = sram_addr + 1;
            mask_start_nxt = mask_start + ROW_PIXEL;
            origin_addr_nxt =  pixel_w*3;
            store_addr_nxt = pixel_w*3;
        end
        FIRST_ROW:begin
            w_count_nxt = w_count + 1;
				if(SRAM_DATA[7:0]<MINUS)
					add_ans_nxt = add_ans ;
				else
					add_ans_nxt = add_ans + SRAM_DATA[7:0] -MINUS;
					
            if(w_count == (BLUR_SIZE-1))begin //end of first row
                sram_addr_nxt = sram_addr + OFFSET;
            end
            else if(w_count == (BLUR_SIZE))begin
                v_count_nxt = 1;
                sram_addr_nxt = sram_addr + 1;
            end
            else begin
                sram_addr_nxt = sram_addr + 1;
            end    
				if(SRAM_DATA[7:0]<MINUS)
					row_add_nxt[0] = row_add[0];
				else 	
					row_add_nxt[0] = row_add[0] + SRAM_DATA[7:0] -MINUS;
        end
        TAKE_DATA:begin
            w_count_nxt = w_count + 1;
				if(SRAM_DATA[7:0]<MINUS)begin
					add_ans_nxt = add_ans; 
					last_add_nxt = last_add;
				end
				else begin
					 add_ans_nxt = add_ans + SRAM_DATA[7:0] -MINUS; 
					last_add_nxt = last_add + SRAM_DATA[7:0]-MINUS;
				end
           

            if(OK & OK2)begin
                lock_addr_nxt = sram_addr;
            end    
				if(SRAM_DATA[7:0]<MINUS)
					row_add_nxt[v_count] = row_add[v_count];
				else
					row_add_nxt[v_count] = row_add[v_count] + SRAM_DATA[7:0]-MINUS;

            if(w_count == (BLUR_SIZE-1))begin
       
                sram_addr_nxt = sram_addr + OFFSET;
            end
            else if(w_count == (BLUR_SIZE))begin
                v_count_nxt = v_count + 1;
                sram_addr_nxt = sram_addr + 1;
            end
            else begin
                sram_addr_nxt = sram_addr + 1;
            end
        end
        BLUR:begin
            blur_ans_nxt = add_ans >> 14;
    
            for(i=0;i<127;i=i+1)begin
                row_add_nxt[i] = row_add[i+1];
            end
            add_ans_nxt = add_ans - row_add[0];
            row_add_nxt[127] = 0;
        end
        MAX:begin  
            if(max_cycle==0)begin
                max_cycle_nxt = 1;
                sram_addr_nxt = origin_addr;
                sh1 =  blur_ans[0] ? ({1'd0, blur_ans[7:1]} + 1) : {1'd0, blur_ans[7:1]};
                sh2 =  blur_ans[1] ? ({2'd0, blur_ans[7:2]} + 1) : {2'd0, blur_ans[7:2]};
                sh3 =  blur_ans[2] ? ({3'd0, blur_ans[7:3]} + 1) : {3'd0, blur_ans[7:3]};
                sh4 =  blur_ans[3] ? ({4'd0, blur_ans[7:4]} + 1) : {4'd0, blur_ans[7:4]};
                sh5 =  blur_ans[4] ? ({5'd0, blur_ans[7:5]} + 1) : {5'd0, blur_ans[7:5]};
                max_ans_nxt = sh1 + sh2 + sh3 + sh4 + sh5;
            end
            else begin
                
                max_cycle_nxt = 0;
                if(max_ans>MAX_V)begin
                    max_ans_nxt = MAX_V;
                end
            end
        end
        GET_Y:begin
           
				temp2 = {8'd0,SRAM_DATA[7:0]} - {8'd0, max_ans};
            temp = temp2 << 8;
            numerator_nxt = temp - temp2;		
            sh6 = max_ans[7:0] + { 5'd0, max_ans[7:5]}; 
            denominator_nxt = 255 - sh6;
            if(rgb_cnt==2)begin
                origin_addr_nxt = origin_addr + 958;
            end
            else begin
                origin_addr_nxt = origin_addr + 1;
            end
        end
        COMPUTE:begin
            sram_addr_nxt = store_addr;
        end
        SEND:begin
            rgb_cnt_nxt = rgb_cnt + 1;
            if(rgb_cnt == 2)begin
                rgb_cnt_nxt = 0;
                sram_addr_nxt = lock_addr;
                if(pixel_v == 479)begin
                    pixel_w_nxt = pixel_w + 1;
                    sram_addr_nxt = START_ADDR + pixel_w + 1;
                    pixel_v_nxt = 0;
                    add_ans_nxt = 0;
                    last_add_nxt = 0;
                    for(i=0;i<128;i=i+1)begin
                        row_add_nxt[i] = 0;
                    end
                end
            end
            else begin
                sram_addr_nxt = origin_addr;
            end    
            sram_write = 1;
            store_addr_nxt = store_addr + 1;
        end
        BUFFER:begin
            
        end
        BUFFER2:begin
            v_count_nxt = 127;
            sram_addr_nxt = sram_addr + 1;
            store_addr_nxt = store_addr + 957;
            pixel_v_nxt = pixel_v + 1;
        end
        LOAD_RIGHT:begin
            div_valid = 1;
				if(div_ready)
					div_temp = div_out;
				
            output_ans_nxt = { div_temp[7:0], SRAM_DATA[7:0]};
            
        end
    endcase
end
integer j;
always_ff@(posedge clk or posedge rst) begin
    if (rst) begin
        state   <= IDLE;
        w_count <= 0;
        v_count <= 0;
        y_cycle <= 0;
        max_cycle <= 0;
        sram_addr <= START_ADDR;
        add_ans   <= 0;
        blur_ans  <= 0;
        max_ans   <= 0;
        origin_addr <= 0;
        numerator <= 0;
        denominator <= 0;
        store_addr <= STORE_START;
        output_ans <= 0;
        mask_start <= START_ADDR;
        rgb_cnt <= 0;
        lock_addr <= lock_addr_nxt;
        pixel_w <= 0;
        pixel_v <= 0;
        last_add <= 0;
        for(j=0;j<128;j=j+1)begin
            row_add[j] <= 0;
        end
    end
    else begin
        state   <= state_nxt;
        w_count <= w_count_nxt;
        v_count <= v_count_nxt;
        y_cycle <= y_cycle_nxt;
        max_cycle <= max_cycle_nxt;
        sram_addr <= sram_addr_nxt;
        add_ans   <= add_ans_nxt;
        blur_ans  <= blur_ans_nxt;
        max_ans   <= max_ans_nxt;
        origin_addr <= origin_addr_nxt;
        numerator <= numerator_nxt;
        denominator <= denominator_nxt;
        store_addr <= store_addr_nxt;
        output_ans <= output_ans_nxt;
        mask_start <= mask_start_nxt;
        rgb_cnt <= rgb_cnt_nxt;
        lock_addr <= lock_addr_nxt;
        pixel_w <= pixel_w_nxt;
        pixel_v <= pixel_v_nxt;
        last_add <= last_add_nxt;
        for(j=0;j<128;j=j+1)begin
            row_add[j] <= row_add_nxt[j];
        end
    end
end

endmodule