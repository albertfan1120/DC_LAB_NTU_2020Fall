module VGA(
	input SRAM_CLK,
	input VGA_CLK,
	input RST_N,
	input i_start,
	input [15:0] data,
	output [7:0] VGA_R,
	output [7:0] VGA_G,
	output [7:0] VGA_B,
	output VGA_BLANK_N,
	output VGA_HS,
	output VGA_VS,
	output [19:0] SRAM_ADDR
	
);
// Horizontal Parameter
parameter H_FRONT = 16;
parameter H_SYNC  = 96;
parameter H_BACK  = 48;
parameter H_ACT   = 640;
parameter H_BLANK = H_FRONT + H_SYNC + H_BACK;
parameter H_TOTAL = H_FRONT + H_SYNC + H_BACK + H_ACT;//H_TOTAL=H_BLANK+H_ACT(640)

// Vertical Parameter
parameter V_FRONT = 11;
parameter V_SYNC  = 2;
parameter V_BACK  = 32;
parameter V_ACT   = 480;
parameter V_BLANK = V_FRONT + V_SYNC + V_BACK;
parameter V_TOTAL = V_FRONT + V_SYNC + V_BACK + V_ACT;//V_TOTAL=V_BLANK+V_ACT(480)

parameter WIDTH=320;
parameter HEIGHT=480;

parameter VGA_state_IDLE=3'd0;
parameter VGA_state_BLANK=3'd1;
parameter VGA_state_DISPLAY_0=3'd2;
//parameter VGA_state_DISPLAY_1=3'd3;
parameter VGA_state_BLACK=3'd3;
parameter VGA_state_RESET=3'd4;

//parameter SRAM_state_IDLE=4'd0;
parameter SRAM_state_PRE=4'd1;
parameter SRAM_state_PRE_ADDR_PLUS=4'd2;
parameter SRAM_state_R1G1=4'd3;
parameter SRAM_state_B1R2_0=4'd4;
parameter SRAM_state_B1R2_1=4'd5;
parameter SRAM_state_G2B2=4'd6;
parameter SRAM_state_WAIT_MINUS=4'd7;
parameter SRAM_state_WAIT=4'd8;
parameter SRAM_state_WAIT_PRE=4'd9;
parameter SRAM_state_RESET=4'd10;
//parameter SRAM_state_BR_WAIT=3'd4;

parameter SRAM_state_IDLE=4'd0;
parameter SRAM_state_VGA_BLANK_SRAM_PRE=4'd1;
parameter SRAM_state_VGA_BLANK_SRAM_PRE_ADDR_PLUS_PRE=4'd2;
parameter SRAM_state_VGA_BLANK_SRAM_PRE_ADDR_PLUS=4'd3;
parameter SRAM_state_VGA_DISPLAY_0_SRAM_R=4'd4;
parameter SRAM_state_VGA_DISPLAY_0_SRAM_G=4'd5;
parameter SRAM_state_VGA_DISPLAY_0_SRAM_B=4'd6;
parameter SRAM_state_VGA_DISPLAY_0_SRAM_B_TRANS=4'd7;

parameter SRAM_state_VGA_DISPLAY_1_SRAM_R=4'd8;
parameter SRAM_state_VGA_DISPLAY_1_SRAM_G=4'd9;
parameter SRAM_state_VGA_DISPLAY_1_SRAM_B=4'd10;
parameter SRAM_state_VGA_DISPLAY_1_SRAM_B_TRANS=4'd11;
parameter SRAM_state_VGA_DISPLAY_1_SRAM_B_RESET=4'd12;
parameter SRAM_state_VGA_BLANK_SRAM_RESET=4'd13;
//parameter SRAM_state_VGA_DISPLAY_1_SRAM_G2B2=4'd6;
/*
parameter SRAM_state_VGA_BLACK_SRAM_WAIT_MINUS=4'd12;
parameter SRAM_state_VGA_BLACK_SRAM_WAIT=4'd13;
parameter SRAM_state_VGA_BLANK_SRAM_WAIT_PRE_PRE=4'd14;
parameter SRAM_state_VGA_BLANK_SRAM_WAIT_PRE=4'd15;
parameter SRAM_state_VGA_BLANK_SRAM_RESET=4'd16;
*/
parameter OUTPUT_ADDR_INIT=780000;



