module dark(input clk,
			input rst,
			input start,
			input  [15:0] data,
			output [15:0] ANS,
			output [19:0] SRAM_ADDR,
			output        SRAM_WRITE,
			output o_finish


	);
		
	parameter IDLE=0;
	parameter WAIT=1;
	parameter PRE=2;
	parameter LOAD_R=3;
	parameter LOAD_G=4;
	parameter LOAD_B=5;
	parameter OUTPUT_0=6;
	parameter OUTPUT_1=7;
	parameter OUTPUT_ZERO=8;
	
	parameter MEMORY_OFFSET_INIT=500000;
	parameter MEMORY_OFFSET=500000+64*(320+64+63)+64;
	reg [15:0] ans, ans_nxt;
	reg [19:0] sram_addr;
	reg [19:0] sram_read_addr,sram_read_addr_nxt;
	reg [19:0] sram_write_addr,sram_write_addr_nxt;
	reg        sram_write; 
	reg [3:0] state, state_nxt;
	reg       finish;
	reg [20:0] h_count, h_count_nxt, v_count, v_count_nxt;
	reg [7:0] red, red_nxt;
	reg [7:0] green, green_nxt;
	reg [7:0] blue, blue_nxt;
	reg [7:0] red_green_min;
	reg [100:0] write_count,write_count_nxt;
	
	
	assign ANS=ans;
	assign SRAM_ADDR=sram_addr;
	assign SRAM_WRITE=sram_write;
	assign o_finish = finish;
	
	always@(*)
	begin
		case(state)
			IDLE:
			begin
				state_nxt=WAIT;
			end
			WAIT:
			begin
				if(start)
				begin
					state_nxt=OUTPUT_ZERO;
				end
				else
				begin
					state_nxt=WAIT;
				end			
			end
			PRE:
			begin
				state_nxt=LOAD_R;
			end
			LOAD_R:
			begin
				state_nxt=LOAD_G;
			end
			LOAD_G:
			begin
				state_nxt=LOAD_B;
			end
			LOAD_B:
			begin
				state_nxt=OUTPUT_0;
			end
			OUTPUT_0:
			begin
				if(h_count==64+320-1)
				begin
					state_nxt=OUTPUT_ZERO;
				end
				else
				begin
					state_nxt=PRE;
				end
			end
			OUTPUT_1:
			begin
				state_nxt=LOAD_R;
			end
			OUTPUT_ZERO:
			begin
				if(finish)
				begin
					state_nxt=IDLE;
				end
				else if( (v_count>64-1) && (v_count<64-1+480+1) && (h_count==63) )
				begin
					state_nxt=PRE;
				end
				else
				begin
					state_nxt=OUTPUT_ZERO;
				end
			end
			default:
			begin
				state_nxt=IDLE;
			end
		endcase
	end
	always@(posedge clk)
	begin
		if(rst)
		begin
			state<=0;
		end
		else
		begin
			state<=state_nxt;
		end
	end
	
	always@(*)
	begin
		h_count_nxt=h_count;
		red_nxt=red;
		green_nxt=green;
		blue_nxt=blue;
		ans_nxt=ans;
		sram_read_addr_nxt=sram_read_addr;
		sram_write_addr_nxt=sram_write_addr;
		sram_write=0;
		v_count_nxt=v_count;
		write_count_nxt=write_count;
		sram_addr=sram_read_addr;
		
		case(state)
			IDLE:
			begin
			end
			WAIT:
			begin
			end			
			PRE:
			begin
				sram_read_addr_nxt=sram_read_addr+1;
			end
			LOAD_R:
			begin
				red_nxt=data[7:0];
				sram_read_addr_nxt=sram_read_addr+1;
			end
			LOAD_G:
			begin
				green_nxt=data[7:0];
				sram_read_addr_nxt=sram_read_addr+1;
			end
			LOAD_B:
			begin
				blue_nxt=data[7:0];
				//sram_read_addr_nxt=sram_read_addr+1;
				if(blue_nxt>red_green_min)
				begin
					ans_nxt={8'd0,red_green_min};
				end
				else
				begin
					ans_nxt={8'd0,blue_nxt};			
				end	
				
			end
			OUTPUT_0:
			begin
				sram_write=1;
				write_count_nxt=write_count+1;
				sram_write_addr_nxt=sram_write_addr+1;
				h_count_nxt=h_count+1;
				sram_addr=sram_write_addr;
			end
			OUTPUT_1:
			begin
				
			end
			OUTPUT_ZERO:
			begin
				sram_write=1;
				write_count_nxt=write_count+1;
				sram_write_addr_nxt=sram_write_addr+1;
				ans_nxt={ 8'd0, 8'd40};
				sram_addr=sram_write_addr;
				if(h_count==64+320+63-1)
				begin
					v_count_nxt=v_count+1;
					h_count_nxt=0;
				end
				else
				begin
					h_count_nxt=h_count+1;
				end
			end
			
			default:
			begin
				red_nxt=red;
			end
		endcase
		

		if (v_count>=64+480+63)
 		begin
			finish=1;
		end
		else
		begin
			finish=0;
		end
		if(red>green)
		begin
			red_green_min=green;
		end
		else
		begin
			red_green_min=red;
		end
		
	end
	always@(posedge clk)
	begin
		if(rst)
		begin
			h_count<=0;
			v_count<=0;
			red<=0;
			green<=0;
			sram_write_addr<=MEMORY_OFFSET_INIT;
			blue<=0;
			ans<=0;
			sram_read_addr<=0;
			write_count<=0;
		end
		else
		begin
			h_count<=h_count_nxt;
			v_count<=v_count_nxt;
			red<=red_nxt;
			green<=green_nxt;
			ans<=ans_nxt;
			sram_read_addr<=sram_read_addr_nxt;
			sram_write_addr<=sram_write_addr_nxt;
			blue<=blue_nxt;
			write_count<=write_count_nxt;
		end
	end	

endmodule