module Top (
	input        i_clk,//
	input        i_rst_n, // key 0
	input        i_start, // key 1 
	output [3:0] o_random_out
);


wire [3:0] data_out;
reg  [3:0] answer_reg;
reg  [3:0] answer_reg_nxt;

reg  [2:0] state, state_nxt;

reg [31:0] counter, counter_nxt;
    

//==================================//
parameter IDLE     = 3'd0;
parameter RUN_FAST = 3'd1;
parameter RUN_MID  = 3'd2;
parameter RUN_SLOW = 3'd3;
parameter READY    = 3'd4;
integer i;
//==================================//

assign o_random_out = answer_reg;

LFSR XX( .i_clk(i_clk), .i_rst_n(i_rst_n), .timer(counter), .data_out(data_out) );

always@(*)begin
    case(state)
        READY:   counter_nxt = 0;
        default: counter_nxt = counter + 1;
    endcase
end

always@(*)begin
    case(state)
        IDLE:begin
            if(i_start)
                state_nxt = READY;
            else
                state_nxt = IDLE; 
        end
        READY:begin
            state_nxt = RUN_FAST;
        end
        RUN_FAST:begin
            if(i_start)
                state_nxt = READY;
            else if(counter[28])
                state_nxt = RUN_MID;
            else
                state_nxt = RUN_FAST;
        end
        RUN_MID:begin
            if(i_start)
                state_nxt = READY;
            else if(counter[29])
                state_nxt = RUN_SLOW;
            else
                state_nxt = RUN_MID;
        end
        RUN_SLOW:begin
            if(i_start)
                state_nxt = READY;
            else if(counter[28]&&counter[29])
                state_nxt = IDLE;
            else
                state_nxt = RUN_SLOW;
        end
        default:begin
            state_nxt = IDLE;
        end
    endcase
end


always@(*)begin   
    answer_reg_nxt = answer_reg;
    case(state)
        RUN_FAST:begin   
            if(&counter[21:0])
                answer_reg_nxt = data_out;    
        end
        RUN_MID:begin
            if(&counter[23:0])
                answer_reg_nxt = data_out;
        end
        RUN_SLOW:begin
            if(&counter[24:0])begin
                answer_reg_nxt = data_out;
            end
        end
        default:begin
            answer_reg_nxt = answer_reg;
        end
    endcase
end


always@( posedge i_clk or negedge i_rst_n)begin
    if (!i_rst_n) begin
		counter    <= 32'd0;
        state      <= IDLE;
        answer_reg <= 4'd0;
	end
	else begin
		counter    <= counter_nxt;
        state      <= state_nxt;
        answer_reg <= answer_reg_nxt;
	end
end
endmodule


module LFSR( i_clk, i_rst_n, timer, data_out);

input         i_clk, i_rst_n;
input  [7:0]  timer;

output [3:0]  data_out;

reg           shift_reg     [0:15];
reg           shift_reg_nxt [0:15];

wire          xor_out1, xor_out2, xor_out3;
wire   [1:0]  select  [0:3];
reg    [3:0]  data_in [0:3];

integer   i, j, k;


assign select[0] = { timer[0], timer[4] };
assign select[1] = { timer[5], timer[3] };
assign select[2] = { timer[7], timer[6] };
assign select[3] = { timer[2], timer[1] };

always@(*)begin
    for(i=0;i<4;i=i+1)begin
         data_in[i] ={ shift_reg[4*i], shift_reg[i*4+1], shift_reg[i*4+2], shift_reg[i*4+3] };
    end
end


MUX4 A1( .select(select[0]), .data_in(data_in[0]), .data_out(data_out[0]) );
MUX4 A2( .select(select[1]), .data_in(data_in[1]), .data_out(data_out[1]) );
MUX4 A3( .select(select[2]), .data_in(data_in[2]), .data_out(data_out[2]) );
MUX4 A4( .select(select[3]), .data_in(data_in[3]), .data_out(data_out[3]) );

assign xor_out1 = shift_reg[10] ^ xor_out2;
assign xor_out2 = shift_reg[12] ^ xor_out3;
assign xor_out3 = shift_reg[13] ^ shift_reg[15];

always@(*)begin
    shift_reg_nxt[0] = xor_out1;
    for(j=1;j<16;j=j+1)begin
        shift_reg_nxt[j] = shift_reg[j-1];
    end
end


always@( posedge i_clk or negedge i_rst_n )begin
    if (!i_rst_n) begin
        for(k=0;k<16;k=k+1)
            shift_reg[k] <= 1'b1;
	end
	else begin
        for(k=0;k<16;k=k+1)
            shift_reg[k] <= shift_reg_nxt[k];
	end
end

endmodule

module MUX4( select, data_in, data_out );

input [1:0] select;
input [3:0] data_in;

output      data_out;

reg         data_out;

always@(*)begin
    case(select)
        2'b00: data_out = data_in[0];
        2'b01: data_out = data_in[1];
        2'b10: data_out = data_in[2];
        2'b11: data_out = data_in[3];
        default: data_out = 1'b0;
    endcase
end

endmodule