reg [10:0] H_Cont;
reg [10:0] V_Cont;
reg [7:0]  vga_r;
reg [7:0]  vga_g;
reg [7:0]  vga_b;
reg        vga_hs;
reg        vga_vs;
reg [10:0] X;
reg [10:0] Y;

reg [7:0]  sram_r;
reg [7:0]  sram_g;
reg [7:0]  sram_b;
reg [7:0]  sram_r_ff;
reg [7:0]  sram_g_ff;
reg [7:0]  sram_b_ff;
reg [7:0]  sram_r_ff_nxt;
reg [7:0]  sram_g_ff_nxt;
reg [7:0]  sram_b_ff_nxt;

reg [7:0]  sram_r_ff_ff;
reg [7:0]  sram_g_ff_ff;
reg [7:0]  sram_b_ff_ff;
reg [7:0]  sram_r_ff_ff_nxt;
reg [7:0]  sram_g_ff_ff_nxt;
reg [7:0]  sram_b_ff_ff_nxt;

reg [7:0]  vga_r_ff;
reg [7:0]  vga_g_ff;
reg [7:0]  vga_b_ff;

reg [2:0] VGA_state,VGA_state_nxt;
reg [3:0] SRAM_state,SRAM_state_nxt;
//reg       sram_data_on;
reg [19:0] sram_addr;
//reg [19:0] sram_addr_nxt;

reg [19:0] sram_addr_1;
reg [19:0] sram_addr_1_nxt;
reg [19:0] sram_addr_2;
reg [19:0] sram_addr_2_nxt;

reg [5:0]  pre_counter,pre_counter_nxt;



/*
reg [7:0] red_r, green_r, red_r_r, green_r_r, blue_r_r;
reg [1:0] cnt_r; 
reg [8:0] cnt_col_r;
reg       trigger_r;
reg       i_start_r;
*/




assign VGA_R = vga_r;
assign VGA_G = vga_g;
assign VGA_B = vga_b;
assign VGA_HS = vga_hs;
assign VGA_VS = vga_vs;
//assign trigger = trigger_r;
assign VGA_SYNC  = 1'b0;        // This pin is unused.
assign VGA_BLANK_N = ~(H_Cont<H_BLANK)||(V_Cont<V_BLANK);
//assign SRAM_DATA_ON=sram_data_on;
assign SRAM_ADDR=sram_addr;

// Horizontal Generator: Refer to the pixel clock
	//H_Cont: how many horizontal pixel has pass , which include H_BLANK
	//vga_hs:vertical generator clk
	//X:from 0-640 how many horizontal pixel has pass
always@(posedge VGA_CLK or posedge RST_N) begin
  if(RST_N) begin
    H_Cont <= 0;
    vga_hs <= 1;
    X      <= 0;
  end 
  else if(!i_start) begin
    H_Cont <= 0;
    vga_hs <= 1;
    X      <= 0;
  end  
  else begin
    if (H_Cont < H_TOTAL)
      H_Cont	<=	H_Cont+1'b1;
    else
      H_Cont	<=	0;
      
    // Horizontal Sync
    if(H_Cont == H_FRONT-1) // Front porch end
      vga_hs <= 1'b0;
      
    if(H_Cont == H_FRONT + H_SYNC -1) // Sync pulse end
      vga_hs <= 1'b1;

    // Current X
    if(H_Cont >= H_BLANK)
      X <= H_Cont-H_BLANK;
    else
      X <= 10'd1000;
  end
end

// Vertical Generator: Refer to the horizontal sync
	//V_Cont: how many vertical pixel has pass , which include V_BLANK
	//vga_vs:useless?
	//Y:from 0-480 how many vertical pixel has pass
always@(posedge VGA_HS or posedge RST_N) begin
  if(RST_N) begin
    V_Cont <= 0;
    vga_vs <= 1;
    Y      <= 0;
  end
  else if(!i_start) begin
   V_Cont <= 0;
    vga_vs <= 1;
    Y      <= 0;
  end  
  else begin
    if (V_Cont<V_TOTAL)
      V_Cont <= V_Cont + 1'b1;
    else
      V_Cont	<= 0;
      
    // Vertical Sync
    if (V_Cont == V_FRONT-1) // Front porch end
      vga_vs <= 1'b0;
      
    if (V_Cont == V_FRONT + V_SYNC-1) // Sync pulse end
      vga_vs <= 1'b1;
      
    // Current Y
    if (V_Cont >= V_BLANK)
      Y <= V_Cont-V_BLANK;
    else
      Y <= 10'd1000;
  end
end

// Pattern Generator
	//vga_r,vga_g,vga_b: output, 
	//					 if X,Y<= 255 output=r/g/b_r_r
	//                   else output=255
	
always@(*)
begin
	//sram_data_on=0;
	case(VGA_state)
		VGA_state_IDLE:
		begin
			if(i_start)
			begin
				VGA_state_nxt=VGA_state_BLANK;
			end
			else
			begin
				VGA_state_nxt=VGA_state_IDLE;
			end
		end
		VGA_state_BLANK:
		begin
			if( (H_Cont==(H_BLANK-1) )&&(V_Cont>=V_BLANK) )
			begin
				if(V_Cont<(V_BLANK+HEIGHT) )
				begin
					VGA_state_nxt=VGA_state_DISPLAY_0;
					//sram_data_on=1;
				end
				else
				begin
					VGA_state_nxt=VGA_state_BLACK;
					//sram_data_on=0;
				end
			end
			else
			begin
				VGA_state_nxt=VGA_state_BLANK;
			end
		end
		VGA_state_DISPLAY_0:
		begin
			if( (H_Cont== (H_BLANK+WIDTH-1) ) )
			begin
				VGA_state_nxt=VGA_state_BLACK;
				//sram_data_on=0;
			end
			else
			begin
				VGA_state_nxt=VGA_state_DISPLAY_0;
				//sram_data_on=1;
			end	
		end
/*		VGA_state_DISPLAY_1:
		begin
			if( (H_Cont==(H_BLANK+WIDTH-1)) )
			begin
				VGA_state_nxt=VGA_state_BLACK;
				//sram_data_on=0;
			end
			else
			begin
				VGA_state_nxt=VGA_state_DISPLAY_0;
				//sram_data_on=1;
			end	
		end		
*/
		VGA_state_BLACK:
		begin
		    if( (H_Cont==800 ) )
			begin
				if(V_Cont==(V_TOTAL))
					VGA_state_nxt=VGA_state_RESET;
				else
					VGA_state_nxt=VGA_state_BLANK;
			end
			else 
			begin
				VGA_state_nxt=VGA_state_BLACK;
			end
		end
		VGA_state_RESET:
		begin
			VGA_state_nxt=VGA_state_BLANK;
		end	
		default:
		begin
			VGA_state_nxt=VGA_state_IDLE;
		end
	endcase
end

always@(posedge VGA_CLK or posedge RST_N) begin //25
	if(RST_N) 
	begin
		VGA_state<=VGA_state_IDLE;
	end
	else begin
		VGA_state<=VGA_state_nxt;
	end
end
/*
always@(*)
begin
	case(VGA_state)
		VGA_state_IDLE:
		begin
			vga_r=255;
			vga_g=255;
			vga_b=255;	
		end
		VGA_state_BLANK:
		begin
			vga_r=255;
			vga_g=255;
			vga_b=255;
		end
		VGA_state_DISPLAY_0:
		begin
			vga_r=sram_r_ff_ff;
			vga_g=sram_g_ff_ff;
			vga_b=sram_b_ff;
		end
		VGA_state_DISPLAY_1:
		begin
			vga_r=sram_r_ff_ff;
			vga_g=sram_g_ff;
			vga_b=sram_b_ff;
		end		
		VGA_state_BLACK:
		begin
			vga_r=0;
			vga_g=0;
			vga_b=0;
		end
		VGA_state_RESET:
		begin
			vga_r=0;
			vga_g=0;
			vga_b=0;
		end		
		default:
		begin
			vga_r=255;
			vga_g=255;
			vga_b=255;
		end
	endcase
end
*/

always@(posedge VGA_CLK or posedge RST_N) 
begin //25
	if(RST_N) 
	begin
		vga_r_ff<=0;
		vga_g_ff<=0;
		vga_b_ff<=0;		
	end
	else 
	begin
		vga_r_ff<=vga_r;
		vga_g_ff<=vga_g;
		vga_b_ff<=vga_b;		
	end
end

always@(*)
begin
	case(SRAM_state)
		SRAM_state_IDLE:
		begin
			if(i_start)
			begin
				SRAM_state_nxt=SRAM_state_VGA_BLANK_SRAM_PRE;
			end
			else
			begin
				SRAM_state_nxt=SRAM_state_IDLE;
			end
		end
		SRAM_state_VGA_BLANK_SRAM_PRE:
		begin
			if( (H_Cont==(H_BLANK-1) )&&(V_Cont>=V_BLANK) )
			begin
				SRAM_state_nxt=SRAM_state_VGA_BLANK_SRAM_PRE_ADDR_PLUS_PRE;
			end
			else
			begin
				SRAM_state_nxt=SRAM_state_VGA_BLANK_SRAM_PRE;				
			end
		end
		SRAM_state_VGA_BLANK_SRAM_PRE_ADDR_PLUS_PRE:
		begin
			SRAM_state_nxt=SRAM_state_VGA_BLANK_SRAM_PRE_ADDR_PLUS;
		end
		SRAM_state_VGA_BLANK_SRAM_PRE_ADDR_PLUS:
		begin
			SRAM_state_nxt=SRAM_state_VGA_DISPLAY_0_SRAM_R;
		end						
		SRAM_state_VGA_DISPLAY_0_SRAM_R:
		begin
			SRAM_state_nxt=SRAM_state_VGA_DISPLAY_0_SRAM_G;

		end
		SRAM_state_VGA_DISPLAY_0_SRAM_G:
		begin
			if(H_Cont==H_BLANK+WIDTH-1)
			begin
				SRAM_state_nxt=SRAM_state_VGA_DISPLAY_0_SRAM_B_TRANS;
			end
			else
			begin	
				SRAM_state_nxt=SRAM_state_VGA_DISPLAY_0_SRAM_B;
			end
		end		
		SRAM_state_VGA_DISPLAY_0_SRAM_B:
		begin
			SRAM_state_nxt=SRAM_state_VGA_DISPLAY_0_SRAM_R;
		end
		SRAM_state_VGA_DISPLAY_0_SRAM_B_TRANS:
		begin
			SRAM_state_nxt=SRAM_state_VGA_DISPLAY_1_SRAM_R;
		end	
		
		SRAM_state_VGA_DISPLAY_1_SRAM_R:
		begin
			SRAM_state_nxt=SRAM_state_VGA_DISPLAY_1_SRAM_G;

		end
		SRAM_state_VGA_DISPLAY_1_SRAM_G:
		begin
			if(H_Cont==H_BLANK+2*WIDTH-1)
			begin
				SRAM_state_nxt=SRAM_state_VGA_DISPLAY_1_SRAM_B_TRANS;
			end
			else
			begin	
				SRAM_state_nxt=SRAM_state_VGA_DISPLAY_1_SRAM_B;
			end
		end		
		SRAM_state_VGA_DISPLAY_1_SRAM_B:
		begin
			SRAM_state_nxt=SRAM_state_VGA_DISPLAY_1_SRAM_R;
		end
		SRAM_state_VGA_DISPLAY_1_SRAM_B_TRANS:
		begin
			if(( H_Cont==799) &&(V_Cont==525))
			begin
				SRAM_state_nxt=SRAM_state_VGA_BLANK_SRAM_RESET;
			end		
			else 
			begin
				SRAM_state_nxt=SRAM_state_VGA_BLANK_SRAM_PRE;
			end
		end	

		SRAM_state_VGA_BLANK_SRAM_RESET:
		begin
			SRAM_state_nxt=SRAM_state_VGA_BLANK_SRAM_PRE;
		end			
		default:
		begin
			SRAM_state_nxt=SRAM_state_IDLE;
		end
	endcase
end

always@(posedge SRAM_CLK or posedge RST_N)
begin
	if(RST_N) 
	begin
		SRAM_state<=SRAM_state_IDLE;
	end
	else 
	begin
		SRAM_state<=SRAM_state_nxt;
	end
end

always@(*)
begin
	sram_r=0;
	sram_g=0;
	sram_b=0;
	sram_r_ff_nxt=sram_r_ff;
	sram_g_ff_nxt=sram_g_ff;
	sram_b_ff_nxt=sram_b_ff;
	sram_r_ff_ff_nxt=sram_r_ff_ff;
	sram_g_ff_ff_nxt=sram_g_ff_ff;
	sram_b_ff_ff_nxt=sram_b_ff_ff;	
	//sram_addr_nxt=sram_addr;
	sram_addr_1_nxt=sram_addr_1;
	sram_addr_1_nxt=sram_addr_1;
	vga_r=0;
	vga_g=0;
	vga_b=0;
	pre_counter_nxt=0;
	sram_addr=sram_addr_1;
	case(SRAM_state)
		SRAM_state_IDLE:
		begin

		end
		SRAM_state_VGA_BLANK_SRAM_PRE:
		begin

		end	
		SRAM_state_VGA_BLANK_SRAM_PRE_ADDR_PLUS:
		begin
			sram_addr_1_nxt=sram_addr_1+1;	
		end	
		SRAM_state_VGA_DISPLAY_0_SRAM_R:
		begin
			sram_addr_1_nxt=sram_addr_1+1;
			sram_r=data[7:0];
			sram_g=0;
			sram_b=0;
			sram_r_ff_nxt=sram_r;
			sram_g_ff_nxt=sram_g;
			sram_b_ff_nxt=sram_b;
			sram_r_ff_ff_nxt=sram_r_ff;
			sram_g_ff_ff_nxt=sram_g_ff;
			sram_b_ff_ff_nxt=sram_b_ff;
			vga_r=vga_r_ff;
			vga_g=vga_g_ff;
			vga_b=vga_b_ff;			
		end
		SRAM_state_VGA_DISPLAY_0_SRAM_G:
		begin
			if(SRAM_state_nxt==SRAM_state_VGA_DISPLAY_0_SRAM_B_TRANS)
			begin
				sram_addr_1_nxt=sram_addr_1-959;
			end
			else
			begin
				sram_addr_1_nxt=sram_addr_1+1;
			end
			sram_r=0;
			sram_g=data[7:0];
			sram_b=0;
			sram_r_ff_nxt=sram_r;
			sram_g_ff_nxt=sram_g;
			sram_b_ff_nxt=sram_b;
			sram_r_ff_ff_nxt=sram_r_ff;
			sram_g_ff_ff_nxt=sram_g_ff;
			sram_b_ff_ff_nxt=sram_b_ff;
			vga_r=vga_r_ff;
			vga_g=vga_g_ff;
			vga_b=vga_b_ff;				
		end
		SRAM_state_VGA_DISPLAY_0_SRAM_B:
		begin
			
			sram_addr_1_nxt=sram_addr_1+1;
			sram_r=0;
			sram_g=0;
			sram_b=data[7:0];
			sram_r_ff_nxt=sram_r;
			sram_g_ff_nxt=sram_g;
			sram_b_ff_nxt=sram_b;
			sram_r_ff_ff_nxt=sram_r_ff;
			sram_g_ff_ff_nxt=sram_g_ff;
			sram_b_ff_ff_nxt=sram_b_ff;
			vga_r=sram_r_ff_ff;
			vga_g=sram_g_ff;
			vga_b=sram_b;				
		end
		SRAM_state_VGA_DISPLAY_0_SRAM_B_TRANS:
		begin
			sram_addr_1_nxt=sram_addr_1+1;
			sram_r=0;
			sram_g=0;
			sram_b=data[7:0];
			sram_r_ff_nxt=sram_r;
			sram_g_ff_nxt=sram_g;
			sram_b_ff_nxt=sram_b;
			sram_r_ff_ff_nxt=sram_r_ff;
			sram_g_ff_ff_nxt=sram_g_ff;
			sram_b_ff_ff_nxt=sram_b_ff;
			vga_r=sram_r_ff_ff;
			vga_g=sram_g_ff;
			vga_b=sram_b;			
		end
		
		SRAM_state_VGA_DISPLAY_1_SRAM_R:
		begin
			sram_addr_1_nxt=sram_addr_1+1;
			//sram_addr=sram_addr_2;
			sram_r=data[15:8];
			sram_g=0;
			sram_b=0;
			sram_r_ff_nxt=sram_r;
			sram_g_ff_nxt=sram_g;
			sram_b_ff_nxt=sram_b;
			sram_r_ff_ff_nxt=sram_r_ff;
			sram_g_ff_ff_nxt=sram_g_ff;
			sram_b_ff_ff_nxt=sram_b_ff;
			vga_r=vga_r_ff;
			vga_g=vga_g_ff;
			vga_b=vga_b_ff;			
		end
		SRAM_state_VGA_DISPLAY_1_SRAM_G:
		begin
			sram_addr_1_nxt=sram_addr_1+1;
			//sram_addr=sram_addr_2;
			sram_r=0;
			sram_g=data[15:8];
			sram_b=0;
			sram_r_ff_nxt=sram_r;
			sram_g_ff_nxt=sram_g;
			sram_b_ff_nxt=sram_b;
			sram_r_ff_ff_nxt=sram_r_ff;
			sram_g_ff_ff_nxt=sram_g_ff;
			sram_b_ff_ff_nxt=sram_b_ff;
			vga_r=vga_r_ff;
			vga_g=vga_g_ff;
			vga_b=vga_b_ff;				
		end
		SRAM_state_VGA_DISPLAY_1_SRAM_B:
		begin
			sram_addr_1_nxt=sram_addr_1+1;
			//sram_addr=sram_addr_2;
			sram_r=0;
			sram_g=0;
			sram_b=data[15:8];
			sram_r_ff_nxt=sram_r;
			sram_g_ff_nxt=sram_g;
			sram_b_ff_nxt=sram_b;
			sram_r_ff_ff_nxt=sram_r_ff;
			sram_g_ff_ff_nxt=sram_g_ff;
			sram_b_ff_ff_nxt=sram_b_ff;
			vga_r=sram_r_ff_ff;
			vga_g=sram_g_ff;
			vga_b=sram_b;				
		end		
		SRAM_state_VGA_DISPLAY_1_SRAM_B_TRANS:
		begin
			sram_addr_1_nxt=sram_addr_1;
			//sram_addr=sram_addr_2;
			sram_r=0;
			sram_g=0;
			sram_b=data[15:8];
			sram_r_ff_nxt=sram_r;
			sram_g_ff_nxt=sram_g;
			sram_b_ff_nxt=sram_b;
			sram_r_ff_ff_nxt=sram_r_ff;
			sram_g_ff_ff_nxt=sram_g_ff;
			sram_b_ff_ff_nxt=sram_b_ff;
			vga_r=sram_r_ff_ff;
			vga_g=sram_g_ff;
			vga_b=sram_b;			
		
		end		
		
		
		/*
		SRAM_state_VGA_BLACK_SRAM_WAIT_MINUS:
		begin
			sram_addr_nxt=sram_addr-1;
		end		
		SRAM_state_VGA_BLACK_SRAM_WAIT:
		begin

		end
		SRAM_state_VGA_BLANK_SRAM_WAIT_PRE_PRE:
		begin
		end		
		SRAM_state_VGA_BLANK_SRAM_WAIT_PRE:
		begin
			sram_addr_nxt=sram_addr+1;

		end
		*/
		SRAM_state_VGA_BLANK_SRAM_RESET:
		begin
			sram_r=0;
			sram_g=0;
			sram_b=0;
			sram_r_ff_nxt=0;
			sram_g_ff_nxt=0;
			sram_b_ff_nxt=0;
			sram_r_ff_ff_nxt=0;
			sram_g_ff_ff_nxt=0;
			sram_b_ff_ff_nxt=0;	
			sram_addr_1_nxt=0;
			sram_addr_2_nxt=OUTPUT_ADDR_INIT;		
		end
		default:
		begin

		end
	endcase
end

always@(posedge SRAM_CLK or posedge RST_N) begin //25
	if(RST_N) 
	begin
		sram_r_ff<=0;
		sram_g_ff<=0;
		sram_b_ff<=0;
		//sram_addr<=0;
		sram_addr_1<=0;
		sram_addr_2<=OUTPUT_ADDR_INIT;
		sram_r_ff_ff<=0;
		sram_g_ff_ff<=0;
		sram_b_ff_ff<=0;
		
	end
	else 
	begin
		sram_r_ff<=sram_r_ff_nxt;
		sram_g_ff<=sram_g_ff_nxt;
		sram_b_ff<=sram_b_ff_nxt;
		//sram_addr<=sram_addr_nxt;
		sram_addr_1<=sram_addr_1_nxt;
		sram_addr_2<=sram_addr_2_nxt;		
		sram_r_ff_ff<=sram_r_ff_ff_nxt;
		sram_g_ff_ff<=sram_g_ff_ff_nxt;
		sram_b_ff_ff<=sram_b_ff_ff_nxt;
		
	end
end

endmodule